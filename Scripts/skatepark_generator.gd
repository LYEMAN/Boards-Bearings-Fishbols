class_name SkateparkGenerator
extends RefCounted
## Procedurally generates a fresh multi-level street skatepark layout per day.
##
## Features:
##   - High verticality: long elevated promenades (1,400-2,300px) and stacked 2-tier overpasses
##     that climb up via long stair sets, extend across multiple upper-level obstacle lines, and
##     descend via fast handrails and grand stairs (skateable in both directions!).
##   - Environmental variety: traffic cones, street curbs, funboxes, fire hydrants, road barriers,
##     park benches, stacked wooden pallets, corrugated trash cans, wooden crates, and rails.
##   - Tight side-by-side obstacle packs (5-6 cones, 4-6 curbs, double trash cans, stepped crates)
##     paired with ~190-255px combo-flow spaces and ~330-480px inter-cluster push gaps.

enum ClusterKind {
	CONE_AND_BARRIER_ZONE,
	RAIL_CHAIN,
	PARK_BENCH_PLAZA,
	WAREHOUSE_PALLETS_CRATES,
	CURB_AND_TRASH_ALLEY,
	CONE_OR_BOX_TO_RAIL,
	STAIR_PLAZA,
	LONG_UPPER_PROMENADE,
	TWO_TIER_OVERPASS,
	STREET_GAUNTLET,
}

const RAIL_PALETTE := [
	Color("d9e2ec"),
	Color("ffd166"),
	Color("8ecae6"),
	Color("ff9f1c"),
	Color("a8dadc"),
]

const TERRACE_CONCRETE := [
	Color("8c939a"),
	Color("7f8891"),
	Color("958f88"),
]


static func generate(
	stairs_parent: Node2D,
	rails_parent: Node2D,
	obstacles_parent: Node2D,
	ground_y: float = 93.0,
	clusters_per_side: int = 14,
	start_clear: float = 350.0,
	gap_range: Vector2 = Vector2(330.0, 480.0),
	rng: RandomNumberGenerator = null
) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	for parent in [stairs_parent, rails_parent, obstacles_parent]:
		if parent:
			for child in parent.get_children():
				parent.remove_child(child)
				child.queue_free()

	var layout := {
		"stairs_parent": stairs_parent,
		"rails_parent": rails_parent,
		"obstacles_parent": obstacles_parent,
		"ground_y": ground_y,
		"rng": rng,
		# Array of { "x1": float, "x2": float } where surfaces are blocked by obstacles or stair slopes.
		"blocked": [],
		# Array of { "x1": float, "x2": float, "y": float } for flat elevated stair decks.
		"decks": [],
	}

	var right_edge: float = start_clear
	var right_bag: Array[int] = []
	var prev_right: int = -1
	for i in clusters_per_side:
		var kind: int = _draw_archetype(right_bag, prev_right, rng)
		prev_right = kind
		right_edge = _build_cluster(layout, kind, right_edge, 1)
		if i < clusters_per_side - 1:
			right_edge += rng.randf_range(gap_range.x, gap_range.y)

	var left_edge: float = -start_clear
	var left_bag: Array[int] = []
	var prev_left: int = -1
	for i in clusters_per_side:
		var kind: int = _draw_archetype(left_bag, prev_left, rng)
		prev_left = kind
		left_edge = _build_cluster(layout, kind, left_edge, -1)
		if i < clusters_per_side - 1:
			left_edge -= rng.randf_range(gap_range.x, gap_range.y)

	var half_width: float = ceilf(maxf(right_edge, -left_edge) / 100.0) * 100.0 + 550.0
	layout["half_width"] = half_width
	return layout


