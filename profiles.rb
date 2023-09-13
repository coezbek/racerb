require_relative 'paginate.rb'

# Function to get all profiles
def get_profiles(event_name, app_id, token)
  get_all_paginated(event_name, 'profiles', app_id, token)
end
