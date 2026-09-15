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

    # Detect if building App Bundle (.aab) for Google Play or APK
    build_bundle = any(arg in sys.argv for arg in ["bundle", "appbundle", "--bundle", "--aab"]) or (len(sys.argv) == 1)
    
    if build_bundle:
        # Google Play requires an RSA upload key (ECDSA keys are rejected with 'invalid signature')
        rsa_upload_keystore = Path("C:/Users/Devasy/.android/repforge-upload.jks")
        if rsa_upload_keystore.exists():
            os.environ["KEYSTORE_PATH"] = str(rsa_upload_keystore)
            print(f"Using Google Play RSA upload keystore: {rsa_upload_keystore}")
        
        cmd = "flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols"
    else:
        cmd = "flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/app/outputs/symbols"

    print(f"Executing: {cmd}")
    result = subprocess.run(cmd, env=os.environ, shell=True)
    
    if result.returncode == 0:
        if build_bundle:
            aab_path = project_dir / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
            print(f"\n[SUCCESS] Google Play App Bundle ready at:\n  {aab_path}")
        else:
            apk_path = project_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
            print(f"\n[SUCCESS] Release APK ready at:\n  {apk_path}")
            
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()
