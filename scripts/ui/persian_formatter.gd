extends Node
# Formatter فارسی - قانون ۶: تمام نمایشی به بازیکن فارسی

const EN_TO_FA_DIGITS = {
	"0": "۰",
	"1": "۱",
	"2": "۲",
	"3": "۳",
	"4": "۴",
	"5": "۵",
	"6": "۶",
	"7": "۷",
	"8": "۸",
	"9": "۹"
}

func to_persian_digits(text: String) -> String:
	var result = text
	for en in EN_TO_FA_DIGITS.keys():
		result = result.replace(en, EN_TO_FA_DIGITS[en])
	return result

func format_number(num) -> String:
	if num is float:
		return to_persian_digits("%.2f" % num)
	return to_persian_digits(str(num))

func format_percent(value: float) -> String:
	return to_persian_digits("%.1f" % (value * 100.0)) + "٪"

func format_money(amount: float) -> String:
	# میلیارد ریال - نمایشی فارسی
	if amount >= 1_000_000_000:
		return to_persian_digits("%.1f" % (amount / 1_000_000_000.0)) + " میلیارد ریال"
	elif amount >= 1_000_000:
		return to_persian_digits("%.1f" % (amount / 1_000_000.0)) + " میلیون ریال"
	else:
		return to_persian_digits(str(int(amount))) + " ریال"

func format_large(num: float) -> String:
	if num >= 1_000_000_000:
		return to_persian_digits("%.2f" % (num / 1_000_000_000.0)) + " میلیارد"
	elif num >= 1_000_000:
		return to_persian_digits("%.2f" % (num / 1_000_000.0)) + " میلیون"
	elif num >= 1000:
		return to_persian_digits("%.1f" % (num / 1000.0)) + " هزار"
	else:
		return format_number(int(num))
