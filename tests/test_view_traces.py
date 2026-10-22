import json

from tests.conftest import load_module


view_traces = load_module("view_traces.py")


def test_view_traces_reports_missing_file(monkeypatch, tmp_path, capsys):
    missing = tmp_path / "missing.jsonl"
    monkeypatch.setattr(view_traces, "TRACES_FILE", missing)

    view_traces.view_traces()

    assert "[ERROR] Trace file not found" in capsys.readouterr().out


def test_view_traces_reads_valid_jsonl_and_skips_invalid_lines(
    monkeypatch, tmp_path, capsys
):
    trace_file = tmp_path / "traces.jsonl"
    lines = [json.dumps({"batch": index}) for index in range(1, 7)]
    trace_file.write_text("\n".join([lines[0], "not json", *lines[1:]]) + "\n")
    monkeypatch.setattr(view_traces, "TRACES_FILE", trace_file)

    view_traces.view_traces()

    output = capsys.readouterr().out
    assert "[SKIP] Line 2: Invalid JSON" in output
    assert "[OK] Read 6 valid trace batches" in output
    assert "[Batch 1]" in output
    assert "[Batch 5]" in output
