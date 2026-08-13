extends SceneTree
signal finished
var passed:=false
var command_sent:=false
var p2p

func _init():
	await process_frame
	p2p=root.get_node("P2PManager")
	p2p.campaign_lobby_received.connect(_on_lobby)
	p2p.state_snapshot_received.connect(_on_state)
	var result=p2p.join_competitive("127.0.0.1",18778,"رهبر ترکیه","TUR")
	if not result.success:printerr(result.reason);quit(1);return
	var timer=create_timer(15.0);timer.timeout.connect(_on_timeout)
	await finished
	p2p.disconnect_game();quit(0 if passed else 1)

func _on_lobby(lobby:Dictionary):
	if lobby.get("players",{}).size()==2 and not lobby.get("started",false):p2p.set_campaign_ready(true)
	if lobby.get("started",false) and not command_sent:
		command_sent=true
		# پایان نوبت پیش از فرمان ارسال می‌شود تا وقتی فرمان به میزبان رسید،
		# همه بازیکنان «پایان نوبت» را زده باشند (RPCهای مطمئن به ترتیب می‌رسند)
		p2p.mark_turn_finished()
		var cmd=load("res://scripts/core/command.gd").create_tax_set(0.33)
		if not p2p.send_command(cmd):printerr("COMPETITIVE COMMAND SEND FAILED");finished.emit()

func _on_state(state:Dictionary,_version:int,tick:int):
	if tick<1:return
	if state.get("country",{}).get("id","")=="TUR" and float(state.get("economy",{}).get("tax_rate",0.0))>0.30:
		passed=true;print("=== ✅ COMPETITIVE CLIENT PRIVATE COUNTRY SNAPSHOT PASSED ===")
	else:printerr("CLIENT RECEIVED WRONG COUNTRY STATE")
	finished.emit()

func _on_timeout():
	if not passed:printerr("COMPETITIVE CLIENT TIMEOUT");finished.emit()
