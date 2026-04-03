extends Node


# AudioManager.gd — Centralized audio pool and SFX helper for Moonseed
# Handles: pooling, panning, pitch/volume randomization, and flexible SFX playback
#
# Usage: Access via get_node("/root/AudioManager") in all scripts.
# Example: get_node("/root/AudioManager").play_dice_impact(pos, strength)

# Pool of AudioStreamPlayer2D nodes for SFX
var _audio_pool: Array[AudioStreamPlayer2D] = []
var _pool_size: int = 12

# Default bus for SFX
var _bus: String = "SFX"

# Background music support
const MUSIC_BUS: String = "Music"
const UI_BUS: String = "UI"
const MAIN_THEME_PATH: String = "res://assets/audio/MainTheme.ogg"
const LUNAR_BAZAAR_THEME_PATH: String = "res://assets/audio/Lunar Bazzar.ogg"

# Ambience (garden) loops
const AMBIENCE_DAY_PATH: String = "res://assets/audio/garden/Ambiance_Day_Loop_Stereo.wav"
const AMBIENCE_NIGHT_PATH: String = "res://assets/audio/garden/Ambiance_Night_Loop_Stereo.wav"

var _ambience_stream_day: AudioStream = null
var _ambience_stream_night: AudioStream = null
var _ambience_player: AudioStreamPlayer = null
var _ambience_target_volume_db: float = -8.0

# Bazaar bell SFX
const BAZAAR_BELL_PATH: String = "res://assets/audio/bazaar/bazaar_bell.wav"
var _bazaar_bell_stream: AudioStream = null

var _music_stream_main: AudioStream = null
var _music_stream_bazaar: AudioStream = null
# Two players for crossfade
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_idx: int = 0
var _current_theme: String = ""
var _music_target_volume_db: float = -6.0
var _crossfade_dur: float = 1.0

# Utility: convert decibels ↔ linear amplitude
func _db_to_amp(db: float) -> float:
	return pow(10.0, db / 20.0)

func _amp_to_db(a: float) -> float:
	# Use natural log and convert to base-10: log10(x) = ln(x) / ln(10)
	return 20.0 * (log(max(a, 0.00001)) / log(10.0))

# Get a free AudioStreamPlayer2D from the pool
func _get_free_player() -> AudioStreamPlayer2D:
	for player in _audio_pool:
		if not player.playing:
			return player
	return null

# Play a sound with optional pitch, volume, and pan
func play_sfx(stream: AudioStream, pos: Vector2 = Vector2.ZERO, pitch_range: Vector2 = Vector2(1.0, 1.0), volume_db: float = 0.0, pan: float = 0.0):
	var player := _get_free_player()
	if not player:
		return # Pool exhausted
	player.stop()
	player.stream = stream
	player.position = pos
	player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	player.volume_db = volume_db
	player.play()

# Utility: Play a random stream from a list
func play_sfx_random(streams: Array[AudioStream], pos: Vector2 = Vector2.ZERO, pitch_range: Vector2 = Vector2(1.0, 1.0), volume_db: float = 0.0, pan: float = 0.0):
	if streams.size() == 0:
		return
	var stream = streams[randi() % streams.size()]
	play_sfx(stream, pos, pitch_range, volume_db, pan)

# Utility: Calculate pan from X position (screen width -1.0 to 1.0)
func pan_from_x(x: float, screen_width: float) -> float:
	return clamp((x / screen_width) * 2.0 - 1.0, -1.0, 1.0)

func _setup_audio_buses() -> void:
	# Ensure Music bus exists
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		var music_idx := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(music_idx, MUSIC_BUS)
		AudioServer.set_bus_send(music_idx, "Master")
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(0.8))
	# Ensure UI bus exists
	if AudioServer.get_bus_index(UI_BUS) == -1:
		var ui_idx := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(ui_idx, UI_BUS)
		AudioServer.set_bus_send(ui_idx, "Master")
		AudioServer.set_bus_volume_db(ui_idx, linear_to_db(1.0))
	
	# Apply saved volumes
	var music_vol := float(Database.get_setting("volume_music", 0.8))
	set_music_volume(music_vol)
	var ui_vol := float(Database.get_setting("volume_ui", 1.0))
	set_ui_volume(ui_vol)

