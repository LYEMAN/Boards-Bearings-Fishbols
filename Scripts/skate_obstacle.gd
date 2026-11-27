@tool
class_name SkateObstacle
extends StaticBody2D
## A street/skatepark obstacle of configurable height and style to ollie over or onto.
## Origin = bottom-center (ground level).

enum Kind {
	CONE,
	CURB,
	BOX,
	HYDRANT,
	BARRIER,
	PARK_BENCH,
	WOODEN_PALLET,
	TRASH_CAN,
	WOODEN_CRATE,
}

@export var kind: Kind = Kind.BOX:
	set(value):
		kind = value
		_rebuild()

@export var width: float = 64.0:
	set(value):
		width = maxf(value, 16.0)
		_rebuild()

@export var height: float = 48.0:
	set(value):
		height = maxf(value, 14.0)
		_rebuild()

@export var primary_color: Color = Color("e07a5f"):
	set(value):
		primary_color = value
		queue_redraw()

var _collider: CollisionShape2D


func _ready() -> void:
	z_index = -1
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _collider == null:
		_collider = get_node_or_null("ObstacleCollider") as CollisionShape2D
		if _collider == null:
			_collider = CollisionShape2D.new()
			_collider.name = "ObstacleCollider"
			add_child(_collider)

	var shape := RectangleShape2D.new()
	# Upright cylindrical street props are slightly narrower than their visual silhouette.
	var col_w: float = width * 0.7 if kind in [Kind.CONE, Kind.HYDRANT, Kind.TRASH_CAN] else width
	shape.size = Vector2(col_w, height)
	_collider.shape = shape
	_collider.position = Vector2(0.0, -height * 0.5)
	queue_redraw()


