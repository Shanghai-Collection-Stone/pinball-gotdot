class_name Sfx
extends Node
## All sounds are synthesised at start-up: bumper pops, flipper clacks, bells,
## a sad trombone for drains and a looping calliope waltz. No audio files.

const RATE := 22050

var players: Dictionary = {}
var music_player: AudioStreamPlayer
var music_enabled := true
var _music_thread: Thread
var _music_data: PackedByteArray
var _music_frames := 0


func _ready() -> void:
	_add("flipper", _flipper(), 4, -6.0)
	_add("flipper_down", _flipper_down(), 4, -12.0)
	_add("bumper", _bumper(), 6, -3.0)
	_add("sling", _sling(), 4, -4.0)
	_add("rollover", _rollover(), 4, -6.0)
	_add("spinner", _spinner(), 8, -10.0)
	_add("drop", _drop(), 4, -3.0)
	_add("quack", _quack(), 3, -4.0)
	_add("pop", _pop(), 3, -2.0)
	_add("bell", _bell(), 3, -3.0)
	_add("ramp", _ramp(), 3, -5.0)
	_add("launch", _launch(), 2, -4.0)
	_add("jackpot", _jackpot(), 2, -2.0)
	_add("drain", _drain(), 1, -7.0)
	_add("start", _start_jingle(), 1, -3.0)
	_add("siren", _siren(), 1, -5.0)
	_add("cash", _cash(), 2, -4.0)
	_add("thunk", _thunk(), 3, -3.0)
	_add("tick", _tick(), 6, -8.0)
	_add("boom", _boom(), 2, -1.0)
	_add("chime", _chime(), 4, -5.0)
	_add("clink", _clink(), 4, -5.0)
	_add("stamp", _stamp(), 2, -3.0)
	_add("carousel", _carousel(), 2, -6.0)
	_add("fanfare", _fanfare(), 1, -2.0)
	_add("firework", _firework(), 4, -6.0)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -13.0
	add_child(music_player)
	_music_thread = Thread.new()
	_music_thread.start(_render_music)


func _exit_tree() -> void:
	if _music_thread and _music_thread.is_started():
		_music_thread.wait_to_finish()
	for p: AudioStreamPlayer in players.values():
		p.stop()
	music_player.stop()
	music_player.stream = null


func _process(_delta: float) -> void:
	if _music_thread and _music_thread.is_started() and not _music_thread.is_alive():
		_music_thread.wait_to_finish()
		_music_thread = null
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = RATE
		w.data = _music_data
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = _music_frames
		music_player.stream = w
		if music_enabled:
			music_player.play()


func play(sound: String, pitch: float = 1.0, volume_offset: float = 0.0) -> void:
	var p: AudioStreamPlayer = players.get(sound)
	if p == null:
		return
	p.pitch_scale = pitch
	p.volume_db = float(p.get_meta("base_db")) + volume_offset
	p.play()


func toggle_music() -> bool:
	music_enabled = not music_enabled
	if music_player.stream:
		if music_enabled:
			music_player.play()
		else:
			music_player.stop()
	return music_enabled


func _add(sound: String, samples: PackedFloat32Array, polyphony: int, db: float) -> void:
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		var g := 0.9 / peak
		for i in samples.size():
			samples[i] *= g
	var p := AudioStreamPlayer.new()
	p.stream = _wav(samples)
	p.max_polyphony = polyphony
	p.volume_db = db
	p.set_meta("base_db", db)
	add_child(p)
	players[sound] = p


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = _pcm(samples)
	return w


static func _pcm(samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	return data


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


# ---------------------------------------------------------------- effects

func _flipper() -> PackedFloat32Array:
	var b := _buf(0.09)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.6 + sin(TAU * 95.0 * t) * exp(-t * 35.0) * 0.8
	return b


func _flipper_down() -> PackedFloat32Array:
	var b := _buf(0.06)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.4 + sin(TAU * 70.0 * t) * exp(-t * 50.0) * 0.5
	return b


func _bumper() -> PackedFloat32Array:
	var b := _buf(0.22)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 220.0 + 700.0 * exp(-t * 22.0)
		ph += TAU * f / RATE
		b[i] = sin(ph) * exp(-t * 14.0) * 0.8 + (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.4 + sin(ph * 2.01) * exp(-t * 25.0) * 0.2
	return b


func _sling() -> PackedFloat32Array:
	var b := _buf(0.12)
	for i in b.size():
		var t := float(i) / RATE
		var sq := 1.0 if fmod(t * 180.0, 1.0) < 0.5 else -1.0
		b[i] = (randf() * 2.0 - 1.0) * exp(-t * 55.0) * 0.6 + sq * exp(-t * 32.0) * 0.3
	return b


func _rollover() -> PackedFloat32Array:
	var b := _buf(0.16)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1318.0 * t) * exp(-t * 26.0) * 0.5 + sin(TAU * 1975.0 * t) * exp(-t * 34.0) * 0.25
	return b


func _spinner() -> PackedFloat32Array:
	var b := _buf(0.035)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 2600.0 * t) * exp(-t * 140.0) * 0.5 + (randf() * 2.0 - 1.0) * exp(-t * 200.0) * 0.3
	return b


