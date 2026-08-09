extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var tech=state["technology"]
    var cmds=[]
    if tech["in_progress"] == null:
        # انتخاب بهترین شاخه بر اساس نیاز
        var need = {}
        need["صنعت"] = 1.0 - tech["branches"]["صنعت"]
        need["انرژی_پاک"] = state["resources"]["energy_crisis"] as int * 1.0 + (1.0 - tech["branches"]["انرژی_پاک"])
        # ساده: صنعتی ترین
        var best = "صنعت_پیشرفته"
        cmds.append(GameCommand.create_research_start(best))
    return cmds
