class_name TrickGestureRecognizer
extends RefCounted
## Analog-stick-style ("Flick-It") mouse gesture recognizer for skateboarding tricks.
##
## Translates relative mouse movement into a virtual stick position inside a unit circle
## (radius 1.0, +X right, -X left, +Y down, -Y up) and compares the drawn path against
## predetermined resampled polyline templates matching the 6 reference gestures:
##   - Kickflip             (Down -> sharp V flick Up-Right)
##   - Heelflip             (Down -> sharp V flick Up-Left)
##   - Backside Pop-shuvit  (Down -> smooth CCW scoop along bottom-right rim)
##   - Frontside Pop-shuvit (Down -> smooth CW scoop along bottom-left rim)
##   - 360 Flip             (Down-Left -> CCW bottom scoop -> diagonal flick Up-Right)
##   - Laserflip            (Down-Right -> CW bottom scoop -> diagonal flick Up-Left)

const RESAMPLE_COUNT: int = 24

## Mouse pixels needed to push the virtual stick from center (0,0) to the outer rim (1.0).
var sensitivity_px: float = 72.0
## Seconds of inactivity before the spring-loaded virtual stick gently returns to center.
var idle_return_delay: float = 0.28
var return_speed: float = 7.5
## Maximum rolling stroke age kept for gesture matching (supports pre-loading before Space!).
var max_stroke_age: float = 0.65
## Maximum average normalized point distance allowed to accept a template match.
var max_match_distance: float = 0.42

## Current virtual stick position inside the unit circle (length <= 1.0).
var stick_pos: Vector2 = Vector2.ZERO

var _idle_time: float = 0.0
var _stroke: Array[Dictionary] = []  # { "pos": Vector2, "t": float }
var _clock: float = 0.0
var _templates: Array[Dictionary] = []  # { "name": String, "points": PackedVector2Array }


func _init() -> void:
	_build_templates()


func tick(delta: float) -> void:
	_clock += delta
	_idle_time += delta
	_prune_old_points()

	if _idle_time >= idle_return_delay and stick_pos != Vector2.ZERO:
		stick_pos = stick_pos.move_toward(Vector2.ZERO, return_speed * delta)
		if stick_pos.length_squared() < 0.001:
			stick_pos = Vector2.ZERO
			_stroke.clear()


func feed_mouse_delta(relative: Vector2) -> void:
	_idle_time = 0.0
	if _stroke.is_empty():
		_stroke.append({ "pos": stick_pos, "t": _clock })

	stick_pos += relative / maxf(sensitivity_px, 10.0)
	if stick_pos.length() > 1.0:
		# Clamping to the circular rim lets scoops ride smoothly around the perimeter like a real stick gate!
		stick_pos = stick_pos.normalized()

	var last_pos: Vector2 = _stroke.back()["pos"]
	if stick_pos.distance_to(last_pos) >= 0.045:
		_stroke.append({ "pos": stick_pos, "t": _clock })
	_prune_old_points()


func clear_stroke(recenter: bool = false) -> void:
	_stroke.clear()
	if recenter:
		stick_pos = Vector2.ZERO


## True when the player is holding the virtual stick downward (crouch / pre-load pose).
func is_holding_down() -> bool:
	return stick_pos.y >= 0.48 and absf(stick_pos.x) <= 0.65


## Evaluates the current stroke for one of the 6 air trick gestures.
## Returns "" until a gesture reaches its upward/rim flick zone and matches a template.
func recognize_air_trick() -> String:
	if _stroke.size() < 5:
		return ""

	var raw := PackedVector2Array()
	for entry in _stroke:
		raw.append(entry["pos"])

	# 1. Must have pulled into the lower region of the circle first, then moved upward to flick/scoop!
	var peak_down_idx: int = -1
	var max_y: float = -INF
	for i in raw.size():
		if raw[i].y > max_y:
			max_y = raw[i].y
			peak_down_idx = i

	if max_y < 0.30 or peak_down_idx >= raw.size() - 2:
		return ""

	var last: Vector2 = raw[raw.size() - 1]
	var prev: Vector2 = raw[raw.size() - 2]
	var moving_up_or_rim: bool = (last.y - prev.y) <= 0.04

	# Flip completion zone (upper circle) OR Pop-shuvit completion zone (outer left/right rim above midline).
	var in_flip_exit: bool = last.y <= -0.22
	var in_shuv_exit: bool = last.y <= -0.02 and absf(last.x) >= 0.56
	if not moving_up_or_rim or (not in_flip_exit and not in_shuv_exit):
		return ""

	# Trim any wandering points long before the pull-down started (keep up to 8 points of lead-in).
	var start_idx: int = 0
	for i in range(peak_down_idx, -1, -1):
		if raw[i].length() <= 0.28:
			start_idx = i
			break
		start_idx = maxi(0, peak_down_idx - 10)

	var candidate := PackedVector2Array()
	for i in range(start_idx, raw.size()):
		candidate.append(raw[i])

	if _path_length(candidate) < 0.92:
		return ""

	# Extract geometric bounds & signed winding to reinforce mirror/scoop distinction.
	var min_x: float = INF
	var max_x: float = -INF
	for p in candidate:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
	var winding: float = _signed_turning(candidate)

	var norm_candidate := _normalize_shape(_resample(candidate, RESAMPLE_COUNT))

	var best_name: String = ""
	var best_dist: float = max_match_distance

	for tpl in _templates:
		var tname: String = tpl["name"]
		if not _passes_guard(tname, min_x, max_x, last, winding):
			continue
		var d: float = _path_distance(norm_candidate, tpl["points"])
		if d < best_dist:
			best_dist = d
			best_name = tname

	return best_name


