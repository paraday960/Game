#!/usr/bin/env python3
"""Prevent CI, project metadata, Android export and docs from drifting off Godot 4.7.1."""
from pathlib import Path
import re

root = Path(__file__).parents[1]
errors = []
expected = "4.7.1-stable"
if (root / "ENGINE_VERSION").read_text(encoding="utf-8").strip() != expected:
    errors.append("ENGINE_VERSION is not 4.7.1-stable")
project = (root / "project.godot").read_text(encoding="utf-8")
if 'config/features=PackedStringArray("4.7", "Mobile")' not in project:
    errors.append("project.godot does not target Godot 4.7")
if 'config/version="6.3.0"' not in project:
    errors.append("application version was not bumped to 6.3.0")
export = (root / "export_presets.cfg").read_text(encoding="utf-8")
if 'version/code=19' not in export or 'version/name="6.3.0"' not in export:
    errors.append("Android version is not 19 / 6.3.0")
workflow = (root / ".github/workflows/build-android.yml").read_text(encoding="utf-8")
for marker in ['GODOT_VERSION: "4.7.1"', 'GODOT_CHANNEL: "stable"', "Godot_v${TAG}_linux.x86_64.zip", "Godot_v${TAG}_export_templates.tpz"]:
    if marker not in workflow:
        errors.append(f"CI Godot 4.7.1 marker missing: {marker}")
# Godot 4.4+ uses sidecar script UIDs. They must be complete, unique and versioned.
scripts = sorted(list((root / "scripts").rglob("*.gd")) + list((root / "tests").glob("*.gd")))
uids = []
for script in scripts:
    sidecar = Path(str(script) + ".uid")
    if not sidecar.exists():
        errors.append(f"Godot 4.7 UID sidecar missing: {script.relative_to(root)}")
        continue
    value = sidecar.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"uid://[a-z0-9]+", value):
        errors.append(f"invalid UID sidecar: {sidecar.relative_to(root)}")
    uids.append(value)
if len(uids) != len(set(uids)):
    errors.append("duplicate Godot script UID detected")
for relative in ["scenes/main.tscn", "tests/test_scene.tscn", "tests/test_long.tscn"]:
    if 'ext_resource type="Script" uid="uid://' not in (root / relative).read_text(encoding="utf-8"):
        errors.append(f"scene script reference was not migrated to UID: {relative}")
# No executable build path may still pin the obsolete 4.2.2 engine.
for relative in [".github/workflows/build-android.yml", "BUILD.md", "GUIDE_ANDROID.md", "tests/README.md", "ALL_SYSTEMS_COMPLETE.md"]:
    text = (root / relative).read_text(encoding="utf-8")
    if "4.2.2" in text or re.search(r"Godot 4\.2(?:\D|$)", text):
        errors.append(f"obsolete Godot 4.2 reference remains in {relative}")
if errors:
    raise SystemExit("ENGINE VERSION INVALID\n" + "\n".join(errors))
print(f"ENGINE VERSION OK: Godot 4.7.1-stable, app 6.3.0 (Android 19), {len(uids)} script UIDs")
