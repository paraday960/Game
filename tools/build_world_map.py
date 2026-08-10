#!/usr/bin/env python3
"""Build the game's compact selectable world polygons from Natural Earth 1:50m.

Natural Earth is public domain. This generator downloads the source, maps map-units
onto the game's 195 sovereign IDs, simplifies rings, and emits deterministic JSON.
"""
from __future__ import annotations
import json
import math
import urllib.request
from pathlib import Path

ROOT = Path(__file__).parents[1]
SOURCE_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson"
OUTPUT = ROOT / "data" / "world_polygons.json"
COUNTRIES = ROOT / "data" / "countries.json"


def point_line_distance(p, a, b):
    if a == b:
        return math.dist(p, a)
    x, y = p; x1, y1 = a; x2, y2 = b
    t = max(0.0, min(1.0, ((x-x1)*(x2-x1)+(y-y1)*(y2-y1))/((x2-x1)**2+(y2-y1)**2)))
    return math.dist(p, (x1+t*(x2-x1), y1+t*(y2-y1)))


def rdp(points, epsilon):
    if len(points) < 3:
        return points
    index, maximum = 0, 0.0
    for i in range(1, len(points)-1):
        distance = point_line_distance(points[i], points[0], points[-1])
        if distance > maximum:
            index, maximum = i, distance
    if maximum > epsilon:
        return rdp(points[:index+1], epsilon)[:-1] + rdp(points[index:], epsilon)
    return [points[0], points[-1]]


def simplify_ring(raw):
    points = [(float(x), float(y)) for x, y in raw]
    if len(points) < 4:
        return []
    if points[0] == points[-1]:
        points = points[:-1]
    span = max(max(p[0] for p in points)-min(p[0] for p in points), max(p[1] for p in points)-min(p[1] for p in points))
    epsilon = 0.008 if span < 1.0 else (0.025 if span < 5.0 else 0.06)
    closed = points + [points[0]]
    simple = rdp(closed, epsilon)
    if simple[0] != simple[-1]:
        simple.append(simple[0])
    if len(simple) < 4:
        simple = closed
    return [[round(x, 4), round(y, 4)] for x, y in simple]


def iter_polygons(geometry):
    if geometry["type"] == "Polygon":
        yield geometry["coordinates"]
    elif geometry["type"] == "MultiPolygon":
        yield from geometry["coordinates"]


def main():
    source_path = Path("/tmp/ne_50m_admin_0_countries.geojson")
    if not source_path.exists():
        urllib.request.urlretrieve(SOURCE_URL, source_path)
    source = json.loads(source_path.read_text())
    countries_data = json.loads(COUNTRIES.read_text())
    ids = {c["id"] for c in countries_data["countries"]}
    output = {code: [] for code in ids}
    original_points = simplified_points = 0
    for feature in source["features"]:
        props = feature["properties"]
        adm, sovereign, iso = props.get("ADM0_A3"), props.get("SOV_A3"), props.get("ISO_A3")
        if adm in ids:
            target = adm
        elif iso in ids:
            target = iso
        elif sovereign in ids:
            target = sovereign
        else:
            continue
        for polygon in iter_polygons(feature["geometry"]):
            if not polygon:
                continue
            original_points += sum(len(r) for r in polygon)
            outer = simplify_ring(polygon[0])
            holes = [simplify_ring(r) for r in polygon[1:] if len(r) >= 4]
            holes = [r for r in holes if r]
            if not outer:
                continue
            simplified_points += len(outer) + sum(len(r) for r in holes)
            output[target].append({"outer": outer, "holes": holes})
    # Natural Earth has geometry for all 195 in the current dataset. Fail rather than silently emit gaps.
    missing = sorted(code for code, polygons in output.items() if not polygons)
    if missing:
        raise SystemExit(f"Missing Natural Earth polygons: {missing}")
    result = {
        "version": "1.0.0",
        "source": {"name": "Natural Earth 1:50m Admin-0 Countries", "url": SOURCE_URL, "license": "Public Domain"},
        "projection": "web_mercator_runtime",
        "country_count": len(output),
        "original_points": original_points,
        "simplified_points": simplified_points,
        "countries": {code: output[code] for code in sorted(output)},
    }
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"Wrote {OUTPUT}: {len(output)} countries, {original_points} -> {simplified_points} points")


if __name__ == "__main__":
    main()
