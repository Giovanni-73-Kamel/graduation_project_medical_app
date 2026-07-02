from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT), str(ROOT / ".python-packages")]

import uvicorn


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, log_level="info")
