"""Apply disk compression to large opaque story art, preserving UI and masks.

Run after replacing PNGs/exporting Flash art, then let Godot reimport textures.
Requires Pillow. --check reports drift without writing.
"""
import argparse
import json
import re
from pathlib import Path

from PIL import Image


def protected_textures(root):
    protected = set()

    def walk(value, protect=False):
        if isinstance(value, dict):
            protect = protect or value.get("type") == "mask" or bool(value.get("eye_lid"))
            if protect and value.get("texture"):
                protected.add(value["texture"])
            for child in value.values():
                walk(child, protect)
        elif isinstance(value, list):
            for child in value:
                walk(child, protect)

    for path in (root / "data").glob("*.json"):
        value = json.loads(path.read_text(encoding="utf-8"))
        walk(value, not path.name.startswith("episode"))
        if path.name.startswith("episode") and isinstance(value, dict):
            for name, child in value.items():
                if any(tag in name.lower() for tag in ("dialog", "item", "keypad", "console", "terminal")):
                    walk(child, True)
    return protected


def desired_import(text):
    values = {
        "compress/mode": "1",  # Godot Lossy (WebP), not GPU block compression.
        "compress/lossy_quality": "0.85",
        "mipmaps/generate": "false",
    }
    if "[params]" not in text:
        raise ValueError("Texture import has no [params] section")
    for key, value in values.items():
        pattern = rf"^{re.escape(key)}=.*$"
        if re.search(pattern, text, flags=re.MULTILINE):
            text = re.sub(pattern, f"{key}={value}", text, flags=re.MULTILINE)
        else:
            text = text.replace("[params]", f"[params]\n{key}={value}", 1)
    return text


def configure(root, check=False):
    art_root = root / "assets" / "flash_ui"
    protected = protected_textures(root)
    eligible = changed = missing = 0
    for path in sorted(art_root.glob("episode*/*.png")):
        if not re.fullmatch(r"episode\d+_(components|animation_parts)", path.parent.name):
            continue
        if path.relative_to(art_root).as_posix() in protected:
            continue
        with Image.open(path) as image:
            if image.width < 640 or image.height < 360:
                continue
            if image.convert("RGBA").getchannel("A").getextrema() != (255, 255):
                continue
        eligible += 1
        metadata = Path(str(path) + ".import")
        if not metadata.exists():
            missing += 1
            print(f"Import in Godot first: {path.relative_to(root)}")
            continue
        original = metadata.read_text(encoding="utf-8")
        updated = desired_import(original)
        if original != updated:
            changed += 1
            if not check:
                metadata.write_text(updated, encoding="utf-8")
    print(json.dumps({"eligible": eligible, "changed": changed, "missing_imports": missing, "check": check}))
    return 1 if missing or (check and changed) else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    raise SystemExit(configure(args.project.resolve(), args.check))
