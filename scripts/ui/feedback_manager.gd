extends Node
# افکت صوتی رویه‌ای و رایگان؛ بدون فایل خارجی یا مجوز تجاری

var muted: bool = false
var volume: float = 0.22
var _player: AudioStreamPlayer
var _available: bool = false

func _ready():
	muted = not bool(SettingsManager.get_value("sound_enabled", true))
	volume = float(SettingsManager.get_value("sound_volume", 0.22))
	SettingsManager.settings_changed.connect(_on_setting_changed)
	_available = DisplayServer.get_name() != "headless" and not OS.has_feature("server")
	if not _available:
		return
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)

func toggle_mute() -> bool:
	muted = not muted
	SettingsManager.set_value("sound_enabled", not muted)
	if muted and _player != null:
		_player.stop()
	return muted

func _on_setting_changed(key: String, value):
	if key == "sound_enabled":
		muted = not bool(value)
		if muted and _player != null:
			_player.stop()
	elif key == "sound_volume":
		volume = float(value)

func play_click():
	_play_tone(520.0, 0.045, volume * 0.55)

func play_success():
	_play_tone(760.0, 0.09, volume)

func play_alert():
	_play_tone(220.0, 0.14, volume * 0.9)

func play_achievement():
	if muted or not _available:
		return
	# آکورد کوتاه دو مرحله‌ای؛ فراخوانی دوم با تأخیر غیرمسدودکننده
	_play_tone(660.0, 0.10, volume)
	_play_delayed_tone(880.0, 0.14, volume)

func _play_delayed_tone(frequency: float, duration: float, amplitude: float):
	await get_tree().create_timer(0.10).timeout
	_play_tone(frequency, duration, amplitude)

func _play_tone(frequency: float, duration: float, amplitude: float):
	if muted or not _available or _player == null:
		return
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = max(duration + 0.04, 0.12)
	_player.stream = generator
	_player.play()
	var playback = _player.get_stream_playback()
	if not playback is AudioStreamGeneratorPlayback:
		return
	var frames = int(generator.mix_rate * duration)
	for i in range(frames):
		var t = float(i) / generator.mix_rate
		var envelope = min(1.0, float(i) / 100.0) * (1.0 - float(i) / max(frames, 1))
		var sample = sin(TAU * frequency * t) * amplitude * envelope
		playback.push_frame(Vector2(sample, sample))
