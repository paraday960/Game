#!/usr/bin/env python3
"""Validate the original in-game polygon map and strategic transport layers."""
import json
from pathlib import Path
root = Path(__file__).parents[1]
countries = json.loads((root / "data/countries.json").read_text(encoding="utf-8"))
geometry = json.loads((root / "data/world_polygons.json").read_text(encoding="utf-8"))
transport = json.loads((root / "data/transport_hubs.json").read_text(encoding="utf-8"))
ids = {c["id"] for c in countries["countries"]}
errors = []
if set(geometry.get("countries", {})) != ids:
    errors.append("polygon ISO3 set does not exactly match 195 playable countries")
if geometry.get("country_count") != 195:
    errors.append("polygon country_count is not 195")
points = 0
for code, polygons in geometry.get("countries", {}).items():
    if not polygons:
        errors.append(f"{code}: no polygon")
    for polygon in polygons:
        outer = polygon.get("outer", [])
        if len(outer) < 4 or outer[0] != outer[-1]:
            errors.append(f"{code}: invalid/uncLOSED outer ring")
            continue
        for lon, lat in outer:
            points += 1
            if not -180 <= lon <= 180 or not -90 <= lat <= 90:
                errors.append(f"{code}: coordinate out of bounds")
if not 20_000 <= points <= 45_000:
    errors.append(f"simplified point budget invalid: {points}")
hubs = {h["id"]: h for h in transport.get("hubs", [])}
if len(hubs) < 40:
    errors.append("too few strategic hubs")
if len(transport.get("routes", [])) < 40:
    errors.append("too few curated routes")
for route in transport.get("routes", []):
    if route.get("from") not in hubs or route.get("to") not in hubs:
        errors.append(f"route references unknown hub: {route}")
if str(geometry.get("source", {}).get("license", "")).lower() != "public domain":
    errors.append("Natural Earth public-domain metadata missing")
if errors:
    raise SystemExit("WORLD MAP INVALID\n" + "\n".join(errors[:100]))
print(f"WORLD MAP OK: 195 selectable polygon countries, {points} points, {len(hubs)} hubs")
