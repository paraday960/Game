extends RefCounted
class_name CommandBus
const GameCommandClass = preload("res://scripts/core/command.gd")
# گذرگاه فرمان - بخش ۳.۷ لایه ۶ - فرمان‌محور

var queue: Array = []
var processed_ids: Dictionary = {} # برای ایدمپوتنسی

func enqueue(cmd: GameCommandClass):
    var key = Versioning.make_idempotent_key(cmd.type, cmd.tick, cmd.player_id)
    if processed_ids.has(key):
        # قبلا پردازش شده - ایدمپوتنت
        return false
    queue.append(cmd)
    return true

func dequeue_all() -> Array:
    var all = queue.duplicate()
    queue.clear()
    for cmd in all:
        var key = Versioning.make_idempotent_key(cmd.type, cmd.tick, cmd.player_id)
        processed_ids[key] = true
    # حفظ 1000 کلید آخر برای ایدمپوتنسی
    if processed_ids.size() > 1000:
        var keys = processed_ids.keys()
        for i in range(500):
            processed_ids.erase(keys[i])
    return all

func size() -> int:
    return queue.size()
