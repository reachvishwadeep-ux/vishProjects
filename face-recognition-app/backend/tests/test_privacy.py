from pathlib import Path


def test_privacy_policy_covers_beta_data_handling() -> None:
    policy = (Path(__file__).parents[1] / "app" / "static" / "privacy.html").read_text(
        encoding="utf-8"
    )

    assert "ReuniteNow Beta Privacy Policy" in policy
    assert "numerical face embeddings" in policy
    assert "DigitalOcean" in policy
    assert "Telnyx" in policy
    assert "Apple TestFlight" in policy
    assert "reachvishwadeep2@gmail.com" in policy
