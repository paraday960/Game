extends BaseSystem
# ۳.۴۵ تجارت خرد و بازار - بازار سنتی، فروشگاه زنجیره‌ای، سوپرمارکت

func compute(state: Dictionary, tick: int) -> Dictionary:
	var retail = state.get("retail", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var tourism = state.get("tourism", {})

	retail["shops"] = retail.get("shops", 200000)
	retail["chain_stores"] = retail.get("chain_stores", 5000)
	retail["bazaars"] = retail.get("bazaars", 5000)
	retail["supermarkets"] = retail.get("supermarkets", 3000)
	retail["coverage"] = retail.get("coverage", 0.85)
	retail["competition"] = retail.get("competition", 0.60)
	retail["price_level"] = retail.get("price_level", 1.0)
	retail["e_commerce_share"] = retail.get("e_commerce_share", 0.15)
	retail["employment"] = retail.get("employment", 1500000)

	var events = []

	var gdp_per_capita = econ.get("gdp_per_capita",5000.0)
	var urban_pop = state.get("settlements_detail",{}).get("urban_pop", 60_000_000) if state.has("settlements_detail") else 60_000_000

	# پوشش تجارت خرد = f(جمعیت شهری، درآمد، زیرساخت)
	var coverage_target = 0.7 + urban_pop / 85_000_000.0 * 0.2 + gdp_per_capita / 10000.0 * 0.1
	retail["coverage"] = clamp(retail["coverage"] * 0.99 + coverage_target * 0.01, 0.4, 0.98)

	# رقابت = f(تعداد فروشگاه، زنجیره‌ای، قانون ضد انحصار)
	var shop_density = retail["shops"] / max(urban_pop / 1000.0, 1.0)
	var competition_target = 0.5 + shop_density * 0.1 + (1.0 - retail["chain_stores"]/10000.0) * 0.2
	retail["competition"] = clamp(retail["competition"] * 0.98 + competition_target * 0.02, 0.1, 0.90)

	# سطح قیمت = f(رقابت، تورم، لجستیک)
	var inflation = econ.get("inflation",0.08)
	var logistics = state.get("transport_detail",{}).get("logistics_efficiency",0.65) if state.has("transport_detail") else 0.65
	retail["price_level"] = clamp(1.0 + inflation * 0.5 - retail["competition"] * 0.2 - logistics * 0.1, 0.7, 1.8)

	# سهم تجارت الکترونیک = f(فناوری دیجیتال، درآمد، زیرساخت)
	var digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	retail["e_commerce_share"] = clamp(retail["e_commerce_share"] + digital * 0.001 + gdp_per_capita/10000.0 * 0.0005, 0.02, 0.60)

	# تعداد فروشگاه‌ها با جمعیت رشد
	retail["shops"] = int(200000 * pop.get("total",85_000_000)/85_000_000.0)
	retail["chain_stores"] = int(5000 * pop.get("total",85_000_000)/85_000_000.0 * (1.0 + retail["e_commerce_share"]))

	# اشتغال
	retail["employment"] = retail["shops"] * 5 + retail["supermarkets"] * 50

	# اثر بر رفاه و رضایت
	var price_effect = (1.5 - retail["price_level"]) * 0.001
	state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.6) + price_effect, 0.05, 0.95)

	# رویدادها
	if retail["competition"] < 0.3 and Deterministic.chance(0.01):
		events.append({"type": "retail_monopoly", "message": "انحصار فروشگاه‌های زنجیره‌ای - افزایش قیمت و کاهش رقابت"})

	if retail["coverage"] < 0.6 and Deterministic.chance(0.01):
		events.append({"type": "retail_coverage_crisis", "message": "کمبود فروشگاه در مناطق روستایی - قیمت بالاتر"})

	if retail["e_commerce_share"] > 0.4 and Deterministic.chance(0.008):
		events.append({"type": "e_commerce_boom", "message": "رونق تجارت الکترونیک - تغییر الگوی خرید"})

	state["retail"] = retail
	
		# ── لایه واقع‌گرایانه اختصاصی بازار خرده‌فروشی (جایگزین قالب خودکار) — بخش ۳.۴۵ ──
	# ساختار بازار در گذار: زنجیره‌ها با درآمد و دیجیتال رشد، بازار سنتی تحلیل تدریجی
	var digital_r = float(state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20))
	var income_r = float(econ.get("gdp_per_capita", 5000.0)) / 10000.0
	retail["chain_stores"] = maxi(int(float(retail.get("chain_stores", 5000)) * (1.0 + (income_r - 0.5) * 0.001 + digital_r * 0.001)), 500)
	retail["bazaars"] = maxi(int(float(retail.get("bazaars", 5000)) * (1.0 - float(retail.get("e_commerce_share", 0.15)) * 0.0005)), 1500)
	# اشتغال خرده‌فروشی از ساختار واقعی: مغازه‌های کوچک ۳ نفر، زنجیره‌ها ۶۰ نفر
	retail["employment"] = maxi(int(float(retail.get("shops", 200000)) * 3.0 + float(retail.get("chain_stores", 5000)) * 60.0), 300000)
	# گردشگر خارجی → رونق بازارهای گردشگری (پیوند گردشگری دور ۸)
	var visitors_r = float(tourism.get("visitors", 5_000_000))
	retail["tourism_sales"] = visitors_r * 420.0
	# تجارت الکترونیک بالا → ورشکستگی فروشگاه‌های فیزیکی محلی
	var ecom = float(retail.get("e_commerce_share", 0.15))
	if ecom > 0.35:
		retail["shops"] = maxi(int(float(retail.get("shops", 200000)) * (1.0 - (ecom - 0.35) * 0.0003)), 60000)
		if Deterministic.chance(0.004):
			events.append({"type": "local_shops_decline", "message": "تعطیلی فروشگاه‌های محلی در برابر موج خرید اینترنتی", "e_commerce": ecom})
	# انحصار زنجیره‌ای → تورم خرد: قیمت خرد بالاتر از تورم عمومی
	if float(retail.get("chain_stores", 5000)) / maxf(float(retail.get("shops", 200000)), 1.0) > 0.08 and Deterministic.chance(0.004):
		events.append({"type": "chain_pricing_power", "message": "تسلط فروشگاه‌های زنجیره‌ای بر بازار - شکایت از قیمت‌گذاری انحصاری"})
	state["retail"] = retail

	return {"success": true, "state": state, "events": events}
