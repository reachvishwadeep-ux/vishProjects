
import json
import sys
import openai
from dotenv import load_dotenv

load_dotenv()


prompt = """ Return the response in JSON format only.
    Example:
    {{
        "Country": "USA",
        "Capital": "Washington, D.C."
        "President": "Donald Trump"
    }}

    Now tell me about this country: {country_name}
    """


prompt = prompt.format(country_name="Falkland Islands")

client = openai.OpenAI()
response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[{"role":"user", "content":prompt}]
)

json_response = response.choices[0].message.content

if not isinstance(json_response, str) or not json_response.strip():
    print("Error: model returned an empty completion.")
    sys.exit(1)

try:
    data = json.loads(json_response)
except json.JSONDecodeError as e:
    print("Error decoding JSON:", e)
    print("Raw payload:", json_response)
    sys.exit(1)

if not isinstance(data, dict) or "President" not in data:
    print(f"Error: JSON response is missing the required 'President' field: {data}")
    sys.exit(1)

print(data["President"])