## Evaluates whether `local_x` is a clean, flat walkable spot (ground or topmost stair deck) for an NPC.
## Returns NAN if blocked by an obstacle or stair slope.
static func get_flat_surface_y(layout: Dictionary, local_x: float, margin: float = 24.0) -> float:
	if layout.is_empty():
		return 93.0
	for b in layout["blocked"]:
		if local_x + margin >= b["x1"] and local_x - margin <= b["x2"]:
			return NAN
	var best_y: float = layout["ground_y"]
	for d in layout["decks"]:
		if local_x - margin >= d["x1"] and local_x + margin <= d["x2"]:
			best_y = minf(best_y, d["y"])
	return best_y


static func _draw_archetype(bag: Array[int], prev: int, rng: RandomNumberGenerator) -> int:
	if bag.is_empty():
		for k in ClusterKind.values():
			bag.append(int(k))
		# Add one extra LONG_UPPER_PROMENADE ticket per bag so long vertical sections appear often!
		bag.append(int(ClusterKind.LONG_UPPER_PROMENADE))
		for i in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: int = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		if bag.size() > 1 and bag.back() == prev:
			var first_val: int = bag[0]
			bag[0] = bag[bag.size() - 1]
			bag[bag.size() - 1] = first_val
	return bag.pop_back()


# ---------------------------------------------------------------- cluster builders

