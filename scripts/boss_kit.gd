class_name BossKit
extends RefCounted
## Shared boss rules (the patterns in docs/MECHANICS_REFERENCE.md, Bosses). A boss owns one,
## sets what it needs, and routes its hurt() and contact hits through it:
##   thresholds        HP fractions, high to low, that each fire `phase` once
##   heal_on_phase     heal to this share of max HP when a phase fires (0 = no heal)
##   absorbs_ki        ki shots heal instead of hurting (forces melee)
##   drain_on_contact  share of the boss's contact damage it heals (forces range)
## Interruptible wind-ups stay in the boss's own state machine: a launching hit (heavy
## strike, charged orb) during the wind-up should knock it out (see Enemy and LifeSaiyan).

signal phase(index: int, fraction: float)

var boss: Node3D
var thresholds: Array = []
var heal_on_phase := 0.0
var absorbs_ki := false
var drain_on_contact := 0.0
var _next := 0

func _init(owner_boss: Node3D, phase_at: Array = []) -> void:
	boss = owner_boss
	thresholds = phase_at

## The damage to apply for a hit (negative heals). Call at the top of the boss's hurt().
func incoming(amount: float, kind: String) -> float:
	if absorbs_ki and kind == "ki":
		DamageNumber.word(boss.get_parent(), boss.position, "Absorbed", DamageNumber.HEAL)
		return -amount
	return amount

## HP the boss regains after dealing `dealt` damage by touch.
func contact_heal(dealt: float) -> float:
	return dealt * drain_on_contact

## Call after every HP change. Fires each threshold that HP has fallen to, once and in
## order, and returns the boss's HP after any phase heal.
func check(hp: float, max_hp: float) -> float:
	while _next < thresholds.size() and hp <= max_hp * float(thresholds[_next]):
		var i := _next
		_next += 1
		if heal_on_phase > 0.0:
			hp = maxf(hp, max_hp * heal_on_phase)
		phase.emit(i, float(thresholds[i]))
	return hp

## Marks the first `count` thresholds as already fired (developer skips, reloads).
func skip_to(count: int) -> void:
	_next = maxi(_next, count)

func next_index() -> int:
	return _next
