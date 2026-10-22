import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.json_utils import parse_json_response, strip_code_fences

json_response_with_markdown = """ '''json
{
        "sentiment": "neutral",
        "rating_estimate": 3,
        "key_issues": ["price high", "nothing special", "okay"],
        "would_recommend": false
}
'''
"""

print(strip_code_fences(json_response_with_markdown))

data = parse_json_response(json_response_with_markdown)
print(data)
