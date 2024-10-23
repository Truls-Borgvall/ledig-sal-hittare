require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'pycall/import'
include PyCall::Import
require 'json'

# pyimport :get_unoccupied_rooms_test

# data = get_unoccupied_rooms_test.get_unoccupied_rooms

current_time = Time.now
puts current_time

get '/viewer' do
  slim :home
end


data = `python3 get_unoccupied_rooms_test.py`
data = JSON.parse(data)
puts data
puts data[1]["room"]

