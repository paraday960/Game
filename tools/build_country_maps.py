#!/usr/bin/env python3
"""Build compact national maps for every playable country.

The runtime output contains real Natural Earth Admin-1 polygons and a curated set of
real populated places. Static geometry remains outside game State/network snapshots.
Natural Earth data is public domain.
"""
from __future__ import annotations

import json
import math
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).parents[1]
COUNTRIES_PATH = ROOT / "data" / "countries.json"
WORLD_PATH = ROOT / "data" / "world_polygons.json"
OUTPUT_PATH = ROOT / "data" / "country_maps.json"
ADMIN_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_1_states_provinces.geojson"
CITY_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_populated_places.geojson"
ADMIN_CACHE = Path("/tmp/ne_10m_admin_1_states_provinces.geojson")
CITY_CACHE = Path("/tmp/ne_10m_populated_places.geojson")
CODE_ALIASES = {"PSX": "PSE", "SDS": "SSD"}

TYPE_FA = {
    "State": "ایالت", "Province": "استان", "Region": "منطقه",
    "Governorate": "استان", "Department": "بخش", "District": "ناحیه",
    "County": "شهرستان", "Municipality": "منطقه شهری", "Parish": "حوزه",
    "Prefecture": "استان", "Territory": "قلمرو", "Canton": "کانتون",
    "Oblast": "استان", "Republic": "جمهوری خودمختار", "Emirate": "امارت",
    "Autonomous Region": "منطقه خودمختار", "Federal District": "ناحیه فدرال",
    "Federal Territory": "قلمرو فدرال", "Special Municipality": "منطقه ویژه",
}


def download(url: str, target: Path) -> None:
    if not target.exists():
        urllib.request.urlretrieve(url, target)


def point_line_distance(point, start, end):
    if start == end:
        return math.dist(point, start)
    x, y = point
    x1, y1 = start
    x2, y2 = end
    denominator = (x2 - x1) ** 2 + (y2 - y1) ** 2
    ratio = max(0.0, min(1.0, ((x - x1) * (x2 - x1) + (y - y1) * (y2 - y1)) / denominator))
    return math.dist(point, (x1 + ratio * (x2 - x1), y1 + ratio * (y2 - y1)))


def rdp(points, epsilon):
    """Non-recursive Ramer-Douglas-Peucker for unusually long coastlines."""
    if len(points) < 3:
        return points
    keep = {0, len(points) - 1}
    stack = [(0, len(points) - 1)]
    while stack:
        start, end = stack.pop()
        furthest = 0.0
        index = -1
        for i in range(start + 1, end):
            distance = point_line_distance(points[i], points[start], points[end])
            if distance > furthest:
                furthest, index = distance, i
        if index >= 0 and furthest > epsilon:
            keep.add(index)
            stack.append((start, index))
            stack.append((index, end))
    return [points[i] for i in sorted(keep)]


def simplify_ring(raw):
    points = [(float(point[0]), float(point[1])) for point in raw if len(point) >= 2]
    if len(points) < 4:
        return []
    if points[0] == points[-1]:
        points.pop()
    if len(points) < 3:
        return []
    lon_span = max(p[0] for p in points) - min(p[0] for p in points)
    lat_span = max(p[1] for p in points) - min(p[1] for p in points)
    span = max(lon_span, lat_span)
    # Admin-1 is viewed much closer than the global map. Preserve small islands,
    # while strongly reducing large coastlines for Android rendering.
    epsilon = 0.003 if span < 0.20 else (0.008 if span < 1.0 else (0.018 if span < 5.0 else 0.035))
    closed = points + [points[0]]
    simple = rdp(closed, epsilon)
    if simple[0] != simple[-1]:
        simple.append(simple[0])
    if len(simple) < 4:
        simple = closed
    return [[round(x, 4), round(y, 4)] for x, y in simple]


def iter_polygons(geometry):
    if not geometry:
        return
    if geometry.get("type") == "Polygon":
        yield geometry.get("coordinates", [])
    elif geometry.get("type") == "MultiPolygon":
        yield from geometry.get("coordinates", [])


def ring_area(ring):
    if len(ring) < 4:
        return 0.0
    # Equirectangular approximation is sufficient for relative in-country weights.
    mean_lat = math.radians(sum(point[1] for point in ring[:-1]) / max(1, len(ring) - 1))
    scale = max(0.12, abs(math.cos(mean_lat)))
    total = 0.0
    for first, second in zip(ring, ring[1:]):
        total += (first[0] * scale) * second[1] - (second[0] * scale) * first[1]
    return abs(total) * 0.5


