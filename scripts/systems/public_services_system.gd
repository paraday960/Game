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

cat > scripts/systems/industry_sites_system.gd <<'GD'
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

cat > scripts/systems/financial_services_system.gd <<'GD'
extends BaseSystem
# ۳.۵۰ خدمات مالی - بانک، بیمه، صرافی، بورس
func compute(state: Dictionary, tick: int) -> Dictionary:
    var fin=state.get("financial_services", {})
    fin["banks"]=fin.get("banks",30)
    fin["bank_branches"]=fin.get("bank_branches",5000)
    fin["insurance_companies"]=fin.get("insurance_companies",30)
    fin["atms"]=fin.get("atms",15000)
    fin["financial_inclusion"]=fin.get("financial_inclusion",0.65)
    fin["digital_banking"]=fin.get("digital_banking",0.50)
    fin["non_performing_loans"]=fin.get("non_performing_loans",0.08)
    fin["insurance_penetration"]=fin.get("insurance_penetration",0.02)

    var events=[]
    var econ=state.get("economy",{})
    var cb=state.get("central_bank",{})
    var tech=state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)

    fin["financial_inclusion"]=clamp(fin["financial_inclusion"] + tech*0.001, 0.2, 0.95)
    fin["digital_banking"]=clamp(fin["digital_banking"] + tech*0.002, 0.1, 0.90)
    fin["non_performing_loans"]=clamp(fin["non_performing_loans"] + (econ.get("unemployment",0.08)-0.08)*0.01, 0.02, 0.30)
    fin["insurance_penetration"]=clamp(fin["insurance_penetration"] + econ.get("gdp_per_capita",5000.0)/10000.0*0.0001, 0.01, 0.15)

    if fin["non_performing_loans"]>0.15 and Deterministic.chance(0.012):
        events.append({"type":"npl_crisis","message":"بحران مطالبات معوق بانکی - ریسک اعتباری"})

    if fin["digital_banking"]>0.7 and Deterministic.chance(0.008):
        events.append({"type":"fintech_boom","message":"رونق فین‌تک و بانکداری دیجیتال"})

    state["financial_services"]=fin
    return {"success":true,"state":state,"events":events}

# AIs
cat > scripts/ai/public_services_ai.gd <<'GD'
extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    return []
