"""Thin wrappers around the OpenAI SDK used across the examples."""

from collections.abc import Sequence

from openai import OpenAI

from common.env import load_env

DEFAULT_CHAT_MODEL = "gpt-3.5-turbo"
DEFAULT_EMBEDDING_MODEL = "text-embedding-3-small"


def get_openai_client() -> OpenAI:
    """Return an OpenAI client with .env credentials loaded."""
    load_env()
    return OpenAI()


def chat_completion(
    prompt: str,
    model: str = DEFAULT_CHAT_MODEL,
    client: OpenAI | None = None,
) -> str:
    """Send a single user prompt and return the assistant message content."""
    client = client or get_openai_client()
    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.choices[0].message.content


def embed_texts(
    texts: Sequence[str],
    model: str = DEFAULT_EMBEDDING_MODEL,
    client: OpenAI | None = None,
) -> list[list[float]]:
    """Embed a batch of texts."""
    client = client or get_openai_client()
    response = client.embeddings.create(model=model, input=list(texts))
    return [item.embedding for item in response.data]


def embed_text(
    text: str,
    model: str = DEFAULT_EMBEDDING_MODEL,
    client: OpenAI | None = None,
) -> list[float]:
    """Embed a single text."""
    return embed_texts([text], model=model, client=client)[0]