static func _build_cluster(layout: Dictionary, kind: int, edge: float, dir: int) -> float:
	var rng: RandomNumberGenerator = layout["rng"]
	var g: float = layout["ground_y"]
	var cursor: float = 0.0

	match kind:
		ClusterKind.CONE_AND_BARRIER_ZONE:
			# Roadwork zone: packed row of 5-6 cones (or 1 solo cone) -> flow space -> road barrier + rail!
			var big_first: bool = rng.randf() < 0.7
			var count1: int = rng.randi_range(5, 6) if big_first else 1
			cursor += _place_cone_pack(layout, edge, dir, cursor, g, count1, rng.randf_range(26.0, 32.0))
			cursor += rng.randf_range(195.0, 245.0)

			# Road barrier tucked in front of a steel rail, or solo barrier + contrasting cone pack.
			var bar_w: float = rng.randf_range(54.0, 68.0)
			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.BARRIER, bar_w, rng.randf_range(54.0, 72.0))
			cursor += bar_w

			if rng.randf() < 0.75:
				cursor += rng.randf_range(28.0, 55.0)
				var rlen: float = rng.randf_range(210.0, 300.0)
				_place_rail(layout, edge, dir, cursor, g, rlen, rng.randf_range(56.0, 74.0))
				cursor += rlen
			else:
				cursor += rng.randf_range(195.0, 245.0)
				var count2: int = 1 if big_first else rng.randi_range(5, 6)
				cursor += _place_cone_pack(layout, edge, dir, cursor, g, count2, 30.0)

		ClusterKind.RAIL_CHAIN:
			# Optional pallet stack or cone right at the start, then 2-3 close fast rails.
			if rng.randf() < 0.7:
				if rng.randf() < 0.5:
					cursor += _place_cone_pack(layout, edge, dir, cursor, g, 1, 30.0)
				else:
					_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.WOODEN_PALLET, 78.0, 30.0)
					cursor += 78.0
				cursor += rng.randf_range(18.0, 40.0)

			var count: int = rng.randi_range(2, 3)
			var pattern: int = rng.randi_range(0, 2)
			for i in count:
				var rlen: float = rng.randf_range(180.0, 280.0)
				var rh: float = 42.0
				match pattern:
					0: rh = 38.0 + i * rng.randf_range(16.0, 22.0)
					1: rh = 76.0 - i * rng.randf_range(15.0, 20.0)
					_: rh = 40.0 if i % 2 == 0 else 68.0
				_place_rail(layout, edge, dir, cursor, g, rlen, rh)
				cursor += rlen
				if i < count - 1:
					cursor += rng.randf_range(85.0, 135.0)

		ClusterKind.PARK_BENCH_PLAZA:
			# Park bench + trash can(s) + high rail + second park bench!
			var bench_w: float = rng.randf_range(100.0, 124.0)
			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.PARK_BENCH, bench_w, rng.randf_range(38.0, 44.0))
			cursor += bench_w

			# Trash can sitting right beside the park bench (like a real park!) or spaced out.
			if rng.randf() < 0.65:
				cursor += 6.0
				_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.TRASH_CAN, 36.0, 50.0)
				cursor += 36.0

			cursor += rng.randf_range(195.0, 250.0)

			var rlen: float = rng.randf_range(210.0, 300.0)
			_place_rail(layout, edge, dir, cursor, g, rlen, rng.randf_range(48.0, 64.0))
			cursor += rlen + rng.randf_range(190.0, 240.0)

			var bench_w2: float = rng.randf_range(96.0, 118.0)
			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.PARK_BENCH, bench_w2, 40.0)
			cursor += bench_w2

		ClusterKind.WAREHOUSE_PALLETS_CRATES:
			# Stacked wooden pallets -> stepped wooden crates -> fast rail -> crate/cone finish!
			var pw: float = rng.randf_range(78.0, 96.0)
			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.WOODEN_PALLET, pw, rng.randf_range(18.0, 34.0))
			cursor += pw + rng.randf_range(185.0, 235.0)

			# Stepped side-by-side wooden crates right before a rail!
			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.WOODEN_CRATE, 50.0, 40.0)
			cursor += 49.0
			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.WOODEN_CRATE, 54.0, 60.0)
			cursor += 54.0 + rng.randf_range(24.0, 48.0)

			var rlen: float = rng.randf_range(220.0, 320.0)
			_place_rail(layout, edge, dir, cursor, g, rlen, rng.randf_range(62.0, 78.0))
			cursor += rlen + rng.randf_range(195.0, 245.0)

			# Triple-stacked pallet pad or solo crate at the end.
			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.WOODEN_PALLET, 86.0, 46.0)
			cursor += 86.0

		ClusterKind.CURB_AND_TRASH_ALLEY:
			# 4-6 touching street curbs -> flow space -> 2-3 side-by-side trash cans -> rail!
			cursor += _place_curb_pack(layout, edge, dir, cursor, g, rng.randi_range(4, 6), rng.randf_range(44.0, 52.0), rng.randf_range(22.0, 28.0))
			cursor += rng.randf_range(200.0, 255.0)

			var cans: int = rng.randi_range(1, 3)
			cursor += _place_trash_can_pack(layout, edge, dir, cursor, g, cans, rng.randf_range(48.0, 58.0))
			cursor += rng.randf_range(26.0, 52.0)

			var rlen: float = rng.randf_range(200.0, 290.0)
			_place_rail(layout, edge, dir, cursor, g, rlen, rng.randf_range(50.0, 66.0))
			cursor += rlen

		ClusterKind.CONE_OR_BOX_TO_RAIL:
			# Classic launch into rail, then 5-6 cone gap or crate + bench.
			if rng.randf() < 0.5:
				cursor += _place_cone_pack(layout, edge, dir, cursor, g, rng.randi_range(1, 3), 30.0)
			else:
				_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.BOX, 72.0, 38.0)
				cursor += 72.0
			cursor += rng.randf_range(18.0, 42.0)

			var rlen: float = rng.randf_range(230.0, 330.0)
			_place_rail(layout, edge, dir, cursor, g, rlen, rng.randf_range(50.0, 70.0))
			cursor += rlen + rng.randf_range(195.0, 250.0)

			cursor += _place_cone_pack(layout, edge, dir, cursor, g, rng.randi_range(5, 6), 30.0)

		ClusterKind.STAIR_PLAZA:
			# Medium elevated plaza (500-800px deck) with benches/crates/rails on top & sloped handrail.
			var steps: int = [4, 5, 6][rng.randi_range(0, 2)]
			var depth: float = 32.0
			var sh: float = float(steps) * rng.randf_range(14.0, 15.5)
			var deck: float = rng.randf_range(520.0, 820.0)
			cursor += _build_elevated_terrace(
				layout, edge, dir, cursor, g,
				sh, deck, steps, steps, depth,
				rng.randf() < 0.5, true, 1
			)

		ClusterKind.LONG_UPPER_PROMENADE:
			# Stairs climb HIGH (6-9 steps, 90-140px) and extend for a LONG elevated street (1,500-2,350px)
			# packed with upper-deck benches, crates, pallets, barriers, cones & rails!
			var entry_steps: int = rng.randi_range(6, 9)
			var exit_steps: int = rng.randi_range(6, 9)
			var depth: float = 33.0
			var sh: float = float(entry_steps) * rng.randf_range(14.5, 16.0)
			var deck: float = rng.randf_range(1500.0, 2350.0)
			cursor += _build_elevated_terrace(
				layout, edge, dir, cursor, g,
				sh, deck, entry_steps, exit_steps, depth,
				true, true, rng.randi_range(3, 4)
			)

		ClusterKind.TWO_TIER_OVERPASS:
			# Massive 2-story verticality!
			# Climb Tier 1 stairs -> skate Tier 1 street props -> climb Tier 2 stairs EVEN HIGHER
			# -> skate high-altitude Tier 2 deck -> handrail down to Tier 1 -> handrail down to street!
			cursor += _build_two_tier_overpass(layout, edge, dir, cursor, g)

		ClusterKind.STREET_GAUNTLET:
			# 5-6 touching cones -> Hydrant + Rail -> Wooden Crate + Road Barrier!
			cursor += _place_cone_pack(layout, edge, dir, cursor, g, rng.randi_range(5, 6), 29.0)
			cursor += rng.randf_range(200.0, 250.0)

			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.HYDRANT, 30.0, 52.0)
			cursor += 30.0 + rng.randf_range(28.0, 54.0)

			var rlen: float = rng.randf_range(220.0, 310.0)
			_place_rail(layout, edge, dir, cursor, g, rlen, rng.randf_range(54.0, 70.0))
			cursor += rlen + rng.randf_range(195.0, 245.0)

			_place_obs(layout, edge, dir, cursor, g, SkateObstacle.Kind.BARRIER, 60.0, rng.randf_range(62.0, 78.0))
			cursor += 60.0

	return edge + cursor * float(dir)


