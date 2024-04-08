# racerb

Ruby script to download the race results from IRONMAN / rtrt.me tracker website.

Data downloaded includes Name/Country/City/Bib/Age Group/Gender, the times for each segment (swim, t1, bike, t2, run) and the ranking (overall, by gender, by age group).

Data is stored as an Excel spreadsheet. Data is cached in the profiles folder, so that the script can be run multiple times without downloading the same data again.

This script is for personal use. Observe the API terms of rtrt.me: https://rtrt.me/docs/misc/acceptable-use

# Whats new

- Added some scripts to read data from Berlin Marathon and Halfmarathon.

# How to use

Clone this repo locally:

```
git clone https://github.com/coezbek/racerb.git
```

Install dependencies (description for Ubuntu):

```
# Needs chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb

# Install gems ferrum and axlsx
gem install ferrum axlsx
```

Edit ironman.rb to set the URL of your event to download (`event_result_url`)

Run the script:

```
ruby ironman.rb
```
