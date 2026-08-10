extends BaseSystem
# ۳.۵۷ کارکنان بخش عمومی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var emp=state.get("public_employees",{})
    emp["count"]=emp.get("count",2000000)
    emp["salary"]=emp.get("salary",4000.0)
    emp["satisfaction"]=emp.get("satisfaction",0.55)
    emp["efficiency"]=emp.get("efficiency",0.60)
    emp["corruption"]=emp.get("corruption",0.25)
    var events=[]
    var econ=state.get("economy",{})
    emp["salary"]*= (1.0 + econ.get("inflation",0.08)/365.0)
    emp["satisfaction"]=clamp(emp["satisfaction"]+ (emp["salary"]/4000.0-1.0)*0.001 - emp["corruption"]*0.001,0.1,0.90)
    emp["efficiency"]=clamp(emp["efficiency"]*0.99 + emp["satisfaction"]*0.01,0.2,0.90)
    if emp["satisfaction"]<0.3 and Deterministic.chance(0.01):
        events.append({"type":"public_employee_strike","message":"اعتصاب کارکنان دولت"})
    state["public_employees"]=emp
    return {"success":true,"state":state,"events":events}
