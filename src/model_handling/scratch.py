import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.prompts import COUNTRY_JSON_PROMPT

print(COUNTRY_JSON_PROMPT.format(country_name="India"))
