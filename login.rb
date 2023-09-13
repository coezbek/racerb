require 'ferrum'

#
# Login to the Ironman Tracker website and return the event name, app_id and token
#
# Needs Chrome:
# wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
# sudo apt install ./google-chrome-stable_current_amd64.deb
#
# Needs Ferrum Gem:
# gem install ferrum
#
# event_url for instance is: https://www.ironman.com/5150-erkner-results
#
def login(event_url)


  # Initialize a new browser instance
  browser = Ferrum::Browser.new(process_timeout: 60)# , js_errors: true) #browser_options: { "no-sandbox": nil, "headless": nil })

  # Set up request interception
  browser.network.intercept pattern: 'https://api.rtrt.me/*'

  app_id = nil
  token = nil
  event_name = nil

  # Define a request interception
  browser.on(:request) do |request|

    begin
      if request.url.match?(/api\.rtrt\.me\/events/) && request.method == 'POST' && !(app_id && token && event_name)

        event_name = request.url.match(/events\/([^\/]+)/)[1]

        # puts "Request method: #{request.method.inspect}"
        # puts "Request headers: #{request.headers.inspect}"

        post_data = request.instance_variable_get("@request")['postData']

        # puts post_data.inspect # "timesort=1&nohide=1&checksum=2c04a036e0fd3bb01a48aa781b6a4ba6&appid=5824c5c948fd08c23a8b4567&token=57D3466C3BF59955779C&max=10&catloc=1&cattotal=1&units=metric&source=webtracker"

        # Parse the post_data into a hash
        parsed_post_data = Hash[URI.decode_www_form(post_data)]

        # Extract app_id and token
        if app_id.nil? || token.nil?
          app_id = parsed_post_data['appid']
          token = parsed_post_data['token']
          puts "Got app_id and token from intercepted request to: #{request.url}"
          puts "App ID: #{app_id}"
          puts "Token: #{token}"
          puts "Event Name: #{event_name}"
          puts
        end
      end

    rescue => e
      puts "Error in Request intercept: #{e}"
      # Stacktrace
      puts e.backtrace
    end

    request.continue # Important: Don't forget to continue the request
  end

  # Navigate to the URL
  browser.goto(event_url)

  wait_time = 0

  while app_id.nil? && token.nil? && event_name.nil? && wait_time < 30
    sleep 5
    puts "Waiting for page to load... #{wait_time}"
    wait_time += 5
  end

  if event_name.nil?
    # Search for the iframe
    iframe_node = browser.at_xpath('//iframe[@id="rtframe"]')

    # Check if the iframe is found and extract the event name
    if iframe_node
      src_value = iframe_node.attribute('src')
      event_name = src_value.match(/event=([^&]+)/)[1]
      puts "Event Name: #{event_name}"
    else
      puts "iframe not found."
    end
  end

  # Close the browser
  browser.quit

  return event_name, app_id, token
end

