"""Vector similarity helpers (no numpy/sklearn dependency)."""

from collections.abc import Sequence
from typing import Any


def cosine_similarity(a: Sequence[float], b: Sequence[float]) -> float:
    """Cosine similarity between two equally sized vectors."""
    dot_product = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x ** 2 for x in a) ** 0.5
    norm_b = sum(y ** 2 for y in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot_product / (norm_a * norm_b)


def top_matches(
    query_embedding: Sequence[float],
    entries: Sequence[tuple[Any, Sequence[float]]],
    top_n: int = 1,
) -> list[tuple[Any, float]]:
    """Rank ``(payload, embedding)`` pairs by similarity, highest score first."""
    scored = [
        (payload, cosine_similarity(query_embedding, embedding))
        for payload, embedding in entries
    ]
    scored.sort(key=lambda item: item[1], reverse=True)
    return scored[:top_n]