func set_music_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func set_ui_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(UI_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func set_music_mute(muted: bool) -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

func set_ui_mute(muted: bool) -> void:
	var idx := AudioServer.get_bus_index(UI_BUS)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

# ─────────────────────────────────────────────────────────────
# Dice SFX logic migrated from DiceSound.gd
# ─────────────────────────────────────────────────────────────

const DICE_SOUND_PATHS := [
	"res://assets/audio/dice_sounds/dice_clack_01.wav",
	"res://assets/audio/dice_sounds/dice_clack_02.wav",
	"res://assets/audio/dice_sounds/dice_clack_03.wav",
	"res://assets/audio/dice_sounds/dice_clack_04.wav",
]

var _dice_streams: Array[AudioStream] = []

# Load dice SFX streams on ready
func _ready():
	# Ensure audio buses exist
	_setup_audio_buses()
	
	# Audio pool setup (already present)
	for i in range(_pool_size):
		var player := AudioStreamPlayer2D.new()
		player.bus = _bus
		player.autoplay = false
		player.volume_db = 0.0
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		_audio_pool.append(player)

	# Load dice SFX streams
	for path in DICE_SOUND_PATHS:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res and res is AudioStream:
				_dice_streams.append(res as AudioStream)

	# Setup two music players for crossfading
	var resolved_bus := "Master"
	if Engine.has_singleton("AudioServer"):
		# Use AudioServer.get_bus_index to check existence
		var idx: int = AudioServer.get_bus_index(MUSIC_BUS) if typeof(AudioServer.get_bus_index) != TYPE_NIL else -1
		if idx >= 0:
			resolved_bus = MUSIC_BUS

	for i in range(2):
		var mp := AudioStreamPlayer.new()
		mp.bus = resolved_bus
		mp.stream = null
		mp.volume_db = -80.0
		mp.autoplay = false
		add_child(mp)
		# Ensure background music players loop by reconnecting finished -> play
		mp.connect("finished", Callable(mp, "play"))
		_music_players.append(mp)

	# Lazy-load theme streams if present
	if ResourceLoader.exists(MAIN_THEME_PATH):
		_music_stream_main = load(MAIN_THEME_PATH)
	if ResourceLoader.exists(LUNAR_BAZAAR_THEME_PATH):
		_music_stream_bazaar = load(LUNAR_BAZAAR_THEME_PATH)

	# Load ambience streams if present
	if ResourceLoader.exists(AMBIENCE_DAY_PATH):
		_ambience_stream_day = load(AMBIENCE_DAY_PATH)
	if ResourceLoader.exists(AMBIENCE_NIGHT_PATH):
		_ambience_stream_night = load(AMBIENCE_NIGHT_PATH)

	# Load bazaar bell stream
	if ResourceLoader.exists(BAZAAR_BELL_PATH):
		_bazaar_bell_stream = load(BAZAAR_BELL_PATH)

	# Setup one ambience player for looping day/night background
	var ambience_bus := "Master"
	var amb_idx: int = -1
	# prefer an "Ambience" bus if available
	if Engine.has_singleton("AudioServer"):
		amb_idx = AudioServer.get_bus_index("Ambience") if typeof(AudioServer.get_bus_index) != TYPE_NIL else -1
		if amb_idx >= 0:
			ambience_bus = "Ambience"
	else:
		# fallback to MUSIC_BUS if defined
		ambience_bus = MUSIC_BUS

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = ambience_bus
	_ambience_player.stream = null
	_ambience_player.volume_db = -80.0
	_ambience_player.autoplay = false
	add_child(_ambience_player)
	# Ensure looping behavior by restarting when finished
	_ambience_player.connect("finished", Callable(_ambience_player, "play"))

# Play a dice impact sound at a given position, strength 0.0–1.0
func play_dice_impact(pos: Vector2, strength: float = 0.5) -> void:
	if _dice_streams.is_empty():
		return
	var screen_width: float = 1920.0
	var vp := get_viewport()
	if vp:
		screen_width = float(vp.size.x)
	var pan := pan_from_x(pos.x, screen_width)
	var pitch := randf_range(0.92, 1.06) * (1.0 + (strength - 0.5) * 0.25)
	var volume := lerpf(-10.0, -2.0, clamp(strength, 0.0, 1.0))
	play_sfx_random(_dice_streams, pos, Vector2(pitch, pitch), volume, pan)

# Play a dice result pop (called on settle). is_crit for louder/bright variants.
func play_dice_result(pos: Vector2, is_crit: bool = false) -> void:
	if _dice_streams.is_empty():
		return
	var screen_width: float = 1920.0
	var vp := get_viewport()
	if vp:
		screen_width = float(vp.size.x)
	var pan := pan_from_x(pos.x, screen_width)
	var base_pitch := randf_range(0.98, 1.12)
	var pitch := base_pitch * (1.0 + (0.06 if is_crit else 0.0))
	var volume := -1.0 if is_crit else -4.0
	play_sfx_random(_dice_streams, pos, Vector2(pitch, pitch), volume, pan)

# Play a single dice clack immediately
func play_dice_clack() -> void:
	if _dice_streams.is_empty():
		return
	play_sfx_random(_dice_streams)

# Play one clack per die in `count`, staggered by `interval_sec`
func play_dice_clacks(count: int, interval_sec: float = 0.08) -> void:
	for i in range(count):
		if i == 0:
			play_dice_clack()
		else:
			await get_tree().create_timer(interval_sec * i).timeout
			play_dice_clack()

# -------------------------
# Background music controls
# -------------------------
func _set_music_player_stream(stream: AudioStream) -> void:
	# Crossfade to `stream` over _crossfade_dur seconds using equal-power curve.
	var cur_idx := _active_music_idx
	var next_idx := (_active_music_idx + 1) % 2
	var cur_player: AudioStreamPlayer = _music_players[cur_idx]
	var next_player: AudioStreamPlayer = _music_players[next_idx]

	# Stop / fade out entirely
	if stream == null:
		if cur_player.playing:
			var start_amp := _db_to_amp(cur_player.volume_db)
			var tw_off := create_tween()
			tw_off.tween_method(func(t: float):
				cur_player.volume_db = _amp_to_db(start_amp * (1.0 - t))
			, 0.0, 1.0, _crossfade_dur)
			tw_off.tween_callback(func():
				if cur_player.playing:
					cur_player.stop()
					cur_player.volume_db = -80.0
			)
		return

	# If next_player already playing same stream, just crossfade volumes
	if next_player.stream == stream and next_player.playing:
		var start_old_amp := _db_to_amp(cur_player.volume_db)
		var target_new_amp := _db_to_amp(_music_target_volume_db)
		var tw_swap := create_tween()
		tw_swap.tween_method(func(t: float):
			cur_player.volume_db = _amp_to_db(start_old_amp * cos(t * PI * 0.5))
			next_player.volume_db = _amp_to_db(target_new_amp * sin(t * PI * 0.5))
		, 0.0, 1.0, _crossfade_dur)
		tw_swap.tween_callback(func(): _on_crossfade_complete(cur_idx, next_idx))
		_active_music_idx = next_idx
		return

	# Start next player with the requested stream quietly
	next_player.stream = stream
	next_player.volume_db = -80.0
	if not next_player.playing:
		next_player.play()

	# Equal-power crossfade: old_amp * cos(t) , new_amp * sin(t)
	var start_old_amp := _db_to_amp(cur_player.volume_db)
	var target_new_amp := _db_to_amp(_music_target_volume_db)
	var xf := create_tween()
	xf.tween_method(func(t: float):
		cur_player.volume_db = _amp_to_db(start_old_amp * cos(t * PI * 0.5))
		next_player.volume_db = _amp_to_db(target_new_amp * sin(t * PI * 0.5))
	, 0.0, 1.0, _crossfade_dur)
	xf.tween_callback(func(): _on_crossfade_complete(cur_idx, next_idx))
	_active_music_idx = next_idx

func _on_crossfade_complete(old_idx: int, new_idx: int) -> void:
	var old_player: AudioStreamPlayer = _music_players[old_idx]
	if old_player.playing:
		old_player.stop()
		old_player.volume_db = -80.0

func play_theme(theme: String) -> void:
	# theme: "main" or "bazaar"; other values stop music
	if theme == _current_theme:
		return
	_current_theme = theme
	match theme:
		"main":
			if _music_stream_main != null:
				_set_music_player_stream(_music_stream_main)
		"bazaar":
			if _music_stream_bazaar != null:
				_set_music_player_stream(_music_stream_bazaar)
		_:
			_set_music_player_stream(null)

func play_main_theme() -> void:
	play_theme("main")

func play_bazaar_theme() -> void:
	play_theme("bazaar")

func stop_music() -> void:
	_current_theme = ""
	_set_music_player_stream(null)


# -------------------------
# Ambience controls (garden day/night loops)
# -------------------------
func play_ambience(mode: String) -> void:
	match mode:
		"day":
			if _ambience_stream_day != null:
				_set_ambience_stream(_ambience_stream_day)
		"night":
			if _ambience_stream_night != null:
				_set_ambience_stream(_ambience_stream_night)
		_:
			stop_ambience()

func _set_ambience_stream(stream: AudioStream) -> void:
	if _ambience_player == null:
		return
	if _ambience_player.stream == stream and _ambience_player.playing:
		return

	_ambience_player.stream = stream
	if not _ambience_player.playing:
		_ambience_player.play()

	var target_amp := _db_to_amp(_ambience_target_volume_db)
	var start_amp := _db_to_amp(_ambience_player.volume_db)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		_ambience_player.volume_db = _amp_to_db(lerp(start_amp, target_amp, t))
	, 0.0, 1.0, 1.0)

func stop_ambience() -> void:
	if _ambience_player == null or not _ambience_player.playing:
		return
	var start_amp := _db_to_amp(_ambience_player.volume_db)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		_ambience_player.volume_db = _amp_to_db(start_amp * (1.0 - t))
	, 0.0, 1.0, 0.8)
	tw.tween_callback(func():
		if _ambience_player.playing:
			_ambience_player.stop()
			_ambience_player.volume_db = -80.0
	)

func play_bazaar_bell() -> void:
	if _bazaar_bell_stream == null:
		return
	# Play as SFX using pooled 2D players for UI click
	play_sfx(_bazaar_bell_stream, Vector2.ZERO, Vector2(1.0, 1.0), -3.0)
