extends Node
# ============================================================
# 🎵 موسیقی محیطی آرام (Procedural — بدون هیچ فایل صوتی خارجی)
# ملودی پنتاتونیک ملایم که هر چند ثانیه یک نت جدید پخش می‌کند
# (شبیه موسیقی استراتژی‌های آرام). رایگان، سبک و بدون مجوز.
# ============================================================

const MIX_RATE := 22050
const NOTE_SECONDS := 3.0
const PENTATONIC := [220.0, 261.63, 293.66, 329.63, 392.0, 440.0]  # A C D E G

var _player: AudioStreamPlayer
var _available := false
var _enabled := true
var _timer := 0.0
var _note_index := 0
var _volume := 0.06
# کش نوت‌های پیش‌ساخته: تولید ۶۶ هزار نمونه WAV در GDScript هر ۳ ثانیه
# یک جهش CPU پنهان بود؛ هر نوت فقط یک‌بار ساخته و بعداً استفاده مجدد می‌شود.
var _note_cache: Array = []

func _ready() -> void:
	_enabled = bool(SettingsManager.get_value("music_enabled", true))
	_volume = 0.05 + float(SettingsManager.get_value("sound_volume", 0.22)) * 0.05
	_available = DisplayServer.get_name() != "headless" and not OS.has_feature("server")
	if not _available:
		return
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = linear_to_db(_volume)
	add_child(_player)
	SettingsManager.settings_changed.connect(_on_setting_changed)

func _process(delta: float) -> void:
	if not _available or not _enabled or _player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 2.5 + randf_range(0.0, 3.5)
		_play_note()

func _play_note() -> void:
	var idx := _note_index % PENTATONIC.size()
	_note_index += 1
	if idx >= _note_cache.size():
		# اولین اجرای هر نوت: تولید و کش؛ دفعات بعد فقط پخش
		_note_cache.append(_build_note_stream(PENTATONIC[idx], NOTE_SECONDS))
	_player.stream = _note_cache[idx]
	_player.play()

func _build_note_stream(freq: float, seconds: float) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	# سینوس با حمله/رها ملایم (attack/release) تا گوش نزند
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var envelope := 1.0
		var attack := minf(1.0, t / 0.4)
		var release := minf(1.0, (seconds - t) / 0.8)
		envelope = minf(attack, release)
		var v := sin(TAU * freq * t) * 0.42 * envelope
		# هارمونیک دوم برای گرمی (octave)
		v += sin(TAU * freq * 2.0 * t) * 0.12 * envelope
		var s := int(clampf(v, -1.0, 1.0) * 32767.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

func is_enabled() -> bool:
	return _enabled

func toggle() -> bool:
	set_enabled(not _enabled)
	return _enabled

func set_enabled(value: bool) -> void:
	_enabled = value
	SettingsManager.set_value("music_enabled", value)
	if not value and _player != null:
		_player.stop()

func _on_setting_changed(key: String, value) -> void:
	if key == "music_enabled":
		_enabled = bool(value)
		if not _enabled and _player != null:
			_player.stop()
	elif key == "sound_volume":
		_volume = 0.05 + float(value) * 0.05
		if _player != null:
			_player.volume_db = linear_to_db(_volume)
