# cocoaheads-repeating-meeting

This script allows the user to add regularly scheduled CocoaHeads meetings to cocoaheads.org in bulk. It assumes that the meeting occurs monthly on (for example) the second Thursday of every month. The day and week number are configurable, but the script will require customization if that is not the meeting pattern for your group. It also assumes that the time and location information for your meetings does not vary.

You define the following in a configuration file:

* The cocoaheads.org organizer username.
* The month and year of the first meeting to add.
* The number of meetings to add.
* The start time and end time of the meetings.
* The location as a string and as latitude + longitude. You can use http://www.gps-coordinates.net to get the coordinates of a location.
* Meeting details as a long multi-line string.

The script will add the meetings. It will avoid creating duplicates, assuming the duplicate meeting has the same start date and time.

To use this:

* Clone this repository.

```
git clone git@github.com:jbrayton/cocoaheads-repeating-meeting.git
```

* Navigate into the directory.

```
cd cocoaheads-repeating-meeting
```
    
* Copy "config.yaml.template" to "config.yaml".

```
cp config.yaml.template config.yaml
```
    
* Open config.yaml and customize it.

* Execute the script

```
./add_meetings
```

The script will ask you to confirm the details of the meetings and then add them.

Pull requests welcome.
