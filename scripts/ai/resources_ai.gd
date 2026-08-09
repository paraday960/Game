extends BaseAI
# هوش منابع - ۳.۹.۷
func decide(state: Dictionary, tick: int) -> Array:
    var cmds = []
    var res = state["resources"]
    # اگر غذایی کم است، اولویت تولید غذا
    if res["food_crisis"]:
        # پیشنهاد افزایش بودجه کشاورزی - در عمل از طریق بودجه اعمال می‌شود
        pass
    if res["energy_crisis"] and state["technology"]["branches"]["انرژی_پاک"] > 0.2:
        # پیشنهاد جایگزینی سوخت با انرژی پاک
        pass
    return cmds
