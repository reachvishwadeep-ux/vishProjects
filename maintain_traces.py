#!/usr/bin/env python3
"""Maintain traces-export.json file size (truncate if > 100 MB)."""

import json
import shutil
from pathlib import Path
from datetime import datetime

TRACES_FILE = Path("traces-export.json")
MAX_SIZE_MB = 100
MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024
BACKUP_DIR = Path("traces_backups")

def maintain_traces():
    """Check file size and truncate if necessary."""
    if not TRACES_FILE.exists():
        print(f"[INFO] {TRACES_FILE} does not exist yet")
        return
    
    file_size_bytes = TRACES_FILE.stat().st_size
    file_size_mb = file_size_bytes / (1024 * 1024)
    
    print(f"[CHECK] {TRACES_FILE.name}: {file_size_mb:.2f} MB")
    
    if file_size_bytes > MAX_SIZE_BYTES:
        print(f"[WARN] File exceeds {MAX_SIZE_MB} MB limit ({file_size_mb:.2f} MB)")
        
        # Create backup before truncating
        BACKUP_DIR.mkdir(exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = BACKUP_DIR / f"traces_backup_{timestamp}.json"
        
        try:
            shutil.copy2(TRACES_FILE, backup_file)
            print(f"[BACKUP] Created: {backup_file}")
        except Exception as e:
            print(f"[ERROR] Backup failed: {e}")
            return
        
        # Truncate file
        try:
            TRACES_FILE.write_text("")
            print(f"[TRUNCATE] {TRACES_FILE} cleared (was {file_size_mb:.2f} MB)")
        except Exception as e:
            print(f"[ERROR] Truncate failed: {e}")
            return
    else:
        print(f"[OK] File size within limit ({file_size_mb:.2f} MB < {MAX_SIZE_MB} MB)")

if __name__ == "__main__":
    maintain_traces()
