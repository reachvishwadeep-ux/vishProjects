# this file makes a simple connection to openai api using the openai python library. it is used to test the connection and to get a response from the api.  
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from langchain_openai import OpenAI

from common.env import require_env

require_env("OPENAI_API_KEY", "Enter OPENAI API Key")

llm = OpenAI()
response = llm.invoke("What is the capital of France?")
print(response)