func _drop() -> PackedFloat32Array:
	var b := _buf(0.22)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (90.0 + 160.0 * exp(-t * 30.0)) / RATE
		b[i] = sin(ph) * exp(-t * 16.0) * 0.9 + (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.35
	return b


func _quack() -> PackedFloat32Array:
	var b := _buf(0.28)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 330.0 - 140.0 * t / 0.28
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		lp += (saw - lp) * 0.35
		var env := minf(1.0, t * 60.0) * exp(-t * 7.0)
		b[i] = (lp * 0.8 + saw * 0.25) * env * (0.7 + 0.3 * sin(TAU * 28.0 * t))
	return b


func _pop() -> PackedFloat32Array:
	var b := _buf(0.18)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.9 + sin(TAU * 600.0 * t) * exp(-t * 50.0) * 0.4
	return b


func _bell() -> PackedFloat32Array:
	var b := _buf(1.6)
	var partials := [[1.0, 1.0, 2.2], [2.0, 0.55, 3.0], [2.76, 0.45, 4.0], [5.4, 0.25, 6.5], [8.93, 0.12, 9.0]]
	var f0 := 1046.5
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * f0 * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]))
		b[i] = v * 0.4 * minf(1.0, t * 400.0)
	return b


func _ramp() -> PackedFloat32Array:
	var b := _buf(0.8)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 420.0 + 1500.0 * (t / 0.8) * (t / 0.8)
		ph += TAU * f * (1.0 + 0.01 * sin(TAU * 7.0 * t)) / RATE
		var n := randf() * 2.0 - 1.0
		lp += (n - lp) * (0.05 + t * 0.3)
		var env := minf(1.0, t * 10.0) * (1.0 - smoothstep(0.55, 0.8, t))
		b[i] = (sin(ph) * 0.45 + sin(ph * 2.0) * 0.12 + lp * 0.6) * env
	return b


func _launch() -> PackedFloat32Array:
	var b := _buf(0.45)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 160.0 * (1.0 + 0.7 * exp(-t * 7.0) * sin(TAU * 14.0 * t))
		ph += TAU * f / RATE
		b[i] = sin(ph) * exp(-t * 6.0) * 0.8 + (randf() * 2.0 - 1.0) * exp(-t * 80.0) * 0.4
	return b


func _note_into(b: PackedFloat32Array, start: float, dur: float, freq: float, amp: float, square_mix: float = 0.3) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	for k in n:
		var i := s0 + k
		if i >= b.size():
			return
		var t := float(k) / RATE
		var sq := 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		var env := minf(1.0, t * 200.0) * exp(-t * 2.5) * (1.0 - smoothstep(dur - 0.03, dur, t))
		b[i] += (sin(TAU * freq * t) * (1.0 - square_mix) + sq * square_mix * 0.5) * amp * env


func _jackpot() -> PackedFloat32Array:
	var b := _buf(1.25)
	var notes := [72, 76, 79, 84, 79, 84]
	var times := [0.0, 0.09, 0.18, 0.27, 0.42, 0.52]
	var durs := [0.12, 0.12, 0.12, 0.16, 0.1, 0.7]
	for k in notes.size():
		_note_into(b, times[k], durs[k], _midi(notes[k]), 0.35)
		_note_into(b, times[k], durs[k], _midi(notes[k] - 12), 0.15)
	_note_into(b, 0.52, 0.7, _midi(76), 0.2)
	return b


func _start_jingle() -> PackedFloat32Array:
	var b := _buf(1.1)
	var notes := [67, 72, 76, 79]
	for k in notes.size():
		_note_into(b, k * 0.11, 0.6 if k == 3 else 0.14, _midi(notes[k]), 0.35)
	_note_into(b, 0.33, 0.7, _midi(64), 0.2)
	_note_into(b, 0.33, 0.7, _midi(60), 0.2)
	return b


