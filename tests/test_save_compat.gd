extends SceneTree
# تست فرمت ذخیره: گردش کامل فشرده (فرمت ۳) + سازگاری با ذخیره قدیمی JSON متنی

func _init():
	await process_frame
	var GS = root.get_node("GameState")
	var SM = root.get_node("SaveManager")
	var fails: Array = []

	# ── ۱) ذخیره و بارگذاری با فرمت فشرده جدید ──
	var saved = SM.save_game("user://saves/compat_test.json", {"label": "تست فشرده", "slot": 0})
	if not saved.success:
		fails.append("ذخیره فشرده ناموفق: " + str(saved.get("reason", "")))
	else:
		# فایل باید باینری CS3 باشد نه JSON متنی
		var f = FileAccess.open("user://saves/compat_test.json", FileAccess.READ)
		var buf := f.get_buffer(3)
		f.close()
		if buf.get_string_from_utf8() != "CS3":
			fails.append("فایل ذخیره جدید با سرآیند CS3 نوشته نشد")
		# بایتی فشرده باید به‌وضوح کوچک‌تر از JSON خام باشد
		var size = FileAccess.open("user://saves/compat_test.json", FileAccess.READ).get_length()
		var json_size = JSON.stringify(GS.get_state_copy()).length()
		if float(size) > float(json_size) * 0.9:
			fails.append("فشرده‌سازی ذخیره بی‌اثر است: %d بایت در برابر %d بایت JSON" % [size, json_size])
		else:
			print("✓ فشرده‌سازی ذخیره: %d بایت (%.0f٪ کوچک‌تر از JSON)" % [size, (1.0 - float(size) / float(json_size)) * 100.0])

	# تیک بزن تا state تغییر کند، بعد بارگذاری
	var GE = root.get_node("GameEngine")
	var r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	var loaded = SM.load_game("user://saves/compat_test.json")
	if not loaded.success:
		fails.append("بارگذاری فشرده ناموفق: " + str(loaded.get("reason", "")))
	else:
		var m = SM._read_metadata_file("user://saves/compat_test.json")
		if not m.get("valid", false) or str(m.get("label", "")) != "تست فشرده":
			fails.append("خواندن هدر سبک ذخیره فشرده ناموفق بود")
		else:
			print("✓ هدر سبک ذخیره بدون بازکردن فشرده‌سازی خوانده شد")

	# ── ۲) سازگاری با فرمت قدیمی متنی ──
	var legacy_payload = {
		"format_version": 2,
		"saved_at": Time.get_unix_time_from_system(),
		"game_version": "6.4.0",
		"label": "ذخیره قدیمی",
		"slot": 0,
		"state": GS.get_state_copy(),
		"events": []
	}
	var payload_str = JSON.stringify(legacy_payload)
	var envelope = {"checksum": payload_str.sha256_text(), "payload": payload_str}
	var legacy_file = FileAccess.open("user://saves/legacy_test.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(envelope))
	legacy_file.close()
	var legacy_loaded = SM.load_game("user://saves/legacy_test.json")
	if not legacy_loaded.success:
		fails.append("بارگذاری ذخیره قدیمی JSON ناموفق: " + str(legacy_loaded.get("reason", "")))
	else:
		print("✓ ذخیره قدیمی JSON (فرمت ۲) بدون مهاجرت خوانده شد")

	# ── ۳) هدر سبک: فایل خراب نباید valid باشد ──
	var broken = FileAccess.open("user://saves/broken_test.json", FileAccess.WRITE)
	broken.store_buffer(PackedByteArray([0x43, 0x53, 0x33, 0xFF, 0xFF, 0xFF]))
	broken.close()
	var broken_meta = SM._read_metadata_file("user://saves/broken_test.json")
	if broken_meta.get("valid", false):
		fails.append("فایل خراب، سالم تشخیص داده شد")

	SM.delete_save("user://saves/compat_test.json")
	SM.delete_save("user://saves/legacy_test.json")
	SM.delete_save("user://saves/broken_test.json")

	print("")
	if fails.is_empty():
		print("=== ✅ SAVE FORMAT COMPAT TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(0 if fails.is_empty() else 1)
