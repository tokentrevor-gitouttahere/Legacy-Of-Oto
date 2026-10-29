extends Cutscene
## The opening: Oto flies in over Diablo Desert at dusk, charges and fires a void-violet beam
## that blows a sandstone spire apart, lands, takes her stance, and the title fades in.
## Any confirm or cancel press skips to the title.

## The beam clip (Mixamo "BEAM"): hands drawn back by GATHER, thrust out and held from
## RELEASE to about 2.7 s. Measured with scripts/tools/probe_anims.gd and the pose sheet.
const GATHER := 0.72
const RELEASE := 1.0
const STANCE := ["kick", 0.3]

var _spire: Node3D

func play() -> void:
	Overlay.fade_to(Color.BLACK, 0.01)
	sky("dusk")
	open_set(Color(0.86, 0.62, 0.42), "noise", "mesa", ["cactus", "rock", "cactus", "dead_tree", "hoodoo"], 5)
	var spot := Vector3.ZERO                   # where she lands
	var target := spot + Vector3(-3, 0, -24)   # the spire she hits
	_spire = Props.make("hoodoo", {"size": 2.2})
	_spire.position = target
	add_child(_spire)
	var oto := actor("oto", spot + Vector3(30, 14, 26))
	camera_at(spot + Vector3(-9, 2.5, 12), spot + Vector3(6, 4, 4), 55)
	await Overlay.fade_from(1.2)
	# she streaks in low over the canyon, the camera turning to follow
	Sfx.play("flight", 0.9)
	fly(oto, oto.position, spot + Vector3(0, 2.2, 0), 2.6, spot + Vector3(14, 3.5, 8))
	await camera_follow(oto, Vector3(-6, 1.8, 8), 2.6, 0.8)
	# she pulls up, turns on the spire, draws her hands back and gathers ki between them
	oto.rotation.x = 0.0
	face(oto, target)
	anim(oto, "falling")
	await move(oto, spot, 0.45)
	face_expr(oto, "cold")
	var aura := CutFx.aura(self, oto)
	Sfx.loop_on("ki_charge")
	camera_to(spot + Vector3(6.5, 1.6, -2.0), spot + Vector3(-0.3, 1.25, -2.6), 0.8, 45)  # side-on: the beam crosses the frame
	anim(oto, "beam", 0.55)  # slowed: the gather is the held breath before the shot
	var hands := func() -> Vector3: return (bone_pos(oto, "RightHand") + bone_pos(oto, "LeftHand")) * 0.5
	var orb := CutFx.charge(self, hands, GATHER / 0.55)
	await wait(RELEASE / 0.55)
	# the beam, from both hands
	anim_speed(oto, 1.0)
	orb.queue_free()
	Sfx.loop_off("ki_charge")
	Sfx.play("ki_orb", 0.8)
	Sfx.loop_on("ki_beam")
	CutFx.beam(self, hands.call(), target + Vector3(0, 2.5, 0), 0.22, 1.2, 0.3)
	shake(1.2, 0.12)
	camera_to(spot + Vector3(12, 3.0, -9), spot.lerp(target, 0.6) + Vector3(0, 1.8, 0), 0.6, 55)
	await wait(0.22)
	Sfx.play("explosion")
	Sfx.play("rock_break", 0.8)
	CutFx.impact(self, target + Vector3(0, 2.5, 0), 2.6, CutFx.VOID_GLOW.lightened(0.3))
	CutFx.debris(self, target + Vector3(0, 2.5, 0), Color(0.8, 0.5, 0.32), 22, 11.0)
	CutFx.dust_ring(self, target, 9.0)
	_spire.visible = false
	shake(0.6, 0.3)
	await wait(1.2)
	# she turns to us: her stance, and the title
	Sfx.loop_off("ki_beam")
	aura.queue_free()
	face(oto, spot + Vector3(0, 0, 10))
	camera_to(spot + Vector3(0, 1.2, 4.6), spot + Vector3(0, 1.15, 0), 0.9, 40)
	await wait(0.5)
	hold(oto, STANCE[0], STANCE[1])
	face_expr(oto, "neutral")
	await wait(1.6)
	await Overlay.fade_to(Color.BLACK, 0.9)

func finish() -> void:
	skippable = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
