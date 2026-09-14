extends Node
## Audio 100% procedural, zero asset : SFX en WAV generes + moteur en boucle.
## Autoload "Audio" (apres ChaosEventSystem, aucune dependance inverse).
## Usage : Audio.play("coin"), Audio.play("boost")...

var _players: Array = []
var _idx: int = 0
var _engine: AudioStreamPlayer = null
var _skid: AudioStreamPlayer = null
var _music: AudioStreamPlayer = null
var music_on: bool = true
var _streams: Dictionary = {}

## SFX vocaux : colores par la voix du pilote local (CharacterData.voice_pitch).
const VOICE_SFX := ["chicken", "hit", "star"]
const CHAR_RES := "res://assets/resources/character_%s.tres"

var _char_cache: Dictionary = {}

const RATE := 22050

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _loop_tone(110.0, 0.5)
	_engine.volume_db = -17.0
	add_child(_engine)
	_skid = AudioStreamPlayer.new()
	_skid.stream = _loop_noise(0.4)
	_skid.volume_db = -60.0
	add_child(_skid)
	_skid.play()
	_music = AudioStreamPlayer.new()
	_music.stream = _build_music()
	_music.volume_db = -20.0
	add_child(_music)
	_streams["pickup"] = _slide(500.0, 1050.0, 0.12, 0.5)
	_streams["roulette"] = _tone(1250.0, 0.04, 0.3)
	_streams["coin"] = _melody([[988.0, 0.07], [1319.0, 0.22]])
	_streams["boost"] = _slide(200.0, 1250.0, 0.45, 0.5)
	_streams["pad"] = _slide(300.0, 950.0, 0.3, 0.45)
	_streams["hit"] = _tone(140.0, 0.25, 0.6, true)
	_streams["shell"] = _slide(850.0, 280.0, 0.2, 0.5)
	_streams["beep"] = _tone(880.0, 0.12, 0.5)
	_streams["go"] = _tone(1318.0, 0.45, 0.55)
	_streams["shield"] = _slide(900.0, 1800.0, 0.15, 0.4)
	_streams["star"] = _melody([[660.0, 0.09], [830.0, 0.09], [990.0, 0.09], [1320.0, 0.25]])
	_streams["lightning"] = _noise_hit(0.6, 0.6)
	_streams["chicken"] = _melody([[700.0, 0.06], [500.0, 0.06], [820.0, 0.12]])
	# Reglages deja charges par GameManager (autoload precedent) : on les applique
	# (bus + musique + qualite particules) au lieu des valeurs en dur d'avant.
	GameManager.apply_settings()

func play(sfx: String) -> void:
	if not _streams.has(sfx) or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _streams[sfx]
	var vmult := _local_voice_pitch() if sfx in VOICE_SFX else 1.0
	p.pitch_scale = randf_range(0.97, 1.03) * vmult
	p.play()

## Voix du pilote local : croco grave (0.7) … poulet aigu (1.8). Repli 1.0.
func voice_pitch_for(cid: String) -> float:
	if _char_cache.has(cid):
		return float(_char_cache[cid])
	var pitch := 1.0
	var path := CHAR_RES % cid
	if ResourceLoader.exists(path):
		var cd := load(path) as CharacterData
		if cd:
			pitch = clampf(float(cd.voice_pitch), 0.5, 2.0)
	_char_cache[cid] = pitch
	return pitch

func _local_voice_pitch() -> float:
	if get_tree() == null:
		return 1.0
	var v: Node = get_tree().get_first_node_in_group("local_player")
	if v == null or v.get("character_id") == null:
		return 1.0
	return voice_pitch_for(str(v.get("character_id")))

func _process(_delta: float) -> void:
	if get_tree() == null:
		return
	var v: Node = get_tree().get_first_node_in_group("local_player")
	var on := v != null and GameManager.current_phase == GameManager.MatchPhase.RACING
	if on and v.get("linear_velocity") != null:
		if not _engine.playing:
			_engine.play()
		var lv: Vector3 = v.get("linear_velocity")
		var top := 22.0
		if v.get("stats") != null:
			top = float((v.get("stats") as KartStats).top_speed)
		_engine.pitch_scale = clampf((0.7 + clampf(lv.length() / maxf(top, 1.0), 0.0, 1.2)) * _local_voice_pitch(), 0.5, 2.0)
	elif _engine.playing:
		_engine.stop()
	var want_skid := -60.0
	if on and v.get("drift_active") != null and bool(v.get("drift_active")):
		want_skid = -16.0
	_skid.volume_db = lerpf(_skid.volume_db, want_skid, clampf(_delta * 6.0, 0.0, 1.0))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_music()

