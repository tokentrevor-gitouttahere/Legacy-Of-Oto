extends Node
## Autoload. Every sound in the game: one-shot effects by name, looping sounds that start and
## stop, footsteps by ground, and babble: the gibberish a character "speaks" while their line
## types. Sounds are Kenney's CC0 packs (assets/audio, CREDITS.md), picked by the owner on
## 2026-10-29 from the sound preview.
##
##   Sfx.play("punch")              # a one-shot, a little pitch variety each time
##   Sfx.loop_on("ki_charge")       # start a loop (no-op if it is playing); Sfx.loop_off(...) ends it
##   Sfx.babble("Oto")              # one syllable in that speaker's voice (Overlay calls this)

const SFX_DIR := "res://assets/audio/sfx/"
const VOICE_DIR := "res://assets/audio/voice/"

## name -> [volume dB, pitch variety (+-)]
const SOUNDS := {
	"punch": [-4.0, 0.08], "punch_heavy": [-2.0, 0.05], "hurt": [-3.0, 0.08], "guard": [-5.0, 0.06], "swing": [-12.0, 0.12],
	"ki_blast": [-12.0, 0.1], "ki_orb": [-6.0, 0.05], "explosion": [-4.0, 0.08],
	"form_up": [-2.0, 0.0], "form_down": [-6.0, 0.0], "flight": [-8.0, 0.06], "enemy_down": [-3.0, 0.08],
	"rock_break": [-3.0, 0.06], "door": [-6.0, 0.04], "gate": [-5.0, 0.0], "lantern": [-6.0, 0.0],
	"step_grass": [-20.0, 0.12], "step_stone": [-20.0, 0.12], "step_wood": [-18.0, 0.12], "step_snow": [-18.0, 0.12],
	"capsule": [-6.0, 0.04], "food": [-8.0, 0.0], "dish": [-4.0, 0.0], "level_up": [-3.0, 0.0], "key_item": [-5.0, 0.0],
	"ui_move": [-12.0, 0.0], "ui_confirm": [-9.0, 0.0], "ui_back": [-9.0, 0.0], "ui_error": [-8.0, 0.0],
	"ui_open": [-9.0, 0.0], "dialogue_next": [-10.0, 0.0],
}
## Looping sounds and their volume.
const LOOPS := {"ki_charge": -10.0, "ki_beam": -6.0}

## Babble voices: the blip each is built on, its pitch (Hz), its speed (syllables come every
## SYLLABLE_GAP / speed seconds at most) and how far each syllable's pitch wanders. Pitch and
## speed are the owner's picks. A blip sits near 440 Hz and plays an octave above the voice.
const VOICES := {
	"oto": {"blip": "blip_tone", "pitch": 209.0, "speed": 1.0, "spread": 0.07},
	"woman": {"blip": "blip_pep", "pitch": 340.0, "speed": 1.0, "spread": 0.16},
	"man": {"blip": "blip_tone", "pitch": 118.0, "speed": 0.95, "spread": 0.1},
	"goku": {"blip": "blip_pluck", "pitch": 172.0, "speed": 1.25, "spread": 0.24, "lilt": 0.12, "db": 8.0},  # his blip is quieter
}
const SYLLABLE_GAP := 0.083
const BLIP_BASE := 440.0
## Women whose voice is the women's babble, beyond the townswomen (who are all women).
const WOMEN := ["Chi-Chi", "Bulma", "Mrs. Briefs", "Lottie", "Clementine"]
## Ground -> footstep sound.
const STEPS := {"grass": "step_grass", "dirt": "step_grass", "sand": "step_snow", "snow": "step_snow", "ice": "step_snow",
	"wood": "step_wood", "carpet": "step_wood"}

var muted := false
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}
var _last_syllable := {}
var _bus_ok := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = DisplayServer.get_name() == "headless"  # tests and screenshots stay quiet
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]

func has(name: String) -> bool:
	return SOUNDS.has(name) and _stream(SFX_DIR + name + ".ogg") != null

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]  # every voice busy: steal the oldest slot

## A one-shot effect by name; `pitch` scales it on top of its own variety.
func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if muted or not SOUNDS.has(name):
		return
	var s := _stream(SFX_DIR + name + ".ogg")
	if s == null:
		return
	var spec: Array = SOUNDS[name]
	var p := _free_player()
	p.stream = s
	p.volume_db = float(spec[0]) + volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-1.0, 1.0) * float(spec[1]))
	p.play()

func loop_on(name: String) -> void:
	if muted or not LOOPS.has(name):
		return
	var p: AudioStreamPlayer = _loops.get(name)
	if p and p.playing:
		return
	if p == null:
		var s := _stream(SFX_DIR + name + ".ogg")
		if s == null:
			return
		s = s.duplicate()
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		p = AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = float(LOOPS[name])
		add_child(p)
		_loops[name] = p
	p.play()

func loop_off(name: String) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if p and p.playing:
		p.stop()

func looping(name: String) -> bool:
	var p: AudioStreamPlayer = _loops.get(name)
	return p != null and p.playing

func step(ground: String) -> void:
	play(STEPS.get(ground, "step_stone"))

# --- babble -----------------------------------------------------------------------

## Which voice a speaker talks in.
static func voice_of(speaker: String) -> String:
	if speaker == "Oto":
		return "oto"
	if speaker == "Goku":
		return "goku"
	if speaker in WOMEN or NpcWomen.look_for_speaker(speaker) != "":
		return "woman"
	return "man"

## One syllable for `speaker`, unless the last came too recently for their speed. `phrase_end`
## (near the end of a sentence) lifts Goku's pitch and settles everyone else's.
func babble(speaker: String, phrase_end := false) -> void:
	if muted or speaker == "":
		return
	var vid := voice_of(speaker)
	var v: Dictionary = VOICES[vid]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_syllable.get(vid, -10.0)) < SYLLABLE_GAP / float(v["speed"]):
		return
	_last_syllable[vid] = now
	var s := _stream(VOICE_DIR + str(v["blip"]) + ".ogg")
	if s == null:
		return
	var pitch: float = float(v["pitch"]) * (1.0 + randf_range(-1.0, 1.0) * float(v["spread"]))
	if phrase_end:
		pitch *= 1.0 + float(v.get("lilt", -0.06))
	var p := _free_player()
	p.stream = s
	p.volume_db = -9.0 + float(v.get("db", 0.0))
	p.pitch_scale = clampf(pitch * 2.0 / BLIP_BASE, 0.2, 4.0)
	p.play()
