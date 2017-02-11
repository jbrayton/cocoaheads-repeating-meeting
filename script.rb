require 'highline/import'
require 'httpclient'
require "ice_cube"
require 'io/console'
require 'oga'
require 'yaml'

URL = "http://cocoaheads.org:8106/admin/"

# The format used by the script to display a date (without the time) to the user.
DISPLAY_DATE_FORMAT = "%A, %B %e, %Y"

# The format used by the script to display a time (without the date) to the user.
DISPLAY_TIME_FORMAT = "%l:%M %p"

# The format in which cocoaheads.org expects dates and times of meetings.
DATE_INPUT_FORMAT = "%Y-%m-%d %H:%M"

# The format in which cocoaheads.org presents dates and times of meetings.
PAGE_DISPLAY_DATE_FORMAT = "%B %e, %Y %H:%M"

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
# logged in. If this exits successfully, the user is logged in.
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
# Return a list of meeting dates based on the configuration.
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
# Allow the user to confirm information for the meetings.
###
def display_confirmation(config)
	puts
	puts "Meeting Dates:"
	repeat_dates = get_repeat_dates(config)
	repeat_dates.each do |d|
		puts "• " + d.strftime(DISPLAY_DATE_FORMAT)
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
# Retrieve and return the meeting page as a DOM document.
###
def get_meeting_page_document(config, http_client)
	puts
	puts "Retrieving the meetings page…"
	response = http_client.get(URL, { 'rm' => 'scheduleeditor' })
	return Oga.parse_html response.content
end

###
# Retrieve the Group ID from the meeting page document.
# This is needed to add the meetings.
###
def get_group_id(meeting_page_document)
	group_id_element = meeting_page_document.at_xpath("//input[@name='groupid']")
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
# Return true if a meeting for the specified date is found in the document.
# Otherwise return false.
###
def get_meeting_date_found(config, meeting_page_document, meeting_date)
	config = config['start_time']
	formatted_date = Time.parse(config, meeting_date).strftime(PAGE_DISPLAY_DATE_FORMAT).gsub("  ", " ")
	return !meeting_page_document.at_xpath("//input[@value='#{formatted_date}']").nil?
end

###
# Return the date in the format that cocoaheads.org expects it.
###
def get_ch_input_date(config, meeting_date, config_name)
	config = config[config_name]
	return Time.parse(config, meeting_date).strftime(DATE_INPUT_FORMAT)
end

###
# Add meetings. Stop if adding a meeting appears to have failed. Tries to avoid creating
# duplicates.
###
def add_meetings(config, http_client)
	meeting_page_document = get_meeting_page_document(config, http_client)
	group_id = get_group_id(meeting_page_document)
	repeat_dates = get_repeat_dates(config)
	repeat_dates.each do |meeting_date|
		display_date = meeting_date.strftime(DISPLAY_DATE_FORMAT)
		if get_meeting_date_found(config, meeting_page_document, meeting_date)
			puts "Meeting for #{display_date} already found."
		else
			puts "Adding #{display_date} meeting…"
			start_date_string = get_ch_input_date(config, meeting_date, 'start_time')
			end_date_string = get_ch_input_date(config, meeting_date, 'end_time')
			args = { 'runnum' => '2', 'rm' => 'scheduleeditor', 'groupid' => group_id, 'eventid' => '', 'startdate' => start_date_string, 'enddate' => end_date_string, 'location' => config['location_string'], 'latitude' => config['latitude'], 'longitude' => config['longitude'], 'locationdetails' => config['meeting_details'], 'newmeeting' => 'Create New Meeting...' } 
			response = http_client.post(URL, args)
			response_document = Oga.parse_html response.content
			if !get_meeting_date_found(config, response_document, meeting_date) 
				puts "Should have added a meeting for #{display_date} but did not find one in the resulting document. Stopping."
				exit
			end
		end
	end
end

###
# Main body
###
config = YAML.load_file('config.yaml')
http_client = HTTPClient.new
display_confirmation(config)
password = prompt_for_password(config)
login(config, http_client, password)
add_meetings(config, http_client)
puts "Done."
