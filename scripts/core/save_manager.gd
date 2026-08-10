extends Node
# ذخیره/بارگذاری نسخه‌دار، اتمی، دارای checksum و پشتیبان

const FORMAT_VERSION = 2
const DEFAULT_PATH = "user://savegame.json"

signal save_completed(path)
signal load_completed(path)
signal operation_failed(reason)

func save_game(path: String = DEFAULT_PATH) -> Dictionary:
	var payload_data = {
		"format_version": FORMAT_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"state": GameState.get_state_copy(),
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
	if not FileAccess.file_exists(path):
		return _fail("فایل ذخیره‌ای یافت نشد")
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("فایل ذخیره قابل خواندن نیست")
	var raw_text = file.get_as_text()
	file.close()
	var raw = JSON.parse_string(raw_text)
	if not raw is Dictionary:
		return _fail("ساختار فایل ذخیره خراب است")

	var decoded = _decode_and_migrate(raw)
	if not decoded.success:
		return _fail(decoded.reason)
	var new_state: Dictionary = decoded.state
	var new_events: Array = decoded.events
	var validation = _validate_state(new_state)
	if not validation.valid:
		return _fail(validation.reason)
	if not _validate_events(new_events):
		return _fail("گزارش رویدادهای فایل ذخیره نامعتبر است")

	# Commit بارگذاری فقط پس از اعتبارسنجی کامل هر دو بخش انجام می‌شود.
	GameState.set_state(new_state, int(new_state.get("version", 0)), int(new_state.get("tick", 0)))
	EventLog.import_events(new_events)
	EventLog.log_event("load", {"tick": GameState.tick, "path": path}, GameState.tick, GameState.version)
	emit_signal("load_completed", path)
	return {
		"success": true,
		"path": path,
		"migrated": decoded.get("migrated", false),
		"format_version": FORMAT_VERSION
	}

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
		state_data["schema_version"] = 2
		state_data["command_receipts"] = state_data.get("command_receipts", [])
		migrated = true
	return {"success": true, "state": state_data, "events": event_data, "migrated": migrated}

func _validate_state(candidate: Dictionary) -> Dictionary:
	for key in ["economy", "population", "resources", "politics", "clock", "indicators"]:
		if not candidate.has(key) or not candidate[key] is Dictionary:
			return {"valid": false, "reason": "بخش حیاتی «%s» در ذخیره وجود ندارد" % key}
	if int(candidate.get("tick", -1)) < 0 or int(candidate.get("version", -1)) < 0:
		return {"valid": false, "reason": "شماره تیک یا نسخه ذخیره نامعتبر است"}
	if float(candidate["population"].get("total", 0.0)) <= 0.0:
		return {"valid": false, "reason": "جمعیت ذخیره نامعتبر است"}
	if float(candidate["economy"].get("gdp", -1.0)) < 0.0:
		return {"valid": false, "reason": "اقتصاد ذخیره نامعتبر است"}
	return {"valid": true, "reason": ""}

func _validate_events(candidate: Array) -> bool:
	for event in candidate:
		if not event is Dictionary or not event.has("type") or not event.has("data"):
			return false
	return true

func _atomic_write(path: String, content: String) -> Dictionary:
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
	var absolute_target = ProjectSettings.globalize_path(path)
	var absolute_temp = ProjectSettings.globalize_path(temporary)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_target)
	if DirAccess.rename_absolute(absolute_temp, absolute_target) != OK:
		return {"success": false, "reason": "ثبت اتمی فایل ذخیره ناموفق بود"}
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
