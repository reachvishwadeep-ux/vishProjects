import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from langchain_core.callbacks import UsageMetadataCallbackHandler

from common.langchain_utils import get_web_search_model
from common.prompts import HOROSCOPE_WEB_SEARCH_PROMPT

model_with_tools = get_web_search_model()

callback = UsageMetadataCallbackHandler()

model_with_tools.invoke(HOROSCOPE_WEB_SEARCH_PROMPT,
                        config={"callbacks": [callback]})
print(callback.usage_metadata)
