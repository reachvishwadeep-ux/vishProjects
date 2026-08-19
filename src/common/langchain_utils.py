"""LangChain model helpers shared by the agent/RAG examples."""

from typing import Any

from langchain.chat_models import init_chat_model
from langchain_openai import ChatOpenAI

from common.env import load_env

DEFAULT_AGENT_MODEL = "gpt-4o-mini"
DEFAULT_WEB_SEARCH_MODEL = "gpt-5.4-mini"


def get_chat_openai(
    model: str = DEFAULT_AGENT_MODEL,
    temperature: float = 0,
    **kwargs: Any,
) -> ChatOpenAI:
    """Return a ChatOpenAI model; temperature 0 keeps responses deterministic."""
    load_env()
    return ChatOpenAI(model=model, temperature=temperature, **kwargs)


def get_web_search_model(model: str = DEFAULT_WEB_SEARCH_MODEL):
    """Return a chat model with the server-side web_search tool bound."""
    load_env()
    return init_chat_model(model).bind_tools([{"type": "web_search"}])
