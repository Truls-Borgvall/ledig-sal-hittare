require 'pycall/import'
include PyCall::Import

pyimport :ruby_converter

data = ruby_converter.get_unoccupied_rooms

data = `python3 ruby_converter.py`
data = JSON.parse(data)
puts data
puts data[1]["room"]