"""Shared utilities used by the example scripts in this repository.

Scripts are usually run directly (``python src/rag/rag_from_scratch.py``), so the
``src`` directory is not automatically on ``sys.path``. Add it before importing:

    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

    from common.json_utils import parse_json_response
"""
