#!/usr/bin/env python3
"""Strict offline validation for the 195-country gameplay dataset."""
import json
import math
import re
from pathlib import Path

path = Path(__file__).parents[1] / "data" / "countries.json"
data = json.loads(path.read_text(encoding="utf-8"))
rows = data.get("countries", [])
errors = []
ids = [row.get("id") for row in rows]
if len(rows) != 195:
    errors.append(f"expected 195 countries, got {len(rows)}")
if len(set(ids)) != len(ids):
    errors.append("duplicate ISO3 identifiers")
if sum(bool(row.get("un_member")) for row in rows) != 193:
    errors.append("UN member count is not 193")
if sum(bool(row.get("observer_state")) for row in rows) != 2:
    errors.append("observer-state count is not 2")
required = {
    "id", "alpha2", "name_fa", "capital_fa", "currency_fa", "population",
    "gdp", "military_power", "tech_level", "lat", "lon", "bloc",
    "climate_fa", "snow_factor", "flood_factor", "heat_factor",
    "municipal_capacity", "strategic_weight", "playable",
}
for row in rows:
    code = row.get("id", "???")
    missing = required - row.keys()
    if missing:
        errors.append(f"{code}: missing {sorted(missing)}")
        continue
    for field in ("name_fa", "capital_fa", "currency_fa", "climate_fa"):
        if not re.search(r"[\u0600-\u06ff]", str(row[field])):
            errors.append(f"{code}: {field} is not Persian-facing")
    numeric_ranges = {
        "population": (1, 2_000_000_000), "gdp": (1, 100_000_000_000_000),
        "military_power": (0, 100), "tech_level": (0, 1),
        "lat": (-90, 90), "lon": (-180, 180), "snow_factor": (0, 1),
        "flood_factor": (0, 1), "heat_factor": (0, 1),
        "municipal_capacity": (0, 1), "strategic_weight": (0, 1),
    }
    for field, (low, high) in numeric_ranges.items():
        value = row[field]
        if not isinstance(value, (int, float)) or not math.isfinite(value) or not low <= value <= high:
            errors.append(f"{code}: invalid {field}={value!r}")
if data.get("country_count") != 195:
    errors.append("country_count metadata mismatch")
if len(data.get("sources", [])) < 3:
    errors.append("source attribution is incomplete")
if errors:
    raise SystemExit("COUNTRY DATA INVALID\n" + "\n".join(errors[:100]))
print("COUNTRY DATA OK: 195 sovereign states, 193 UN members + 2 observers")
