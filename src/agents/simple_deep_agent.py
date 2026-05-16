from deepagents import create_deep_agent
from dotenv import load_dotenv

load_dotenv()

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


