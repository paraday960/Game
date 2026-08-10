extends BaseSystem
# ۳.۴۸ خدمات عمومی - بیمارستان، مدرسه، پلیس، آتش‌نشانی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var pub = state.get("public_services_detail", {})
    pub["hospitals"] = pub.get("hospitals", 500)
    pub["schools"] = pub.get("schools", 10000)
    pub["universities"] = pub.get("universities", 150)
    pub["police_stations"] = pub.get("police_stations", 2000)
    pub["fire_stations"] = pub.get("fire_stations", 500)
    pub["coverage_health"] = pub.get("coverage_health", 0.75)
    pub["coverage_education"] = pub.get("coverage_education", 0.80)
    pub["response_police"] = pub.get("response_police", 8.0)
    pub["response_fire"] = pub.get("response_fire", 7.0)

    var events=[]
    var econ=state.get("economy",{})
    var budget_share=econ.get("budget_allocations",{}).get("بهداشت",0.10)*0.5 + econ.get("budget_allocations",{}).get("آموزش",0.08)*0.5
    var pop_total=state.get("population",{}).get("total",85_000_000)

    # پوشش خدمات = f(بودجه، جمعیت، زیرساخت)
    pub["coverage_health"] = clamp(pub["coverage_health"] + (budget_share-0.09)*0.002, 0.3, 0.98)
    pub["coverage_education"] = clamp(pub["coverage_education"] + (budget_share-0.09)*0.002, 0.3, 0.98)

    # تعداد مراکز با رشد جمعیت
    if tick % 365 == 0:
        pub["hospitals"] = int(pop_total / 170000.0)
        pub["schools"] = int(pop_total / 8500.0)

    # زمان واکنش
    pub["response_police"] = clamp(15.0 - pub["police_stations"]/200.0, 3.0, 25.0)
    pub["response_fire"] = clamp(12.0 - pub["fire_stations"]/80.0, 2.0, 20.0)

    if pub["response_police"] > 15.0 and Deterministic.chance(0.01):
        events.append({"type":"police_slow","message":"کندی واکنش پلیس - کمبود کلانتری"})

    state["public_services_detail"]=pub
    return {"success":true,"state":state,"events":events}
