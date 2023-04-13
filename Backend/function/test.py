# import requests

# api = requests.get(
#     "https://vc28hwfjij.execute-api.us-east-1.amazonaws.com/test"
# )
# print(api.json())


batman = {
    'firstname': 'Bruce',
    'lastnamee': 'wayne'
}
item = batman["firstname"]
catman = {
    'firstname': item
}
print(item)
print(catman)