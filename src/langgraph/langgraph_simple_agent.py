from langchain.tools import tool
from langchain.chat_models import init_chat_model

model = None
model_with_tools = None

@tool("add", return_direct=True)
def add(x:int, y:int) ->int:
    """Add two numbers together."""
    return x + y

@tool("subtract", return_direct=True)
def subtract(x:int, y:int) ->int:
    """Subtract two numbers."""
    return x - y

tools=[add, subtract]
tools_by_name = {tool.name: tool for tool in tools}

def _get_model_with_tools():
    global model, model_with_tools
    if model_with_tools is None:
        if model is None:
            model = init_chat_model("gpt-3.5-turbo", temperature=0.0)
        model_with_tools = model.bind_tools(tools)
    return model_with_tools

from langchain.messages import AnyMessage
from typing_extensions import TypedDict, Annotated
import operator

class MessageState(TypedDict):
    messages:Annotated[list[AnyMessage],operator.add]
    llm_calls:int

from langchain.messages import SystemMessage

def llm_call(state: dict):
    """LLM decides whether to call a tool or not"""

    return {
        "messages":[_get_model_with_tools().invoke(
            [
            SystemMessage(
                        content="You are a helpful assistant tasked with " \
                        "performing arithmetic on a set of inputs."
            )
            ] + state["messages"]
        )],

        "llm_calls": state["llm_calls"] + 1
    }

from langchain.messages import ToolMessage
def tool_node(state:dict):
    """If the LLM decided to call a tool, this node executes the tool and adds the result to the messages."""
    result = []
    for tool_call in state["messages"][-1].tool_calls:
        tool = tools_by_name[tool_call["name"]]
        observation = tool.invoke(tool_call["args"])
        result.append(ToolMessage(content=observation, tool_call_id=tool_call["id"]))
    
    return {"messages": result}


