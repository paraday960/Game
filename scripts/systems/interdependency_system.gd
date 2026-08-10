extends BaseSystem
# ۳.۶۳ مدل اثرگذاری متقابل - جریان‌های پول، کالا، انرژی، نیروی کار، اطلاعات، خدمات، پسماند
func compute(state: Dictionary, tick: int) -> Dictionary:
    var inter=state.get("interdependency",{})
    inter["money_flow"]=inter.get("money_flow", state.get("economy",{}).get("gdp",500_000_000_000.0)/365.0)
    inter["goods_flow"]=inter.get("goods_flow", state.get("industry",{}).get("output",100.0))
    inter["energy_flow"]=inter.get("energy_flow", state.get("resources",{}).get("inventory",{}).get("برق",100.0))
    inter["labor_flow"]=inter.get("labor_flow", state.get("population",{}).get("workforce",55000000))
    inter["information_flow"]=inter.get("information_flow", state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)*100.0)
    inter["services_flow"]=inter.get("services_flow", 0.70)
    inter["waste_flow"]=inter.get("waste_flow", state.get("environment",{}).get("pollution",0.4)*100.0)
    inter["bottlenecks"]=inter.get("bottlenecks",[])
    var events=[]
    var energy_demand=state.get("resources",{}).get("demand",{}).get("برق",12.0)
    if inter["energy_flow"] < energy_demand:
        inter["bottlenecks"].append({"type":"energy","flow":inter["energy_flow"],"demand":energy_demand})
        events.append({"type":"energy_bottleneck","message":"گلوگاه انرژی - جریان کمتر از تقاضا!"})
    inter["money_flow"]*= (1.0 + state.get("economy",{}).get("growth_rate",0.02)/365.0)
    if inter["bottlenecks"].size()>3 and Deterministic.chance(0.01):
        events.append({"type":"systemic_bottleneck","message":"گلوگاه‌های چندگانه - اقتصاد کند شد"})
        inter["bottlenecks"]=[]
    state["interdependency"]=inter
    return {"success":true,"state":state,"events":events}
