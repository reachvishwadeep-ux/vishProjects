"""Helpers for turning (often messy) model output into JSON."""

import json
from collections.abc import Iterable, Sequence
from typing import Any

_FENCES = ("```json", "```", "'''json", "'''")


def strip_code_fences(text: str) -> str:
    """Remove markdown code fences that models wrap JSON in."""
    cleaned = text
    for fence in _FENCES:
        cleaned = cleaned.replace(fence, "")
    return cleaned.strip()


def extract_json_object(text: str) -> str:
    """Return the outermost ``{...}`` block, dropping preamble/postamble text.

    A bare ``key: value`` payload without braces is wrapped in braces.
    """
    cleaned = strip_code_fences(text)
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start != -1 and end > start:
        return cleaned[start:end + 1]
    if ":" in cleaned:
        return "{" + cleaned + "}"
    return cleaned


def validate_required_fields(data: Any, required_fields: Iterable[str]) -> dict:
    """Check that ``data`` is a JSON object containing every required field."""
    if not isinstance(data, dict):
        raise ValueError("Response is not a JSON object")
    for field in required_fields:
        if field not in data:
            raise ValueError(f"missing required field: {field}")
    return data


def parse_json_response(
    text: str,
    required_fields: Sequence[str] | None = None,
) -> dict | list | None:
    """Parse model output as JSON, tolerating fences and surrounding prose.

    Returns ``None`` when the payload is not valid JSON or a required field is
    missing; the reason is printed so example scripts stay short.
    """
    try:
        data = json.loads(extract_json_object(text))
    except json.JSONDecodeError as error:
        print("Error decoding JSON:", error)
        return None

    if required_fields is not None:
        try:
            validate_required_fields(data, required_fields)
        except ValueError as error:
            print("Invalid JSON response:", error)
            return None
    return data
