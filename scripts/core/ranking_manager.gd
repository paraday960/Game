extends Node
# ============================================================
# 🏆 مدیر رتبه‌بندی جهانی (الهام از World Empire)
# امتیاز کلی هر کشور از ترکیب اقتصاد، قدرت نظامی، فناوری و رضایت محاسبه می‌شود.
# رتبه بازیکن در میان ۱۹۵ کشور + همسایه‌های رتبه‌ای نمایش داده می‌شود.
# ============================================================

const MAX_RANKED = 30

func compute_rankings(state: Dictionary) -> Dictionary:
	var world: Dictionary = state.get("world", {})
	var countries: Dictionary = world.get("countries", {})
	var player: String = str(world.get("player_country", "IRN"))
	var player_econ: Dictionary = state.get("economy", {})
	var player_mil: Dictionary = state.get("military", {})
	var player_pop: Dictionary = state.get("population", {})
	var player_tech: Dictionary = state.get("technology", {})

	var entries: Array = []
	for code in countries.keys():
		var c: Dictionary = countries[code]
		var is_player: bool = str(code) == player
		var gdp: float = float(player_econ.get("gdp", 0.0)) if is_player else float(c.get("gdp", 1.0))
		var mil_power: float = float(player_mil.get("power", 60.0)) if is_player else float(c.get("military_power", 50.0))
		var pop: float = float(player_pop.get("total", 85e6)) if is_player else float(c.get("population", 1e6))
		var tech: float = float(player_tech.get("level", 0.3)) if is_player else float(c.get("tech_level", 0.3))
		var happiness: float = float(player_pop.get("happiness", 0.6)) if is_player else 0.6
		var gdp_pc: float = gdp / max(pop, 1.0)
		# امتیاز ترکیبی وزن‌دار
		var score := 0.0
		score += clamp(log(gdp_pc + 1.0) / 12.0, 0.0, 1.0) * 30.0
		score += clamp(mil_power / 100.0, 0.0, 1.3) * 30.0
		score += tech * 20.0
		score += happiness * 20.0
		entries.append({
			"code": code, "name_fa": c.get("name_fa", code),
			"gdp": gdp, "mil": mil_power, "pop": pop, "tech": tech,
			"score": score, "is_player": is_player
		})
	entries.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var ranked: Array = []
	var player_rank := -1
	for i in range(entries.size()):
		entries[i]["rank"] = i + 1
		if entries[i]["is_player"]:
			player_rank = i + 1
		if i < MAX_RANKED or entries[i]["is_player"]:
			ranked.append(entries[i])
	return {"ranked": ranked, "player_rank": player_rank, "total": entries.size()}
