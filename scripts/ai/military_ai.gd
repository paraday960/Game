extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var cmds=[]
    var mil=state["military"]
    if mil["readiness"] < 0.5:
        # درخواست بودجه بیشتر برای ارتش در ذهن AI
        pass
    return cmds
