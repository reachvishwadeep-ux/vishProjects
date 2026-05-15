import json

json_response_with_markdown = """ '''json
{
        "sentiment": "neutral",
        "rating_estimate": 3,
        "key_issues": ["price high", "nothing special", "okay"],
        "would_recommend": false
}
'''
"""

clean_jsosn_response = json_response_with_markdown.replace("'''json","").replace("'''","")

try:
    print(clean_jsosn_response)
    data = json.loads(clean_jsosn_response)
    
except json.JSONDecodeError as e:
    print("Error decoding JSON:", e)

