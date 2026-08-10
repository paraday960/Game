#!/usr/bin/env python3
"""Validate national Admin-1/city maps for all 195 playable countries."""
from __future__ import annotations
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).parents[1]
country_data = json.loads((ROOT / "data/countries.json").read_text(encoding="utf-8"))
map_path = ROOT / "data/country_maps.json"
national = json.loads(map_path.read_text(encoding="utf-8"))
ids = {country["id"] for country in country_data["countries"]}
map_ids = set(national.get("countries", {}))
errors = []
fa_pattern = re.compile(r"[\u0600-\u06ff\ufb50-\ufdff\ufe70-\ufeff]")

if map_ids != ids:
    errors.append(f"national map ISO set mismatch: missing={sorted(ids-map_ids)}, extra={sorted(map_ids-ids)}")
if national.get("country_count") != 195:
    errors.append("country_count must be 195")
if not 4_000 <= int(national.get("admin_unit_count", 0)) <= 6_000:
    errors.append("Admin-1 count outside expected Natural Earth range")
if not 1_500 <= int(national.get("city_count", 0)) <= 3_000:
    errors.append("city count outside mobile display budget")
if not fa_pattern.search(str(national.get("model_notice_fa", ""))):
    errors.append("Persian gameplay-model notice missing")
for source in national.get("sources", []):
    if str(source.get("license", "")).lower() != "public domain":
        errors.append(f"non-public-domain national map source: {source}")

point_count = 0
unit_count = 0
city_count = 0
for code, data in national.get("countries", {}).items():
    units = data.get("units", [])
    cities = data.get("cities", [])
    if not units:
        errors.append(f"{code}: no administrative unit")
        continue
    if not cities:
        errors.append(f"{code}: no city/capital")
    if not any(city.get("capital") for city in cities):
        errors.append(f"{code}: no national capital")
    if len(cities) > 16:
        errors.append(f"{code}: too many mobile city markers")
    pop_sum = sum(float(unit.get("population_share", 0)) for unit in units)
    economy_sum = sum(float(unit.get("economy_share", 0)) for unit in units)
    if not math.isclose(pop_sum, 1.0, abs_tol=2e-5):
        errors.append(f"{code}: population shares sum to {pop_sum}")
    if not math.isclose(economy_sum, 1.0, abs_tol=2e-5):
        errors.append(f"{code}: economy shares sum to {economy_sum}")
    seen = set()
    for unit in units:
        unit_count += 1
        unit_id = str(unit.get("id", ""))
        if not unit_id or unit_id in seen:
            errors.append(f"{code}: empty/duplicate unit ID {unit_id!r}")
        seen.add(unit_id)
        if not fa_pattern.search(str(unit.get("name_fa", ""))) or not fa_pattern.search(str(unit.get("type_fa", ""))):
            errors.append(f"{code}/{unit_id}: non-Persian player-facing admin label")
        if float(unit.get("area_weight", 0)) <= 0:
            errors.append(f"{code}/{unit_id}: invalid area weight")
        if not 0 <= float(unit.get("resource_index", -1)) <= 1 or not 0 <= float(unit.get("strategic_index", -1)) <= 1:
            errors.append(f"{code}/{unit_id}: invalid gameplay index")
        polygons = unit.get("polygons", [])
        if not polygons:
            errors.append(f"{code}/{unit_id}: no polygons")
        for polygon in polygons:
            outer = polygon.get("outer", [])
            if len(outer) < 4 or outer[0] != outer[-1]:
                errors.append(f"{code}/{unit_id}: invalid or unclosed outer ring")
                continue
            for ring in [outer] + polygon.get("holes", []):
                point_count += len(ring)
                for point in ring:
                    if len(point) < 2 or not -180 <= point[0] <= 180 or not -90 <= point[1] <= 90:
                        errors.append(f"{code}/{unit_id}: coordinate out of range")
                        break
    for city in cities:
        city_count += 1
        if not fa_pattern.search(str(city.get("name_fa", ""))):
            errors.append(f"{code}: non-Persian city name")
        if not -180 <= float(city.get("lon", 999)) <= 180 or not -90 <= float(city.get("lat", 999)) <= 90:
            errors.append(f"{code}: city coordinate out of range")
        if str(city.get("unit_id", "")) and str(city.get("unit_id")) not in seen:
            errors.append(f"{code}: city references unknown unit")

if unit_count != national.get("admin_unit_count"):
    errors.append("admin_unit_count metadata mismatch")
if city_count != national.get("city_count"):
    errors.append("city_count metadata mismatch")
if not 180_000 <= point_count <= 350_000:
    errors.append(f"national-map point budget invalid: {point_count}")
if map_path.stat().st_size > 8_000_000:
    errors.append(f"national-map data exceeds 8 MB mobile budget: {map_path.stat().st_size}")
if errors:
    raise SystemExit("COUNTRY MAPS INVALID\n" + "\n".join(errors[:150]))
print(f"COUNTRY MAPS OK: 195 countries, {unit_count} admin units, {city_count} Persian cities, {point_count} points")
