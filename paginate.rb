require 'net/http'
require 'uri'
require 'json'
require 'pp'  # Pretty print

# Function to get entries in a single batch
#
# Returns a tuple of entry_list (maybe []) and last_fetched (maybe nil)
def get_paginated_once(event_name, endpoint, app_id, token, start = 1, max = 100)

  puts "Getting entries for #{event_name}/#{endpoint}: from #{start} (max = #{max})."
  base_url = "https://api.rtrt.me/events/#{event_name}/#{endpoint}"

  # Initial query parameters
  params = {
    'appid' => app_id,
    'token' => token,
    'max' => max,
    'start' => start,  # Include start parameter
    'loc' => 1,
    'cbust' => Random.rand,
    'places' => 2,
    'etimes' => 1,
    'units' => 'metric',
    'source' => 'webtracker'
  }

  # Build the URL with parameters
  uri = URI.parse(base_url)
  uri.query = URI.encode_www_form(params)

  # Make the request
  response = Net::HTTP.get_response(uri)

  # Parse the JSON response
  parsed_response = JSON.parse(response.body)

  # Extract 'list' and 'info' from the parsed response
  entry_list = parsed_response['list'] || []
  info = parsed_response['info']
  last_fetched = info['last']&.to_i

  # Print for debugging
  # pp info

  # Return the list and the last index fetched
  [entry_list, last_fetched]
end

# Function to get all entries of the given event and endpoint (profiles or points)
def get_all_paginated(event_name, endpoint, app_id, token)
  all_entries = []
  start = 1
  max = 100  # You can change this to up to 1000 if you are authenticated

  while true
    entry_list, last_fetched = get_paginated_once(event_name, endpoint, app_id, token, start, max)

    # Add the fetched entries to all_entries
    all_entries.concat(entry_list)

    # Exit loop if no more entries
    break if last_fetched == nil || entry_list.size == 0

    # Update start for the next batch
    start = last_fetched + 1
  end

  return all_entries
end
