extends Node
# ذخیره/بارگذاری نسخه‌دار، اتمی، دارای checksum و پشتیبان

const FORMAT_VERSION = 2
const DEFAULT_PATH = "user://savegame.json"
const SAVES_DIR = "user://saves"
const AUTOSAVE_PATH = "user://saves/autosave.json"
const MAX_SLOTS = 5

signal save_completed(path)
signal load_completed(path)
signal operation_failed(reason)

func save_game(path: String = DEFAULT_PATH, metadata: Dictionary = {}) -> Dictionary:
	var state_copy = GameState.get_state_copy()
	var payload_data = {
		"format_version": FORMAT_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"label": str(metadata.get("label", "ذخیره سریع")),
		"slot": int(metadata.get("slot", 0)),
		"country_name": str(state_copy.get("country", {}).get("name", "کشور شما")),
		"tick": int(state_copy.get("tick", 0)),
		"total_days": TimeManager.get_total_days(state_copy),
		"year": int(state_copy.get("clock", {}).get("year", 2027)),
		"month": int(state_copy.get("clock", {}).get("month", 1)),
		"state": state_copy,
		"events": EventLog.get_events()
	}
	var payload = JSON.stringify(payload_data)
	var envelope = {
		"checksum": payload.sha256_text(),
		"payload": payload
	}
	var write_result = _atomic_write(path, JSON.stringify(envelope, "\t"))
	if not write_result.success:
		emit_signal("operation_failed", write_result.reason)
		return write_result
	EventLog.log_event("save", {"tick": GameState.tick, "path": path}, GameState.tick, GameState.version)
	emit_signal("save_completed", path)
	return {"success": true, "path": path, "backup": path + ".bak"}

func load_game(path: String = DEFAULT_PATH) -> Dictionary:
	var prepared = _prepare_load(path)
	var recovered_from_backup = false
	var primary_reason = str(prepared.get("reason", "فایل اصلی نامعتبر است"))
	if not prepared.success:
		var backup_path = path + ".bak"
		var backup = _prepare_load(backup_path)
		if backup.success:
			prepared = backup
			recovered_from_backup = true
		else:
			return _fail("%s؛ نسخه پشتیبان نیز قابل بازیابی نیست: %s" % [primary_reason, backup.get("reason", "یافت نشد")])

	var new_state: Dictionary = prepared.state
	var new_events: Array = prepared.events
	# Commit بارگذاری فقط پس از اعتبارسنجی کامل هر دو بخش انجام می‌شود.
	GameState.set_state(new_state, int(new_state.get("version", 0)), int(new_state.get("tick", 0)))
	EventLog.import_events(new_events)
	if recovered_from_backup:
		# نسخه سالم پشتیبان جای فایل خراب را می‌گیرد تا بارگذاری بعدی نیز امن باشد.
		_copy_file(path + ".bak", path)
	EventLog.log_event("load", {
		"tick": GameState.tick, "path": path, "recovered_from_backup": recovered_from_backup
	}, GameState.tick, GameState.version)
	emit_signal("load_completed", path)
	return {
		"success": true,
		"path": path,
		"migrated": prepared.get("migrated", false),
		"recovered_from_backup": recovered_from_backup,
		"format_version": FORMAT_VERSION
	}

func _prepare_load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "reason": "فایل ذخیره‌ای یافت نشد"}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "reason": "فایل ذخیره قابل خواندن نیست"}
	var raw = JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary:
		return {"success": false, "reason": "ساختار فایل ذخیره خراب است"}
	var decoded = _decode_and_migrate(raw)
	if not decoded.success:
		return decoded
	var validation = _validate_state(decoded.state)
	if not validation.valid:
		return {"success": false, "reason": validation.reason}
	if not _validate_events(decoded.events):
		return {"success": false, "reason": "گزارش رویدادهای فایل ذخیره نامعتبر است"}
	return {
		"success": true,
		"state": decoded.state,
		"events": decoded.events,
		"migrated": decoded.get("migrated", false)
	}

func save_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_SLOTS:
		return _fail("شماره جایگاه ذخیره نامعتبر است")
	return save_game(slot_path(slot), {"label":"جایگاه %d" % slot, "slot":slot})

func load_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_SLOTS:
		return _fail("شماره جایگاه ذخیره نامعتبر است")
	return load_game(slot_path(slot))

func delete_slot(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		return false
	return delete_save(slot_path(slot))

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVES_DIR, slot]

func list_slots() -> Array:
	var slots: Array = []
	for slot in range(1, MAX_SLOTS + 1):
		var path = slot_path(slot)
		var metadata = _read_metadata(path)
		metadata["slot"] = slot
		metadata["path"] = path
		slots.append(metadata)
	return slots

func maybe_autosave(tick: int) -> Dictionary:
	var interval = int(BalanceConfig.get_value("simulation.autosave_interval_turns", 1))
	if interval <= 0 or tick <= 0 or tick % interval != 0:
		return {"success": false, "skipped": true}
	return save_game(AUTOSAVE_PATH, {"label":"ذخیره خودکار", "slot":-1})

