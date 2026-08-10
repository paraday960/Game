extends BaseSystem
# ۳.۵۸ بخش خصوصی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var priv=state.get("private_sector",{})
    priv["entrepreneurs"]=priv.get("entrepreneurs",50000)
    priv["smes"]=priv.get("smes",200000)
    priv["startups"]=priv.get("startups",5000)
    priv["business_climate"]=priv.get("business_climate",0.60)
    priv["ease_of_doing"]=priv.get("ease_of_doing",0.55)
    priv["investment"]=priv.get("investment",20_000_000_000.0)
    var events=[]
    var econ=state.get("economy",{})
    var corruption=state.get("politics",{}).get("corruption",0.30)
    priv["business_climate"]=clamp(priv["business_climate"]+ (0.6-corruption)*0.001 + econ.get("growth_rate",0.02)*0.01,0.1,0.95)
    priv["ease_of_doing"]=clamp(priv["ease_of_doing"]+priv["business_climate"]*0.0005,0.1,0.90)
    if tick % 180==0 and priv["business_climate"]>0.6:
        priv["entrepreneurs"]+=100
        priv["startups"]+=20
    if priv["business_climate"]<0.3 and Deterministic.chance(0.01):
        events.append({"type":"business_climate_crisis","message":"فضای کسب و کار نامساعد"})
    state["private_sector"]=priv
    return {"success":true,"state":state,"events":events}
