extends BaseAI
# هوش رفاه - ۳.۲۱.۷
func decide(state: Dictionary, tick: int) -> Array:
    var welfare = state.get("welfare", {})
    # تعادل بین حمایت و انگیزه کار
    if welfare.get("poverty",0.15) > 0.25 and welfare.get("gini",0.38) > 0.5:
        pass
    if welfare.get("pension_fund_balance",1_000_000_000.0) < 200_000_000.0:
        pass
    return []
