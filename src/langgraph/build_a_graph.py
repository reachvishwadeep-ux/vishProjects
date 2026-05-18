from typing import TypedDict,Annotated,List
from langgraph.graph import StateGraph, END
import operator

#1. Define the agent state
class AgentState(TypedDict):
    messages:Annotated[List[str],operator.add]
    revision_count:int
    is_valid:bool

#2. Define node1
def research_node(state:AgentState) ->AgentState:
    """This node performs a research step and adds the result to the messages."""
    return {"messages":["Research data"],"revision_count":state["revision_count"]+1,
            "is_valid":state["is_valid"]}

#3. Define node2
def validator_node(state:AgentState)->AgentState:
    """This node validates the research data and updates the state accordingly."""
    is_valid = state["messages"][-1] == "Research data"

    return {"messages":state["messages"] + ["Validation result"],"revision_count":state["revision_count"],
            "is_valid":is_valid}

#4. Build the graph
workflow = StateGraph(AgentState)
workflow.add_node("research", research_node)
workflow.add_node("validate", validator_node)

workflow.set_entry_point("research")
workflow.add_edge("research", "validate")

# The Cycle: if not valid and under 3 trials, go back, go back to research
workflow.add_conditional_edges(
    "validate", 
    lambda state: "research" if not state["is_valid"] and state["revision_count"] < 3 else END     

)

app = workflow.compile()

from IPython.display import Image
try:
    print(app.get_graph().draw_ascii())
    Image(app.get_graph().draw_mermaid_png())
    
except ImportError:
    print(app.get_graph())
