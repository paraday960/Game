extends BaseSystem
# ۳.۶۹ مهاجرت و پناهندگی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var mig=state.get("migration_detail",{})
    mig["immigration"]=mig.get("immigration",50000.0)
    mig["emigration"]=mig.get("emigration",40000.0)
    mig["net"]=mig.get("net",10000.0)
    mig["refugees_in"]=mig.get("refugees_in",10000.0)
    mig["refugees_out"]=mig.get("refugees_out",5000.0)
    mig["border_control_effect"]=mig.get("border_control_effect",state.get("security",{}).get("border_control",0.60))
    mig["integration"]=mig.get("integration",0.55)
    var events=[]
    var pop_hap=state.get("population",{}).get("happiness",0.6)
    var econ_growth=state.get("economy",{}).get("growth_rate",0.02)
    mig["immigration"]=50000.0 * (0.5 + pop_hap*0.3 + econ_growth*10.0*0.2)
    mig["emigration"]=40000.0 * (0.5 + (1.0-pop_hap)*0.3)
    mig["net"]=mig["immigration"]-mig["emigration"]
    mig["border_control_effect"]=state.get("security",{}).get("border_control",0.60)
    mig["integration"]=clamp(mig["integration"]+ (pop_hap-0.5)*0.001,0.2,0.90)
    if mig["refugees_in"]>50000.0 and Deterministic.chance(0.01):
        events.append({"type":"refugee_wave","message":"موج پناهجویان ورودی"})
    state["migration_detail"]=mig
    return {"success":true,"state":state,"events":events}