func toggle_music() -> void:
	GameManager.set_music_enabled(not GameManager.settings_music)

func set_music_enabled(on: bool) -> void:
	music_on = on
	if _music == null:
		return
	if music_on:
		_music.play()
	else:
		_music.stop()

func set_master_volume(v: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if v <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(v, 0.001, 1.0)))

# --- Synthese ---

func _mk(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _tone(freq: float, dur: float, vol: float = 0.5, square: bool = false) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var d := PackedByteArray()
	d.resize(n)
	var ph := 0.0
	for i in n:
		ph += TAU * freq / RATE
		var s := sin(ph)
		if square:
			s = 0.6 if s >= 0.0 else -0.6
		var env := exp(-3.0 * float(i) / float(maxi(n, 1)))
		d[i] = clampi(128 + int(110.0 * vol * env * s), 0, 255)
	return _mk(d)

func _slide(f0: float, f1: float, dur: float, vol: float = 0.5) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var d := PackedByteArray()
	d.resize(n)
	var ph := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / float(maxi(n, 1)))
		ph += TAU * f / RATE
		var env := exp(-2.0 * float(i) / float(maxi(n, 1)))
		d[i] = clampi(128 + int(110.0 * vol * env * sin(ph)), 0, 255)
	return _mk(d)

func _melody(notes: Array) -> AudioStreamWAV:
	var d := PackedByteArray()
	for note in notes:
		var f: float = float(note[0])
		var n := int(RATE * float(note[1]))
		var start := d.size()
		d.resize(start + n)
		var ph := 0.0
		for i in n:
			ph += TAU * f / RATE
			var env := exp(-2.5 * float(i) / float(maxi(n, 1)))
			d[start + i] = clampi(128 + int(100.0 * env * sin(ph)), 0, 255)
	return _mk(d)

func _noise_hit(dur: float, vol: float = 0.5) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var d := PackedByteArray()
	d.resize(n)
	var prev := 0.0
	for i in n:
		var r := randf() * 2.0 - 1.0
		var s := (r + prev) * 0.5
		prev = r
		var env := exp(-3.5 * float(i) / float(maxi(n, 1)))
		d[i] = clampi(128 + int(115.0 * vol * env * s), 0, 255)
	return _mk(d)

func _loop_tone(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var d := PackedByteArray()
	d.resize(n)
	for i in n:
		d[i] = clampi(128 + int(60.0 * sin(TAU * freq * float(i) / RATE)), 0, 255)
	var w := _mk(d)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _loop_noise(dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var d := PackedByteArray()
	d.resize(n)
	var prev := 0.0
	for i in n:
		var r := randf() * 2.0 - 1.0
		var s := (r + prev) * 0.5
		prev = r
		d[i] = clampi(128 + int(70.0 * s), 0, 255)
	var w := _mk(d)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _build_music() -> AudioStreamWAV:
	# Chiptune 8s : C - G - Am - F, basse + arpèges, boucle parfaite.
	var step := 0.25 # croches a 120bpm
	var step_n := int(RATE * step)
	var chords := [[130.8, false], [98.0, false], [110.0, true], [87.3, false]]
	var d := PackedByteArray()
	for ch in chords:
		var root: float = ch[0]
		var third := 3 if bool(ch[1]) else 4
		for s in 16:
			var start := d.size()
			d.resize(start + step_n)
			var arp_note: int = [0, third, 7, 12][s % 4]
			var af: float = root * 2.0 * pow(2.0, float(arp_note) / 12.0)
			var bf: float = root / 2.0 if s % 4 == 0 else 0.0
			var ph := 0.0
			for i in step_n:
				ph += TAU * af / RATE
				var samp := 0.35 * sin(ph)
				if bf > 0.0:
					samp += 0.5 * sin(TAU * bf * float(i) / RATE)
				var env := 0.6 + 0.4 * sin(PI * float(i) / float(step_n))
				d[start + i] = clampi(128 + int(55.0 * samp * env), 0, 255)
	var w := _mk(d)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = d.size()
	return w
