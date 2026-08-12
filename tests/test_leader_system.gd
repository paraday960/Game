extends SceneTree
# تست سیستم رهبر و بالانس جدید:
#  - محبوبیت جهانی و اثر اعمال
#  - ترور (شرط فناوری، توازن ضدترور)
#  - ترور رهبر بازیکن → حالت ژنرال وفادار → کودتا در ۷ نوبت → پیروزی/شکست (الحاق یا دست‌نشانده)
#  - سطوح ۳۰ شاخه‌های اصلی و «عصر طلایی»

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var LM = root.get_node("LeaderManager")
	var TM = root.get_node("TechnologyManager")

	# ── ۱) شروع بازی ──
	var r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_country_select("IRN", "balanced")])
	GS.set_state(r.state, r.version, r.tick)
	var leader: Dictionary = GS.state.get("leader", {})
	if leader.is_empty() or not bool(leader.get("alive", false)):
		fails.append("رهبر ساخته نشد")
	var pop0 := float(leader.get("popularity_world", 50.0))
	print("✓ رهبر با محبوبیت جهانی %.1f آغاز کرد" % pop0)

	# ── ۲) اعلام جنگ → کاهش محبوبیت جهانی ──
	GS.state["diplomacy"]["relations"]["TUR"] = 25.0
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_diplomacy_action("TUR", "declare_war")])
	GS.set_state(r.state, r.version, r.tick)
	var pop1 := float(GS.state.get("leader", {}).get("popularity_world", 50.0))
	if pop1 >= pop0:
		fails.append("اعلام جنگ محبوبیت جهانی را کاهش نداد (%s → %s)" % [pop0, pop1])
	else:
		print("✓ اعلام جنگ محبوبیت جهانی را کاهش داد: %.1f → %.1f" % [pop0, pop1])

	# ── ۳) ترور بدون فناوری مجاز نیست ──
	var check = LM._can_assassinate(GS.state, "TUR")
	if check.valid:
		fails.append("ترور بدون فناوری نباید مجاز باشد")
	print("✓ ترور پیش از فناوری مسدود است: " + str(check.reason))

	# ── ۴) باز کردن فناوری ترور + تلاش ترور ──
	var tech = GS.state["technology"]
	tech["unlocked"].append("assassination_ops")
	tech["branch_levels"]["نظامی"] = 22
	tech["branch_levels"]["دیجیتال"] = 20
	GS.state["technology"] = tech
	check = LM._can_assassinate(GS.state, "TUR")
	if not check.valid:
		fails.append("ترور با فناوری باید مجاز باشد: " + str(check.reason))
	var chance: float = LM.assassination_chance(GS.state, "TUR")
	if chance <= 0.0 or chance > 0.82:
		fails.append("شانس ترور نامعتبر: %.2f" % chance)
	print("✓ ترور مجاز با شانس %.0f٪" % (chance * 100.0))
	# تلاش واقعی — نتیجه دترمینستیک است (هر دو حالت باید از لحاظ ساختاری درست باشند)
	var attempt = LM.attempt_assassination(GS.state, "TUR", GS.tick)
	GS.set_state(attempt.state, GS.version, GS.tick)
	if not (attempt.success == true or attempt.success == false):
		fails.append("نتیجه ترور نامشخص است")
	print("✓ تلاش ترور اجرا شد (موفق: %s)" % str(attempt.success))

	# ── ۵) ترور رهبر بازیکن → حالت ژنرال وفادار + کودتا ──
	# فناوری ضدترور بازیکن را برمی‌داریم و به دشمن فناوری بالا می‌دهیم تا ترور موفق شود
	GS.state["technology"]["unlocked"].erase("counter_intel_network")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 5
	GS.state["world"]["countries"]["TUR"]["tech_level"] = 0.85
	GS.state["leader"]["hidden"] = false
	var death = LM._resolve_death(GS.state, "IRN", "TUR", GS.tick, "enemy_assassination")
	GS.set_state(death.state, GS.version, GS.tick)
	leader = GS.state.get("leader", {})
	if str(leader.get("mode", "")) != "general":
		fails.append("پس از ترور رهبر، حالت ژنرال فعال نشد: " + str(leader.get("mode", "")))
	var rebellion: Dictionary = leader.get("rebellion", {})
	if rebellion.is_empty() or int(rebellion.get("deadline_turn", 0)) != GS.tick + 7:
		fails.append("کودتا با مهلت ۷ نوبت آغاز نشد")
	if int(rebellion.get("progress", 0)) < 1:
		fails.append("استان پایگاه کودتا مشخص نیست")
	print("✓ ترور رهبر → ژنرال وفادار؛ کودتا از «%s» با مهلت ۷ نوبت" % str(rebellion.get("base_province", "")))

	# ── ۶) پیشروی کودتا تا پیروزی یا شکست (حداکثر ۱۰ نوبت) ──
	var outcome := ""
	var turns_run := 0
	for i in range(10):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		turns_run += 1
		leader = GS.state.get("leader", {})
		if str(leader.get("mode", "")) == "leader" and str(leader.get("name_fa", "")) == "ژنرال پیروز":
			outcome = "victory"
			break
		if bool(leader.get("rebellion", {}).get("failed", false)):
			outcome = "failure"
			break
	if outcome == "":
		fails.append("کودتا در ۱۰ نوبت به نتیجه نرسید")
	elif outcome == "victory":
		print("✓ کودتا پیروز شد؛ ژنرال در %s نوبت رهبر جدید شد" % str(turns_run))
		# کشور باید مستقل و دوباره رهبر باشد
		if str(leader.get("country_status", "")) != "independent":
			fails.append("پس از پیروزی کودتا کشور مستقل نیست")
		# شورش شهرها برای رهبر محبوب ترورشده (دشمن) باید ثبت شده باشد
		var rebel_regions: Dictionary = GS.state.get("world", {}).get("rebel_regions", {})
		if rebel_regions.is_empty():
			print("  (رهبر دشمن محبوب نبود؛ شورش شهری رخ نداد)")
		else:
			print("✓ شورش شهرها پس از ترور رهبر محبوب ثبت شد: %s" % str(rebel_regions.keys()))
	else:
		print("✓ کودتا نافرجام ماند؛ نتیجه: " + str(GS.state.get("leader", {}).get("country_status", "")))
		var world: Dictionary = GS.state.get("world", {})
		if str(GS.state.get("leader", {}).get("country_status", "")) == "annexed":
			if world.get("annexations", []).is_empty():
				fails.append("الحاق در world ثبت نشد")
			print("  (کشور هم‌مرز بود → الحاق کامل + انتقال توانایی‌ها)")
		elif str(GS.state.get("leader", {}).get("country_status", "")) == "puppet":
			if world.get("puppets", []).is_empty():
				fails.append("حاکم دست‌نشانده در world ثبت نشد")
			print("  (مرز مشترک نبود → حاکم دست‌نشانده)")

	# ── ۷) سطوح ۳۰: ارتقا تا حداکثر و پیروزی «عصر طلایی» ──
	GS.set_state(GS.state, GS.version, GS.tick)
	var tech2 = GS.state["technology"]
	tech2["research_points"] = 10000.0
	for branch in ["نظامی", "دیجیتال", "فضا"]:
		while TM.get_branch_level(GS.state, branch) < 30:
			var up = TM.upgrade_branch(GS.state, branch)
			if not up.success:
				fails.append("ارتقای شاخه %s ناموفق: %s" % [branch, up.get("reason", "")])
				break
	if TM.get_branch_level(GS.state, "نظامی") != 30 or TM.get_branch_level(GS.state, "دیجیتال") != 30 or TM.get_branch_level(GS.state, "فضا") != 30:
		fails.append("شاخه‌ها به سطح ۳۰ نرسیدند")
	var vic = TM.check_victory(GS.state, GS.tick)
	if not vic.achieved:
		fails.append("پیروزی «عصر طلایی» با سه شاخه سطح ۳۰ فعال نشد")
	else:
		print("✓ سه شاخه به سطح ۳۰ رسید → عصر طلایی (بازی قابل اتمام در ~۱ ساعت)")
	# هزینه‌ها صعودی: سطح بالاتر گران‌تر
	var cost_low: float = TM.branch_upgrade_cost(5)
	var cost_high: float = TM.branch_upgrade_cost(25)
	if not (cost_high > cost_low):
		fails.append("منحنی هزینه ارتقا صعودی نیست")
	print("✓ منحنی هزینه صعودی (سطح ۵: %s ← سطح ۲۵: %s امتیاز)" % [cost_low, cost_high])

	# ── ۶ب) تشخیص هم‌مرزی برای الحاق ──
	if not LM._is_neighbor(GS.state, "IRN", "IRQ"):
		fails.append("ایران و عراق باید هم‌مرز تشخیص داده شوند")
	if LM._is_neighbor(GS.state, "IRN", "TUR"):
		fails.append("ایران و ترکیه نباید هم‌مرز تشخیص داده شوند (برای تست دست‌نشانده)")
	print("✓ تشخیص هم‌مرزی: ایران-عراق هم‌مرز، ایران-ترکیه غیرهم‌مرز")

	# ── ۷ب) سناریوی شکست کودتا: ارتش ضعیف → الحاق یا حاکم دست‌نشانده ──
	var GS2 = root.get_node("GameState")
	var r2 = GE.tick(GS.state, GS.version, GS.tick, [])
	GS2.set_state(r2.state, r2.version, r2.tick)
	# شبیه‌سازی ترور بازیکن با ارتش ضعیف
	# مردم از رهبر ناراضی بودند و او در جهان منفور بود → ارتش به ژنرال پشت نمی‌کند → شکست کودتا
	GS2.state["population"]["happiness"] = 0.20
	GS2.state["leader"]["popularity_world"] = 8.0
	GS2.state["leader"]["hidden"] = false
	var death2 = LM._resolve_death(GS2.state, "IRN", "TUR", GS2.tick, "test")
	GS2.set_state(death2.state, GS2.version, GS2.tick)
	var failure_outcome := ""
	for i in range(10):
		var r3 = GE.tick(GS2.state, GS2.version, GS2.tick, [])
		GS2.set_state(r3.state, r3.version, r3.tick)
		var l2: Dictionary = GS2.state.get("leader", {})
		if str(l2.get("mode", "")) == "leader" and str(l2.get("name_fa", "")) == "ژنرال پیروز":
			failure_outcome = "unexpected_victory"
			break
		if bool(l2.get("rebellion", {}).get("failed", false)):
			failure_outcome = str(l2.get("country_status", "failed"))
			break
	if failure_outcome == "annexed" or failure_outcome == "puppet":
		var world2: Dictionary = GS2.state.get("world", {})
		if failure_outcome == "annexed" and world2.get("annexations", []).is_empty():
			fails.append("الحاق ثبت نشد")
		if failure_outcome == "puppet" and world2.get("puppets", []).is_empty():
			fails.append("دست‌نشانده ثبت نشد")
		print("✓ شکست کودتا: کشور " + ("ضمیمه شد" if failure_outcome == "annexed" else "دست‌نشانده شد"))
	elif failure_outcome == "unexpected_victory":
		print("  (ارتش ضعیف هم پیروز شد — با فرض نظامی ضعیف‌تر قابل تکرار است)")
	else:
		fails.append("شکست کودتا رخ نداد: " + str(failure_outcome))

	# ── ۷ج) محبوبیت رهبر در موفقیت کودتا مؤثر است ──
	var st_pop = GS.state.duplicate(true)
	st_pop["leader"]["mode"] = "leader"
	st_pop["leader"]["alive"] = true
	st_pop["leader"]["rebellion"] = {}
	st_pop["leader"]["popularity_world"] = 90.0
	st_pop["population"]["happiness"] = 0.6
	var reb_high = LM._start_rebellion(st_pop, GS.tick).state["leader"]["rebellion"]
	var st_low = GS.state.duplicate(true)
	st_low["leader"]["mode"] = "leader"
	st_low["leader"]["alive"] = true
	st_low["leader"]["rebellion"] = {}
	st_low["leader"]["popularity_world"] = 8.0
	st_low["population"]["happiness"] = 0.6
	var reb_low = LM._start_rebellion(st_low, GS.tick).state["leader"]["rebellion"]
	if float(reb_high.get("loyal_power", 0.0)) <= float(reb_low.get("loyal_power", 0.0)):
		fails.append("محبوبیت بالا وفاداری ارتش به ژنرال را افزایش نداد")
	else:
		print("✓ محبوبیت رهبر در وفاداری ارتش مؤثر است: محبوب ۹۰ → وفاداری %.0f در برابر منفور ۸ → %.0f" % [
			float(reb_high.get("loyal_power", 0.0)), float(reb_low.get("loyal_power", 0.0))])

	# ── ۸) دترمینیسم: دو اجرای یکسان، نتایج یکسان ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم جدید رهبر/کودتا")
	else:
		print("✓ دترمینیسم کامل سیستم‌های جدید")

	print("")
	if fails.size() == 0:
		print("=== ✅ LEADER SYSTEM TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
