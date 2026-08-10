extends BaseSystem
# ۳.۵۴ نیروی کار و مشاغل - تفصیلی مشاغل و دستمزد
func compute(state: Dictionary, tick: int) -> Dictionary:
    var workforce=state.get("workforce_detail",{})
    workforce["total"]=workforce.get("total",state.get("population",{}).get("workforce",55000000))
    workforce["farmers"]=workforce.get("farmers",0.20)
    workforce["industrial"]=workforce.get("industrial",0.25)
    workforce["services"]=workforce.get("services",0.35)
    workforce["gov"]=workforce.get("gov",0.15)
    workforce["unemployed"]=workforce.get("unemployed",state.get("economy",{}).get("unemployment",0.08))
    workforce["avg_wage"]=workforce.get("avg_wage",state.get("economy",{}).get("gdp_per_capita",5000.0)*0.8)
    workforce["productivity"]=workforce.get("productivity",0.60)
    var events=[]
    var econ=state.get("economy",{})
    var edu=state.get("education",{})
    # بهره‌وری = f(آموزش، سلامت، رضایت)
    var prod_target=0.5+edu.get("quality",0.55)*0.2+state.get("health",{}).get("quality",0.60)*0.1+state.get("population",{}).get("happiness",0.6)*0.2
    workforce["productivity"]=clamp(workforce["productivity"]*0.99+prod_target*0.01,0.2,0.95)
    # دستمزد با بهره‌وری و تورم
    workforce["avg_wage"]*= (1.0 + econ.get("growth_rate",0.02)/365.0 + econ.get("inflation",0.08)/365.0*0.5)
    # بیکاری
    workforce["unemployed"]=econ.get("unemployment",0.08)
    # ترکیب شغلی با فناوری
    var tech=state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
    if tech>0.4:
        workforce["farmers"]=clamp(workforce["farmers"]-0.0001,0.05,0.40)
        workforce["services"]+=0.0001
    state["workforce_detail"]=workforce
    return {"success":true,"state":state,"events":events}