# ---------------------------------------------------------------- verticality builders

## Builds an elevated stair terrace (short plaza or 2,300px-long upper promenade) and populates
## `deck_subclusters` obstacle mini-lines across its flat upper deck. Returns total footprint width.
static func _build_elevated_terrace(
	layout: Dictionary, edge: float, dir: int, offset: float, base_y: float,
	height: float, deck_length: float, entry_steps: int, exit_steps: int, step_depth: float,
	entry_handrail: bool, exit_handrail: bool, deck_subclusters: int
) -> float:
	var rng: RandomNumberGenerator = layout["rng"]
	var stairs_parent: Node2D = layout["stairs_parent"]
	var left_steps: int = entry_steps if dir > 0 else exit_steps
	var right_steps: int = exit_steps if dir > 0 else entry_steps
	var left_run: float = float(left_steps) * step_depth
	var right_run: float = float(right_steps) * step_depth
	var total_w: float = left_run + deck_length + right_run
	var lx: float = _left_x(edge, dir, offset, total_w)

	if stairs_parent:
		var stairs := StairSet.new()
		stairs.height = height
		stairs.deck_length = deck_length
		stairs.left_steps = left_steps
		stairs.right_steps = right_steps
		stairs.step_depth = step_depth
		stairs.concrete_color = TERRACE_CONCRETE[rng.randi_range(0, TERRACE_CONCRETE.size() - 1)]
		stairs.position = Vector2(lx, base_y)
		stairs_parent.add_child(stairs)

	var deck_left: float = lx + left_run
	var deck_right: float = deck_left + deck_length
	var deck_y: float = base_y - height

	layout["blocked"].append({ "x1": lx - 12.0, "x2": deck_left + 10.0 })
	layout["blocked"].append({ "x1": deck_right - 10.0, "x2": lx + total_w + 12.0 })
	layout["decks"].append({ "x1": deck_left + 14.0, "x2": deck_right - 14.0, "y": deck_y })

	# Sloped handrails on left and/or right stair flights.
	var want_left_rail: bool = entry_handrail if dir > 0 else exit_handrail
	var want_right_rail: bool = exit_handrail if dir > 0 else entry_handrail
	if want_left_rail and left_steps > 0 and layout["rails_parent"]:
		var lrail := GrindRail.new()
		lrail.length = left_run
		lrail.height = 42.0
		lrail.end_y_offset = -height
		lrail.right_base_y = -height
		lrail.rail_color = Color("8ecae6")
		lrail.position = Vector2(lx, base_y)
		layout["rails_parent"].add_child(lrail)

	if want_right_rail and right_steps > 0 and layout["rails_parent"]:
		var rrail := GrindRail.new()
		rrail.length = right_run
		rrail.height = 42.0
		rrail.end_y_offset = height
		rrail.right_base_y = height
		rrail.rail_color = Color("8ecae6")
		rrail.position = Vector2(deck_right, deck_y)
		layout["rails_parent"].add_child(rrail)

	# Populate obstacles & rails across the elevated deck!
	var deck_near_edge: float = deck_left if dir > 0 else deck_right
	_populate_deck_features(layout, deck_near_edge, dir, deck_length, deck_y, deck_subclusters)

	return total_w


