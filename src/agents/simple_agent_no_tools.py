#agent with No tools
from langchain.agents import create_agent
from langchain_openai import ChatOpenAI
from dotenv import load_dotenv

load_dotenv()

#set temperature to 0 for deterministic responses.
model = ChatOpenAI(model="gpt-4o-mini", temperature=0)

"""
under the hood, the create_agent will create an agent and do following steps:
build a model node,
build a tool node
edge model to tool
state handling
iteration handling
stop condition
"""
agent = create_agent(model, tools=[])

result = agent.invoke({"messages":[{"role":"user", "content":"what is 2+2 ?"}]})
print(result)




