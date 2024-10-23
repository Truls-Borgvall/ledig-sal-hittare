require 'json'

data = `python ruby_converter.py` #How to add arguments??
data = JSON.parse(data)
puts data
puts data[1]["room"]