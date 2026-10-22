import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.json_utils import parse_json_response
from common.openai_utils import chat_completion
from common.prompts import COUNTRY_JSON_PROMPT

prompt = COUNTRY_JSON_PROMPT.format(country_name="Falkland Islands")

data = parse_json_response(chat_completion(prompt))

if data is not None:
    print(data["President"])
