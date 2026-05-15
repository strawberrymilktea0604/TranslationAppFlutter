import os
import sys
from pathlib import Path


os.environ.setdefault("SECRET_KEY", "test-secret-key-for-backend-tests")

backend_path = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(backend_path))
