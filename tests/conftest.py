import hashlib
import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).parents[1]


def load_module(relative_path):
    path = ROOT / relative_path
    digest = hashlib.sha1(str(path).encode()).hexdigest()[:12]
    module_name = f"test_target_{digest}"
    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module