func get_autosave_metadata() -> Dictionary:
	return _read_metadata(AUTOSAVE_PATH)

func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)

func delete_save(path: String = DEFAULT_PATH) -> bool:
	var ok = true
	for candidate in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var absolute = ProjectSettings.globalize_path(candidate)
			if DirAccess.remove_absolute(absolute) != OK:
				ok = false
	return ok

func _read_metadata(path: String) -> Dictionary:
	var primary = _read_metadata_file(path)
	if primary.get("valid", false):
		return primary
	var backup = _read_metadata_file(path + ".bak")
	if backup.get("valid", false):
		backup["exists"] = true
		backup["valid"] = true
		backup["recovery_available"] = true
		backup["label"] = str(backup.get("label", "ذخیره")) + " — نسخه پشتیبان"
		return backup
	return primary

func _read_metadata_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "valid": false, "label": "خالی"}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "valid": false, "label": "غیرقابل خواندن"}
	var raw = JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary or not raw.has("payload") or not raw.has("checksum"):
		return {"exists": true, "valid": false, "label": "ذخیره قدیمی"}
	if not raw.payload is String or raw.payload.sha256_text() != str(raw.checksum):
		return {"exists": true, "valid": false, "label": "خراب یا دستکاری‌شده"}
	var payload = JSON.parse_string(raw.payload)
	if not payload is Dictionary:
		return {"exists": true, "valid": false, "label": "نامعتبر"}
	return {
		"exists": true, "valid": true,
		"label": str(payload.get("label", "ذخیره")),
		"country_name": str(payload.get("country_name", payload.get("state", {}).get("country", {}).get("name", ""))),
		"tick": int(payload.get("tick", payload.get("state", {}).get("tick", 0))),
		"total_days": int(payload.get("total_days", TimeManager.get_total_days(payload.get("state", {})))),
		"year": int(payload.get("year", payload.get("state", {}).get("clock", {}).get("year", 2027))),
		"month": int(payload.get("month", payload.get("state", {}).get("clock", {}).get("month", 1))),
		"saved_at": float(payload.get("saved_at", 0.0)),
		"game_version": str(payload.get("game_version", ""))
	}

func _decode_and_migrate(raw: Dictionary) -> Dictionary:
	var data: Dictionary
	var migrated = false
	if raw.has("payload") and raw.has("checksum"):
		if not raw.payload is String or not raw.checksum is String:
			return {"success": false, "reason": "پوش ذخیره نامعتبر است"}
		if raw.payload.sha256_text() != raw.checksum:
			return {"success": false, "reason": "صحت فایل ذخیره تأیید نشد؛ فایل دستکاری یا خراب شده است"}
		var parsed_payload = JSON.parse_string(raw.payload)
		if not parsed_payload is Dictionary:
			return {"success": false, "reason": "محتوای فایل ذخیره قابل بازیابی نیست"}
		data = parsed_payload
	elif raw.has("state"):
		# فرمت میانی بدون checksum
		data = raw.duplicate(true)
		migrated = true
	elif raw.has("economy") and raw.has("population"):
		# فرمت قدیمی: خود State مستقیماً در JSON نوشته شده بود.
		data = {"format_version": 1, "state": raw, "events": []}
		migrated = true
	else:
		return {"success": false, "reason": "نسخه فایل ذخیره شناخته‌شده نیست"}

	var version = int(data.get("format_version", 1))
	if version > FORMAT_VERSION:
		return {"success": false, "reason": "این ذخیره با نسخه جدیدتری از بازی ساخته شده است"}
	var state_data = data.get("state", {})
	var event_data = data.get("events", [])
	if not state_data is Dictionary or not event_data is Array:
		return {"success": false, "reason": "وضعیت یا رویدادهای ذخیره نامعتبر است"}
	if version < 2 or not state_data.has("schema_version"):
		state_data["command_receipts"] = state_data.get("command_receipts", [])
		migrated = true
	if int(state_data.get("schema_version", 1)) < 3:
		state_data["pending_decisions"] = state_data.get("pending_decisions", [])
		state_data["decision_history"] = state_data.get("decision_history", [])
		migrated = true
	if int(state_data.get("schema_version", 1)) < 4:
		state_data["progression"] = state_data.get("progression", {
			"streak":0, "best_streak":0, "combo":1, "previous_score":0.0,
			"high_score":0.0, "legacy_score":0, "achievements":[], "last_unlocks":[], "stage":"دولت نوپا"
		})
		migrated = true
	if int(state_data.get("schema_version", 1)) < 5 or not state_data.has("world"):
		state_data = WorldManager.ensure_world(state_data)
		migrated = true
	if int(state_data.get("schema_version", 1)) < 6 or not state_data.get("technology", {}).has("tree_version"):
		state_data = TechnologyManager.migrate_state(state_data)
		migrated = true
	var source_schema = int(state_data.get("schema_version", 1))
	if source_schema < 10 or not state_data.has("time"):
		state_data = TimeManager.migrate_legacy_state(state_data)
		migrated = true
	if source_schema < 7 or not state_data.has("scenario"):
		state_data = ScenarioManager.apply_scenario(
			state_data, ScenarioManager.default_scenario, int(state_data.get("tick", 0)))
		migrated = true
	else:
		state_data = ScenarioManager.ensure_scenario(state_data)
	if source_schema < 10 or not state_data.has("analytics"):
		# تاریخچه روزانه قدیمی با خط پایه ماهانه قابل قیاس نیست.
		state_data = AnalyticsManager.reset(state_data)
		migrated = true
	if source_schema < 9 or not state_data.has("policies"):
		state_data = PolicyManager.reset(state_data)
		migrated = true
	if source_schema < 11 or not state_data.has("municipal_services") or not state_data.has("weather"):
		state_data = SeasonalManager.reset_for_country(
			state_data, str(state_data.get("country", {}).get("id", WorldManager.default_country)))
		migrated = true
	if source_schema < 12 or not state_data.has("military_development"):
		state_data = MilitaryManager.reset(state_data)
		migrated = true
	if source_schema < 13 or not state_data.has("national_projects"):
		state_data = NationalProjectManager.reset(state_data)
		migrated = true
	if source_schema < 14 or not state_data.has("cabinet"):
		state_data = CabinetManager.reset(state_data)
		migrated = true
	if source_schema < 15 or not state_data.has("audit"):
		state_data = AuditManager.reset(state_data)
		migrated = true
	if source_schema < 16 or not state_data.has("legislation"):
		state_data = LawManager.reset(state_data)
		migrated = true
	if source_schema < 17 or not state_data.has("intelligence_operations"):
		state_data = IntelligenceOperationManager.reset(state_data)
		migrated = true
	state_data = WorldManager.ensure_world(state_data)
	if source_schema < 18 or not state_data.has("map_network"):
		state_data = MapLayerManager.update_network_metrics(state_data)
		migrated = true
	state_data["schema_version"] = 18
	return {"success": true, "state": state_data, "events": event_data, "migrated": migrated}

