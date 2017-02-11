require 'highline/import'
require 'httpclient'
require "ice_cube"
require 'io/console'
require 'yaml'

URL_PREFIX = "http://cocoaheads.org:8106/admin/"
LOGIN_URL = "http://cocoaheads.org:8106/admin/index.pl"


###
# Ask the user to enter the cocoaheads.org password. Returns the entered password.
###
def prompt_for_password(config)
	print "URL: #{URL_PREFIX}\n"
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
	login_response = http_client.post(LOGIN_URL, post_args)
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
		puts "• " + start_time(config, d).strftime("%A, %B %d, %Y")
	end
	puts
	puts "Start time: " + Time.parse(config['start_time']).strftime("%l:%M %p").strip
	puts "End time: " + Time.parse(config['end_time']).strftime("%l:%M %p").strip
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

config = YAML.load_file('config.yaml')
http_client = HTTPClient.new
display_confirmation(config)
password = prompt_for_password(config)
login(config, http_client, password)
puts "done"
