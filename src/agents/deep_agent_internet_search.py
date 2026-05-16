import os
from typing import Literal
from tavily import TavilyClient
from deepagents import create_deep_agent
from dotenv import load_dotenv

load_dotenv()

tavily_client = TavilyClient()


def internet_search(query:str,
                    max_results: int=1,
                    search_engine: Literal["DuckDuckGo"] = "DuckDuckGo",
                    topic:Literal["news", "sports", "entertainment"] = "news",
                    include_raw_content:bool=False):
    """Search the web for recent information and return Tavily search results."""
    return tavily_client.search(query=query,
                                max_results=max_results,
                                search_engine=search_engine, 
                                topic=topic, 
                                include_raw_content=include_raw_content)


#print(tavily_client.search("what is the headline in timesofindia.com today?"))

#System prompt for the agent
research_instructions="""
You are an expert researcher. Your job is to conduct thorough research and then write a polished report.

You have access to an internet search tool as your primary means of gathering information.
#internet_search(query:str, max_results: int=5, search_engine: Literal["DuckDuckGo"] = 
# "DuckDuckGo", topic:Literal["news", "sports", "entertainment"] = "news", 
# include_raw_content:bool=False)

Use this to run an internet search for a given query. 
You can specify the max number of results to return, the topic, 
and whether raw content should be included.


"""

agent = create_deep_agent(model="gpt-4o-mini", 
                          tools=[internet_search],
                          system_prompt=research_instructions)

result = agent.invoke(
    {"messages":[{"role":"user","content":"What is taurus career horoscope for next week?"}]}
)

# Print the agent's response
print(result["messages"][-1].content)