require 'nokogiri'
require 'open-uri'
require 'csv'

year = 2024

base_url = 'https://berlin.r.mikatiming.com/%{year}/?page=%{page}&event=BML&event_main_group=BMW+BERLIN+MARATHON&num_results=100&pid=list&search%%5Bsex%%5D=%{sex}&search%%5Bage_class%%5D=%%25'

# For Marathon:
event = 'BML' # Berlin Marathon Läufer
base_url = 'https://berlin.r.mikatiming.com/%{year}/?page=%{page}&event=BML&event_main_group=BMW+BERLIN+MARATHON&num_results=100&pid=list&search%%5Bsex%%5D=%{sex}&search%%5Bage_class%%5D=%%25'

# For Halbmarathon:
# Example: https://berlinerhm.r.mikatiming.net/2024/?page=2&event=HML&pid=list&pidp=start&search%5Bsex%5D=M&search%5Bage_class%5D=%25
event = 'HML' # Halfmarathon Läufer
base_url = 'https://berlinerhm.r.mikatiming.com/%{year}/?page=%{page}&event=HML&num_results=100&pid=list&search%%5Bsex%%5D=%{sex}&search%%5Bage_class%%5D=%%25'


def fetch_page(url)
  Nokogiri::HTML(URI.open(url))
end

def extract_data(page, sex)
  results = []
  page.css('li.list-group-item.row').each do |li|
    place = li.at_xpath('.//div[contains(@class, "type-place place-primary")]/text()').to_s.strip

    name = li.at_xpath('.//h4[contains(@class, "type-fullname")]/a/text()').to_s.strip

    next if name.empty?

    # start_number = li.at_xpath('.//div[contains(@class, "type-field")]/div[text()="Startnr."]/following-sibling::text()').to_s.strip

    start_number = li.at_xpath('.//div[contains(@class, "type-field") and div[contains(@class, "visible-xs-block") and (text()="Startnr." or text()="Number")]]/text()').to_s.strip

    age_class = li.at_xpath('.//div[contains(@class, "type-field") and div[contains(@class, "visible-xs-block") and (text()="AK" or text()="AC")]]/text()').to_s.strip

    club = li.at_xpath('.//div[contains(@class, "type-club") and div[contains(@class, "visible-xs-block") and (text()="Verein" or text()="Club")]]/text()').to_s.strip

    finish_time = li.at_xpath('.//div[contains(@class, "type-time")]/div[text()="Finish" or text()="Netto"]/following-sibling::text()').to_s.strip

    country = name.scan(/\((.*)\)/) [0][0]
    name = name.gsub(/\(.*\)/, '').strip

    sex = 'F' if sex == 'W'

    result = [place, name, country, start_number, age_class, club, finish_time, sex]
    if true # debug
      puts result.inspect
      #if result.any? { |s| s.strip == "" }
      #  System.exit(1)
      #end
    end

    results << result
  end
  results
end

# Saves the extracted data to an XLSX file
def save_to_xlsx(data, filename, worksheetname)
  require 'axlsx'
  Axlsx::Package.new do |p|
    p.workbook.add_worksheet(name: worksheetname) do |sheet|
      sheet.add_row ['ranking', 'name', 'countryCode', 'bibNumber', 'category', 'club', 'runTime', 'Sex']
      data.each { |row| sheet.add_row row }
    end
    p.serialize(filename)
  end
end

all_results = []

# Loop through pages and sexes
['M', 'W'].each do |sex|
  (1..).each do |page|  # Adjust the range based on the number of pages
    url = base_url % {page: page, sex: sex, year: year}
    puts "Fetching url: #{url}"
    page_data = fetch_page(url)
    results = extract_data(page_data, sex)
    if results.empty?
      break
    end
    puts "#{sex} - #{page} - Number of results: #{results.size}"
    all_results += results
  end
end

save_to_xlsx(all_results, "#{year}-#{event}_results.xlsx", "#{event} #{year}")
