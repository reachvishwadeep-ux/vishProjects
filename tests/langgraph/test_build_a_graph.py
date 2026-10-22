from tests.conftest import load_module


build_a_graph = load_module("src/langgraph/build_a_graph.py")


def test_research_node_increments_revision_and_adds_data():
    state = {
        "messages": ["old"],
        "revision_count": 1,
        "is_valid": False,
        "total_cost": 0.5,
        "max_budget": 1.0,
    }

    assert build_a_graph.research_node(state) == {
        "messages": ["Research data"],
        "revision_count": 2,
        "is_valid": False,
    }


def test_validator_node_sets_validity_from_latest_message():
    state = {
        "messages": ["Research data"],
        "revision_count": 2,
        "is_valid": False,
        "total_cost": 0.5,
        "max_budget": 1.0,
    }

    result = build_a_graph.validator_node(state)

    assert result["messages"] == ["Research data", "Validation result"]
    assert result["revision_count"] == 2
    assert result["is_valid"] is True

    state["messages"] = ["other"]
    assert build_a_graph.validator_node(state)["is_valid"] is False


def test_financial_guardrail_stops_at_budget_boundary():
    state = {"total_cost": 1.0, "max_budget": 1.0}
    assert build_a_graph.financial_guardrail(state) == "hard_stop"
    state["total_cost"] = 0.99
    assert build_a_graph.financial_guardrail(state) == "continue"
