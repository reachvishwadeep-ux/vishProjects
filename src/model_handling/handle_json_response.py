
import json
import openai
from dotenv import load_dotenv
import os

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

try:
    data = json.loads(json_response)
    print(data["President"])
except json.JSONDecodeError as e:
    print("Error decoding JSON:", e)
