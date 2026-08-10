extends BaseSystem
# ۳.۵۳ شهروندان - نمونه ۱۰۰۰ نفر با ویژگی سن، جنسیت، مهارت، شغل، رضایت
func compute(state: Dictionary, tick: int) -> Dictionary:
    var citizens=state.get("citizens_detail",{})
    citizens["sample_size"]=citizens.get("sample_size",1000)
    citizens["avg_age"]=citizens.get("avg_age",35.0)
    citizens["avg_happiness"]=citizens.get("avg_happiness",state.get("population",{}).get("happiness",0.60))
    citizens["diversity_index"]=citizens.get("diversity_index",0.60)
    citizens["social_mobility"]=citizens.get("social_mobility",0.50)
    var events=[]
    var pop=state.get("population",{})
    citizens["avg_happiness"]=pop.get("happiness",0.60)
    citizens["social_mobility"]=clamp(citizens["social_mobility"]+state.get("education",{}).get("quality",0.55)*0.0005 - state.get("welfare",{}).get("gini",0.38)*0.0003,0.1,0.90)
    if citizens["social_mobility"]<0.3 and Deterministic.chance(0.01):
        events.append({"type":"low_mobility","message":"تحرک اجتماعی پایین - فقر موروثی"})
    state["citizens_detail"]=citizens
    return {"success":true,"state":state,"events":events}
