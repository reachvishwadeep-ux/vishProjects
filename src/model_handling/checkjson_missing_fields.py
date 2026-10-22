import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.json_utils import parse_json_response
from common.prompts import PRODUCT_REVIEW_FIELDS

my_json_response = """
{
        "sentiment": "neutral",
        "rating_estimate": 3,
        "key_issues": ["price high", "nothing special", "okay"],
        "would_recommend": false
}
"""

data = parse_json_response(my_json_response, required_fields=PRODUCT_REVIEW_FIELDS)

if data is not None:
    print(f"All Good JSON data: {data}")
