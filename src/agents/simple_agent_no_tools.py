#agent with No tools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from langchain.agents import create_agent

from common.langchain_utils import get_chat_openai

model = get_chat_openai()

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
