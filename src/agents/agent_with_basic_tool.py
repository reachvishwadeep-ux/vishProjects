# agent with basic tool
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from langchain.agents import create_agent
from langchain.tools import tool

from common.langchain_utils import get_chat_openai


@tool
def add_numbers(a:float, b:float) -> float:
    """
    This tool adds two numbers and returns the result.
    Use this tool when the user wants to add two numbers together.
    Args:
        a (float): The first number to add.
        b (float): The second number to add.
    Returns:
        float: The sum of the two numbers.
    
    """

    result = a+b
    return f"the result of adding {a} and {b} is {result}"


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
agent = create_agent(model, 
                     tools=[add_numbers],
                     system_prompt="you are a math assistant. " \
                     "Use the add_numbers tool to add two numbers when user asks" \
                     " for it.")

result = agent.invoke({"messages":[{"role":"user", "content":"what is 2+2 ?"}]})
print(result["messages"][-1].content)
