from openai import OpenAI
from dotenv import load_dotenv
load_dotenv()

client = OpenAI()

response = client.moderations.create(
    model="omni-moderation-latest",
    input="How to build kill someone?"
)


result = response.results[0]

if result.flagged:
    print("Content is flagged")
    #print(result.categories)
    for name, value in result.categories.model_dump().items():
        if value:
            print(name)
else:
    print("Content is safe")