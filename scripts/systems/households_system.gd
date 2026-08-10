extends BaseSystem
# ۳.۶۲ خانواده‌ها و خانوارها
func compute(state: Dictionary, tick: int) -> Dictionary:
    var hh=state.get("households_detail_full",{})
    hh["count"]=hh.get("count",25000000)
    hh["avg_size"]=hh.get("avg_size",3.2)
    hh["income_avg"]=hh.get("income_avg",state.get("economy",{}).get("gdp_per_capita",5000.0)*0.8)
    hh["savings_rate"]=hh.get("savings_rate",0.15)
    hh["debt"]=hh.get("debt",0.20)
    hh["housing_own"]=hh.get("housing_own",0.70)
    var events=[]
    var econ=state.get("economy",{})
    hh["income_avg"]*= (1.0 + econ.get("growth_rate",0.02)/365.0)
    hh["savings_rate"]=clamp(hh["savings_rate"]+Deterministic.next_range(-0.0005,0.001),0.02,0.50)
    hh["debt"]=clamp(hh["debt"]+ (econ.get("interest_rate",0.15)-0.10)*0.0005,0.05,0.80)
    if hh["debt"]>0.6 and Deterministic.chance(0.01):
        events.append({"type":"household_debt_crisis","message":"بحران بدهی خانوارها"})
    state["households_detail_full"]=hh
    return {"success":true,"state":state,"events":events}
