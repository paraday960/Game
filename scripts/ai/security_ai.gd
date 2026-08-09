extends BaseAI
# هوش امنیت داخلی - ۳.۱۸.۷
func decide(state: Dictionary, tick: int) -> Array:
    var sec = state.get("security", {})
    var pol = state.get("politics", {})
    # توازن بین امنیت و آزادی
    if sec.get("organized_crime",0.3) > 0.6 and sec.get("police_presence",0.5) < 0.7:
        # پیشنهاد افزایش حضور پلیس در ذهن
        pass
    if pol.get("tension",0.35) > 0.7 and sec.get("community_trust",0.55) < 0.4:
        # پیشنهاد گفتگو به جای سرکوب
        pass
    return []