func _cash() -> PackedFloat32Array:
	var b := _buf(0.7)
	for i in b.size():
		var t := float(i) / RATE
		var v := sin(TAU * 2093.0 * t) * exp(-t * 9.0) * 0.4
		if t > 0.12:
			var t2 := t - 0.12
			v += sin(TAU * 2637.0 * t2) * exp(-t2 * 7.0) * 0.4 + sin(TAU * 3951.0 * t2) * exp(-t2 * 12.0) * 0.15
		v += (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.3
		b[i] = v
	return b


func _thunk() -> PackedFloat32Array:
	var b := _buf(0.25)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (70.0 + 80.0 * exp(-t * 25.0)) * t) * exp(-t * 14.0) + (randf() * 2.0 - 1.0) * exp(-t * 50.0) * 0.25
	return b


func _siren() -> PackedFloat32Array:
	var b := _buf(1.6)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 600.0 + 400.0 * sin(TAU * 1.9 * t - PI * 0.5)
		ph += TAU * f / RATE
		var env := minf(1.0, t * 8.0) * (1.0 - smoothstep(1.3, 1.6, t))
		b[i] = (sin(ph) * 0.6 + sin(ph * 3.0) * 0.12) * env * 0.7
	return b


## "Wah wah wah waaah" — the classic sad trombone.
func _drain() -> PackedFloat32Array:
	var notes := [67.0, 66.0, 65.0, 64.0]
	var durs := [0.36, 0.36, 0.36, 1.1]
	var total := 0.0
	for d in durs:
		total += float(d)
	var b := _buf(total + 0.1)
	var start := 0.0
	var ph := 0.0
	var lp := 0.0
	for k in notes.size():
		var dur: float = durs[k]
		var f0 := _midi(notes[k] - 12.0)
		var s0 := int(start * RATE)
		for j in int(dur * RATE):
			var t := float(j) / RATE
			var vib := 1.0
			if k == 3:
				vib = 1.0 + 0.025 * sin(TAU * 5.5 * t) * minf(1.0, t * 2.0)
			var f := f0 * vib * (1.0 - 0.02 * exp(-t * 20.0))
			ph += f / RATE
			var saw := fmod(ph, 1.0) * 2.0 - 1.0
			lp += (saw - lp) * 0.12
			var env := minf(1.0, t * 25.0) * (1.0 - smoothstep(dur - 0.08, dur, t))
			if s0 + j < b.size():
				b[s0 + j] = lp * env * 1.2
		start += dur
	return b


func _tick() -> PackedFloat32Array:
	var b := _buf(0.04)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1800.0 * t) * exp(-t * 120.0) * 0.6 + (randf() * 2.0 - 1.0) * exp(-t * 300.0) * 0.4
	return b


## Cannon: low thump, noise blast and a rumbling tail.
func _boom() -> PackedFloat32Array:
	var b := _buf(1.0)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (40.0 + 90.0 * exp(-t * 12.0)) / RATE
		var n := randf() * 2.0 - 1.0
		lp += (n - lp) * (0.08 + 0.4 * exp(-t * 20.0))
		b[i] = sin(ph) * exp(-t * 5.0) * 0.9 + lp * exp(-t * 3.5) * 1.4
	return b


func _chime() -> PackedFloat32Array:
	var b := _buf(0.6)
	for k in 3:
		_note_into(b, k * 0.06, 0.5, _midi(84 + [0, 4, 7][k]), 0.25, 0.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] += sin(TAU * 4186.0 * t) * exp(-t * 18.0) * 0.12
	return b


func _clink() -> PackedFloat32Array:
	var b := _buf(0.5)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 2350.0 * t) * 0.5 + sin(TAU * 3720.0 * t) * 0.35 + sin(TAU * 5310.0 * t) * 0.2) * exp(-t * 11.0)
		b[i] += (randf() * 2.0 - 1.0) * exp(-t * 150.0) * 0.3
	return b


## Passport stamp: a wooden thunk followed by a little ding.
func _stamp() -> PackedFloat32Array:
	var b := _buf(0.8)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (110.0 + 60.0 * exp(-t * 30.0)) * t) * exp(-t * 22.0) * 0.9
		if t > 0.12:
			var t2 := t - 0.12
			b[i] += sin(TAU * 1568.0 * t2) * exp(-t2 * 6.0) * 0.35 + sin(TAU * 3136.0 * t2) * exp(-t2 * 9.0) * 0.12
	return b


## Carousel organ flourish (short major arpeggio with vibrato).
func _carousel() -> PackedFloat32Array:
	var b := _buf(0.7)
	var notes := [72, 76, 79, 76]
	for k in notes.size():
		_note_into(b, k * 0.11, 0.3, _midi(notes[k]), 0.22, 0.1)
	return b


