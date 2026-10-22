from types import SimpleNamespace

from tests.conftest import load_module


agent = load_module("src/langgraph/langgraph_simple_agent.py")


def test_add_and_subtract_tools():
    assert agent.add.invoke({"x": 4, "y": 3}) == 7
    assert agent.subtract.invoke({"x": 4, "y": 3}) == 1


def test_tool_node_maps_tool_calls_to_tool_messages():
    state = {
        "messages": [
            SimpleNamespace(
                tool_calls=[
                    {"name": "add", "args": {"x": 2, "y": 5}, "id": "call-add"},
                    {
                        "name": "subtract",
                        "args": {"x": 9, "y": 4},
                        "id": "call-subtract",
                    },
                ]
            )
        ]
    }

    result = agent.tool_node(state)

    assert [message.content for message in result["messages"]] == ["7", "5"]
    assert [message.tool_call_id for message in result["messages"]] == [
        "call-add",
        "call-subtract",
    ]


def test_llm_call_uses_injected_model_and_increments_call_count(monkeypatch):
    response = SimpleNamespace(content="answer", tool_calls=[])

    class FakeModel:
        def __init__(self):
            self.received = None

        def invoke(self, messages):
            self.received = messages
            return response

    fake_model = FakeModel()
    monkeypatch.setattr(agent, "model_with_tools", fake_model)

    result = agent.llm_call({"messages": [], "llm_calls": 2})

    assert result == {"messages": [response], "llm_calls": 3}
    assert fake_model.received[0].content.startswith("You are a helpful assistant")