## Builds a 2-story stacked overpass: Tier 1 long promenade with a Tier 2 elevated plaza on top!
static func _build_two_tier_overpass(
	layout: Dictionary, edge: float, dir: int, offset: float, ground_y: float
) -> float:
	var rng: RandomNumberGenerator = layout["rng"]
	var s1: int = rng.randi_range(5, 7)
	var depth1: float = 33.0
	var h1: float = float(s1) * rng.randf_range(14.5, 15.5)

	var lead_deck_len: float = rng.randf_range(520.0, 680.0)
	var tail_deck_len: float = rng.randf_range(460.0, 620.0)

	var s2: int = rng.randi_range(5, 7)
	var depth2: float = 32.0
	var h2: float = float(s2) * rng.randf_range(14.0, 15.5)
	var deck2_len: float = rng.randf_range(760.0, 1150.0)
	var tier2_total_w: float = 2.0 * float(s2) * depth2 + deck2_len

	var deck1_len: float = lead_deck_len + tier2_total_w + tail_deck_len
	var run1: float = float(s1) * depth1
	var total_w: float = 2.0 * run1 + deck1_len
	var lx1: float = _left_x(edge, dir, offset, total_w)

	if layout["stairs_parent"]:
		var stairs1 := StairSet.new()
		stairs1.height = h1
		stairs1.deck_length = deck1_len
		stairs1.left_steps = s1
		stairs1.right_steps = s1
		stairs1.step_depth = depth1
		stairs1.concrete_color = Color("7f8891")
		stairs1.position = Vector2(lx1, ground_y)
		layout["stairs_parent"].add_child(stairs1)

	var deck1_left: float = lx1 + run1
	var deck1_right: float = deck1_left + deck1_len
	var deck1_y: float = ground_y - h1

	layout["blocked"].append({ "x1": lx1 - 12.0, "x2": deck1_left + 10.0 })
	layout["blocked"].append({ "x1": deck1_right - 10.0, "x2": lx1 + total_w + 12.0 })
	layout["decks"].append({ "x1": deck1_left + 14.0, "x2": deck1_right - 14.0, "y": deck1_y })

	# Handrails on both ends of Tier 1.
	if layout["rails_parent"]:
		var lr := GrindRail.new()
		lr.length = run1
		lr.height = 42.0
		lr.end_y_offset = -h1
		lr.right_base_y = -h1
		lr.rail_color = Color("ffd166")
		lr.position = Vector2(lx1, ground_y)
		layout["rails_parent"].add_child(lr)

		var rr := GrindRail.new()
		rr.length = run1
		rr.height = 42.0
		rr.end_y_offset = h1
		rr.right_base_y = h1
		rr.rail_color = Color("ffd166")
		rr.position = Vector2(deck1_right, deck1_y)
		layout["rails_parent"].add_child(rr)

	var deck1_near: float = deck1_left if dir > 0 else deck1_right

	# Populate Tier 1 lead-in section before Tier 2 stairs.
	_populate_deck_features(layout, deck1_near, dir, lead_deck_len - 40.0, deck1_y, 1)

	# Build Tier 2 stairs + high deck right on top of Tier 1!
	_build_elevated_terrace(
		layout, deck1_near, dir, lead_deck_len, deck1_y,
		h2, deck2_len, s2, s2, depth2,
		true, true, 2
	)

	# Populate Tier 1 run-out section after Tier 2 stairs.
	var tail_start_edge: float = deck1_near + (lead_deck_len + tier2_total_w + 35.0) * float(dir)
	_populate_deck_features(layout, tail_start_edge, dir, tail_deck_len - 50.0, deck1_y, 1)

	return total_w


