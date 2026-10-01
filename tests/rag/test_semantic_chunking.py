from types import SimpleNamespace

import pytest

from tests.conftest import load_module


semantic_chunking = load_module("src/rag/semantic_chunking.py")


class FakeEmbeddings:
    def __init__(self, vectors):
        self.vectors = vectors

    def create(self, model, input):
        values = input if isinstance(input, list) else [input]
        return SimpleNamespace(
            data=[SimpleNamespace(embedding=self.vectors[value]) for value in values]
        )


def test_chunk_text_boundaries_and_empty_input():
    assert semantic_chunking.chunk_text("abcdefghij", 6, 2) == [
        "abcdef",
        "efghij",
        "ij",
    ]
    assert semantic_chunking.chunk_text("", 6, 2) == []


def test_get_embeddings_uses_the_expected_model_and_returns_vectors(monkeypatch):
    fake_client = SimpleNamespace(
        embeddings=FakeEmbeddings({"one": [1, 0], "two": [0, 1]})
    )
    monkeypatch.setattr(semantic_chunking, "client", fake_client)

    assert semantic_chunking.get_embeddings(["one", "two"]) == [[1, 0], [0, 1]]


def test_semantic_search_ranks_results_and_preserves_ties(monkeypatch):
    fake_client = SimpleNamespace(
        embeddings=FakeEmbeddings(
            {
                "query": [1, 1],
                "first": [1, 0],
                "second": [0, 1],
                "best": [1, 1],
            }
        )
    )
    monkeypatch.setattr(semantic_chunking, "client", fake_client)
    semantic_chunking.vector_store[:] = [
        {"text": "first", "embedding": [1, 0]},
        {"text": "second", "embedding": [0, 1]},
        {"text": "best", "embedding": [1, 1]},
    ]

    results = semantic_chunking.semantic_search("query", top_k=3)

    assert [result["text"] for result in results] == ["best", "first", "second"]
    assert results[0]["score"] == pytest.approx(1.0)
    assert semantic_chunking.semantic_search("query", top_k=2)[1]["text"] == "first"
