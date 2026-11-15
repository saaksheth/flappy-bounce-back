class_name Ground
extends StaticBody2D

const HEIGHT = 96.0
const SCROLL_SPEED = 135.0

const GRASS_DARK = Color("#6fb437")
const GRASS = Color("#8bd44a")
const SAND = Color("#deda9a")
const STRIPE = Color("#d2ce8c")

var scrolling = true
var _offset = 0.0


func _process(delta):
	if not scrolling:
		return
	_offset = fmod(_offset + SCROLL_SPEED * delta, 26)
	queue_redraw()


func _draw():
	draw_rect(Rect2(-172, 0, 344, 6), GRASS_DARK)
	draw_rect(Rect2(-172, 6, 344, 8), GRASS)
	draw_rect(Rect2(-172, 14, 344, HEIGHT - 14), SAND)
	draw_rect(Rect2(-172, 14, 344, 2), STRIPE)

	var offset = round(_offset)
	var x = -172 - 26 - offset
	while x < 172:
		var y = 20
		while y < HEIGHT:
			draw_rect(Rect2(round(x + (y - 20) * 0.45), y, 2, 2), STRIPE)
			y = y + 2
		x = x + 26
