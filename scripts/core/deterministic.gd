extends Node
# سیستم تصادفی دترمینستیک - قانون ۳.۷ - ضد تقلب برای چندنفره
# از seed وضعیت استفاده می‌کند، نه random واقعی

var _seed: int = 123456789
var _state: int = 0

func _ready():
	_state = _seed

func set_seed(new_seed: int):
	_seed = new_seed
	_state = new_seed

func next_int() -> int:
	# LCG ساده و دترمینستیک - قابل بازتولید در همه گوشی‌ها
	_state = (_state * 1103515245 + 12345) & 0x7fffffff
	return _state

func next_float() -> float:
	return float(next_int() % 1000000) / 1000000.0

func next_range(min_val: float, max_val: float) -> float:
	return min_val + next_float() * (max_val - min_val)

func next_int_range(min_val: int, max_val: int) -> int:
	return min_val + (next_int() % (max_val - min_val + 1))

func chance(p: float) -> bool:
	# p بین 0 و 1 - آیا رویداد اتفاق می‌افتد؟
	return next_float() < p

func shuffle_array(arr: Array) -> Array:
	var copy = arr.duplicate()
	var n = copy.size()
	for i in range(n - 1, 0, -1):
		var j = next_int() % (i + 1)
		var tmp = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy

func get_state() -> int:
	return _state
