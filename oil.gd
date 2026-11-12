@tool
extends Node2D
class_name oil
## Wok oil: a rippling, bowl-shaped liquid that slows fishballs and tells them when they're frying.
## Origin is the TOP-LEFT of the oil surface. Place it at the left rim, at oil level.

signal body_entered_oil(body: Node2D)
signal body_exited_oil(body: Node2D)

@export_group("Shape")
## x = width of the oil surface, y = oil depth at the centre of the wok.
@export var water_size: Vector2 = Vector2(450.0, 194.0)
@export var surface_pos_y: float = 0.5
@export_range(4, 512) var segment_count: int = 48
## Oil depth at the wok's edges (thin film). Centre depth is water_size.y.
@export var edge_depth: float = 2.0
@export var curved_bottom: bool = true

@export_group("Look")
@export var surface_line_thickness: float = 1.0
@export var surface_color: Color = Color("ae741cff")
@export var water_fill_color: Color = Color("e29b45ff")

@export_group("Ripples")
@export_range(0.0, 1000.0) var water_physics_speed: float = 80.0
@export var water_restoring_force: float = 0.02
## Higher = ripples die faster. Oil is thick, so keep this above water's 0.04.
@export var wave_energy_loss: float = 0.08
@export var wave_strength: float = 0.25
@export_range(1, 64) var wave_spread_updates: int = 8
## Surface push per unit of fishball speed. Lower this if splashes look too big.
@export var splash_multiplier: float = 0.02
## Fishballs slower than this make no splash.
@export var min_splash_speed: float = 40.0
## Cap on the push so a fast fishball can't blow up the surface.
@export var max_splash_velocity: float = 4.0
## How many segments on each side of the impact also get pushed.
@export_range(0, 8) var splash_spread: int = 2

@export_group("Fishball Interaction")
## Bodies in this group are affected by the oil.
@export var interact_group: StringName = &"fishball"
## Physics layers the oil can see. Must include the fishball's layer.
@export_flags_2d_physics var detect_mask: int = 1
## How much the oil slows bodies down (applied as extra linear damp).
@export var oil_drag: float = 3.0
## 0 = no buoyancy, 1 = floats exactly, above 1 = rises. Cancels part of gravity inside the oil.
@export_range(0.0, 2.0) var buoyancy: float = 0.5
## Cooking speed multiplier fishballs can read (turn it up/down for a hotter/cooler wok).
@export var heat: float = 1.0

@export_group("Bubbles")
@export var bubbles_enabled: bool = true

@export_tool_button("Update Water") var update_water_button: Callable = func():
	_ready()

var heights: PackedFloat32Array = PackedFloat32Array()
var velocities: PackedFloat32Array = PackedFloat32Array()
var wave_left: PackedFloat32Array = PackedFloat32Array()
var wave_right: PackedFloat32Array = PackedFloat32Array()

var bodies_in_oil: Array[Node2D] = []

var _root: Node2D
var surface_line: Line2D
var fill_polygon: Polygon2D
var area: Area2D
var bubbles: CPUParticles2D


func _ready() -> void:
	build()


func build() -> void:
	# Only remove what this script generated, not nodes you added by hand.
	if _root and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	bodies_in_oil.clear()

	_root = Node2D.new()
	_root.name = "OilGenerated"
	add_child(_root)

	_init_segments()
	_build_surface()
	_build_area()
	_build_bubbles()

	update_visuals()
	set_process(true)


func _init_segments() -> void:
	heights.resize(segment_count)
	velocities.resize(segment_count)
	wave_left.resize(segment_count)
	wave_right.resize(segment_count)
	heights.fill(surface_pos_y)
	velocities.fill(0.0)
	wave_left.fill(0.0)
	wave_right.fill(0.0)


func _build_surface() -> void:
	surface_line = Line2D.new()
	surface_line.width = surface_line_thickness
	surface_line.default_color = surface_color
	_root.add_child(surface_line)

	fill_polygon = Polygon2D.new()
	fill_polygon.color = water_fill_color
	fill_polygon.show_behind_parent = true
	surface_line.add_child(fill_polygon)


func _build_area() -> void:
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = detect_mask

	# Built-in physics: drag + partial anti-gravity act on every RigidBody2D inside.
	area.linear_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	area.linear_damp = oil_drag
	area.angular_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	area.angular_damp = oil_drag
	var default_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	area.gravity_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	area.gravity_point = false
	area.gravity_direction = Vector2.DOWN
	area.gravity = -default_gravity * buoyancy

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_root.add_child(area)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(water_size.x, water_size.y)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(water_size.x / 2.0, surface_pos_y + water_size.y / 2.0)
	area.add_child(cs)


