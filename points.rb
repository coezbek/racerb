require 'json'
require 'set'

# Analyzes a given list of (way/split)points of one or more 'courses' of a race event.
#
# Returns a hash of 'course' name to Array of Race segments with the total length of the segment and the names of all splits in the segment
#
# @example
#   analyze_points([
#     {'course' => 'ironman5150', 'segment' => 'swim', 'km' => 1.5, 'name' => 'SWIM'},
#     {'course' => 'ironman5150', 'segment' => 'transition', 'km' => 1.78, 'name' => 'T1'}
#   ])
#   # => { "ironman5150" =>
#          { "swim" => { :distance => 1.5, :split_points => ["SWIM"] },
#          { "transition" => { :distance => 0.28, :split_points => ["T1"] },
#          { "total" => { :distance => 1.78, :split_points => ["SWIM", "T1"] }
#        }
def analyze_points(data)

  results = {}

  data.group_by { |e| e['course'] }.each do |course, events|

    results[course] = {}

    # Sort just in case
    sorted_events = events.sort_by { |e| e['km'].to_f }

    previous_km = 0.0
    sliced_segments = sorted_events.slice_when { |a,b| a['segment'] != b['segment'] }

    # Count occurrences of each segment type
    max_segment_counts = Hash.new(0)
    sliced_segments.each { |segments| max_segment_counts[segments.last['segment']] += 1 }

    cur_segment_counts = Hash.new(0)

    sliced_segments.each do |segments|

      last_km = segments.last['km'].to_f.round(3)

      segment_name = segments.last['segment']
      cur_segment_counts[segment_name] += 1
      if max_segment_counts[segment_name] > 1
        segment_name = segment_name + "#{cur_segment_counts[segment_name]}"
      end

      results[course][segment_name] = {
        distance: (last_km - previous_km).round(3),
        split_points: segments.map { |a| a['name'] }
      }
      previous_km = last_km
    end

    results[course]['total'] = {
        distance: previous_km.round(3),
        split_points: sorted_events.map { |a| a['name'] }
      }

  end

  return results

end

return if $0 != __FILE__

data = JSON.parse(File.read('points.json'))['list']

pp analyze_points(data)