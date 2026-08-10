extends BaseSystem
# ۳.۷۲ مسیر شغلی سیاسی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var career=state.get("political_career",{})
    career["ministers_avg_tenure"]=career.get("ministers_avg_tenure",2.5)
    career["governors_avg_tenure"]=career.get("governors_avg_tenure",3.0)
    career["promotion_rate"]=career.get("promotion_rate",0.15)
    career["corruption_career"]=career.get("corruption_career",state.get("politics",{}).get("corruption",0.30))
    career["meritocracy"]=career.get("meritocracy",0.50)
    var events=[]
    var stability=state.get("politics",{}).get("stability",0.60)
    career["meritocracy"]=clamp(career["meritocracy"]+ (1.0-career["corruption_career"])*0.0005,0.1,0.90)
    career["promotion_rate"]=clamp(0.10 + stability*0.1,0.05,0.40)
    if career["meritocracy"]<0.3 and Deterministic.chance(0.01):
        events.append({"type":"nepotism_crisis","message":"شایسته‌سالاری پایین - پارتی‌بازی"})
    state["political_career"]=career
    return {"success":true,"state":state,"events":events}