func _build_bubbles() -> void:
	bubbles = CPUParticles2D.new()
	bubbles.emitting = false
	bubbles.amount = 20
	bubbles.lifetime = 0.7
	bubbles.local_coords = true
	bubbles.position = Vector2(water_size.x / 2.0, surface_pos_y + water_size.y * 0.5)
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(water_size.x * 0.4, water_size.y * 0.25)
	bubbles.direction = Vector2.UP
	bubbles.spread = 25.0
	bubbles.gravity = Vector2(0, -20)
	bubbles.initial_velocity_min = 8.0
	bubbles.initial_velocity_max = 22.0
	bubbles.scale_amount_min = 1.0
	bubbles.scale_amount_max = 2.0
	bubbles.color = Color(1, 0.95, 0.75, 0.8)
	_root.add_child(bubbles)


func _process(delta: float) -> void:
	update_physics(delta)
	update_visuals()


func update_physics(delta: float) -> void:
	# Cap delta so one long frame can't make the ripples explode.
	var step: float = minf(delta, 0.05) * water_physics_speed

	for i in segment_count:
		var displacement: float = heights[i] - surface_pos_y
		var acceleration: float = -water_restoring_force * displacement - velocities[i] * wave_energy_loss
		velocities[i] += acceleration * step
		heights[i] += velocities[i] * step

	for _u in wave_spread_updates:
		for i in segment_count:
			if i > 0:
				wave_left[i] = (heights[i] - heights[i - 1]) * wave_strength
				velocities[i - 1] += wave_left[i] * step
			if i < segment_count - 1:
				wave_right[i] = (heights[i] - heights[i + 1]) * wave_strength
				velocities[i + 1] += wave_right[i] * step
		for i in segment_count:
			if i > 0:
				heights[i - 1] += wave_left[i] * step
			if i < segment_count - 1:
				heights[i + 1] += wave_right[i] * step

	# Pin the edges to the wok wall.
	for i in [0, 1, segment_count - 2, segment_count - 1]:
		heights[i] = surface_pos_y
		velocities[i] = 0.0

	# Sleep when settled (a splash or a new body wakes it again).
	var settled: bool = true
	for i in segment_count:
		if absf(heights[i] - surface_pos_y) > 0.001 or absf(velocities[i]) > 0.001:
			settled = false
			break
	if settled:
		set_process(false)


func update_visuals() -> void:
	var seg_w: float = water_size.x / (segment_count - 1)

	var top := PackedVector2Array()
	for i in segment_count:
		top.append(Vector2(i * seg_w, heights[i]))
	surface_line.points = top

	var poly: PackedVector2Array = top.duplicate()
	if curved_bottom:
		# Walk back right-to-left along an elliptical bowl bottom.
		for i in range(segment_count - 1, -1, -1):
			var u: float = (float(i) / (segment_count - 1)) * 2.0 - 1.0  # -1..1
			var depth: float = edge_depth + (water_size.y - edge_depth) * sqrt(maxf(0.0, 1.0 - u * u))
			poly.append(Vector2(i * seg_w, surface_pos_y + depth))
	else:
		var bottom_y: float = surface_pos_y + water_size.y
		poly.append(Vector2(water_size.x, bottom_y))
		poly.append(Vector2(0.0, bottom_y))
	fill_polygon.polygon = poly


func splash(splash_pos: Vector2, splash_velocity: float) -> void:
	if segment_count < 4:
		return
	var v: float = clampf(splash_velocity, -max_splash_velocity, max_splash_velocity)
	var seg_w: float = water_size.x / (segment_count - 1)
	var centre: int = clampi(roundi(to_local(splash_pos).x / seg_w), 0, segment_count - 1)

	for offset in range(-splash_spread, splash_spread + 1):
		var j: int = centre + offset
		if j < 2 or j > segment_count - 3:
			continue  # pinned edge segments
		var falloff: float = 1.0 - absf(offset) / float(splash_spread + 1)
		velocities[j] += v * falloff
	set_process(true)


func get_fishball_count() -> int:
	return bodies_in_oil.size()


func _get_body_velocity_y(body: Node) -> float:
	if body is CharacterBody2D:
		return body.velocity.y
	elif body is RigidBody2D:
		return body.linear_velocity.y
	return 0.0


func _update_bubbles() -> void:
	if bubbles:
		bubbles.emitting = bubbles_enabled and not bodies_in_oil.is_empty()


func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint() or not body.is_in_group(interact_group):
		return
	if body in bodies_in_oil:
		return
	bodies_in_oil.append(body)

	var vy: float = _get_body_velocity_y(body)
	if absf(vy) >= min_splash_speed:
		# Falling in (vy > 0) pushes the surface down at the impact point.
		splash(body.global_position, vy * splash_multiplier)

	if body.has_method("enter_oil"):
		body.enter_oil(self)
	body_entered_oil.emit(body)
	_update_bubbles()


func _on_body_exited(body: Node2D) -> void:
	if Engine.is_editor_hint() or not body.is_in_group(interact_group):
		return
	bodies_in_oil.erase(body)

	var vy: float = _get_body_velocity_y(body)
	if absf(vy) >= min_splash_speed:
		# Leaving upward (vy < 0) pulls the surface up.
		splash(body.global_position, vy * splash_multiplier)

	if body.has_method("exit_oil"):
		body.exit_oil(self)
	body_exited_oil.emit(body)
	_update_bubbles()
