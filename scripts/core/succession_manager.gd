extends Node
# ────────────────────────────────────────────────────────────────────────────
# جانشینی رهبر — عمق تداوم قدرت
# وارث تربیت می‌شود (هزینه سرمایه سیاسی) و ویژگی می‌گیرد. هر ~۴۰ نوبت بحران
# جانشینی (بیماری/فرسودگی رهبر) رخ می‌دهد: اگر وارث آماده باشد آرام می‌گذرد و
# محبوبیت می‌آورد؛ اگر نه، جناح‌ها برای قدرت می‌جنگند (ثبات آسیب، ریسک کودتای
# قصر). وارثِ آماده اگر رهبر بمیرد جانشین می‌شود.
#
# state["succession"] = { "heir":"", "heir_trait":"", "heir_approval":0..1,
#   "crisis":{..}|{}, "train_count":0, "history":[] }
# ────────────────────────────────────────────────────────────────────────────

const HEIR_TRAITS := ["صلح‌طلب", "جنگ‌طلب", "تکنوکرات", "پوپولیست", "میانه‌رو"]
const HEIR_NAMES := ["فرزند ارشد", "برادر رهبر", "وزیر باتجربه", "سردار وفادار", "تکنوکرات جوان"]

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("succession"):
		state["succession"] = {
			"heir": "", "heir_trait": "", "heir_approval": 0.4,
			"crisis": {}, "train_count": 0, "history": []
		}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var suc: Dictionary = state["succession"]
	var leader: Dictionary = state.get("leader", {})
	if str(leader.get("mode", "leader")) != "leader":
		return {"state": state, "events": events}
	var pol: Dictionary = state.get("politics", {})
	var factions: Dictionary = state.get("factions", {})

	# وارث آماده با گذر زمان محبوب‌تر می‌شود (تا حدی)
	var approval := float(suc.get("heir_approval", 0.4))
	suc["heir_approval"] = clampf(approval + 0.002, 0.0, 1.0)

	# بحران جانشینی هر ~۴۰ نوبت
	if suc.get("crisis", {}).is_empty() and Deterministic.chance(0.025):
		suc["crisis"] = {"turn": turn, "reason": "بیماری و فرسودگی رهبر"}
		if suc.get("heir", "") != "":
			events.append({"type": "succession_crisis", "message": "⚠️ بحران جانشینی: رهبر بیمار است؛ وارث «%s» آماده جانشینی است" % suc["heir"]})
		else:
			events.append({"type": "succession_crisis", "message": "⚠️ بحران جانشینی: رهبر بیمار است و وارثی تربیت نشده! جناح‌ها برای قدرت می‌جنگند"})
	elif not suc.get("crisis", {}).is_empty():
		var crisis: Dictionary = suc["crisis"]
		var age := turn - int(crisis.get("turn", turn))
		if age >= 2:
			# حل بحران
			if suc.get("heir", "") != "":
				var heir_trait := str(suc.get("heir_trait", "میانه‌رو"))
				# وارث به‌عنوان رهبر موقت منصوب می‌شود (رهبر بهبود می‌یابد ولی مشروعیت وارث بالا می‌رود)
				pol["stability"] = clampf(float(pol.get("stability", 0.6)) + 0.02, 0.05, 1.0)
				events.append({"type": "succession_resolved", "message": "🏛️ وارث «%s» (ویژگی: %s) به‌عنوان جانشین رسمی معرفی شد؛ آرامش بازگشت" % [suc["heir"], heir_trait]})
			else:
				# نبرد جناح‌ها: ثبات آسیب، محبوبیت رهبر کم می‌شود
				pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.06, 0.05, 1.0)
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 3.0, 0.0, 100.0)
				state["leader"] = leader
				events.append({"type": "succession_power_struggle", "message": "⚔️ مبارزه قدرت در قصر! جناح‌ها جانشین خود را تحمیل می‌کنند؛ ثبات ملی فرو ریخت"})
				# ریسک کودتای قصر
				if Deterministic.chance(0.15):
					# کودتای قصر: رهبر با فردی از جناح قوی جایگزین می‌شود
					var strongest := "ارتش"
					var strongest_loyalty := -1.0
					for fid in factions.keys():
						var f: Dictionary = factions[fid]
						if float(f.get("loyalty", 0.0)) > strongest_loyalty:
							strongest_loyalty = float(f.get("loyalty", 0.0))
							strongest = fid
					var old_name := str(leader.get("name_fa", "رهبر"))
					leader["name_fa"] = "رهبر جدید (از جناح " + strongest + ")"
					leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 5.0, 0.0, 100.0)
					state["leader"] = leader
					suc["crisis"] = {}
					state["succession"] = suc
					events.append({"type": "palace_coup", "message": "👑 کودتای قصر! «%s» کنار رفت و رهبر جدید از جناح %s قدرت گرفت" % [old_name, strongest]})
					state["politics"] = pol
					return {"state": state, "events": events}
			suc["crisis"] = {}
			var history: Array = suc.get("history", [])
			history.append({"turn": turn, "resolved": true})
			while history.size() > 20:
				history.pop_front()
			suc["history"] = history
	state["succession"] = suc
	state["politics"] = pol
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func train_heir(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست (۱ واحد)", "state": state, "events": []}
	var suc: Dictionary = state["succession"]
	if suc.get("heir", "") != "" and float(suc.get("heir_approval", 0.0)) >= 0.8:
		return {"success": false, "reason": "وارث کاملاً تربیت شده است", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 1.0
	if suc.get("heir", "") == "":
		suc["heir"] = HEIR_NAMES[Deterministic.next_int_range(0, HEIR_NAMES.size() - 1)]
		suc["heir_trait"] = HEIR_TRAITS[Deterministic.next_int_range(0, HEIR_TRAITS.size() - 1)]
		suc["heir_approval"] = 0.35
	suc["heir_approval"] = clampf(float(suc.get("heir_approval", 0.35)) + 0.12, 0.0, 1.0)
	suc["train_count"] = int(suc.get("train_count", 0)) + 1
	state["succession"] = suc
	return {"success": true, "state": state,
		"events": [{"type": "heir_training", "message": "🎓 تربیت وارث «%s» (ویژگی: %s) — آمادگی %s٪" % [
			suc["heir"], suc["heir_trait"], PersianFormatter.to_persian_digits(str(int(float(suc["heir_approval"]) * 100.0)))]}]}

func get_heir_summary(state: Dictionary) -> String:
	state = ensure(state)
	var suc: Dictionary = state["succession"]
	if suc.get("heir", "") == "":
		return "وارثی تربیت نشده است"
	return "وارث: %s (ویژگی: %s) — آمادگی %s٪" % [
		suc["heir"], suc["heir_trait"], PersianFormatter.to_persian_digits(str(int(float(suc.get("heir_approval", 0.0)) * 100.0)))]
