from dotenv import load_dotenv
from langchain.chat_models import init_chat_model
from langchain_core.callbacks import UsageMetadataCallbackHandler

load_dotenv()

model = init_chat_model("gpt-5.4-mini")
tool = {"type": "web_search"}
model_with_tools = model.bind_tools([tool])

prompt = "What was Aquarious career Horoscope for tomorrow based on moon sign? give structured ouput" \
"as Date, Horoscope, and Source." \
"show output in indented form for better readability."

callback = UsageMetadataCallbackHandler()

response = model_with_tools.invoke(prompt, config={"callbacks": [callback]})
print(callback.usage_metadata)
