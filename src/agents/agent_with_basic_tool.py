# agent with basic tool
from langchain.agents import create_agent
from langchain_openai import ChatOpenAI
from langchain.tools import tool
from dotenv import load_dotenv

load_dotenv()

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
agent = create_agent(model, 
                     tools=[add_numbers],
                     system_prompt="you are a math assistant. " \
                     "Use the add_numbers tool to add two numbers when user asks" \
                     " for it.")

result = agent.invoke({"messages":[{"role":"user", "content":"what is 2+2 ?"}]})
print(result["messages"][-1].content)




