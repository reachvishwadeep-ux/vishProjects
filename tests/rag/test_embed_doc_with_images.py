from types import SimpleNamespace

from tests.conftest import load_module


embed_doc = load_module("src/rag/embed_doc_with_images.py")


class FakePage:
    def get_text(self, kind, sort):
        assert kind == "text"
        assert sort is True
        return "A short paragraph."

    def get_images(self, full):
        assert full is True
        return [(42,)]


class FakeDocument:
    def __iter__(self):
        return iter([FakePage()])

    def extract_image(self, xref):
        assert xref == 42
        return {"image": b"image-bytes"}


def test_caption_image_returns_placeholder():
    assert "Image description placeholder" in embed_doc.caption_image(b"bytes")


def test_extract_pdf_collects_text_and_image_records(monkeypatch):
    monkeypatch.setattr(
        embed_doc,
        "fitz",
        SimpleNamespace(open=lambda path: FakeDocument()),
    )
    monkeypatch.setattr(
        embed_doc,
        "caption_image",
        lambda image_bytes: f"caption for {len(image_bytes)} bytes",
    )

    records = embed_doc.extract_pdf_for_embeddings("fake.pdf")

    assert records == [
        {
            "content": "A short paragraph.",
            "metadata": {
                "source": "fake.pdf",
                "page": 1,
                "chunk_type": "text",
                "chunk_index": 0,
            },
        },
        {
            "content": "caption for 11 bytes",
            "metadata": {
                "source": "fake.pdf",
                "page": 1,
                "chunk_type": "image_caption",
                "image_index": 0,
            },
        },
    ]


def test_create_embedding_uses_injected_openai_client(monkeypatch):
    fake_client = SimpleNamespace(
        embeddings=SimpleNamespace(
            create=lambda model, input: SimpleNamespace(
                data=[SimpleNamespace(embedding=[0.1, 0.2])]
            )
        )
    )
    monkeypatch.setattr(embed_doc, "client", fake_client)

    assert embed_doc.create_embedding("text") == [0.1, 0.2]
