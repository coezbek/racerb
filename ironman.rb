
require 'net/http'
require 'json'
require 'fileutils'
require 'uri'
require 'set'
require_relative 'points.rb'
require_relative 'paginate.rb'

#
# Download all race results from the IRONMAN / IRONMAN tracker website for the following race:
#

event_result_url = "https://www.ironman.com/im703-erkner-results" #'https://www.ironman.com/5150-erkner-results'

# Alternatively provide the URL at https://track.rtrt.me/e/<event>

event_result_url = 'https://track.rtrt.me/e/IRM-ERKNER703-2023'

# Note:
#  * IRONMAN disables the tracker 2 days after the race, then you need to use the track.rtrt.me URL.
#  * The tracker does not disqualify people automatically, so you need to check the results for DNFs and DQs or obvious bogus times (such as a short swim)
#  * Only segment results are reported (SWIM, T1, BIKE, T2, RUN), no splits (BIKE1,2,3,etc.)
#  * The ranking information (e.g. 1st in age group of 47 participants) can be inconsistent, e.g.
#    some participants might have been disqualified and their ranking is thus empty, but they are still included in the total.
#    Also RELAY participants are still included in the total.

# Options:
# 1.) Set to false, if results should include RELAY participants
remove_relay = true

#
# Prerequisites:
#  1.) headless chrome
#
#  2.) The following Gems:
#      ferrum, axlsx
#

#
# If you don't want to install headless chrome and use ferrum to log in to IRONMAN side automatically, you can also do the following manually in Chrome:
#
# 1.) To get the event_name you can also use the following method:
#
#  * Open the DevTools in Chrome (you can do this by right-clicking on the page and selecting "Inspect" or by pressing F12 or Cmd+Opt+I on Mac).
#  * Go to the Console tab.
#  * Paste the JavaScript code below and press Enter.
#
#    var iframeSrc = document.querySelector("#rtframe").src;
#    var eventName = new URL(iframeSrc).searchParams.get("event");
#    console.log("Event Name: " + eventName);
#
# 2.) To get the app_id and token you can also use the following method:
#  * Open the DevTools in Chrome (you can do this by right-clicking on the page and selecting "Inspect" or by pressing F12 or Cmd+Opt+I on Mac).
#  * Go to the Network tab.
#  * Reload the page.
#  * Filter the requests for api.rtrt.me
#  * Go to Payload of any of the requests (such as conf, SWIM, etc.) and copy the appid and token parameters.

#
# Documentation of the RTRT API: https://rtrt.me/docs/api/rest
#

#
# Todos:
# * Add some event information (distances, etc.) from the points endpoint: https://api.rtrt.me/events/<event>/points
#

app_id = nil     # e.g. '5824c5c948fd08c23a8b4567'
token = nil      # e.g. '93258F60E91BA997E394'
event_name = nil # e.g. 'IRM-ERKNER5150-2023'
if app_id == nil || token == nil || event_name == nil
  require_relative 'login.rb'

  event_name, app_id, token = login(event_result_url)
end

# Create the directory for storing the JSON files if it doesn't exist
event_folder = File.join('profiles', event_name.downcase)
FileUtils.mkdir_p(event_folder)

#### PROFILES

# Define the path for the profiles JSON file
profile_file_path = File.join(event_folder, 'profiles.json')

# Fetch profiles only if the file doesn't already exist
unless File.exist?(profile_file_path)
  puts "Fetching profiles..."
  require_relative 'profiles.rb'
  File.write(profile_file_path, JSON.pretty_generate(get_profiles(event_name, app_id, token)))
end

# Load the profile data from profile.json
profile_data = JSON.parse(File.read(profile_file_path))
puts "Loaded #{profile_data.size} profiles from #{profile_file_path}"

#### POINTS

# Define the path for the points JSON file
points_file_path = File.join(event_folder, 'points.json')

# Fetch profiles only if the file doesn't already exist
unless File.exist?(points_file_path)
  puts "Fetching points..."
  require_relative 'points.rb'
  File.write(points_file_path, JSON.pretty_generate(get_all_paginated(event_name, 'points', app_id, token)))
end

# Load the profile data from profile.json
point_data = JSON.parse(File.read(points_file_path))
puts "Loaded #{point_data.size} points from #{points_file_path}"

######################################
# Print some infos about this race:

course_data = analyze_points(point_data)

course_data.each do |course_name, course|
  puts "Course: #{course_name}"
  course.each do |segment_name, segment|
    puts "  Segment: #{segment_name}"
    puts "    Distance: #{segment[:distance]} km"
    puts "    Split Points: #{segment[:split_points].join(', ')}"

  end
end

######################################

# Parameters to include in the request
params = {
  'appid' => app_id,
  'token' => token,
  'max' => 2000,
  'loc' => 1,
  'cbust' => 0.6730120746296351,
  'places' => 2,
  'etimes' => 1,
  'units' => 'metric',
  'source' => 'webtracker'
}


# Initialize sets for unique divisions and courses
unique_divisions = Set.new
unique_courses = Set.new
unique_legs = Set.new

# Initialize a hash to store participant (PID) information
pids_data = {}

# Initialize an array to hold groups of profile IDs (up to 10 at a time)
profile_id_groups_to_fetch = []

# Determine which profiles need to be fetched
missing_profiles = profile_data.select do |profile|
  !File.exist?(File.join(event_folder, "splits", "#{profile['pid']}.json"))
end

# Iterate over the profile_data to create groups of up to 10 profile IDs
missing_profiles.each_slice(10) do |group|
  profile_ids = group.map { |profile| profile['pid'] }
  profile_id_groups_to_fetch << profile_ids
end

FileUtils.mkdir_p(File.join(event_folder, "splits"))

