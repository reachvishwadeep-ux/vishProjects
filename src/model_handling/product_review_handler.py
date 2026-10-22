import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.json_utils import parse_json_response
from common.openai_utils import chat_completion, get_openai_client
from common.prompts import PRODUCT_REVIEW_FIELDS, PRODUCT_REVIEW_PROMPT

review_text_positive = """Absolutely love this laptop! 
Battery lasts all day and the keyboard feels great. 
Would buy again."""

review_text_negative = "Terrible experience. " \
"The screen flickered constantly, " \
"customer support was useless, " \
"and it died after 2 months. Never again."

review_text_neutral = "It’s okay I guess. Does the job but nothing special. " \
"The price feels a bit high for what you get."

client = get_openai_client()
for review_text in [review_text_positive, review_text_negative,
                    review_text_neutral]:
    prompt = PRODUCT_REVIEW_PROMPT.format(review_text=review_text)
    json_response = chat_completion(prompt, client=client)
    print(json_response)

    parse_json_response(json_response, required_fields=PRODUCT_REVIEW_FIELDS)
