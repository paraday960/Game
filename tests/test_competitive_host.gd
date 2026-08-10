extends SceneTree
# تست واقعی ENet برای دو کشور مستقل
signal finished
var passed:=false
var p2p
var campaign
var command_seen:=false

func _init():
	await process_frame
	p2p=root.get_node("P2PManager")
	campaign=root.get_node("MultiplayerCampaignManager")
	p2p.campaign_lobby_received.connect(_on_lobby)
	p2p.command_received.connect(_on_command)
	var result=p2p.host_competitive("رهبر ایران","IRN",18778)
	if not result.success:printerr(result.reason);quit(1);return
	p2p.set_campaign_ready(true)
	var timer=create_timer(15.0);timer.timeout.connect(_on_timeout)
	await finished
	await create_timer(0.8).timeout
	p2p.disconnect_game();quit(0 if passed else 1)

func _on_lobby(lobby:Dictionary):
	if lobby.get("players",{}).size()==2 and campaign.all_ready() and not campaign.started:
		var result=p2p.start_competitive_campaign()
		if not result.success:printerr(result.reason);finished.emit()

func _on_command(_cmd):
	if command_seen or not campaign.started:return
	command_seen=true
	var result=p2p.advance_competitive_month([])
	if not result.success:printerr(result.reason);finished.emit();return
	var iran=campaign.get_state_for_peer(p2p.host_id)
	var turkey_peer=""
	for peer_id in campaign.peer_registry.keys():
		if campaign.get_country_for_peer(str(peer_id))=="TUR":turkey_peer=str(peer_id)
	var turkey=campaign.get_state_for_peer(turkey_peer)
	if iran.get("country",{}).get("id","")=="IRN" and turkey.get("country",{}).get("id","")=="TUR" and float(turkey.get("economy",{}).get("tax_rate",0.0))>0.30 and float(iran.get("economy",{}).get("tax_rate",1.0))<0.25:
		passed=true;print("=== ✅ COMPETITIVE HOST SEPARATE STATES PASSED ===")
	else:printerr("COMPETITIVE STATES OR COMMAND ROUTING FAILED")
	finished.emit()

func _on_timeout():
	if not passed:printerr("COMPETITIVE HOST TIMEOUT");finished.emit()