def point_in_ring(lon, lat, ring):
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i]
        xj, yj = ring[j]
        intersects = ((yi > lat) != (yj > lat)) and (lon < (xj - xi) * (lat - yi) / ((yj - yi) or 1e-12) + xi)
        if intersects:
            inside = not inside
        j = i
    return inside


def unit_contains(unit, lon, lat):
    for polygon in unit["polygons"]:
        if point_in_ring(lon, lat, polygon["outer"]):
            if not any(point_in_ring(lon, lat, hole) for hole in polygon["holes"]):
                return True
    return False


def country_code(properties, upper=False):
    key = "ADM0_A3" if upper else "adm0_a3"
    return CODE_ALIASES.get(str(properties.get(key, "")), str(properties.get(key, "")))


def fa_type(value):
    raw = str(value or "Region")
    if raw in TYPE_FA:
        return TYPE_FA[raw]
    lower = raw.lower()
    for key, translated in TYPE_FA.items():
        if key.lower() in lower:
            return translated
    return "ناحیه اداری"


def stable_fraction(text):
    value = 2166136261
    for byte in text.encode("utf-8"):
        value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
    return value / 0xFFFFFFFF


def build_admin_units(admin_source, country_profiles, world_geometry):
    ids = set(country_profiles)
    result = defaultdict(list)
    original_points = 0
    simplified_points = 0
    fallback_index = defaultdict(int)
    for feature in admin_source["features"]:
        properties = feature.get("properties", {})
        code = country_code(properties)
        if code not in ids:
            continue
        raw_name = properties.get("name_fa")
        if not raw_name:
            fallback_index[code] += 1
            raw_name = f"ناحیه {fallback_index[code]}"
        polygons = []
        area_weight = 0.0
        for polygon in iter_polygons(feature.get("geometry")):
            if not polygon:
                continue
            original_points += sum(len(ring) for ring in polygon)
            outer = simplify_ring(polygon[0])
            holes = [simplify_ring(ring) for ring in polygon[1:] if len(ring) >= 4]
            holes = [ring for ring in holes if ring]
            if not outer:
                continue
            simplified_points += len(outer) + sum(len(ring) for ring in holes)
            area_weight += ring_area(outer) - sum(ring_area(hole) for hole in holes)
            polygons.append({"outer": outer, "holes": holes})
        if not polygons:
            continue
        index = len(result[code]) + 1
        unit_id = str(properties.get("adm1_code") or f"{code}-{index:03d}")
        center_lon = float(properties.get("longitude") or country_profiles[code]["lon"])
        center_lat = float(properties.get("latitude") or country_profiles[code]["lat"])
        result[code].append({
            "id": unit_id,
            "name_fa": str(raw_name),
            "type_fa": fa_type(properties.get("type_en")),
            "center": [round(center_lon, 4), round(center_lat, 4)],
            "area_weight": round(max(area_weight, 0.000001), 8),
            "capital": False,
            "polygons": polygons,
        })

    # Natural Earth covers all 195 after the PSE/SSD aliases. Keep a defensive
    # whole-country unit so future source revisions can never make a country map empty.
    for code in sorted(ids):
        if result[code]:
            continue
        profile = country_profiles[code]
        polygons = world_geometry["countries"].get(code, [])
        area_weight = sum(ring_area(polygon["outer"]) for polygon in polygons)
        result[code].append({
            "id": f"{code}-000", "name_fa": "ناحیه مرکزی", "type_fa": "ناحیه اداری",
            "center": [profile["lon"], profile["lat"]], "area_weight": round(max(area_weight, 0.000001), 8),
            "capital": True, "polygons": polygons,
        })
        simplified_points += sum(len(polygon["outer"]) + sum(len(hole) for hole in polygon.get("holes", [])) for polygon in polygons)
    return result, original_points, simplified_points


