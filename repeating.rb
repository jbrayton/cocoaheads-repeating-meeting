require 'yaml'
require 'io/console'
require 'httpclient'

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
	post_args =  "runnum=2&username=#{config['username']}&password=#{password}"
	login_response = http_client.post(LOGIN_URL, post_args)
	if login_response.content.include? "<h2>Please login:</h2>"
		puts "Unable to log in, probably because the username/password combination was incorrect."
		exit
	elsif !login_response.content.include? "<h3>Your Group</h3>"
		puts "Unable to determine whether the login was successful."
		exit
	end
end



config = YAML.load_file('config.yaml')
http_client = HTTPClient.new
password = prompt_for_password(config)
login(config, http_client, password)
puts "continuing...\n"