extends BaseAI
# ────────────────────────────────────────────────────────────────────────────
# هوش رهبر (عمق‌بخشی ۴۸) — مشاور رهبری
# وضعیت رهبر و کشور را می‌سنجد و بهترین «اقدام فعال رهبر» را پیشنهاد می‌دهد.
# اصل ۲.۲.۷: هر جزء بازی هوش منحصربه‌فرد خود را دارد — رهبر هم همین‌طور.
# پیشنهاد فقط نمایشی است (بدون کلید command) تا تصمیم نهایی همیشه با بازیکن
# بماند: هوش، رهبر مطلق را هدایت می‌کند نه این‌که جایش تصمیم بگیرد.
# ────────────────────────────────────────────────────────────────────────────

func diagnose(state: Dictionary) -> Dictionary:
	var leader: Dictionary = state.get("leader", {})
	if leader.is_empty() or str(leader.get("mode", "leader")) != "leader" or not bool(leader.get("alive", true)):
		return _profile(state)
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	var corruption := float(state.get("politics", {}).get("corruption", 0.3))
	var tension := float(state.get("ethnicity", {}).get("tension", 0.3))
	var freedom := float(state.get("culture", {}).get("media_freedom", 0.5))
	var wars: Dictionary = state.get("world", {}).get("wars", {})
	var happiness := float(state.get("population", {}).get("happiness", 0.6))
	var stability := float(state.get("politics", {}).get("stability", 0.6))
	var confidence := float(state.get("economy", {}).get("cycle", {}).get("confidence", 55.0))
	var morale := float(state.get("military", {}).get("morale", 0.7))
	# اولویت‌بندی دترمینستیک: بحرانی‌ترین وضعیت اول
	if corruption > 0.45:
		return _advice("🏙️ بازدید سرزده از نهادها",
			"فساد بالاست؛ بازدید سرزده فساد را رو می‌کند و اعتماد مردم را بالا می‌برد.",
			clampf((corruption - 0.3) / 0.5, 0.0, 1.0), "politics.corruption", corruption, 0.3)
	if tension > 0.35:
		return _advice("🕌 گفتگوی ملی با اقوام و مذاهب",
			"تنش هویتی رو به رشد است؛ گفتگوی ملی همبستگی می‌سازد و ثبات را بالا می‌برد.",
			clampf((tension - 0.3) / 0.5, 0.0, 1.0), "ethnicity.tension", tension, 0.3)
	if not wars.is_empty() and morale < 0.8:
		return _advice("🎖️ نشان ملی به قهرمانان جنگ",
			"کشور در جنگ است و روحیهٔ ارتش باید تقویت شود؛ نشان ملی هم روحیه می‌دهد هم جایگاه ایثارگران را بالا می‌برد.",
			clampf((0.8 - morale) / 0.3, 0.0, 1.0), "military.morale", morale, 0.8)
	if happiness < 0.5 or stability < 0.5:
		return _advice("🏃 حضور میدانی رهبر در بحران",
			"رضایت یا ثبات پایین است؛ حضور میدانی سه ماه اثر تقویتی دارد.",
			clampf((0.5 - minf(happiness, stability)) / 0.3, 0.0, 1.0), "population.happiness", happiness, 0.5)
	if confidence < 45.0:
		return _advice("💼 دیدار با سرمایه‌داران",
			"اعتماد سرمایه‌گذاران شکننده است؛ دیدار سرمایه‌داران چرخهٔ اقتصاد را گرم می‌کند.",
			clampf((45.0 - confidence) / 20.0, 0.0, 1.0), "economy.cycle.confidence", confidence, 45.0)
	if capital > 2.5 and freedom >= 0.35:
		return _advice("🕊️ سخنرانی در سازمان ملل",
			"سرمایهٔ سیاسی موجود است و رسانه آزاد؛ وقت نفوذ نرم جهانی رسیده است.",
			0.2, "policies.political_capital", capital, 2.5)
	return _profile(state)

# پروندهٔ پایهٔ تشخیصی — همیشه غیرخالی تا شورای هوشمند همهٔ ۶۸ عامل را کامل ببیند
func _profile(state: Dictionary) -> Dictionary:
	var leader: Dictionary = state.get("leader", {})
	var popularity := float(leader.get("popularity_world", 50.0))
	return {
		"system": "leader",
		"title": "محبوبیت جهانی رهبر",
		"metric_path": "leader.popularity_world",
		"value": popularity,
		"target": 55.0,
		"health": clampf(popularity / 55.0, 0.0, 1.0),
		"urgency": clampf((55.0 - popularity) / 55.0, 0.0, 1.0),
		"budget_key": "ذخیره",
		"reason": "محبوبیت جهانی رهبر زیر نقطهٔ تعادل است؛ دیپلماسی و اقدامات آشکار آن را بالا می‌برد."
	}

func _advice(title: String, reason: String, urgency: float, metric_path: String, value: float, target: float) -> Dictionary:
	return {
		"system": "leader",
		"title": title,
		"reason": reason,
		"urgency": urgency,
		"metric_path": metric_path,
		"value": value,
		"target": target,
		"health": clampf(1.0 - urgency, 0.0, 1.0),
		"budget_key": ""
	}