## Big fanfare for the wizard mode.
func _fanfare() -> PackedFloat32Array:
	var b := _buf(2.2)
	var notes := [67, 72, 76, 79, 76, 79, 84]
	var times := [0.0, 0.15, 0.3, 0.45, 0.68, 0.8, 1.0]
	var durs := [0.14, 0.14, 0.14, 0.2, 0.1, 0.18, 1.1]
	for k in notes.size():
		_note_into(b, times[k], durs[k], _midi(notes[k]), 0.32, 0.45)
		_note_into(b, times[k], durs[k], _midi(notes[k] - 12), 0.14, 0.2)
	for n in [60, 64, 67]:
		_note_into(b, 1.0, 1.1, _midi(n), 0.12, 0.3)
	return b


func _firework() -> PackedFloat32Array:
	var b := _buf(1.2)
	for i in b.size():
		var t := float(i) / RATE
		var crackle := 0.0
		if t > 0.15 and randf() < 0.02 * exp(-(t - 0.15) * 3.0):
			crackle = randf() * 2.0 - 1.0
		b[i] = sin(TAU * (60.0 + 40.0 * exp(-t * 15.0)) * t) * exp(-t * 9.0) * 0.8 + (randf() * 2.0 - 1.0) * exp(-t * 25.0) * 0.5 + crackle * 0.9
	return b


# ---------------------------------------------------------------- music

## Renders an original oom-pah-pah calliope waltz on a worker thread.
func _render_music() -> void:
	var beat := 0.34
	# melody: [midi note (0 = rest), beats]
	var melody := [
		[76, 1], [75, 0.5], [76, 0.5], [79, 1], [76, 2], [72, 1],
		[74, 1], [73, 0.5], [74, 0.5], [77, 1], [74, 2], [71, 1],
		[67, 1], [71, 1], [74, 1], [77, 1], [76, 1], [74, 1],
		[76, 1], [79, 1], [84, 1], [79, 2], [0, 1],
		[76, 1], [75, 0.5], [76, 0.5], [79, 1], [84, 2], [81, 1],
		[81, 1], [80, 0.5], [81, 0.5], [84, 1], [81, 2], [77, 1],
		[76, 1], [79, 1], [84, 1], [74, 1], [77, 1], [83, 1],
		[84, 1], [79, 1], [76, 1], [72, 2], [0, 1],
	]
	# one chord per bar: [bass note, chord notes]
	var C := [48, [64, 67, 72]]
	var G7 := [43, [65, 71, 74]]
	var F := [41, [65, 69, 72]]
	var bars := [C, C, G7, G7, G7, G7, C, C, C, C, F, F, C, G7, C, C]
	var total_beats := bars.size() * 3
	var n := int(total_beats * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var cache := {}

	var t_beat := 0.0
	for m in melody:
		var note: int = int(m[0])
		var beats: float = float(m[1])
		if note > 0:
			_mix(buf, _music_note(cache, "mel", note, beats * beat * 0.92), int(t_beat * beat * RATE))
		t_beat += beats
	for bi in bars.size():
		var bar: Array = bars[bi]
		var bar_start := bi * 3.0 * beat
		_mix(buf, _music_note(cache, "bass", int(bar[0]), beat * 0.9), int(bar_start * RATE))
		for k in [1, 2]:
			for cn in bar[1]:
				_mix(buf, _music_note(cache, "chord", int(cn), beat * 0.45), int((bar_start + k * beat) * RATE))
	_music_data = _pcm(buf)
	_music_frames = n


func _mix(buf: PackedFloat32Array, note: PackedFloat32Array, at: int) -> void:
	var m := mini(note.size(), buf.size() - at)
	for i in m:
		buf[at + i] += note[i]


func _music_note(cache: Dictionary, voice: String, note: int, dur: float) -> PackedFloat32Array:
	var key := "%s_%d_%.3f" % [voice, note, dur]
	if cache.has(key):
		return cache[key]
	var f := _midi(note)
	var b := _buf(dur)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		match voice:
			"mel":
				# steam calliope: breathy, bright, with vibrato
				var ph := TAU * f * t + 0.012 * f / 5.5 * sin(TAU * 5.5 * t)
				v = sin(ph) * 0.6 + sin(ph * 2.0) * 0.28 + sin(ph * 3.0) * 0.12
				var env := minf(1.0, t * 40.0) * (1.0 - smoothstep(dur - 0.04, dur, t))
				v *= env * 0.22
			"bass":
				var ph2 := TAU * f * t
				v = (sin(ph2) * 0.8 + sin(ph2 * 2.0) * 0.35) * minf(1.0, t * 60.0) * exp(-t * 3.5) * 0.32
			_:
				var ph3 := TAU * f * t
				v = (sin(ph3) + sin(ph3 * 2.0) * 0.3) * minf(1.0, t * 120.0) * exp(-t * 9.0) * 0.07
		b[i] = v
	cache[key] = b
	return b
