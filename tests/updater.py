"""Exercise the actual Windows PowerShell updater on disposable game directories."""
from pathlib import Path
import ctypes
from ctypes import wintypes
import hashlib
import json
import shutil
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
release = root / "dist/FreeKill_diy_sunjiale-v0.2.0.zip"
patches = json.loads((root / "client-patches/manifest.json").read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def game_at(path):
    path.mkdir()
    (path / "FreeKill.exe").write_bytes(b"mock executable")
    (path / "fk_ver").write_text("v0.5.25\n")
    (path / "freekill.client.config.json").write_bytes(b"private-settings-sentinel")
    (path / "players.db").write_bytes(b"private-db-sentinel")
    (path / "recording").mkdir()
    (path / "recording/game.fk.rep").write_bytes(b"private-replay-sentinel")
    (path / "packages/other_extension").mkdir(parents=True)
    (path / "packages/other_extension/init.lua").write_text("other-extension")
    for entry in patches:
        target = path / entry["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / "_reference/FreeKill" / entry["path"], target)
    return path


def snapshot(path):
    return {p.relative_to(path).as_posix(): p.read_bytes() for p in path.rglob("*")
            if p.is_file() and not p.relative_to(path).parts[0].startswith((".sunjiale-update", "update-backups"))}


def run(game, package=release, expected=None):
    return subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                           "-GamePath", str(game), "-PackagePath", str(package),
                           "-ExpectedSha256", expected or digest(package)], capture_output=True)


def require(result, success=True):
    if (result.returncode == 0) != success:
        raise AssertionError(result.stdout.decode("gbk", errors="replace") + result.stderr.decode("gbk", errors="replace"))


def variant(path, alter):
    with zipfile.ZipFile(release) as archive:
        files = {name: archive.read(name) for name in archive.namelist()}
    alter(files)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in files.items():
            archive.writestr(name, data)
    return path


with tempfile.TemporaryDirectory(prefix="sunjiale-updater-", dir=root / "_tools") as directory:
    temp = Path(directory)
    script = temp / "update.ps1"
    script.write_text((root / "updater/update-sunjiale.ps1").read_text(encoding="utf-8-sig"), encoding="utf-8-sig")
    fresh = game_at(temp / "fresh")
    personal = snapshot(fresh)
    require(run(fresh))
    for name in ("freekill.client.config.json", "players.db", "recording/game.fk.rep", "packages/other_extension/init.lua"):
        assert (fresh / name).read_bytes() == personal[name]
    assert (fresh / "packages/diy_sunjiale/init.lua").read_bytes() == (root / "diy_sunjiale/init.lua").read_bytes()
    before = snapshot(fresh)
    backup_count = len(list((fresh / "update-backups").iterdir()))
    require(run(fresh))
    assert snapshot(fresh) == before
    assert len(list((fresh / "update-backups").iterdir())) == backup_count
    print("PASS fresh install, personal data/other extensions preserved, repeat is a no-op")

    old = game_at(temp / "old")
    (old / "packages/diy_sunjiale").mkdir()
    (old / "packages/diy_sunjiale/init.lua").write_text("old extension")
    (old / "packages/diy_sunjiale/obsolete.lua").write_text("obsolete")
    require(run(old))
    assert not (old / "packages/diy_sunjiale/obsolete.lua").exists()
    assert list((old / "update-backups").glob("*/extension/obsolete.lua"))
    print("PASS upgrade removes obsolete extension files and retains a backup")

    broken = game_at(temp / "broken")
    (broken / patches[0]["path"]).write_text("another patch")
    original = snapshot(broken)
    require(run(broken), False)
    assert snapshot(broken) == original
    clean = game_at(temp / "invalid")
    original = snapshot(clean)
    require(run(clean, expected="0" * 64), False)
    assert snapshot(clean) == original
    malicious = variant(temp / "traversal.zip", lambda files: files.update({"../escape.txt": b"escape"}))
    require(run(clean, malicious), False)
    assert snapshot(clean) == original and not (clean / ".sunjiale-update/escape.txt").exists()
    tampered = variant(temp / "tampered.zip", lambda files: files.update({"diy_sunjiale/init.lua": b"tampered"}))
    require(run(clean, tampered), False)
    assert snapshot(clean) == original
    print("PASS incompatible game, bad archive checksum, path traversal and tampered file rejected before mutation")

    rollback = game_at(temp / "rollback")
    (rollback / "packages/diy_sunjiale").mkdir()
    (rollback / "packages/diy_sunjiale/init.lua").write_text("old extension")
    locked_file = rollback / "update-sunjiale.ps1"
    locked_file.write_text("old updater")
    original = snapshot(rollback)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p,
                                  wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    kernel.CreateFileW.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.CreateFileW(str(locked_file), 0x80000000, 1, None, 3, 0x80, None)
    assert handle != ctypes.c_void_p(-1).value
    try:
        require(run(rollback), False)
    finally:
        kernel.CloseHandle(handle)
    assert snapshot(rollback) == original
    print("PASS late file-write failure restores all patches and the old extension")

    def new_patch(files):
        manifest = json.loads(files["update-manifest.json"])
        manifest["version"] = "0.2.1"
        patch_manifest = json.loads(files["client-patches/manifest.json"])
        first = patch_manifest[0]
        name = "client-patches/" + first["path"]
        files[name] += b"\n// updater test of the next patch revision\n"
        first["patched"] = hashlib.sha256(files[name]).hexdigest()
        files["client-patches/manifest.json"] = json.dumps(patch_manifest).encode()
        for entry in manifest["files"]:
            entry["sha256"] = hashlib.sha256(files[entry["path"]]).hexdigest()
        files["update-manifest.json"] = json.dumps(manifest).encode()
    future = variant(temp / "future.zip", new_patch)
    require(run(fresh, future))
    assert json.loads((fresh / ".sunjiale-update-state.json").read_text(encoding="utf-8-sig"))["version"] == "0.2.1"
    require(run(fresh), False)
    print("PASS next patch revision accepted through previous state; downgrade rejected")