## Places `count` nicely spaced mini-features along an elevated flat deck.
static func _populate_deck_features(
	layout: Dictionary, deck_near_edge: float, dir: int, deck_length: float, deck_y: float, count: int
) -> void:
	if count <= 0 or deck_length < 220.0:
		return
	var rng: RandomNumberGenerator = layout["rng"]
	var cursor: float = rng.randf_range(65.0, 105.0)
	var max_cursor: float = deck_length - 85.0

	for i in count:
		if cursor >= max_cursor - 90.0:
			break
		var remaining: float = max_cursor - cursor
		var roll: int = rng.randi_range(0, 5)

		match roll:
			0:
				# Park bench + optional close rail!
				var bw: float = minf(108.0, remaining)
				_place_obs(layout, deck_near_edge, dir, cursor, deck_y, SkateObstacle.Kind.PARK_BENCH, bw, 40.0)
				cursor += bw
				if remaining - bw > 220.0 and rng.randf() < 0.6:
					cursor += 28.0
					var rlen: float = minf(180.0, max_cursor - cursor)
					_place_rail(layout, deck_near_edge, dir, cursor, deck_y, rlen, 54.0)
					cursor += rlen
			1:
				# Wooden pallet stack into a grind rail.
				var pw: float = minf(80.0, remaining)
				_place_obs(layout, deck_near_edge, dir, cursor, deck_y, SkateObstacle.Kind.WOODEN_PALLET, pw, rng.randf_range(20.0, 34.0))
				cursor += pw
				if max_cursor - cursor > 180.0:
					cursor += 24.0
					var rlen: float = minf(190.0, max_cursor - cursor)
					_place_rail(layout, deck_near_edge, dir, cursor, deck_y, rlen, 50.0)
					cursor += rlen
			2:
				# Packed row of 4-5 cones on the upper deck!
				var cones: int = clampi(int(remaining / 28.0), 1, rng.randi_range(4, 5))
				cursor += _place_cone_pack(layout, deck_near_edge, dir, cursor, deck_y, cones, 29.0)
			3:
				# Wooden crate (or stepped pair of crates).
				_place_obs(layout, deck_near_edge, dir, cursor, deck_y, SkateObstacle.Kind.WOODEN_CRATE, 50.0, 44.0)
				cursor += 50.0
				if max_cursor - cursor > 70.0 and rng.randf() < 0.55:
					_place_obs(layout, deck_near_edge, dir, cursor - 1.0, deck_y, SkateObstacle.Kind.WOODEN_CRATE, 52.0, 62.0)
					cursor += 51.0
			4:
				# Trash can(s) + rail.
				var cans: int = 2 if remaining > 260.0 and rng.randf() < 0.5 else 1
				cursor += _place_trash_can_pack(layout, deck_near_edge, dir, cursor, deck_y, cans, 50.0)
				if max_cursor - cursor > 180.0:
					cursor += 30.0
					var rlen: float = minf(175.0, max_cursor - cursor)
					_place_rail(layout, deck_near_edge, dir, cursor, deck_y, rlen, 56.0)
					cursor += rlen
			_:
				# Elevated rail or road barrier.
				if remaining >= 170.0:
					var rlen: float = minf(rng.randf_range(160.0, 240.0), remaining)
					_place_rail(layout, deck_near_edge, dir, cursor, deck_y, rlen, rng.randf_range(42.0, 60.0))
					cursor += rlen
				else:
					_place_obs(layout, deck_near_edge, dir, cursor, deck_y, SkateObstacle.Kind.BARRIER, 56.0, 58.0)
					cursor += 56.0

		cursor += rng.randf_range(200.0, 265.0)