## Evaluates virtual stick deflection while grinding a rail.
## Top-Right -> Boardslide, Right -> 5-0 Grind, Left -> Nosegrind (relative to `facing_dir`).
func recognize_grind_trick(facing_dir: float) -> String:
	if stick_pos.length() < 0.62:
		return ""
	var x: float = stick_pos.x * facing_dir
	var y: float = stick_pos.y
	if x > 0.32 and y < -0.32:
		return "Boardslide"
	if absf(x) >= absf(y) * 0.55:
		return "5-0 Grind" if x > 0.0 else "Nosegrind"
	return ""


## Returns the raw stroke points in [-1..1] circle coordinates (useful for flashing the matched gesture).
func get_stroke_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for entry in _stroke:
		pts.append(entry["pos"])
	return pts


# ---------------------------------------------------------------- templates & math

func _passes_guard(trick_name: String, min_x: float, max_x: float, last: Vector2, winding: float) -> bool:
	match trick_name:
		"Kickflip":
			return last.x > 0.06 and last.y < -0.18 and min_x > -0.42
		"Heelflip":
			return last.x < -0.06 and last.y < -0.18 and max_x < 0.42
		"Backside Pop-shuvit":
			return max_x > 0.45 and last.x > 0.36 and winding < -0.05
		"Frontside Pop-shuvit":
			return min_x < -0.45 and last.x < -0.36 and winding > 0.05
		"360 Flip":
			return min_x < -0.32 and last.x > 0.08 and last.y < -0.18
		"Laserflip":
			return max_x > 0.32 and last.x < -0.08 and last.y < -0.18
	return true


func _build_templates() -> void:
	_templates.clear()

	# 1. Kickflip: pull down, sharp V-turn up-right (narrow & wide variants).
	_add_template("Kickflip", [
		Vector2(0.0, -0.05), Vector2(-0.04, 0.40), Vector2(-0.06, 0.78),
		Vector2(0.18, 0.25), Vector2(0.40, -0.30), Vector2(0.58, -0.85),
	])
	_add_template("Kickflip", [
		Vector2(0.0, 0.15), Vector2(0.0, 0.72),
		Vector2(0.28, 0.10), Vector2(0.65, -0.78),
	])

	# 2. Heelflip: pull down, sharp V-turn up-left (narrow & wide variants).
	_add_template("Heelflip", [
		Vector2(0.0, -0.05), Vector2(0.04, 0.40), Vector2(0.06, 0.78),
		Vector2(-0.18, 0.25), Vector2(-0.40, -0.30), Vector2(-0.58, -0.85),
	])
	_add_template("Heelflip", [
		Vector2(0.0, 0.15), Vector2(0.0, 0.72),
		Vector2(-0.28, 0.10), Vector2(-0.65, -0.78),
	])

	# 3. Backside Pop-shuvit: pull down, smooth CCW scoop up the right rim.
	_add_template("Backside Pop-shuvit", [
		Vector2(0.0, 0.0), Vector2(-0.02, 0.45), Vector2(0.0, 0.88),
		Vector2(0.38, 0.86), Vector2(0.72, 0.66), Vector2(0.92, 0.32),
		Vector2(0.96, -0.08), Vector2(0.90, -0.38),
	])
	_add_template("Backside Pop-shuvit", [
		Vector2(0.0, 0.20), Vector2(0.05, 0.85), Vector2(0.55, 0.78),
		Vector2(0.88, 0.40), Vector2(0.92, -0.15),
	])

	# 4. Frontside Pop-shuvit: pull down, smooth CW scoop up the left rim.
	_add_template("Frontside Pop-shuvit", [
		Vector2(0.0, 0.0), Vector2(0.02, 0.45), Vector2(0.0, 0.88),
		Vector2(-0.38, 0.86), Vector2(-0.72, 0.66), Vector2(-0.92, 0.32),
		Vector2(-0.96, -0.08), Vector2(-0.90, -0.38),
	])
	_add_template("Frontside Pop-shuvit", [
		Vector2(0.0, 0.20), Vector2(-0.05, 0.85), Vector2(-0.55, 0.78),
		Vector2(-0.88, 0.40), Vector2(-0.92, -0.15),
	])

	# 5. 360 Flip: down-left to left rim -> CCW bottom scoop -> diagonal flick up-right!
	_add_template("360 Flip", [
		Vector2(-0.10, -0.02), Vector2(-0.52, 0.12), Vector2(-0.88, 0.26),
		Vector2(-0.82, 0.62), Vector2(-0.52, 0.86), Vector2(-0.14, 0.94),
		Vector2(0.12, 0.35), Vector2(0.36, -0.22), Vector2(0.58, -0.78),
	])
	_add_template("360 Flip", [
		Vector2(0.0, 0.0), Vector2(-0.65, 0.35), Vector2(-0.55, 0.78),
		Vector2(-0.10, 0.88), Vector2(0.25, 0.15), Vector2(0.55, -0.75),
	])

	# 6. Laserflip: down-right to right rim -> CW bottom scoop -> diagonal flick up-left!
	_add_template("Laserflip", [
		Vector2(0.10, -0.02), Vector2(0.52, 0.16), Vector2(0.86, 0.34),
		Vector2(0.74, 0.68), Vector2(0.40, 0.86), Vector2(-0.08, 0.90),
		Vector2(-0.24, 0.28), Vector2(-0.40, -0.26), Vector2(-0.54, -0.78),
	])
	_add_template("Laserflip", [
		Vector2(0.0, 0.0), Vector2(0.65, 0.38), Vector2(0.52, 0.78),
		Vector2(0.05, 0.88), Vector2(-0.25, 0.15), Vector2(-0.52, -0.75),
	])


