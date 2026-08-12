extends Node
# ────────────────────────────────────────────────────────────────────────────
# رسانه و افکار عمومی — عمق جامعه
# چهار گروه جمعیتی (شهرنشینان، روستاییان، جوانان، بازنشستگان) هرکدام «رضایت» و
# «وزن» دارند. سیاست رسانه‌ای (آزاد/دولتی/پوپولیستی) رضایت گروه‌ها را جابه‌جا
# می‌کند؛ بحران‌ها و جنگ‌ها افکار را می‌شکنند؛ بازیکن کمپین رسانه‌ای راه می‌اندازد.
#
# state["media"] = {
#   "policy": "free"|"state"|"populist",
#   "groups": { "شهرنشینان": {"approval":0..100,"weight":0..1}, ... },
#   "campaign": {"turns_left":0,"target":"","style":"","strength":0},
#   "trust": 0..1
# }
# ────────────────────────────────────────────────────────────────────────────

const GROUPS := ["شهرنشینان", "روستاییان", "جوانان", "بازنشستگان"]
const DEFAULT_WEIGHTS := {"شهرنشینان": 0.55, "روستاییان": 0.20, "جوانان": 0.15, "بازنشستگان": 0.10}

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("media"):
		state["media"] = {
			"policy": "free",
			"groups": {
				"شهرنشینان": {"approval": 55.0, "weight": 0.55},
				"روستاییان": {"approval": 60.0, "weight": 0.20},
				"جوانان": {"approval": 45.0, "weight": 0.15},
				"بازنشستگان": {"approval": 52.0, "weight": 0.10}
			},
			"campaign": {"turns_left": 0, "target": "", "style": "", "strength": 0.0},
			"trust": 0.55
		}
	return state

# میانگین وزنی رضایت (شاخص افکار عمومی)
func overall_approval(state: Dictionary) -> float:
	state = ensure(state)
	var media: Dictionary = state["media"]
	var total := 0.0
	var weight_sum := 0.0
	for gid in media.get("groups", {}).keys():
		var g: Dictionary = media["groups"][gid]
		total += float(g.get("approval", 50.0)) * float(g.get("weight", DEFAULT_WEIGHTS.get(gid, 0.25)))
		weight_sum += float(g.get("weight", DEFAULT_WEIGHTS.get(gid, 0.25)))
	return total / max(weight_sum, 0.001)

