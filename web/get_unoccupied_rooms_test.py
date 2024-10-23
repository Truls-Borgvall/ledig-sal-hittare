def get_unoccupied_rooms_test():
    return [{"room": "204", "unoccupied_to": "12:50"}, {"room": "213", "unoccupied_to": "15:50"}]

if __name__ == "__main__":
    # Call the function and print the result so Ruby can capture it
    import json
    print(json.dumps(get_unoccupied_rooms_test()))