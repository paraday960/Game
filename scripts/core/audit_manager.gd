extends Node
# خط زمانی حسابرسی‌شده: هش زنجیره فرمان‌ها و Snapshot محدود برای بازگشت امن

const MAX_RECORDS = 500
const MAX_SNAPSHOTS = 13

func reset(state: Dictionary) -> Dictionary:
	var clean_json = _state_json_without_audit(state)
	var genesis = clean_json.sha256_text()
	state["audit"] = {
		"version":1,
		"genesis_hash":genesis,
		"chain_head":genesis,
		"records":[],
		"snapshots":[{"turn":int(state.get("tick",0)),"version":int(state.get("version",0)),"state_json":clean_json,"state_hash":genesis}]
	}
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("audit") or not state["audit"] is Dictionary:
		return reset(state)
	return state

func record_turn(previous_state: Dictionary, new_state: Dictionary, commands: Array) -> Dictionary:
	previous_state = ensure_state(previous_state.duplicate(true))
	var audit: Dictionary = previous_state["audit"].duplicate(true)
	var pre_hash = _state_json_without_audit(previous_state).sha256_text()
	var post_json = _state_json_without_audit(new_state)
	var post_hash = post_json.sha256_text()
	var command_data: Array = []
	for command in commands:
		if command != null and command.has_method("to_dict"):
			var raw: Dictionary = command.to_dict()
			command_data.append({
				"type":raw.get("type",""), "player_id":raw.get("player_id",""),
				"tick":raw.get("tick",0), "version":raw.get("version",0),
				"payload":raw.get("payload",{}).duplicate(true)
			})
	var previous_chain = str(audit.get("chain_head", audit.get("genesis_hash", "")))
	var command_json = JSON.stringify(command_data)
	var chain_hash = (previous_chain + pre_hash + post_hash + command_json).sha256_text()
	var record = {
		"turn":int(new_state.get("tick",0)), "version":int(new_state.get("version",0)),
		"pre_hash":pre_hash, "post_hash":post_hash, "commands":command_data,
		"previous_chain":previous_chain, "chain_hash":chain_hash
	}
	var records: Array = audit.get("records", [])
	records.append(record)
	while records.size() > MAX_RECORDS: records.pop_front()
	var snapshots: Array = audit.get("snapshots", [])
	snapshots.append({"turn":record["turn"],"version":record["version"],"state_json":post_json,"state_hash":post_hash})
	while snapshots.size() > MAX_SNAPSHOTS: snapshots.pop_front()
	audit["records"] = records
	audit["snapshots"] = snapshots
	audit["chain_head"] = chain_hash
	new_state["audit"] = audit
	return new_state

func verify_chain(state: Dictionary) -> Dictionary:
	state = ensure_state(state.duplicate(true))
	var audit: Dictionary = state["audit"]
	var records: Array = audit.get("records", [])
	if records.is_empty():
		return {"valid":true,"records":0,"reason":""}
	var previous = str(records[0].get("previous_chain", audit.get("genesis_hash", "")))
	for record in records:
		if str(record.get("previous_chain", "")) != previous:
			return {"valid":false,"records":records.size(),"reason":"پیوند زنجیره تاریخچه شکسته است"}
		var expected = (previous + str(record.get("pre_hash","")) + str(record.get("post_hash","")) + JSON.stringify(record.get("commands",[]))).sha256_text()
		if expected != str(record.get("chain_hash", "")):
			return {"valid":false,"records":records.size(),"reason":"هش یکی از نوبت‌ها نامعتبر است"}
		previous = expected
	return {"valid":previous == str(audit.get("chain_head", previous)),"records":records.size(),"reason":""}

func can_rewind(state: Dictionary, months: int = 1) -> bool:
	return months > 0 and state.get("audit", {}).get("snapshots", []).size() > months

func rewind(state: Dictionary, months: int = 1) -> Dictionary:
	if not can_rewind(state, months):
		return {"success":false,"reason":"Snapshot کافی برای بازگشت وجود ندارد"}
	var audit: Dictionary = state["audit"].duplicate(true)
	var snapshots: Array = audit.get("snapshots", [])
	var target_index = snapshots.size() - 1 - months
	var target: Dictionary = snapshots[target_index]
	if str(target.get("state_json", "")).sha256_text() != str(target.get("state_hash", "")):
		return {"success":false,"reason":"Snapshot ماه هدف خراب است"}
	var restored = JSON.parse_string(str(target["state_json"]))
	if not restored is Dictionary:
		return {"success":false,"reason":"Snapshot ماه هدف قابل خواندن نیست"}
	var kept_snapshots = snapshots.slice(0, target_index + 1)
	var target_turn = int(target.get("turn", 0))
	var kept_records: Array = []
	for record in audit.get("records", []):
		if int(record.get("turn", 0)) <= target_turn: kept_records.append(record)
	audit["snapshots"] = kept_snapshots
	audit["records"] = kept_records
	audit["chain_head"] = str(kept_records[-1].get("chain_hash", audit.get("genesis_hash", ""))) if not kept_records.is_empty() else str(audit.get("genesis_hash", ""))
	restored["audit"] = audit
	return {"success":true,"state":restored,"target_turn":target_turn}

func _state_json_without_audit(state: Dictionary) -> String:
	var clean = state.duplicate(true)
	clean.erase("audit")
	return JSON.stringify(clean)