func _draw() -> void:
	var hw: float = width * 0.5
	match kind:
		Kind.CONE:
			draw_rect(Rect2(-hw, -5.0, width, 5.0), Color("d9531e"))
			var body := PackedVector2Array([
				Vector2(-hw * 0.8, -5.0),
				Vector2(hw * 0.8, -5.0),
				Vector2(hw * 0.2, -height),
				Vector2(-hw * 0.2, -height),
			])
			draw_colored_polygon(body, Color("ff6b1a"))
			var y1: float = -height * 0.42
			var y2: float = -height * 0.65
			var w1: float = lerpf(hw * 0.8, hw * 0.2, 0.42)
			var w2: float = lerpf(hw * 0.8, hw * 0.2, 0.65)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w1, y1), Vector2(w1, y1), Vector2(w2, y2), Vector2(-w2, y2)
			]), Color.WHITE)

		Kind.CURB:
			draw_rect(Rect2(-hw, -height, width, height), Color("b8bec4"))
			var stripes: int = maxi(2, int(width / 22.0))
			var sw: float = width / float(stripes)
			for i in stripes:
				var c := Color("d62828") if i % 2 == 0 else Color("f1faee")
				draw_rect(Rect2(-hw + i * sw, -height, sw, minf(8.0, height * 0.4)), c)
			draw_rect(Rect2(-hw, -height, width, height), Color("495057"), false, 2.0)

		Kind.BOX:
			draw_rect(Rect2(-hw, -height, width, height), Color("7d8590"))
			draw_rect(Rect2(-hw, -height, width, 7.0), Color("cfd6dc"))
			draw_line(Vector2(-hw, -height), Vector2(hw, -height), Color("eef4f8"), 3.0)
			draw_rect(Rect2(-hw, -height, width, height), Color("3c424a"), false, 2.0)

		Kind.HYDRANT:
			var body_w: float = width * 0.55
			draw_rect(Rect2(-hw * 0.7, -6.0, width * 0.7, 6.0), Color("a4161a"))
			draw_rect(Rect2(-body_w * 0.5, -height * 0.82, body_w, height * 0.82 - 6.0), Color("e5383b"))
			draw_rect(Rect2(-hw * 0.85, -height * 0.65, width * 0.85, height * 0.16), Color("ba181b"))
			draw_circle(Vector2(0.0, -height * 0.82), body_w * 0.55, Color("e5383b"))
			draw_rect(Rect2(-3.0, -height, 6.0, height * 0.12), Color("a4161a"))

		Kind.BARRIER:
			# Street road barrier: heavy rubber feet, steel A-frame legs, reflective orange/white rails & beacon.
			draw_rect(Rect2(-hw * 0.9, -5.0, width * 0.32, 5.0), Color("2b2d42"))
			draw_rect(Rect2(hw * 0.58, -5.0, width * 0.32, 5.0), Color("2b2d42"))
			draw_line(Vector2(-hw * 0.74, -5.0), Vector2(-hw * 0.68, -height + 8.0), Color("495057"), 5.0)
			draw_line(Vector2(hw * 0.74, -5.0), Vector2(hw * 0.68, -height + 8.0), Color("495057"), 5.0)

			var board_h: float = clampf(height * 0.32, 14.0, 22.0)
			var top_board := Rect2(-hw, -height + 6.0, width, board_h)
			draw_rect(top_board, Color("ff6b1a"))
			var stripes: int = maxi(4, int(width / 14.0))
			var sw: float = width / float(stripes)
			for i in range(0, stripes, 2):
				draw_rect(Rect2(-hw + i * sw, top_board.position.y, sw, board_h), Color("f8f9fa"))
			draw_rect(top_board, Color("2b2d42"), false, 2.0)

			# Lower secondary rail on taller road barriers.
			if height >= 56.0:
				var low_board := Rect2(-hw * 0.94, -height * 0.46, width * 0.94, board_h * 0.72)
				draw_rect(low_board, Color("ff6b1a"))
				for i in range(1, stripes, 2):
					var sx: float = clampf(-hw + i * sw, low_board.position.x, low_board.end.x - sw * 0.8)
					draw_rect(Rect2(sx, low_board.position.y, sw * 0.8, low_board.size.y), Color("f8f9fa"))
				draw_rect(low_board, Color("2b2d42"), false, 1.5)

			# Amber road hazard lamps on top.
			draw_circle(Vector2(-hw * 0.68, -height + 3.0), 4.0, Color("ffbe0b"))
			draw_circle(Vector2(hw * 0.68, -height + 3.0), 4.0, Color("ffbe0b"))

		Kind.PARK_BENCH:
			# Wrought-iron legs, backrest posts & armrests + warm wooden seat & backrest slats.
			var iron := Color("2b303a")
			var wood := Color("b5763a")
			var wood_light := Color("d49456")
			var wood_dark := Color("7f4f24")
			var seat_y: float = -height * 0.48

			# Backrest vertical iron posts & ground legs.
			for ratio in [-0.82, 0.0, 0.82]:
				var lx: float = hw * ratio
				draw_line(Vector2(lx, 0.0), Vector2(lx, -height), iron, 4.5)
				draw_rect(Rect2(lx - 5.0, -3.0, 10.0, 3.0), iron)

			# Upper backrest wooden slats (top slat flush with -height for clean riding/grinding).
			var back_top: float = -height
			var back_h: float = (-seat_y - height) * -1.0 - 5.0
			var slat_h: float = maxf(back_h * 0.42, 4.5)
			draw_rect(Rect2(-hw, back_top, width, slat_h), wood_light)
			draw_rect(Rect2(-hw, back_top, width, slat_h), wood_dark, false, 1.5)
			draw_rect(Rect2(-hw, back_top + slat_h + 2.5, width, slat_h), wood)
			draw_rect(Rect2(-hw, back_top + slat_h + 2.5, width, slat_h), wood_dark, false, 1.5)

			# Seat plank + front lip.
			draw_rect(Rect2(-hw - 2.0, seat_y, width + 4.0, 7.0), wood_light)
			draw_rect(Rect2(-hw - 2.0, seat_y, width + 4.0, 7.0), wood_dark, false, 1.5)

			# Wrought-iron curved side armrests.
			for side in [-1.0, 1.0]:
				var ax: float = hw * 0.88 * side
				draw_line(Vector2(ax, seat_y), Vector2(ax, seat_y - height * 0.24), iron, 3.5)
				draw_line(Vector2(ax - 5.0, seat_y - height * 0.24), Vector2(ax + 5.0, seat_y - height * 0.24), iron, 3.5)

		Kind.WOODEN_PALLET:
			# 1 to 4 stacked shipping pallets with top boards, hollow fork pockets & stringer blocks.
			var layers: int = clampi(roundi(height / 16.0), 1, 4)
			var layer_h: float = height / float(layers)
			var wood_top := Color("d4a373")
			var wood_block := Color("a97142")
			var cavity := Color("3d291a")
			var border := Color("5c3d24")

			for i in layers:
				var ly: float = -float(i + 1) * layer_h
				var top_plank_h: float = maxf(layer_h * 0.28, 3.5)
				var bot_plank_h: float = maxf(layer_h * 0.2, 2.5)
				var mid_y: float = ly + top_plank_h
				var mid_h: float = maxf(layer_h - top_plank_h - bot_plank_h, 4.0)

				# Dark fork-pocket interior.
				draw_rect(Rect2(-hw + 2.0, mid_y, width - 4.0, mid_h), cavity)
				# 3 chunky stringer blocks (left, center, right).
				var bw: float = maxf(width * 0.14, 8.0)
				draw_rect(Rect2(-hw, mid_y, bw, mid_h), wood_block)
				draw_rect(Rect2(-bw * 0.5, mid_y, bw, mid_h), wood_block)
				draw_rect(Rect2(hw - bw, mid_y, bw, mid_h), wood_block)

				# Top & bottom pallet deck boards.
				draw_rect(Rect2(-hw, ly, width, top_plank_h), wood_top)
				draw_rect(Rect2(-hw, mid_y + mid_h, width, bot_plank_h), wood_block.lightened(0.1))
				draw_line(Vector2(-hw, ly), Vector2(hw, ly), border, 1.5)
				draw_line(Vector2(-hw, ly + layer_h), Vector2(hw, ly + layer_h), border, 1.5)

		Kind.TRASH_CAN:
			# Corrugated metal street trash bin with side handles & domed lid.
			var can_w: float = width * 0.82
			var lid_h: float = minf(height * 0.16, 9.0)
			var body_h: float = height - lid_h
			var metal := Color("4a5759")
			var metal_dark := Color("2f3e46")
			var metal_light := Color("7b8c8e")

			# Slightly tapered metal body.
			var body := PackedVector2Array([
				Vector2(-can_w * 0.44, 0.0),
				Vector2(can_w * 0.44, 0.0),
				Vector2(can_w * 0.5, -body_h),
				Vector2(-can_w * 0.5, -body_h),
			])
			draw_colored_polygon(body, metal)
			draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), metal_dark, 2.0)

			# Vertical ribs.
			for r in [-0.24, 0.0, 0.24]:
				draw_line(Vector2(can_w * r, -4.0), Vector2(can_w * r, -body_h + 5.0), metal_dark, 2.0)
				draw_line(Vector2(can_w * r + 2.0, -4.0), Vector2(can_w * r + 2.0, -body_h + 5.0), metal_light, 1.0)

			# Side handles.
			draw_rect(Rect2(-hw * 0.96, -body_h * 0.82, 4.0, 9.0), metal_dark)
			draw_rect(Rect2(hw * 0.96 - 4.0, -body_h * 0.82, 4.0, 9.0), metal_dark)

			# Rim band & domed lid.
			draw_rect(Rect2(-can_w * 0.54, -body_h - 4.0, can_w * 1.08, 5.0), metal_light)
			draw_rect(Rect2(-can_w * 0.42, -height + 3.0, can_w * 0.84, lid_h - 3.0), metal)
			draw_rect(Rect2(-5.0, -height, 10.0, 3.5), metal_dark)

		Kind.WOODEN_CRATE:
			# Framed wooden cargo crate with horizontal slats & diagonal brace.
			var plank := Color("c68b59")
			var frame := Color("8c5832")
			var dark := Color("523218")
			var rect := Rect2(-hw, -height, width, height)
			draw_rect(rect, plank)

			# Horizontal plank seams.
			var planks: int = maxi(3, int(height / 13.0))
			for i in range(1, planks):
				var py: float = -height + float(i) * (height / float(planks))
				draw_line(Vector2(-hw, py), Vector2(hw, py), dark, 1.5)

			# Diagonal cross-brace plank.
			var f: float = clampf(minf(width, height) * 0.14, 5.0, 9.0)
			draw_line(Vector2(-hw + f, -f), Vector2(hw - f, -height + f), frame, f)
			draw_line(Vector2(-hw + f, -f), Vector2(hw - f, -height + f), dark, 1.2)

			# Outer wooden frame border.
			draw_rect(Rect2(-hw, -height, width, f), frame)
			draw_rect(Rect2(-hw, -f, width, f), frame)
			draw_rect(Rect2(-hw, -height, f, height), frame)
			draw_rect(Rect2(hw - f, -height, f, height), frame)
			draw_rect(rect, dark, false, 2.0)
