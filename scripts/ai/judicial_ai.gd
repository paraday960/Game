extends BaseAI
# هوش قضایی - ۳.۱۷.۷
func decide(state: Dictionary, tick: int) -> Array:
    var judicial = state.get("judicial", {})
    var cmds = []
    # اگر تراکم پرونده بالا، پیشنهاد اصلاحات
    if judicial.get("case_backlog", 10000) > 40000:
        # در عمل بودجه قضایی را پیشنهاد می‌دهد - اینجا لاگ
        pass
    # اگر فساد بالا، پیشنهاد برخورد
    if judicial.get("corruption_judicial", 0.2) > 0.5:
        pass
    return cmds
