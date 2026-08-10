extends BaseSystem
# ۳.۶۴ دقیق‌سازی کمی و زمانی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var quant=state.get("quantitative",{})
    quant["time_scales"]=quant.get("time_scales",{"hourly":0,"daily":tick,"monthly":int(tick/30),"yearly":int(tick/365),"decadal":int(tick/3650)})
    quant["real_ratios"]=quant.get("real_ratios",{"gdp_pop":0.6,"energy_gdp":0.3,"food_pop":0.85})
    quant["shock_absorption"]=quant.get("shock_absorption",0.60)
    quant["macro_indicators"]=quant.get("macro_indicators",{"hdi":state.get("indicators",{}).get("hdi",0.75),"gini":state.get("welfare",{}).get("gini",0.38),"life_expectancy":state.get("health",{}).get("life_expectancy",74.0)})
    var events=[]
    quant["time_scales"]["daily"]=tick
    quant["time_scales"]["monthly"]=int(tick/30)
    quant["time_scales"]["yearly"]=int(tick/365)
    quant["time_scales"]["decadal"]=int(tick/3650)
    quant["time_scales"]["hourly"]=tick*24
    quant["real_ratios"]["gdp_pop"]=state.get("economy",{}).get("gdp_per_capita",5000.0)/10000.0
    quant["real_ratios"]["energy_gdp"]=state.get("resources",{}).get("self_sufficiency",0.85)
    quant["real_ratios"]["food_pop"]=state.get("agriculture",{}).get("food_security",0.85)
    quant["shock_absorption"]=clamp(quant["shock_absorption"]+state.get("emergency",{}).get("preparedness",0.5)*0.0001,0.2,0.95)
    quant["macro_indicators"]["hdi"]=state.get("indicators",{}).get("hdi",0.75)
    quant["macro_indicators"]["gini"]=state.get("welfare",{}).get("gini",0.38)
    quant["macro_indicators"]["life_expectancy"]=state.get("health",{}).get("life_expectancy",74.0)
    if tick % 365==0:
        events.append({"type":"yearly_report","message":"گزارش سالانه - HDI: %.2f" % quant["macro_indicators"]["hdi"]})
    state["quantitative"]=quant
    return {"success":true,"state":state,"events":events}
