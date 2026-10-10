"""Build the small, checksummed release consumed by the Windows updater."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import zipfile


def build(source, output, version):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("version must be major.minor.patch")
    extension = source / "diy_sunjiale" if (source / "diy_sunjiale/init.lua").exists() else source
    files = {}
    for name in ("init.lua", "helpers.lua", "translations.lua", "README.txt", "武将设计.md", "武将与技能规范.md", "LICENSE"):
        files["diy_sunjiale/" + name] = (extension / name).read_bytes()
    for directory in ("skills", "image"):
        for path in sorted((extension / directory).rglob("*")):
            if path.is_file():
                files["diy_sunjiale/" + path.relative_to(extension).as_posix()] = path.read_bytes()
    for path in sorted((source / "client-patches").rglob("*")):
        if path.is_file():
            files[path.relative_to(source).as_posix()] = path.read_bytes()
    for name in ("update-sunjiale.ps1", "双击更新.cmd"):
        text = (source / "updater" / name).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        files[name] = text.replace("\n", "\r\n").encode("utf-8-sig" if name.endswith(".ps1") else "gbk")
    for name in ("安装扩展.ps1", "安装说明.txt"):
        text = (source / name).read_text(encoding="utf-8-sig")
        files[name] = text.encode("utf-8-sig" if name.endswith(".ps1") else "utf-8")
    manifest = {"format": 1, "version": version, "game_version": "0.5.25", "files": [
        {"path": name, "sha256": hashlib.sha256(data).hexdigest()} for name, data in sorted(files.items())]}
    files["update-manifest.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    output.mkdir(parents=True, exist_ok=True)
    path = output / f"FreeKill_diy_sunjiale-v{version}.zip"
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)
    print(f"{path}: {hashlib.sha256(path.read_bytes()).hexdigest()}")
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path, default=Path("dist"))
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    build(args.source, args.output, args.version)