func _validate_state(candidate: Dictionary) -> Dictionary:
	for key in ["economy", "population", "resources", "politics", "clock", "indicators", "world"]:
		if not candidate.has(key) or not candidate[key] is Dictionary:
			return {"valid": false, "reason": "بخش حیاتی «%s» در ذخیره وجود ندارد" % key}
	if int(candidate.get("tick", -1)) < 0 or int(candidate.get("version", -1)) < 0:
		return {"valid": false, "reason": "شماره تیک یا نسخه ذخیره نامعتبر است"}
	if float(candidate["population"].get("total", 0.0)) <= 0.0:
		return {"valid": false, "reason": "جمعیت ذخیره نامعتبر است"}
	if float(candidate["economy"].get("gdp", -1.0)) < 0.0:
		return {"valid": false, "reason": "اقتصاد ذخیره نامعتبر است"}
	if candidate.has("audit"):
		var audit_check = AuditManager.verify_chain(candidate)
		if not audit_check.valid:
			return {"valid": false, "reason": "زنجیره حسابرسی ذخیره نامعتبر است: %s" % audit_check.reason}
	return {"valid": true, "reason": ""}

func _validate_events(candidate: Array) -> bool:
	for event in candidate:
		if not event is Dictionary or not event.has("type") or not event.has("data"):
			return false
	return true

func _atomic_write(path: String, content: String) -> Dictionary:
	var absolute_target = ProjectSettings.globalize_path(path)
	var make_dir_result = DirAccess.make_dir_recursive_absolute(absolute_target.get_base_dir())
	if make_dir_result != OK and make_dir_result != ERR_ALREADY_EXISTS:
		return {"success": false, "reason": "پوشه ذخیره‌سازی ساخته نشد"}
	var temporary = path + ".tmp"
	var temp_file = FileAccess.open(temporary, FileAccess.WRITE)
	if temp_file == null:
		return {"success": false, "reason": "فضای ذخیره‌سازی قابل نوشتن نیست"}
	temp_file.store_string(content)
	temp_file.flush()
	temp_file.close()

	if FileAccess.file_exists(path):
		if not _copy_file(path, path + ".bak"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			return {"success": false, "reason": "ساخت نسخه پشتیبان ناموفق بود"}
	var absolute_temp = ProjectSettings.globalize_path(temporary)
	var had_previous = FileAccess.file_exists(path)
	if had_previous:
		DirAccess.remove_absolute(absolute_target)
	if DirAccess.rename_absolute(absolute_temp, absolute_target) != OK:
		if had_previous and FileAccess.file_exists(path + ".bak"):
			_copy_file(path + ".bak", path)
		return {"success": false, "reason": "ثبت اتمی فایل ذخیره ناموفق بود؛ نسخه قبلی بازیابی شد"}
	return {"success": true}

func _copy_file(source: String, destination: String) -> bool:
	var input = FileAccess.open(source, FileAccess.READ)
	if input == null:
		return false
	var bytes = input.get_buffer(input.get_length())
	input.close()
	var output = FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		return false
	output.store_buffer(bytes)
	output.flush()
	output.close()
	return true

func _fail(reason: String) -> Dictionary:
	emit_signal("operation_failed", reason)
	return {"success": false, "reason": reason}
