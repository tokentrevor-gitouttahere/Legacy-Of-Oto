extends Node
## Autoload. Background music: one track at a time, crossfaded, every track looping. CC0 tracks
## from OpenGameArt picked by the owner on 2026-10-29 (assets/audio/music, CREDITS.md).
##
##   Music.play("town")          # crossfade to a track (no-op if it is already playing)
##   Music.for_level(data)       # the track a location's level data calls for
##   Music.set_fight(1)          # 1: a fight, 2: a boss; 0 returns to the area's track
##
## A location calls set_fight from its foes each frame; the fight music holds a few seconds
## after the last foe disengages, so it does not flicker.

const DIR := "res://assets/audio/music/"
const TRACKS := {
	"title": "title.mp3",    # Battle Theme A, cynicmusic: the title screen and the intro
	"town": "town.mp3",      # Town Theme RPG, cynicmusic: towns, homes, interiors
	"battle": "battle.mp3",  # Awake! (Megawall-10), cynicmusic: fights
	"boss": "boss.wav",      # Fast fight / battle music (looped), Ville Nousiainen and XCVG: bosses
	"desert": "desert.ogg",  # Desert theme (caravan), yd
	"ice": "ice.ogg",        # Snowfall (looped), Kistol: ice and mountains
	"cave": "cave.mp3",      # Crystal Cave (song18), cynicmusic
	"world": "world.mp3",    # To The Wind, Bobjt: flying the world map
}
const VOLUME := {"title": -8.0, "town": -10.0, "battle": -9.0, "boss": -8.0, "desert": -8.0, "ice": -7.0, "cave": -6.0, "world": -9.0}
const FADE := 1.2
const FIGHT_HOLD := 4.0   # seconds the fight music lingers after the last foe disengages

var muted := false
var current := ""
var area := ""           # the location's own track, to return to after a fight
var _player: AudioStreamPlayer
var _old: AudioStreamPlayer
var _fight := 0
var _calm_for := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = DisplayServer.get_name() == "headless"
	_player = _make()
	_old = _make()

func _make() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	add_child(p)
	return p

static func stream_for(track: String) -> AudioStream:
	if not TRACKS.has(track):
		return null
	var s: AudioStream = load(DIR + TRACKS[track])
	if s == null:
		return null
	s = s.duplicate()
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return s

## Crossfade to `track` ("" fades out to silence).
func play(track: String) -> void:
	if track == current:
		return
	current = track
	if muted:
		return
	var tmp := _old
	_old = _player
	_player = tmp
	if _old.playing:
		var old := _old
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.tween_callback(old.stop)
	if track == "":
		return
	var s := stream_for(track)
	if s == null:
		return
	_player.stream = s
	_player.volume_db = -40.0
	_player.play()
	create_tween().tween_property(_player, "volume_db", float(VOLUME.get(track, -9.0)), FADE)

## The area's track, which fights return to.
func play_area(track: String) -> void:
	area = track
	_fight = 0
	play(track)

## The track a location's level calls for: a "music" key, else from its sky and name.
static func for_level(data: Dictionary) -> String:
	if data.has("music"):
		return str(data["music"])
	var id := str(data.get("id", ""))
	match str(data.get("sky", "day")):
		"desert", "wasteland":
			return "desert"
		"arctic", "alpine", "sky_high":
			return "ice"
		"cavern":
			return "cave"
	if id.begins_with("kami"):
		return "ice"
	return "town"

## 0 calm, 1 a fight, 2 a boss fight. Call it every frame with the worst threat in reach.
func set_fight(level: int, delta: float) -> void:
	if level > 0:
		_calm_for = 0.0
		if level > _fight:
			_fight = level
	else:
		_calm_for += delta
		if _fight > 0 and _calm_for >= FIGHT_HOLD:
			_fight = 0
	play("boss" if _fight == 2 else ("battle" if _fight == 1 else area))