# Iterate over the profile_data to fetch the splits for each profile
profile_id_groups_to_fetch.each_with_index do |profile_group, i|

  puts "Fetching group #{i}: #{profile_group}"

  # Prepare the URL and API call
  base_url = "https://api.rtrt.me/events/#{event_name}/profiles/"
  profile_id = profile_group.join(',')

  uri = URI("#{base_url}#{profile_id}/splits")
  uri.query = URI.encode_www_form(params)

  # Perform the API request
  response = Net::HTTP.get(uri)

  # Parse and save the JSON response
  json_data = JSON.parse(response)

  # Split 'list' by 'pid' and save each participant's data to a separate file
  json_data['list'].group_by { |entry| entry['pid'] }.each do |pid, entries|
    file_path = File.join(event_folder, "splits", "#{pid}.json")
    File.write(file_path, JSON.pretty_generate({ "list" => entries}))
  end

  # Sleep for 1 seconds to rate-limit the requests
  # sleep(1)
end

def strip_milliseconds(time_str)
  # Use a regular expression to check if the time string matches the expected format
  if time_str =~ /^(\d{2}:\d{2}:\d{2})\.\d{1,3}$/
    # Remove the milliseconds part
    time_str = $1
  end

  return time_str
end

profile_data.each do |profile|

  file_path = File.join(event_folder, "#{profile['pid']}.json")

  if File.exist?(file_path)

    data = JSON.parse(File.read(file_path))

    # Iterate through each entry in the 'list'
    data['list'].each do |entry|
      pid = entry['pid']

      # Initialize participant information if not already present
      pids_data[pid] ||= {
        'pid' => pid,
        'name' => entry['name'],
        'sex' => entry['sex'],
        'division' => entry['division'],
        'course' => entry['course'],
        'country' => entry['country'],
        'city' => entry['city'],
        'bib' => entry['bib'],
        'startTime' => entry['startTime'],
      }

      # Add leg information, pace, etc. to the participant information
      leg = entry['point'].gsub('4184','')

      legmap = {
        'SWIM' => {
          'swimTime' => ['legTime'],
          'swimPace' => ['paceAvg']
        },
        'T1' => {
          't1Time' => ['legTime'],
        },
        'BIKE' => {
          'bikeTime' => ['legTime'],
          'bikePace' => ['paceAvg']
        },
        'T2' => {
          't2Time' => ['legTime'],
        },
        'FINISH' => {
          'runTime' => ['legTime'],
          'runPace' => ['paceAvg'],
          'totalTime' => ['netTime'],
          'overallRank' => ['results', 'course', 'p'],
          'overallParticipants' => ['results', 'course', 't'],
          'genderRank' => ['results', 'course-sex', 'p'],
          'genderParticipants' => ['results', 'course-sex', 't'],
          'ageGroupRank' => ['results', 'course-sex-division', 'p'],
          'ageGroupParticipants' => ['results', 'course-sex-division', 't']
        },
      }

      if legmap.keys.include?(leg)
        legmap[leg].each do |key, value|
          pids_data[pid][key] = strip_milliseconds(entry.dig(*value))
        end
        #pids_data[pid][leg.downcase+"Time"] = entry['legTime']
        #pids_data[pid][leg.downcase+"Pace"] = entry[legmap[leg]] if legmap[leg]
      end

      # Add division and course to the sets of unique divisions and courses
      unique_divisions.add(entry['division'])
      unique_courses.add(entry['course'])
      unique_legs.add(leg)
    end
  end
end

# Sort by finish time
pids_data = pids_data.values.sort_by { |attributes| attributes['totalTime'] || '99:99:99' }

# Output unique divisions and courses
puts "Unique Divisions: #{unique_divisions.to_a.sort.join(', ')}"
puts "Unique Courses: #{unique_courses.to_a.join(', ')}"
puts "Unique Legs: #{unique_legs.to_a.join(', ')}"

# Output participant information

unique_attributes = Set.new
pids_data.each { |attributes| unique_attributes.merge(attributes.keys) }

#puts unique_attributes.to_a.join("\t")
#
#pids_data.each do |pid, attributes|
#
#  puts (unique_attributes.map do |key|
#    "#{attributes[key]}"
#  end.join("\t"))
#
#end

require 'axlsx'

puts "Serializing to Excel..."

# Initialize the Axlsx package
p = Axlsx::Package.new
wb = p.workbook

unique_courses.to_a.each { |course_name|

  # Add a worksheet
  wb.add_worksheet(name: "results_#{course_name}") do |sheet|

    # Filter the pids_data by course and remove RELAY participants if requested
    course_pids_data = pids_data.select { |attributes|
      attributes['course'] == course_name &&
      (remove_relay ? attributes['division'] != 'RELAY' : true)
    }

    # Identify unique attributes across all participants
    unique_attributes = Set.new
    course_pids_data.each { |attributes| unique_attributes.merge(attributes.keys) }

    # Add the header row
    sheet.add_row(unique_attributes.to_a)

    # Add the data rows
    row_idx = 0
    course_pids_data.each do |attributes|
      sheet.add_row(unique_attributes.map { |key| attributes[key] })
      row_idx += 1
    end

    # Define the table range considering header row
    table_range = "A1:#{Axlsx::col_ref(unique_attributes.size - 1)}#{row_idx + 1}"

    # Add a table to the sheet based on the data range
    sheet.add_table(table_range, :name => "RaceResult#{course_name}", :display_name => "Race Result #{course_name}")
  end

}

# Serialize to file with event name

excel_name = "race_data_#{event_name.downcase}.xlsx"
p.serialize(excel_name)
puts " -> Serialized to #{excel_name}"