func set_policy(state: Dictionary, policy: String, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	if not ["free", "state", "populist"].has(policy):
		return {"success": false, "reason": "سیاست رسانه‌ای نامعتبر", "state": state, "events": events}
	var media: Dictionary = state["media"]
	var old := str(media.get("policy", "free"))
	if old == policy:
		return {"success": false, "reason": "همین سیاست فعال است", "state": state, "events": events}
	media["policy"] = policy
	var policy_effect: Dictionary = {
		"free": {"شهرنشینان": 4.0, "جوانان": 5.0, "روستاییان": -2.0, "trust": 0.03},
		"state": {"شهرنشینان": -1.0, "جوانان": -3.0, "روستاییان": 3.0, "trust": -0.04},
		"populist": {"شهرنشینان": 2.0, "جوانان": 6.0, "روستاییان": 4.0, "trust": -0.06}
	}.get(policy, {})
	for gid in media.get("groups", {}).keys():
		var g: Dictionary = media["groups"][gid]
		g["approval"] = clampf(float(g.get("approval", 50.0)) + float(policy_effect.get(gid, 0.0)), 5.0, 100.0)
		media["groups"][gid] = g
	media["trust"] = clampf(float(media.get("trust", 0.55)) + float(policy_effect.get("trust", 0.0)), 0.0, 1.0)
	state["media"] = media
	var names := {"free": "رسانه آزاد", "state": "رسانه دولتی", "populist": "رسانه پوپولیستی"}
	events.append({"type": "media_policy", "message": "📺 سیاست رسانه‌ای به «%s» تغییر کرد" % names.get(policy, policy)})
	return {"success": true, "state": state, "events": events}

# ── کمپین رسانه‌ای: هدف گروه + سبک (صادقانه/احساسی/تخریبی) ──
func can_campaign(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست"}
	var media: Dictionary = state["media"]
	var campaign: Dictionary = media.get("campaign", {})
	if int(campaign.get("turns_left", 0)) > 0:
		return {"valid": false, "reason": "یک کمپین هنوز در جریان است"}
	return {"valid": true, "reason": ""}

func start_campaign(state: Dictionary, target_group: String, style: String) -> Dictionary:
	state = ensure(state)
	var check := can_campaign(state)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	if not GROUPS.has(target_group) or not ["honest", "emotional", "smear"].has(style):
		return {"success": false, "reason": "گروه یا سبک نامعتبر", "state": state, "events": []}
	var media: Dictionary = state["media"]
	media["campaign"] = {"turns_left": 2, "target": target_group, "style": style, "strength": 0.5}
	state["media"] = media
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = float(policies.get("political_capital", 0.0)) - 1.0
	state["policies"] = policies
	var styles := {"honest": "صادقانه", "emotional": "احساسی", "smear": "تخریبی"}
	return {"success": true, "state": state,
		"events": [{"type": "campaign_started", "message": "📣 کمپین %s برای «%s» آغاز شد (۲ نوبت)" % [styles.get(style, style), target_group]}]}

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var media: Dictionary = state["media"]
	var groups: Dictionary = media.get("groups", {})
	var campaign: Dictionary = media.get("campaign", {})
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var pol: Dictionary = state.get("politics", {})
	var world: Dictionary = state.get("world", {})
	var at_war: bool = not world.get("wars", {}).is_empty()
	var unemployment := float(econ.get("unemployment", 0.08))
	var inflation := float(econ.get("inflation", 0.08))
	var happiness := float(pop.get("happiness", 0.6))
	var stability := float(pol.get("stability", 0.6))
	var trust := float(media.get("trust", 0.55))
	var policy := str(media.get("policy", "free"))

	# ── رضایت گروه‌ها از وضعیت اقتصادی/اجتماعی ──
	var group_drift: Dictionary = {
		"شهرنشینان": (0.5 - unemployment * 2.0 - inflation * 1.5 + stability * 0.3) * 0.6,
		"روستاییان": (0.45 - inflation * 1.0 + stability * 0.4) * 0.5,
		"جوانان": (0.4 - unemployment * 3.0 + (1.0 - trust) * 0.3) * 0.7,
		"بازنشستگان": (0.5 - inflation * 2.5 + stability * 0.2) * 0.5
	}
	# رسانه دولتی روستاییان را آرام، پوپولیستی جوانان را متحرک نگه می‌دارد
	if policy == "state":
		group_drift["روستاییان"] += 0.8
		group_drift["جوانان"] -= 0.6
	elif policy == "populist":
		group_drift["جوانان"] += 1.2
		group_drift["شهرنشینان"] += 0.4
		trust -= 0.008
	elif policy == "free":
		trust += 0.006
	# جنگ: همه گروه‌ها فرسوده می‌شوند ولی رسانه دولتی می‌تواند امید بفروشد
	if at_war:
		for gid in groups.keys():
			group_drift[gid] = float(group_drift.get(gid, 0.0)) - 1.0
		if policy == "state":
			group_drift["روستاییان"] = float(group_drift.get("روستاییان", 0.0)) + 1.2
	for gid in groups.keys():
		var g: Dictionary = groups[gid]
		g["approval"] = clampf(float(g.get("approval", 50.0)) + float(group_drift.get(gid, 0.0)), 5.0, 100.0)
		groups[gid] = g

	# ── اجرای کمپین فعال ──
	if int(campaign.get("turns_left", 0)) > 0:
		var target := str(campaign.get("target", ""))
		var style := str(campaign.get("style", "honest"))
		var strength := float(campaign.get("strength", 0.5))
		var effect: float = float({"honest": 4.0, "emotional": 6.0, "smear": 8.0}.get(style, 4.0)) * strength
		if groups.has(target):
			var g: Dictionary = groups[target]
			g["approval"] = clampf(float(g.get("approval", 50.0)) + effect, 5.0, 100.0)
			groups[target] = g
		# هزینه اخلاقی سبک‌های تند
		if style == "smear" and trust > 0.15:
			trust -= 0.05
			events.append({"type": "media_backlash", "message": "📉 افشای تخریب‌گری کمپین، اعتماد به رسانه‌ها را خدشه‌دار کرد"})
		elif style == "emotional":
			trust += 0.01
		campaign["turns_left"] = int(campaign.get("turns_left", 0)) - 1
		if int(campaign.get("turns_left", 0)) <= 0:
			media["campaign"] = {"turns_left": 0, "target": "", "style": "", "strength": 0.0}
			events.append({"type": "campaign_ended", "message": "📣 کمپین رسانه‌ای به پایان رسید"})
		else:
			media["campaign"] = campaign

	# ── اثر افکار عمومی بر کشور ──
	media["trust"] = clampf(trust, 0.0, 1.0)
	media["groups"] = groups
	var overall := overall_approval(state)
	state["media"] = media
	# رضایت عمومی به شادی مردم و ثبات سرازیر می‌شود (با وزن کم تا سیستم‌های دیگر له نشوند)
	pop["happiness"] = clampf(happiness + (overall - 55.0) * 0.0004, 0.05, 1.0)
	pol["stability"] = clampf(stability + (overall - 55.0) * 0.0003, 0.05, 1.0)
	state["population"] = pop
	state["politics"] = pol
	# رویداد بحران رسانه‌ای (بی‌اعتمادی شدید)
	if trust < 0.22 and Deterministic.chance(0.20):
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.02, 0.05, 1.0)
		events.append({"type": "media_crisis", "message": "⚠️ بحران اعتماد به رسانه‌ها: مردم اخبار رسمی را باور نمی‌کنند و شایعات جامعه را می‌شکافند"})
		state["politics"] = pol
	return {"state": state, "events": events}
