require 'highline/import'
require 'httpclient'
require "ice_cube"
require 'io/console'
require 'oga'
require 'yaml'

URL = "http://cocoaheads.org:8106/admin/"

DISPLAY_DATE_FORMAT = "%A, %B %d, %Y"
DISPLAY_TIME_FORMAT = "%l:%M %p"
DATE_INPUT_FORMAT = "%Y-%m-%d %H:%M"

###
# Ask the user to enter the cocoaheads.org password. Returns the entered password.
###
def prompt_for_password(config)
	print "URL: #{URL}\n"
	print "Username: #{config['username']}\n"
	print "Password: "
	password = STDIN.noecho(&:gets).chomp
	puts "\n"
	return password
end

###
# Log in to cocoaheads.org. Will exit the script if unable to confirm that the client is 
# logged in. If this exits successfully, assume that the user is logged in.
###
def login(config, http_client, password) 
	post_args =  { 'runnum' => '2', 'username' => config['username'], 'password' => password }
	login_response = http_client.post(URL, post_args)
	if login_response.content.include? "<h2>Please login:</h2>"
		puts "Unable to log in, probably because the username/password combination was incorrect."
		exit
	elsif !login_response.content.include? "<h3>Your Group</h3>"
		puts "Unable to determine whether the login was successful."
		exit
	end
end

###
# Returns a list of meeting dates based on the configuration.
###
def get_repeat_dates(config)
	start_date = Time.new(config['start_date_year'], Date::MONTHNAMES.index(config['start_date_month']), 1)
	day_symbol = config["day_of_week"].downcase.to_sym
	week_number = config['week_number']
	schedule = IceCube::Schedule.new
	schedule.add_recurrence_rule(
		IceCube::Rule.monthly.day_of_week(day_symbol => [week_number])
	)
	return schedule.next_occurrences(config['num_meetings'], start_date)
end

###
# Return the start time (date + time) of a meeting, based on the day of the configured 
# start time and the specified date.
###
def start_time(config, meeting_date) 
	return Time.parse(config['start_time'], meeting_date)
end

###
# Allow the user to confirm the information for the meetings.
###
def display_confirmation(config)
	puts
	puts "Meeting Dates:"
	repeat_dates = get_repeat_dates(config)
	repeat_dates.each do |d|
		puts "• " + start_time(config, d).strftime(DISPLAY_DATE_FORMAT)
	end
	puts
	puts "Start time: " + Time.parse(config['start_time']).strftime(DISPLAY_TIME_FORMAT).strip
	puts "End time: " + Time.parse(config['end_time']).strftime(DISPLAY_TIME_FORMAT).strip
	puts 
	puts "Location: #{config['location_string']}"
	puts 
	puts "Google Maps URL: http://maps.google.com/maps?q=#{config['latitude']},#{config['longitude']}"
	puts 
	puts "Meeting Details:\n#{config['meeting_details']}"
	puts
	
	# This snippet is from https://gist.github.com/botimer/2891186
	confirm = ask("Proceed? [Y/N] ") { |yn| yn.limit = 1, yn.validate = /[yn]/i }
	exit unless confirm.downcase == 'y'
end

###
# Retrieves the Group ID. This is needed to add the meetings.
###
def get_group_id(config, http_client)
	puts
	puts "Retrieving the Group ID…"
	response = http_client.get(URL, { 'rm' => 'scheduleeditor' })
	document = Oga.parse_html response.content
	group_id_element = document.at_xpath("//input[@name='groupid']")
	if group_id_element.nil?
		puts "Unable to find the Group ID."
		exit
	end
	value = group_id_element.attr('value')
	if value.nil?
		puts "Unable to find the Group ID."
		exit
	end
	return value
end

###
# Return the date in the format that cocoaheads.org expects it.
###
def get_ch_date(config, meeting_date, config_name)
	config = config[config_name]
	return Time.parse(config, meeting_date).strftime(DATE_INPUT_FORMAT)
end

###
# Add meetings.
###
def add_meetings(config, http_client)
	group_id = get_group_id(config, http_client)
	repeat_dates = get_repeat_dates(config)
	repeat_dates.each do |meeting_date|
		display_date = meeting_date.strftime(DISPLAY_DATE_FORMAT)
		puts "Adding #{display_date} meeting…"
		start_date_string = get_ch_date(config, meeting_date, 'start_time')
		end_date_string = get_ch_date(config, meeting_date, 'end_time')
		args = { 'runnum' => '2', 'rm' => 'scheduleeditor', 'groupid' => group_id, 'eventid' => '', 'startdate' => start_date_string, 'enddate' => end_date_string, 'location' => config['location_string'], 'latitude' => config['latitude'], 'longitude' => config['longitude'], 'locationdetails' => config['meeting_details'], 'newmeeting' => 'Create New Meeting...' } 
		http_client.post(URL, args)
	end
end

config = YAML.load_file('config.yaml')
http_client = HTTPClient.new
display_confirmation(config)
password = prompt_for_password(config)
login(config, http_client, password)
add_meetings(config, http_client)
puts "Done."
puts
puts "Important: This script has no way to validate that the meetings are added. Please verify through the user interface."
