class_name Bird
extends CharacterBody2D

signal flapped

const GRAVITY = 1500.0
const FLAP_SPEED = -430.0
const MAX_FALL_SPEED = 900.0
const BOUNCE_SPEED = -395.0
const TILT_UP = -0.45
const TILT_DOWN = 1.45
const TOP_LIMIT = -26.0

const LAYER_ALL = 3
const LAYER_GROUND_ONLY = 1

const OUTLINE = Color("#4a3212")
const BODY = Color("#f7d648")
const BELLY = Color("#fdf3c0")
const WING = Color("#f0b52c")
const BEAK = Color("#f28b2f")
const BEAK_DARK = Color("#d9721c")
const POWER_TINT = Color("#ffc23d")
const SHIELD = Color("#9beeff")

var is_alive = true
var bobbing = true

var gravity = GRAVITY
var flap_speed = FLAP_SPEED
var bounces_left = 0
var power_level = 0

@onready var _shape = $CollisionShape2D

var _base_radius = 9.5
var _hitbox_scale = 1.0
var _home_pos = Vector2.ZERO
var _wing_time = 0.0
var _tumbling = false


func _ready():
	_home_pos = position
	collision_mask = LAYER_ALL
	var circle = _shape.shape
	circle = circle.duplicate()
	_shape.shape = circle
	_base_radius = circle.radius
	_update_hitbox()
	queue_redraw()


func reset(at_position):
	position = at_position
	_home_pos = at_position
	velocity = Vector2.ZERO
	rotation = 0
	is_alive = true
	_tumbling = false
	bobbing = true
	_wing_time = 0
	collision_mask = LAYER_ALL
	queue_redraw()


func apply_mods(gravity_scale, flap_scale, hitbox_scale, bounces, power):
	gravity = GRAVITY * gravity_scale
	flap_speed = FLAP_SPEED * flap_scale
	bounces_left = max(bounces, 0)
	power_level = max(power, 0)
	_hitbox_scale = hitbox_scale
	_update_hitbox()
	queue_redraw()


func bounce():
	if not is_alive:
		return false
	if bounces_left <= 0:
		return false
	bounces_left = bounces_left - 1
	velocity = Vector2(0, BOUNCE_SPEED)
	_tumbling = false
	position.y = position.y - 5
	return true


func begin_play():
	bobbing = false
	position = _home_pos
	velocity = Vector2.ZERO
	rotation = 0


func flap():
	if not is_alive:
		return
	if bobbing:
		return
	velocity.y = flap_speed
	_tumbling = false
	flapped.emit()


func die():
	if not is_alive:
		return
	is_alive = false
	_tumbling = true
	if velocity.y > -140:
		velocity.y = -140
	collision_mask = LAYER_GROUND_ONLY


func step(delta):
	velocity.y = velocity.y + gravity * delta
	if velocity.y > MAX_FALL_SPEED:
		velocity.y = MAX_FALL_SPEED
	var collision = move_and_collide(velocity * delta)
	if collision != null:
		velocity = Vector2.ZERO
		_tumbling = false
	if position.y < TOP_LIMIT:
		position.y = TOP_LIMIT
		if velocity.y < 0:
			velocity.y = 0
	return collision


func _process(delta):
	_wing_time = _wing_time + delta
	if bobbing:
		var wobble = sin(_wing_time * 3.2)
		position.y = _home_pos.y + wobble * 7
		rotation = wobble * 0.08
	elif is_alive:
		var target = TILT_UP
		if velocity.y > 0:
			target = clamp(velocity.y / MAX_FALL_SPEED, 0, 1) * TILT_DOWN
		rotation = lerp(rotation, target, clamp(delta * 11, 0, 1))
	elif _tumbling:
		rotation = rotation + delta * 4.5
		if rotation > PI / 2:
			rotation = PI / 2
	queue_redraw()


func _draw():
	var power = clamp(float(power_level) / BirdMods.MAX_TOTAL, 0, 1)
	var body = BODY
	if power > 0:
		body = BODY.lerp(POWER_TINT, power * 0.7)
		_draw_aura(power)

	var lift = 0.5
	if bobbing:
		lift = sin(_wing_time * 13) * 0.5 + 0.5
	elif is_alive:
		lift = clamp(0.55 - velocity.y / MAX_FALL_SPEED * 0.7, 0, 1)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -2), Vector2(-16, -7), Vector2(-15, 3), Vector2(-8, 3),
	]), WING)

	for row in Pixel.ellipse_rows(Vector2.ZERO, Vector2(11.5, 10)):
		draw_rect(row, OUTLINE)
	for row in Pixel.ellipse_rows(Vector2.ZERO, Vector2(10, 8.5)):
		draw_rect(row, body)
	for row in Pixel.ellipse_rows(Vector2(-1, 3), Vector2(6.5, 4.5)):
		draw_rect(row, BELLY)

	var wing_y = 1 - round(lift * 7)
	for row in Pixel.ellipse_rows(Vector2(-3, wing_y), Vector2(6, 3.5)):
		draw_rect(row, WING)

	for row in Pixel.ellipse_rows(Vector2(6, -4), Vector2(3.5, 3.5)):
		draw_rect(row, Color.WHITE)
	draw_rect(Rect2(6, -5, 3, 3), OUTLINE)

	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -2), Vector2(17, 1), Vector2(8, 4),
	]), BEAK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, 1), Vector2(13, 2), Vector2(8, 4),
	]), BEAK_DARK)

	for i in range(bounces_left):
		var x = round((i - (bounces_left - 1) * 0.5) * 6)
		draw_rect(Rect2(x - 1, 13, 3, 3), SHIELD)


func _draw_aura(power):
	var glow = Color("#ffe27a").lerp(Color("#ff9d3c"), power)
	var radius = 15 + power * 6
	glow.a = 0.12 + power * 0.16
	for row in Pixel.ellipse_rows(Vector2.ZERO, Vector2(radius, radius * 0.88)):
		draw_rect(row, glow)
	glow.a = 0.5 + power * 0.4
	for row in Pixel.ring_rows(Vector2.ZERO, radius, 2):
		draw_rect(row, glow)


func _update_hitbox():
	if _shape == null:
		return
	var circle = _shape.shape
	if circle != null:
		circle.radius = _base_radius * _hitbox_scale
