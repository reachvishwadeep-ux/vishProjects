import numpy as np

from scripts.evaluate import equal_error_rate, pair_scores, rank1, tar_at_far


def _synthetic_embeddings(people: int = 6, per_person: int = 4, dim: int = 512):
    """Tight per-person clusters on the unit sphere, i.e. an easy separable case."""
    rng = np.random.default_rng(0)
    out = {}
    for p in range(people):
        centre = rng.normal(size=dim)
        centre /= np.linalg.norm(centre)
        vectors = centre + 0.05 * rng.normal(size=(per_person, dim))
        vectors /= np.linalg.norm(vectors, axis=1, keepdims=True)
        out[f"person{p}"] = vectors
    return out


def test_genuine_scores_exceed_impostor_scores():
    genuine, impostor = pair_scores(_synthetic_embeddings())
    assert genuine.min() > impostor.max()


def test_tar_at_far_is_perfect_on_separable_data():
    genuine, impostor = pair_scores(_synthetic_embeddings())
    _, tar = tar_at_far(genuine, impostor, far=1e-2)
    assert tar == 1.0


def test_eer_is_zero_on_separable_data():
    genuine, impostor = pair_scores(_synthetic_embeddings())
    _, eer = equal_error_rate(genuine, impostor)
    assert eer == 0.0


def test_rank1_is_perfect_on_separable_data():
    assert rank1(_synthetic_embeddings()) == 1.0
