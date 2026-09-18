import importlib
import sys
from pathlib import Path


def test_backend_main_imports():
    repo_root = Path(__file__).resolve().parents[1]
    if str(repo_root) not in sys.path:
        sys.path.insert(0, str(repo_root))

    module = importlib.import_module("backend.main")

    assert hasattr(module, "app")
