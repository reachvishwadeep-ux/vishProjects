from types import SimpleNamespace

import pytest

from tests.conftest import load_module


rag = load_module("src/rag/rag_from_scratch.py")


class FakeOllama:
    def __init__(self):
        self.vectors = {
            "alpha": [1, 0],
            "beta": [0, 1],
            "delta": [0, 1],
            "gamma": [1, 1],
            "query": [1, 0],
        }

    def embed(self, model, input):
        return {"embeddings": [self.vectors[input]]}


def test_cosine_similarity_identical_and_orthogonal_vectors():
    assert rag.cosine_similarity([1, 0], [1, 0]) == pytest.approx(1.0)
    assert rag.cosine_similarity([1, 0], [0, 1]) == pytest.approx(0.0)


def test_add_chunks_and_retrieve_rank_top_n(monkeypatch):
    monkeypatch.setattr(rag, "ollama", FakeOllama())
    rag.VECTOR_DB.clear()
    rag.add_chunks_to_vector_db("alpha")
    rag.add_chunks_to_vector_db("beta")
    rag.add_chunks_to_vector_db("gamma")
    rag.add_chunks_to_vector_db("delta")

    results = rag.retrieve("query", top_n=4)

    assert [chunk for chunk, _ in results] == ["alpha", "gamma", "beta", "delta"]
    assert [score for _, score in results] == pytest.approx(
        [1.0, 2**-0.5, 0.0, 0.0]
    )
    assert rag.retrieve("query", top_n=2)[0][0] == "alpha"
