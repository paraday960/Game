extends BaseSystem
# ۳.۴۹ صنعت و انبار - کارخانه، انبار، معدن، نیروگاه
func compute(state: Dictionary, tick: int) -> Dictionary:
    var sites=state.get("industry_sites_detail", {})
    sites["factories"]=sites.get("factories",5000)
    sites["warehouses"]=sites.get("warehouses",10000)
    sites["mines"]=sites.get("mines",200)
    sites["power_plants"]=sites.get("power_plants",100)
    sites["industrial_parks"]=sites.get("industrial_parks",20)
    sites["utilization"]=sites.get("utilization",0.75)
    sites["pollution_industrial"]=sites.get("pollution_industrial",0.40)

    var events=[]
    var ind=state.get("industry",{})
    sites["utilization"]=ind.get("capacity_usage",0.75)
    sites["pollution_industrial"]=clamp(sites["pollution_industrial"] + (sites["utilization"]-0.5)*0.001, 0.1, 0.9)

    if tick % 180 == 0 and ind.get("output",100.0) > 120.0:
        sites["factories"]+=5
        sites["warehouses"]+=10

    if sites["pollution_industrial"]>0.7 and Deterministic.chance(0.01):
        events.append({"type":"industrial_pollution","message":"آلودگی صنعتی شدید اطراف کارخانه‌ها"})

    state["industry_sites_detail"]=sites
    return {"success":true,"state":state,"events":events}
