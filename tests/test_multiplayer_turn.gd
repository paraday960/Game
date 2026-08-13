extends SceneTree
# تست منطق چندنفره: همگام‌سازی پایان نوبت و چت

func _init():
	await process_frame
	var fails: Array = []
	var cm = root.get_node("MultiplayerCampaignManager")
	cm.reset()
	var r1 = cm.register_peer("10", "علی", "IRN")
	var r2 = cm.register_peer("20", "سارا", "TUR")
	if not r1.success or not r2.success:
		print("ثبت بازیکنان ناموفق"); quit(1)
	cm.set_ready("10", true)
	cm.set_ready("20", true)
	var started = cm.start_campaign({})
	if not started.success:
		print("شروع کمپین ناموفق: ", started.reason); quit(1)

	# بدون پایان نوبت، advance باید رد شود و فهرست منتظر را برگرداند
	var a0 = cm.advance_month()
	if a0.success:
		fails.append("پیش از پایان نوبت همه بازیکنان، نوبت جلو رفت")
	elif not a0.has("waiting"):
		fails.append("دلیل رد شامل فهرست منتظر نیست")
	else:
		print("✓ قبل از پایان همه، نوبت اجرا نشد و فهرست منتظر داده شد")

	# یک بازیکن پایان می‌زند
	cm.mark_turn_finished("10")
	if cm.all_turns_finished():
		fails.append("با یک بازیکن تمام‌شده تلقی شد")
	elif cm.get_turn_finished_snapshot()["TUR"]["finished"] != false:
		fails.append("وضعیت منتظر بازیکن دوم اشتباه است")
	else:
		print("✓ یک بازیکن پایان نوبت زد؛ هنوز منتظر بقیه")

	# بازیکن دوم
	cm.mark_turn_finished("20")
	if not cm.all_turns_finished():
		fails.append("با دو بازیکن هنوز تمام نشده")
	elif cm.has_finished("10") == false or cm.has_finished("20") == false:
		fails.append("وضعیت پایان بازیکنان اشتباه است")
	else:
		print("✓ هر دو پایان نوبت زدند")

	# بعد از اجرای واقعی (که در بازی توسط میزبان انجام می‌شود) پرچم‌ها ریست می‌شوند.
	cm.turn_finished.clear()
	if cm.all_turns_finished():
		fails.append("پس از ریست هنوز تمام‌شده تلقی می‌شود")
	else:
		print("✓ پرچم‌های پایان نوبت پس از اجرا ریست می‌شوند")

	# لغو پایان نوبت
	cm.mark_turn_finished("10")
	cm.unmark_turn_finished("10")
	if cm.has_finished("10"):
		fails.append("لغو پایان نوبت کار نکرد")
	else:
		print("✓ لغو پایان نوبت کار کرد")
	cm.turn_finished.clear()

	# چت
	var chat = cm.add_chat_message("10", "سلام دوست من!")
	if not chat.success:
		fails.append("ارسال چت ناموفق")
	else:
		print("✓ پیام چت ثبت شد")
	var recent = cm.get_recent_chat()
	if recent.size() != 1 or recent[0]["name"] != "علی":
		fails.append("پیام چت به‌درستی بازیابی نشد")
	else:
		print("✓ پیام چت قابل بازیابی است")

	var empty = cm.add_chat_message("20", "   ")
	if empty.success:
		fails.append("پیام خالی ثبت شد")
	else:
		print("✓ پیام خالی رد شد")

	# پیام بلند کوتاه می‌شود
	var long_text := "a".repeat(600)
	var long_chat = cm.add_chat_message("20", long_text)
	if not long_chat.success or str(long_chat.message["text"]).length() > 500:
		fails.append("محدودیت طول پیام رعایت نشد")
	else:
		print("✓ طول پیام به ۵۰۰ کاراکتر محدود شد")

	cm.reset()
	print("")
	if fails.is_empty():
		print("=== ✅ MULTIPLAYER TEST PASSED ===")
	else:
		for f in fails:
			print("❌ ", f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
