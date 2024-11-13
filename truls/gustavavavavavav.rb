require "sinatra"
require "sinatra/reloader"
require 'httparty'
require 'date'
require 'json'

enable :sessions

def get_unoccupied_rooms(school_name, time = nil)
  # Set time to current time if not provided
  time ||= DateTime.now

  # Adjust weekday to match Skola24's weekday (Monday=1, Sunday=7)
  current_day = (time.wday + 6) % 7 + 1
  current_week = time.cweek

  unoccupied_rooms = []
  headers = {
    'Accept' => 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language' => 'sv-SE,sv;q=0.9,en-US;q=0.8,en;q=0.7',
    'Connection' => 'keep-alive',
    'Content-Type' => 'application/json',
    'Origin' => 'https://web.skola24.se',
    'Referer' => 'https://web.skola24.se/timetable/timetable-viewer/it-gymnasiet.skola24.se/NTI%20Johanneberg/',
    'Sec-Fetch-Dest' => 'empty',
    'Sec-Fetch-Mode' => 'cors',
    'Sec-Fetch-Site' => 'same-origin',
    'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'X-Requested-With' => 'XMLHttpRequest',
    'X-Scope' => '8a22163c-8662-4535-9050-bc5e1923df48',
    'sec-ch-ua' => '"Chromium";v="128", "Not;A=Brand";v="24", "Google Chrome";v="128"',
    'sec-ch-ua-mobile' => '?0',
    'sec-ch-ua-platform' => '"Windows"',
  }

  # Initialize session
  session = HTTParty::CookieHash.new

  # Get active school years
  json_data = {
    'hostName' => 'it-gymnasiet.skola24.se',
    'checkSchoolYearsFeatures' => false,
  }
  response = HTTParty.post('https://web.skola24.se/api/get/active/school/years', headers: headers, body: json_data.to_json)
  data = JSON.parse(response.body)
  year_guid = data['data']['activeSchoolYears'][0]['guid']

  # Get timetable viewer units
  json_data = {
    'getTimetableViewerUnitsRequest' => {
      'hostName' => 'it-gymnasiet.skola24.se',
    },
  }
  response = HTTParty.post('https://web.skola24.se/api/services/skola24/get/timetable/viewer/units', headers: headers, body: json_data.to_json)
  data = JSON.parse(response.body)
  units = data['data']['getTimetableViewerUnitsResponse']['units']
  school_unit = units.find { |unit| unit['unitId'] == school_name }
  school_name_guid = school_unit['unitGuid'] if school_unit

  # Get timetable selection
  json_data = {
    'hostName' => 'it-gymnasiet.skola24.se',
    'unitGuid' => school_name_guid,
    'filters' => {
      'class' => false,
      'course' => false,
      'group' => false,
      'period' => false,
      'room' => true,
      'student' => false,
      'subject' => false,
      'teacher' => false,
    },
  }
  response = HTTParty.post('https://web.skola24.se/api/get/timetable/selection', headers: headers, body: json_data.to_json)
  data = JSON.parse(response.body)
  rooms = data['data']['rooms']

  rooms.each do |room|
    # Get timetable render key
    response = HTTParty.post('https://web.skola24.se/api/get/timetable/render/key', headers: headers)
    data = JSON.parse(response.body)
    key = data['data']['key']

    # Get timetable
    json_data = {
      'renderKey' => key,
      'host' => 'it-gymnasiet.skola24.se',
      'unitGuid' => school_name_guid,
      'schoolYear' => year_guid,
      'startDate' => nil,
      'endDate' => nil,
      'scheduleDay' => current_day,
      'blackAndWhite' => false,
      'width' => 1206,
      'height' => 550,
      'selectionType' => 3,
      'selection' => room['eid'],
      'showHeader' => false,
      'periodText' => '',
      'week' => current_week,
      'year' => 2024,
      'privateFreeTextMode' => nil,
      'privateSelectionMode' => false,
      'customerKey' => '',
    }
    response = HTTParty.post('https://web.skola24.se/api/render/timetable', headers: headers, body: json_data.to_json)
    data = JSON.parse(response.body)
    schedule_data = data['data']['lessonInfo']

    clock_time = time.strftime('%H:%M:%S')

    occupied = false
    unoccupied_until = nil

    begin
      schedule_data.each do |entry|
        start_time = entry['timeStart']
        end_time = entry['timeEnd']

        if start_time <= clock_time && clock_time <= end_time
          occupied = true
          break
        elsif clock_time < start_time && (unoccupied_until.nil? || start_time < unoccupied_until)
          unoccupied_until = start_time
        end
      end

      unless occupied
        if unoccupied_until
          unoccupied_rooms << { 'name' => room['name'], 'unoccupied_until' => unoccupied_until[0, 5] }
        else
          unoccupied_rooms << { 'name' => room['name'], 'unoccupied_until' => '24:00' }
        end
      end
    rescue StandardError
      next
    end
  end
  return unoccupied_rooms
end

get("/") do
    erb :get_unoccupied_rooms
end

post("/get_unoccupied_rooms") do
    school_name = params[:school_name]
    time = params[:time]
    unoccupied_rooms = get_unoccupied_rooms(school_name, time)

    session[:unoccupied_rooms] = unoccupied_rooms
    redirect to("/unoccupied_rooms")
end

get("/unoccupied_rooms") do
    unoccupied_rooms = session[:unoccupied_rooms]
    erb :display_unoccupied_rooms, locals: {unoccupied_rooms: unoccupied_rooms}
end