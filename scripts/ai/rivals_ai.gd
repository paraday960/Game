extends BaseAI
# ────────────────────────────────────────────────────────────────────────────
# هوش رقبای داخلی (عمق‌بخشی ۴۹) — مشاور امنیت داخلی رهبر
# وضعیت رقبا را می‌سنجد و بحرانی‌ترین اقدام را پیشنهاد می‌دهد: توطئه‌گرِ فعال
# باید زیر نظر گرفته یا تبعید شود؛ رقیب ناراضی با مذاکره یا همکاری مهار شود.
# اصل ۲.۲.۷: هر جزء بازی هوش منحصربه‌فرد خود را دارد.
# پیشنهاد فقط مشاوره‌ای است (بدون فرمان خودکار) — تصمیم نهایی با بازیکن.
# ────────────────────────────────────────────────────────────────────────────

func diagnose(state: Dictionary) -> Dictionary:
	var rivals: Dictionary = state.get("rivals", {})
	var figures: Array = rivals.get("figures", [])
	var threat := float(rivals.get("threat", 0.15))
	if figures.is_empty():
		return _profile(state)
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	var plotting: Dictionary = {}
	var restless: Dictionary = {}
	var max_score := 0.0
	var danger: Dictionary = {}
	for f in figures:
		var score := float(f.get("support", 0.0)) * 0.6 + float(f.get("ambition", 0.0)) * 0.4
		if score > max_score:
			max_score = score
			danger = f
		if str(f.get("status", "loyal")) == "plotting" and plotting.is_empty():
			plotting = f
		elif str(f.get("status", "loyal")) == "restless" and restless.is_empty():
			restless = f
	if not plotting.is_empty():
		var pname := str(plotting.get("name_fa", ""))
		return _advice("🕵️ خنثی‌سازی توطئهٔ «%s»" % pname,
			"«%s» در حال توطئه است؛ زیر نظر بگیرید یا تبعیدش کنید — سرویس اطلاعات می‌تواند شبکه‌اش را فروبپاشد." % pname,
			clampf(0.65 + threat * 0.35, 0.0, 1.0), "rivals.threat", threat, 0.3)
	if not restless.is_empty() and capital >= 0.5:
		var rname := str(restless.get("name_fa", ""))
		return _advice("🗣️ مذاکره با «%s»" % rname,
			"«%s» از رهبر فاصله گرفته؛ مذاکره وفاداری را بالا می‌برد و جاه‌طلبی را می‌خواباند." % rname,
			clampf(0.4 + threat * 0.3, 0.0, 1.0), "rivals.threat", threat, 0.3)
	if not danger.is_empty() and threat >= 0.55:
		var dname := str(danger.get("name_fa", ""))
		return _advice("🤝 همکاری با «%s»" % dname,
			"«%s» خطرناک‌ترین چهرهٔ مخالف است؛ دعوت به هیئت دولت وفاداری می‌خرد هرچند کمی فساد می‌آورد." % dname,
			clampf(threat * 0.9, 0.0, 1.0), "rivals.threat", threat, 0.3)
	return _profile(state)

# پروندهٔ پایهٔ تشخیصی — همیشه غیرخالی تا شورای هوشمند همهٔ ۶۹ عامل را کامل ببیند
func _profile(state: Dictionary) -> Dictionary:
	var threat := float(state.get("rivals", {}).get("threat", 0.15))
	return {
		"system": "rivals",
		"title": "تهدید رقبای داخلی",
		"metric_path": "rivals.threat",
		"value": threat,
		"target": 0.3,
		"health": clampf(1.0 - threat, 0.0, 1.0),
		"urgency": clampf((threat - 0.15) / 0.55, 0.0, 1.0),
		"budget_key": "ذخیره",
		"reason": "تهدید رقبای داخلی بالاست؛ با مذاکره، همکاری، نظارت یا تبعید آن را مهار کنید."
	}

func _advice(title: String, reason: String, urgency: float, metric_path: String, value: float, target: float) -> Dictionary:
	return {
		"system": "rivals",
		"title": title,
		"reason": reason,
		"urgency": urgency,
		"metric_path": metric_path,
		"value": value,
		"target": target,
		"health": clampf(1.0 - urgency, 0.0, 1.0),
		"budget_key": ""
	}
