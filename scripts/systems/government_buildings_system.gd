extends BaseSystem
# ۳.۵۲ نهادهای دولتی - وزارتخانه، شهرداری، دادگاه، سفارت
func compute(state: Dictionary, tick: int) -> Dictionary:
    var gov=state.get("government_buildings",{})
    gov["ministries"]=gov.get("ministries",20)
    gov["municipalities"]=gov.get("municipalities",1200)
    gov["courts"]=gov.get("courts",400)
    gov["embassies"]=gov.get("embassies",100)
    gov["digital_government"]=gov.get("digital_government",0.50)
    gov["efficiency"]=gov.get("efficiency",0.60)
    var events=[]
    var tech=state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
    gov["digital_government"]=clamp(gov["digital_government"]+tech*0.001,0.2,0.95)
    gov["efficiency"]=clamp(gov["efficiency"]+gov["digital_government"]*0.0005,0.2,0.95)
    if gov["efficiency"]<0.4 and Deterministic.chance(0.01):
        events.append({"type":"gov_inefficiency","message":"ناکارآمدی نهادهای دولتی - صف‌های طولانی"})
    state["government_buildings"]=gov
    return {"success":true,"state":state,"events":events}
