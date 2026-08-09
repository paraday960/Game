extends BaseAI
# هوش اقتصاد - ۳.۱۰.۷
func decide(state: Dictionary, tick: int) -> Array:
    var econ = state["economy"]
    var cmds = []
    # مالیات تعادلی
    if econ["deficit"] > 0 and econ["tax_rate"] < 0.35:
        # پیشنهاد افزایش مالیات کم
        var new_rate = clamp(econ["tax_rate"] + 0.005, 0.10, 0.40)
        cmds.append(GameCommand.create_tax_set(new_rate))
    elif econ["deficit"] == 0 and econ["tax_rate"] > 0.25 and state["population"]["happiness"] < 0.5:
        var new_rate = clamp(econ["tax_rate"] - 0.005, 0.10, 0.40)
        cmds.append(GameCommand.create_tax_set(new_rate))

    # توزیع بودجه بهینه اگر کسری شدید
    if econ["debt_to_gdp"] > 1.2:
        # کاهش بودجه ارتش و افزایش ذخیره
        var allocs = econ["budget_allocations"].duplicate()
        allocs["ارتش"] = max(0.03, allocs["ارتش"] - 0.02)
        allocs["ذخیره"] = allocs.get("ذخیره",0.15)+0.02
        # نرمالایز
        var total=0.0
        for v in allocs.values(): total+=v
        for k in allocs.keys(): allocs[k]/=total
        cmds.append(GameCommand.create_budget_allocate(allocs))

    return cmds
