import os
import sys
import time
import shutil
import subprocess
from pathlib import Path

def main():
    repo_root = Path(__file__).resolve().parent
    cust_dir = repo_root / "stora_customer"
    owner_dir = repo_root / "stora_owner"

    root_apk_dir = repo_root / "flutter-apk"
    apk_dir = repo_root / "apk"
    cust_flutter_apk_dir = cust_dir / "flutter-apk"
    cust_apk_dir = cust_dir / "apk"
    owner_flutter_apk_dir = owner_dir / "flutter-apk"
    owner_apk_dir = owner_dir / "apk"

    all_target_dirs = (
        root_apk_dir,
        apk_dir,
        cust_flutter_apk_dir,
        cust_apk_dir,
        owner_flutter_apk_dir,
        owner_apk_dir,
    )

    for d in all_target_dirs:
        d.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print(" Building Stora Customer & Stora Owner Release APKs Concurrently")
    print("=" * 60)
    print(f"Customer dir: {cust_dir}")
    print(f"Owner dir:    {owner_dir}")
    print("Target dirs:")
    for d in all_target_dirs:
        print(f"  - {d}")
    print("=" * 60)

    start_time = time.time()

    flutter_cmd = "flutter.bat" if os.name == "nt" else "flutter"

    cust_log_path = repo_root / "build_cust.log"
    owner_log_path = repo_root / "build_owner.log"


    distribute_only = "--distribute-only" in sys.argv or "--skip-build" in sys.argv

    if not distribute_only:
        def build_app(app_name, app_dir, log_path):
            print(f"\n-> Building {app_name} Release APK...")
            with open(log_path, "w", encoding="utf-8", errors="replace") as log_file:
                p = subprocess.Popen(
                    [flutter_cmd, "build", "apk", "--release"],
                    cwd=str(app_dir),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                )
                for line in p.stdout:
                    log_file.write(line)
                    stripped = line.strip()
                    if stripped.startswith("Running Gradle task") or "Built " in stripped or "Tree-shaking" in stripped:
                        print(f"   [{app_name}] {stripped}")
                p.wait()
                return p.returncode

        cust_code = build_app("Customer", cust_dir, cust_log_path)
        if cust_code != 0:
            print(f"\n[ERROR] Customer build failed (code {cust_code}):")
            if cust_log_path.exists():
                lines = cust_log_path.read_text(encoding="utf-8", errors="replace").splitlines()
                print("\n".join(lines[-30:]))
            sys.exit(1)
        else:
            print("[SUCCESS] Stora Customer APK built successfully!")
            cust_log_path.unlink(missing_ok=True)

        owner_code = build_app("Owner", owner_dir, owner_log_path)
        if owner_code != 0:
            print(f"\n[ERROR] Owner build failed (code {owner_code}):")
            if owner_log_path.exists():
                lines = owner_log_path.read_text(encoding="utf-8", errors="replace").splitlines()
                print("\n".join(lines[-30:]))
            sys.exit(1)
        else:
            print("[SUCCESS] Stora Owner APK built successfully!")
            owner_log_path.unlink(missing_ok=True)

        total_elapsed = time.time() - start_time
        print(f"\nAll builds finished in {total_elapsed:.1f} seconds.")
    else:
        print("\nSkipping compile (--distribute-only specified). Proceeding to distribution...")

    # Distribute APKs
    cust_built = cust_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    owner_built = owner_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"

    print("\nCopying APKs to all destination folders...")

    if cust_built.exists():
        for d in (cust_flutter_apk_dir, cust_apk_dir, root_apk_dir, apk_dir):
            shutil.copy2(cust_built, d / "Stora-Customer.apk")
        shutil.copy2(cust_built, cust_flutter_apk_dir / "app-release.apk")
        print("-> Customer APK copied to all target folders (apk & flutter-apk).")
    else:
        print(f"[ERROR] Customer output not found: {cust_built}")

    if owner_built.exists():
        for d in (owner_flutter_apk_dir, owner_apk_dir, root_apk_dir, apk_dir):
            shutil.copy2(owner_built, d / "Stora-Owner.apk")
            shutil.copy2(owner_built, d / "Stora.apk")
        shutil.copy2(owner_built, owner_flutter_apk_dir / "app-release.apk")
        print("-> Owner APK copied to all target folders (apk & flutter-apk).")
    else:
        print(f"[ERROR] Owner output not found: {owner_built}")

    print("\n" + "=" * 60)
    print(" SUMMARY OF GENERATED APKS")
    print("=" * 60)
    for folder in all_target_dirs:
        print(f"\nDirectory: {folder}")
        for apk in sorted(folder.glob("*.apk")):
            mb = apk.stat().st_size / (1024 * 1024)
            mtime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(apk.stat().st_mtime))
            print(f"  {apk.name:<22} {mb:6.2f} MB   modified: {mtime}")

    print("\nAll APK release builds complete and distributed successfully!")

if __name__ == "__main__":
    main()