def build_cities(city_source, country_profiles, units):
    ids = set(country_profiles)
    candidates = defaultdict(list)
    for feature in city_source["features"]:
        properties = feature.get("properties", {})
        code = country_code(properties, upper=True)
        if code not in ids:
            continue
        name_fa = str(properties.get("NAME_FA") or "").strip()
        if not name_fa:
            continue
        candidates[code].append({
            "name_fa": name_fa,
            "lon": round(float(properties.get("LONGITUDE") or feature["geometry"]["coordinates"][0]), 4),
            "lat": round(float(properties.get("LATITUDE") or feature["geometry"]["coordinates"][1]), 4),
            "population": max(0, int(properties.get("POP_MAX") or 0)),
            "capital": int(properties.get("ADM0CAP") or 0) == 1,
        })

    output = {}
    for code, profile in country_profiles.items():
        raw = candidates.get(code, [])
        capitals = sorted((city for city in raw if city["capital"]), key=lambda city: -city["population"])
        others = sorted((city for city in raw if not city["capital"]), key=lambda city: -city["population"])
        # Multiple official capitals (South Africa, Bolivia, Côte d'Ivoire) are retained.
        selected = capitals + others[:max(0, 14 - len(capitals))]
        if not capitals:
            selected.insert(0, {
                "name_fa": profile["capital_fa"], "lon": round(float(profile["lon"]), 4),
                "lat": round(float(profile["lat"]), 4), "population": 0, "capital": True,
            })
        seen = set()
        deduplicated = []
        for city in selected:
            key = (city["name_fa"], city["lon"], city["lat"])
            if key in seen:
                continue
            seen.add(key)
            unit_id = ""
            for unit in units[code]:
                if unit_contains(unit, city["lon"], city["lat"]):
                    unit_id = unit["id"]
                    if city["capital"]:
                        unit["capital"] = True
                    break
            city["unit_id"] = unit_id
            deduplicated.append(city)
        output[code] = deduplicated
    return output


def add_gameplay_weights(units, cities):
    for code, country_units in units.items():
        population_weights = []
        economy_weights = []
        for unit in country_units:
            density = 0.55 + stable_fraction(unit["id"] + "-population") * 1.25
            if unit["capital"]:
                density *= 2.25
            city_population = sum(city["population"] for city in cities[code] if city["unit_id"] == unit["id"])
            city_boost = 1.0 + min(3.0, math.log10(max(1, city_population)) / 5.0)
            population_weight = max(unit["area_weight"], 1e-8) ** 0.72 * density * city_boost
            economy_weight = population_weight * (0.70 + stable_fraction(unit["id"] + "-economy") * 0.65 + (0.45 if unit["capital"] else 0.0))
            population_weights.append(population_weight)
            economy_weights.append(economy_weight)
        pop_total = sum(population_weights) or 1.0
        economy_total = sum(economy_weights) or 1.0
        for unit, pop_weight, economy_weight in zip(country_units, population_weights, economy_weights):
            unit["population_share"] = round(pop_weight / pop_total, 8)
            unit["economy_share"] = round(economy_weight / economy_total, 8)
            unit["resource_index"] = round(0.20 + stable_fraction(unit["id"] + "-resource") * 0.80, 4)
            unit["strategic_index"] = round(0.20 + stable_fraction(unit["id"] + "-strategic") * 0.80, 4)


def main():
    download(ADMIN_URL, ADMIN_CACHE)
    download(CITY_URL, CITY_CACHE)
    countries_data = json.loads(COUNTRIES_PATH.read_text(encoding="utf-8"))
    profiles = {country["id"]: country for country in countries_data["countries"]}
    world_geometry = json.loads(WORLD_PATH.read_text(encoding="utf-8"))
    admin_source = json.loads(ADMIN_CACHE.read_text(encoding="utf-8"))
    city_source = json.loads(CITY_CACHE.read_text(encoding="utf-8"))

    units, original_points, simplified_points = build_admin_units(admin_source, profiles, world_geometry)
    cities = build_cities(city_source, profiles, units)
    add_gameplay_weights(units, cities)

    countries = {}
    for code in sorted(profiles):
        countries[code] = {"units": units[code], "cities": cities[code]}
    result = {
        "version": "1.0.0",
        "sources": [
            {"name": "Natural Earth 1:10m Admin-1 States and Provinces", "url": ADMIN_URL, "license": "Public Domain"},
            {"name": "Natural Earth 1:10m Populated Places", "url": CITY_URL, "license": "Public Domain"},
        ],
        "model_notice_fa": "مرزها و شهرها جغرافیایی‌اند؛ توزیع شاخص‌های منطقه‌ای برآورد پویای مدل بازی است.",
        "country_count": len(countries),
        "admin_unit_count": sum(len(value["units"]) for value in countries.values()),
        "city_count": sum(len(value["cities"]) for value in countries.values()),
        "original_points": original_points,
        "simplified_points": simplified_points,
        "countries": countries,
    }
    OUTPUT_PATH.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(
        f"Wrote {OUTPUT_PATH}: {len(countries)} countries, "
        f"{result['admin_unit_count']} units, {result['city_count']} cities, "
        f"{original_points} -> {simplified_points} points"
    )


if __name__ == "__main__":
    main()
