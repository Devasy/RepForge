#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

def load_env_file(env_path: Path):
    """Loads key-value pairs from a .env file into os.environ."""
    if not env_path.exists():
        return
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            # Remove whitespace and wrapping quotes if present
            val = val.strip().strip("'\"")
            os.environ[key.strip()] = val

def main():
    script_dir = Path(__file__).resolve().parent
    project_dir = script_dir.parent if script_dir.name == "scripts" else script_dir
    os.chdir(project_dir)

    env_file = project_dir / ".env"
    if env_file.exists():
        print(f"Loading environment from {env_file}")
        load_env_file(env_file)
    else:
        print("No .env file found. Using existing environment variables.")

    cmd = [
        "flutter", "build", "apk",
        "--release",
        "--target-platform", "android-arm64",
        "--obfuscate",
        "--split-debug-info=build/app/outputs/symbols"
    ]

    print(f"Executing: {' '.join(cmd)}")
    result = subprocess.run(cmd, env=os.environ, shell=(sys.platform == "win32"))
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()
