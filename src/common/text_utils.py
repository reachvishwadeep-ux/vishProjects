"""Text loading and chunking helpers."""

from pathlib import Path


def read_text(path: str | Path) -> str:
    """Read a text file, replacing characters that are not valid UTF-8."""
    return Path(path).read_text(encoding="utf-8", errors="replace")


def read_lines(path: str | Path) -> list[str]:
    """Read a text file as a list of lines, tolerating bad encodings."""
    return read_text(path).splitlines(keepends=True)


def chunk_text(text: str, chunk_size: int = 500, overlap: int = 100) -> list[str]:
    """Split text into fixed size chunks with a sliding overlap."""
    if chunk_size <= overlap:
        raise ValueError("chunk_size must be greater than overlap")

    chunks = []
    start = 0
    while start < len(text):
        chunks.append(text[start:start + chunk_size])
        start += chunk_size - overlap
    return chunks
