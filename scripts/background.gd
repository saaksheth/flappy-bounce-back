class_name Background
extends Node2D

const GROUND_TOP = 416.0
const SKY_TOP = Color("#3ea8c9")
const SKY_BOTTOM = Color("#a9e9ec")
const CLOUD = Color(1, 1, 1, 0.88)
const CLOUD_SHADE = Color("#cfeaf1")
const BUILDING = Color("#bfe9df")
const BUILDING_DARK = Color("#a6dbcf")
const WINDOW = Color("#8fcabe")

const CLOUD_SPEED = 11.0
const CITY_SPEED = 22.0
const FIELD_WIDTH = 360.0

var speed_scale = 1.0

var cloud_x = []
var cloud_y = []
var cloud_size = []
var cloud_speed = []

var building_x = []
var building_width = []
var building_height = []


func _ready():
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261106

	for i in range(6):
		cloud_x.append(rng.randf_range(0, FIELD_WIDTH))
		cloud_y.append(rng.randf_range(40, 250))
		cloud_size.append(rng.randf_range(0.7, 1.5))
		cloud_speed.append(rng.randf_range(0.7, 1.3))

	var x = 0.0
	while x < FIELD_WIDTH:
		var w = rng.randf_range(26, 46)
		building_x.append(x)
		building_width.append(w)
		building_height.append(rng.randf_range(46, 118))
		x = x + w + rng.randf_range(6, 16)

	queue_redraw()


func _process(delta):
	var step = delta * speed_scale
	for i in range(cloud_x.size()):
		cloud_x[i] = cloud_x[i] - CLOUD_SPEED * cloud_speed[i] * step
		if cloud_x[i] < -70:
			cloud_x[i] = FIELD_WIDTH + 70

	for i in range(building_x.size()):
		building_x[i] = building_x[i] - CITY_SPEED * step
		if building_x[i] + building_width[i] < -20:
			building_x[i] = FIELD_WIDTH

	queue_redraw()


func _draw():
	for i in range(32):
		var t = i / 31.0
		draw_rect(Rect2(-40, i * 16, 368, 16), SKY_TOP.lerp(SKY_BOTTOM, t))

	for i in range(cloud_x.size()):
		draw_cloud(Vector2(cloud_x[i], cloud_y[i]), cloud_size[i])

	for i in range(building_x.size()):
		draw_building(i)


func draw_cloud(pos, scale):
	var x = round(pos.x)
	var y = round(pos.y)
	var w = round(17 * scale) * 2
	var h = round(5 * scale) * 2
	var left = x - w / 2

	draw_rect(Rect2(left, y, w, h), CLOUD)
	draw_rect(Rect2(left + round(w * 0.10), y - round(h * 0.55), round(w * 0.42), round(h * 0.6)), CLOUD)
	draw_rect(Rect2(left + round(w * 0.50), y - round(h * 0.95), round(w * 0.30), round(h * 1.0)), CLOUD)
	draw_rect(Rect2(left, y + h - 2, w, 2), CLOUD_SHADE)


func draw_building(i):
	var x = round(building_x[i])
	var w = round(building_width[i])
	if w < 8:
		w = 8
	var h = round(building_height[i])
	var top = round(GROUND_TOP - h)

	draw_rect(Rect2(x, top, w, h), BUILDING)
	draw_rect(Rect2(x, top, w, 4), BUILDING_DARK)

	var y = top + 10
	while y < GROUND_TOP - 12:
		var wx = x + 5
		while wx <= x + w - 8:
			draw_rect(Rect2(wx, y, 3, 5), WINDOW)
			wx = wx + 8
		y = y + 11
