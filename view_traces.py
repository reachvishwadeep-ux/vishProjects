#!/usr/bin/env python3
"""Display OpenTelemetry traces from JSON export file."""

import json
import sys
from pathlib import Path

TRACES_FILE = Path("traces-export.json")

def view_traces():
    if not TRACES_FILE.exists():
        print(f"[ERROR] Trace file not found: {TRACES_FILE}")
        return 1
    
    # Parse JSONL format - read and display samples
    lines_read = 0
    skipped_lines = 0
    with open(TRACES_FILE, encoding='utf-8', errors='replace') as f:
        print("\n[TRACES] OpenTelemetry Export File Contents\n")
        print("=" * 80)
        
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            
            try:
                data = json.loads(line)
                lines_read += 1
                
                # Show first 5 batches in detail
                if line_num <= 5:
                    print(f"\n[Batch {line_num}]")
                    print(json.dumps(data, indent=2)[:1000])
                    print("... (truncated)")
            except json.JSONDecodeError as e:
                skipped_lines += 1
                print(
                    f"  [SKIP] Line {line_num}: Invalid JSON ({e}); "
                    f"prefix: {line[:80]!r}"
                )
        
        print("\n" + "=" * 80)
        print(
            f"[OK] Read {lines_read} valid trace batches from {TRACES_FILE}; "
            f"skipped {skipped_lines} invalid lines"
        )
        print("\nTo parse traces programmatically, use:")
        print(f"  python -c \"import json; [print(json.loads(line)) for line in open('{TRACES_FILE}')]\"")
        print()

    if not lines_read:
        print(f"[ERROR] No valid trace batches parsed from {TRACES_FILE}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(view_traces())
