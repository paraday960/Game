extends BaseSystem
# ۳.۷۱ امور خارجی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var fa=state.get("foreign_affairs",{})
    fa["embassies"]=fa.get("embassies",100)
    fa["consulates"]=fa.get("consulates",150)
    fa["diplomats"]=fa.get("diplomats",2000)
    fa["treaties_active"]=fa.get("treaties_active",state.get("diplomacy",{}).get("treaties",[]).size())
    fa["soft_power"]=fa.get("soft_power",state.get("diplomacy",{}).get("soft_power",35.0)/100.0)
    fa["visa_policy"]=fa.get("visa_policy",0.50)
    var events=[]
    var diplomacy=state.get("diplomacy",{})
    fa["soft_power"]=clamp(diplomacy.get("soft_power",35.0)/100.0,0.05,0.95)
    fa["treaties_active"]=diplomacy.get("treaties",[]).size()
    fa["visa_policy"]=clamp(fa["visa_policy"]+ (fa["soft_power"]-0.5)*0.001,0.1,0.90)
    if fa["embassies"]<50 and Deterministic.chance(0.005):
        events.append({"type":"embassy_shortage","message":"کمبود سفارتخانه"})
    state["foreign_affairs"]=fa
    return {"success":true,"state":state,"events":events}
