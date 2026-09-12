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
    cust_apk_dir = cust_dir / "flutter-apk"
    owner_apk_dir = owner_dir / "flutter-apk"

    for d in (root_apk_dir, cust_apk_dir, owner_apk_dir):
        d.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print(" Building Stora Customer & Stora Owner Release APKs Concurrently")
    print("=" * 60)
    print(f"Customer dir: {cust_dir}")
    print(f"Owner dir:    {owner_dir}")
    print(f"Target dirs:  {root_apk_dir}")
    print(f"              {cust_apk_dir}")
    print(f"              {owner_apk_dir}")
    print("=" * 60)

    start_time = time.time()

    flutter_cmd = "flutter.bat" if os.name == "nt" else "flutter"

    cust_log_path = repo_root / "build_cust.log"
    owner_log_path = repo_root / "build_owner.log"

    cust_log = open(cust_log_path, "w", encoding="utf-8", errors="replace")
    owner_log = open(owner_log_path, "w", encoding="utf-8", errors="replace")

    print("\n-> Launching Customer Release Build...")
    p_cust = subprocess.Popen(
        [flutter_cmd, "build", "apk", "--release"],
        cwd=str(cust_dir),
        stdout=cust_log,
        stderr=subprocess.STDOUT
    )

    print("-> Launching Owner Release Build...")
    p_owner = subprocess.Popen(
        [flutter_cmd, "build", "apk", "--release"],
        cwd=str(owner_dir),
        stdout=owner_log,
        stderr=subprocess.STDOUT
    )

    print(f"Customer build PID: {p_cust.pid} | Owner build PID: {p_owner.pid}")
    print("Compiling release APKs in parallel, please wait...\n")

    # Monitor until both finish
    while p_cust.poll() is None or p_owner.poll() is None:
        time.sleep(3)
        cust_status = "DONE" if p_cust.poll() is not None else "BUILDING"
        owner_status = "DONE" if p_owner.poll() is not None else "BUILDING"
        elapsed = int(time.time() - start_time)
        print(f"[{elapsed:3d}s] Customer: {cust_status:<8} | Owner: {owner_status}")

    cust_log.close()
    owner_log.close()

    total_elapsed = time.time() - start_time
    print(f"\nAll builds finished in {total_elapsed:.1f} seconds.")

    failed = False
    if p_cust.returncode != 0:
        print(f"\n[ERROR] Customer build failed (code {p_cust.returncode}):")
        if cust_log_path.exists():
            lines = cust_log_path.read_text(encoding="utf-8", errors="replace").splitlines()
            print("\n".join(lines[-30:]))
        failed = True
    else:
        print("[SUCCESS] Stora Customer APK built successfully!")

    if p_owner.returncode != 0:
        print(f"\n[ERROR] Owner build failed (code {p_owner.returncode}):")
        if owner_log_path.exists():
            lines = owner_log_path.read_text(encoding="utf-8", errors="replace").splitlines()
            print("\n".join(lines[-30:]))
        failed = True
    else:
        print("[SUCCESS] Stora Owner APK built successfully!")

    # Clean up logs on success
    if not failed:
        cust_log_path.unlink(missing_ok=True)
        owner_log_path.unlink(missing_ok=True)
    else:
        print("\nBuild failed. Aborting APK distribution.")
        sys.exit(1)

    # Distribute APKs
    cust_built = cust_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    owner_built = owner_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"

    print("\nCopying APKs to all destination folders...")

    if cust_built.exists():
        shutil.copy2(cust_built, cust_apk_dir / "app-release.apk")
        shutil.copy2(cust_built, cust_apk_dir / "Stora-Customer.apk")
        shutil.copy2(cust_built, root_apk_dir / "Stora-Customer.apk")
        print(f"-> Customer APK copied to:\n   - {cust_apk_dir / 'app-release.apk'}\n   - {cust_apk_dir / 'Stora-Customer.apk'}\n   - {root_apk_dir / 'Stora-Customer.apk'}")
    else:
        print(f"[ERROR] Customer output not found: {cust_built}")

    if owner_built.exists():
        shutil.copy2(owner_built, owner_apk_dir / "app-release.apk")
        shutil.copy2(owner_built, owner_apk_dir / "Stora.apk")
        shutil.copy2(owner_built, root_apk_dir / "Stora.apk")
        print(f"-> Owner APK copied to:\n   - {owner_apk_dir / 'app-release.apk'}\n   - {owner_apk_dir / 'Stora.apk'}\n   - {root_apk_dir / 'Stora.apk'}")
    else:
        print(f"[ERROR] Owner output not found: {owner_built}")

    print("\n" + "=" * 60)
    print(" SUMMARY OF GENERATED APKS")
    print("=" * 60)
    for folder in (root_apk_dir, cust_apk_dir, owner_apk_dir):
        print(f"\nDirectory: {folder}")
        for apk in sorted(folder.glob("*.apk")):
            mb = apk.stat().st_size / (1024 * 1024)
            mtime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(apk.stat().st_mtime))
            print(f"  {apk.name:<22} {mb:6.2f} MB   modified: {mtime}")

    print("\nAll APK release builds complete and distributed successfully!")

if __name__ == "__main__":
    main()
