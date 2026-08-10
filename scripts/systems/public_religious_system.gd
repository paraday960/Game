extends BaseSystem
# ۳.۵۱ اماکن عمومی و مذهبی - پارک، مسجد، کلیسا، معبد
func compute(state: Dictionary, tick: int) -> Dictionary:
    var places=state.get("public_religious",{})
    places["parks"]=places.get("parks",3000)
    places["mosques"]=places.get("mosques",60000)
    places["churches"]=places.get("churches",300)
    places["temples"]=places.get("temples",100)
    places["green_space_per_capita"]=places.get("green_space_per_capita",15.0)
    places["access"]=places.get("access",0.70)
    places["maintenance"]=places.get("maintenance",0.60)
    var events=[]
    var pop=state.get("population",{}).get("total",85_000_000)
    places["green_space_per_capita"]=clamp(places["parks"]*5000.0/pop*1000.0, 2.0, 50.0)
    places["access"]=clamp(places["access"]+Deterministic.next_range(-0.001,0.002),0.3,0.95)
    if places["green_space_per_capita"]<5.0 and Deterministic.chance(0.01):
        events.append({"type":"green_space_crisis","message":"کمبود فضای سبز سرانه - شهرها بتنی"})
    state["public_religious"]=places
    return {"success":true,"state":state,"events":events}
