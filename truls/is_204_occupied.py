import requests
from datetime import datetime, timedelta
import json

def get_schedule_data():
    session = requests.Session()
    
    headers = {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': 'sv-SE,sv;q=0.9,en-US;q=0.8,en;q=0.7',
        'Connection': 'keep-alive',
        'Content-Type': 'application/json',
        'Origin': 'https://web.skola24.se',
        'Referer': 'https://web.skola24.se/timetable/timetable-viewer/it-gymnasiet.skola24.se/NTI%20Johanneberg/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'X-Requested-With': 'XMLHttpRequest',
        'X-Scope': '8a22163c-8662-4535-9050-bc5e1923df48',
        'sec-ch-ua': '"Chromium";v="128", "Not;A=Brand";v="24", "Google Chrome";v="128"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
    }

    json_data = {
        'hostName': 'it-gymnasiet.skola24.se',
        'checkSchoolYearsFeatures': False,
    }
    response = session.post('https://web.skola24.se/api/get/active/school/years', headers=headers, json=json_data)
    data = response.json()
    year_guid = data['data']['activeSchoolYears'][0]['guid']


    json_data = {
        'getTimetableViewerUnitsRequest': {
            'hostName': 'it-gymnasiet.skola24.se',
        },
    }
    response = session.post('https://web.skola24.se/api/services/skola24/get/timetable/viewer/units', headers=headers, json=json_data)
    data = response.json()
    nti_johanneberg_guid = next(unit['unitGuid'] for unit in data['data']['getTimetableViewerUnitsResponse']['units'] if unit['unitId'] == 'NTI Johanneberg')
    #nti guid = MzMzODU1NjAtZGYyZS1mM2U2LTgzY2MtNDA0NGFjMmZjZjUw

    json_data = {
        'hostName': 'it-gymnasiet.skola24.se',
        'unitGuid': nti_johanneberg_guid,
        'filters': {
            'class': False,
            'course': False,
            'group': False,
            'period': False,
            'room': True,
            'student': False,
            'subject': False,
            'teacher': False,
        },
    }
    response = session.post('https://web.skola24.se/api/get/timetable/selection', headers=headers, json=json_data)
    data = response.json()
    room_eid_204 = next(room['eid'] for room in data['data']['rooms'] if room['name'] == '204')

    json_data = None
    response = session.post('https://web.skola24.se/api/get/timetable/render/key', headers=headers, json=json_data)
    data =response.json()
    key = data['data']['key']

    json_data = {
        'renderKey': key,#'8Cwray_A1HVYgPUAhD7_SM5ZXClAiEAmn8WBBqYXq1QX-NebheYJzqFcBrSssuB9ZIvnPfV-xFpHsHnaJhLzMlMUEenq5vLgWFjatgmGcAkP5GvOlO635mSG4Z6iA0kG'
        'host': 'it-gymnasiet.skola24.se',
        'unitGuid': nti_johanneberg_guid,
        'schoolYear': year_guid,
        'startDate': None,
        'endDate': None,
        'scheduleDay': 0,
        'blackAndWhite': False,
        'width': 1206,
        'height': 550,
        'selectionType': 3,
        'selection': room_eid_204,
        'showHeader': False,
        'periodText': '',
        'week': 37,
        'year': 2024,
        'privateFreeTextMode': None,
        'privateSelectionMode': False,
        'customerKey': '',
    }
    response = session.post('https://web.skola24.se/api/render/timetable', headers=headers, json=json_data)
    data = response.json()
    schedule_data = data["data"]["lessonInfo"]
    return schedule_data

# Helper function to convert time strings to datetime.time
def parse_time(time_str):
    return datetime.strptime(time_str, '%H:%M:%S').time()

# Function to check room availability
def check_room_availability(schedule_data, date_time=None):
    if date_time is None:
        date_time = datetime.now()  # Default to current time

    current_day = date_time.weekday() + 1  # Get day of the week (1=Monday, 7=Sunday)
    current_time = date_time.time()        # Get the current time

    occupied = False
    unoccupied_until = None

    for entry in schedule_data:
        if entry['dayOfWeekNumber'] == current_day:
            start_time = parse_time(entry['timeStart'])
            end_time = parse_time(entry['timeEnd'])

            if start_time <= current_time <= end_time:
                occupied = True
                break
            elif current_time < start_time and (unoccupied_until is None or start_time < unoccupied_until):
                unoccupied_until = start_time

    if occupied:
        return "Room is currently occupied."
    elif unoccupied_until:
        time_until_next_occupation = datetime.combine(date_time.date(), unoccupied_until) - date_time
        return f"Room is unoccupied for the next {time_until_next_occupation}."
    else:
        return "Room is unoccupied for the rest of the day."

# Example usage
schedule_data = get_schedule_data()
print(check_room_availability(schedule_data))