func _add_template(trick_name: String, waypoints: Array) -> void:
	var poly := PackedVector2Array()
	for wp in waypoints:
		poly.append(wp as Vector2)
	var norm := _normalize_shape(_resample(poly, RESAMPLE_COUNT))
	_templates.append({ "name": trick_name, "points": norm })


func _prune_old_points() -> void:
	var cutoff: float = _clock - max_stroke_age
	while _stroke.size() > 1 and float(_stroke[0]["t"]) < cutoff:
		_stroke.remove_at(0)


static func _path_length(pts: PackedVector2Array) -> float:
	var d: float = 0.0
	for i in range(1, pts.size()):
		d += pts[i - 1].distance_to(pts[i])
	return d


static func _resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	if pts.is_empty():
		return PackedVector2Array()
	var total_len: float = _path_length(pts)
	if total_len <= 0.0001:
		var flat := PackedVector2Array()
		for _i in n:
			flat.append(pts[0])
		return flat

	var interval: float = total_len / float(n - 1)
	var out := PackedVector2Array()
	out.append(pts[0])

	var accum: float = 0.0
	var src := pts.duplicate()
	var i: int = 1
	while i < src.size() and out.size() < n:
		var seg: float = src[i - 1].distance_to(src[i])
		if accum + seg >= interval and seg > 0.00001:
			var t: float = (interval - accum) / seg
			var q: Vector2 = src[i - 1].lerp(src[i], t)
			out.append(q)
			src.insert(i, q)
			accum = 0.0
			i += 1
		else:
			accum += seg
			i += 1

	while out.size() < n:
		out.append(pts[pts.size() - 1])
	return out


## Translates centroid to origin and uniformly scales max bounding dimension to 1.0 (keeps orientation & aspect!).
static func _normalize_shape(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var centroid := Vector2.ZERO
	var min_v := Vector2(INF, INF)
	var max_v := Vector2(-INF, -INF)
	for p in pts:
		centroid += p
		min_v.x = minf(min_v.x, p.x)
		min_v.y = minf(min_v.y, p.y)
		max_v.x = maxf(max_v.x, p.x)
		max_v.y = maxf(max_v.y, p.y)
	centroid /= float(pts.size())
	var span: float = maxf(maxf(max_v.x - min_v.x, max_v.y - min_v.y), 0.001)

	var out := PackedVector2Array()
	for p in pts:
		out.append((p - centroid) / span)
	return out


static func _path_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var n: int = mini(a.size(), b.size())
	if n == 0:
		return INF
	var sum: float = 0.0
	for i in n:
		sum += a[i].distance_to(b[i])
	return sum / float(n)


## Signed shoelace/cross sum relative to centroid (+ = clockwise in Y-down screen coords, - = counter-clockwise).
static func _signed_turning(pts: PackedVector2Array) -> float:
	if pts.size() < 3:
		return 0.0
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var area2: float = 0.0
	for i in range(1, pts.size()):
		var u: Vector2 = pts[i - 1] - c
		var v: Vector2 = pts[i] - c
		area2 += u.x * v.y - u.y * v.x
	return area2