# ---------------------------------------------------------------- node placement helpers

static func _left_x(edge: float, dir: int, offset: float, width: float) -> float:
	return edge + offset if dir > 0 else edge - offset - width


static func _place_cone_pack(
	layout: Dictionary, edge: float, dir: int, offset: float, surface_y: float,
	count: int, height: float, cone_width: float = 24.0
) -> float:
	for i in count:
		_place_obs(layout, edge, dir, offset + float(i) * cone_width, surface_y, SkateObstacle.Kind.CONE, cone_width, height)
	return float(count) * cone_width


static func _place_curb_pack(
	layout: Dictionary, edge: float, dir: int, offset: float, surface_y: float,
	count: int, seg_width: float = 48.0, height: float = 26.0
) -> float:
	var step: float = seg_width - 1.0
	for i in count:
		_place_obs(layout, edge, dir, offset + float(i) * step, surface_y, SkateObstacle.Kind.CURB, seg_width, height)
	return float(maxi(count - 1, 0)) * step + seg_width


static func _place_trash_can_pack(
	layout: Dictionary, edge: float, dir: int, offset: float, surface_y: float,
	count: int, height: float = 52.0, can_width: float = 36.0
) -> float:
	for i in count:
		_place_obs(layout, edge, dir, offset + float(i) * can_width, surface_y, SkateObstacle.Kind.TRASH_CAN, can_width, height)
	return float(count) * can_width


static func _place_obs(
	layout: Dictionary, edge: float, dir: int, offset: float, surface_y: float,
	kind: SkateObstacle.Kind, width: float, height: float
) -> void:
	var parent: Node2D = layout["obstacles_parent"]
	if parent == null:
		return
	var lx: float = _left_x(edge, dir, offset, width)
	var obs := SkateObstacle.new()
	obs.kind = kind
	obs.width = width
	obs.height = height
	obs.position = Vector2(lx + width * 0.5, surface_y)
	parent.add_child(obs)
	layout["blocked"].append({ "x1": lx - 14.0, "x2": lx + width + 14.0 })


static func _place_rail(
	layout: Dictionary, edge: float, dir: int, offset: float, surface_y: float,
	length: float, height: float, end_y_offset: float = 0.0, right_base_y: float = 0.0
) -> void:
	var parent: Node2D = layout["rails_parent"]
	if parent == null:
		return
	var rng: RandomNumberGenerator = layout["rng"]
	var lx: float = _left_x(edge, dir, offset, length)
	var rail := GrindRail.new()
	rail.length = length
	rail.height = height
	rail.end_y_offset = end_y_offset
	rail.right_base_y = right_base_y
	rail.rail_color = RAIL_PALETTE[rng.randi_range(0, RAIL_PALETTE.size() - 1)]
	rail.position = Vector2(lx, surface_y)
	parent.add_child(rail)
