class_name Tuning
extends RefCounted
## The garage's tuning sliders (they unlock after story contract 3, as
## "Pip's Toolkit"). Every slider has a real downside: there's no "best"
## setting, only the best one for the job.
##
## id -> name, min, default, max, step, what it does.
const SLIDERS := {
	"stiffness": ["Suspension stiffness", 22.0, 35.0, 55.0, 1.0,
		"Stiff: flat and steady on hardpan, doesn't bottom out. But it bounces over bumps and throws cargo."],
	"ride_height": ["Ride height", 0.12, 0.18, 0.26, 0.01,
		"High: clears ridges and holes. But a higher centre of mass tips over in corners."],
	"pressure": ["Tyre pressure", 0.0, 0.5, 1.0, 0.05,
		"Hard tyres: fast and grippy on hardpan, but sink ~40% deeper in soft sand. Soft tyres float (40% less sinking) but grip less and lose ~12% top speed."],
	"gearing": ["Gearing", 0.75, 1.0, 1.35, 0.05,
		"Low gears (high number): pull out of holes and up dunes. But lower top speed, and the wheels spin and dig more easily."],
}


static func defaults() -> Dictionary:
	var d := {}
	for id in SLIDERS:
		d[id] = SLIDERS[id][2]
	return d


static func value(tuning: Dictionary, id: String) -> float:
	var s: Array = SLIDERS[id]
	return clampf(float(tuning.get(id, s[2])), s[1], s[3])


## Tyre pressure (0..1, default 0.5) -> (grip, sinking, drag) multipliers.
static func pressure_effects(p: float) -> Vector3:
	if p < 0.5:
		var t := p / 0.5            # 0 = softest, 1 = normal
		return Vector3(lerpf(1.9 / 2.2, 1.0, t), lerpf(0.6, 1.0, t), lerpf(1.3, 1.0, t))
	var u := (p - 0.5) / 0.5        # 0 = normal, 1 = hardest
	return Vector3(lerpf(1.0, 2.5 / 2.2, u), lerpf(1.0, 1.4, u), lerpf(1.0, 0.85, u))
