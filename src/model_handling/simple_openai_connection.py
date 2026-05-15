# this file makes a simple connection to openai api using the openai python library. it is used to test the connection and to get a response from the api.  
import os
import getpass
from dotenv import load_dotenv
from langchain_openai import OpenAI


load_dotenv()
if("OPENAI_API_KEY" not in os.environ):
    os.environ["OPENAI_API_KEY"] = getpass.getpass("Enter OPENAI API Key")
else:
    OPEN_AI_API_KEY = os.getenv("OPENAI_API_KEY")


llm = OpenAI()
response = llm.invoke("What is the capital of France?")
print(response)






