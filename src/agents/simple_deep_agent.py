import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from deepagents import create_deep_agent

from common.env import load_env

load_env()

def getWeather(city:str) ->str:
    """Get Weather for a given city"""

    return f"Its always Sunny in {city}"

agent = create_deep_agent(model="gpt-3.5-turbo", tools=[getWeather], 
                          system_prompt="Your are an helpful assistant that " \
                          "provides weather information")

response =agent.invoke(
    {"messages":[{"role":"user","content":"Whats the weather in New York?"}]}
)

print(response)
