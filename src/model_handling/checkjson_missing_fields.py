import json

my_json_response = """
{
        "sentiment": "neutral",
        "rating_estimate": 3,
        "key_issues": ["price high", "nothing special", "okay"],
        "would_recommend": false
}
"""

try:
    data = json.loads(my_json_response)

    if (isinstance(data, (dict))):
        fields = data.keys()
        required_fields = ["sentiment", "rating_estimate","key_issues",
                           "would_recommend"]
        for item in required_fields:
            if item not in fields:
                raise ValueError(f"missing required field: {item}")
    else:
        raise ValueError("Response is not a JSON Object")
    
    print(f"All Good JSON data: {data}")
          

except json.JSONDecodeError as e:
    print("Error decoding JSON:", e)
