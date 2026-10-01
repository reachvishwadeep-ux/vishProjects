import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.openai_utils import get_openai_client

client = get_openai_client()

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
