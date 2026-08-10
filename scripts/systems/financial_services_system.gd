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
