class_name PipePair
extends Node2D

const PIPE_WIDTH = 54.0
const GAP_HEIGHT = 120.0
const RIM_HEIGHT = 24.0
const RIM_OVERHANG = 5.0
const COLLISION_LAYER = 2

const BODY = Color("#6fbf3a")
const SHADE = Color("#55991f")
const HIGHLIGHT = Color("#a6df60")
const OUTLINE = Color("#3f6f1d")

var gap_center = 240.0
var gap_scale = 1.0
var scored = false

var top_body
var bottom_body


func configure(center_y, scale = 1.0):
	gap_center = center_y
	gap_scale = scale
	if gap_scale < 0.5:
		gap_scale = 0.5
	if top_body != null:
		update_bodies()
	queue_redraw()


func gap_height():
	return GAP_HEIGHT * gap_scale


func _ready():
	top_body = make_body()
	bottom_body = make_body()
	update_bodies()
	queue_redraw()


func make_body():
	var body = StaticBody2D.new()
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	body.add_child(shape)
	add_child(body)
	return body


func update_bodies():
	var h = gap_height()
	var top_edge = gap_center - h / 2
	var bottom_edge = gap_center + h / 2
	place_segment(top_body, -420, top_edge)
	place_segment(bottom_body, bottom_edge, 620)


func place_segment(body, top, bottom):
	var shape = body.get_child(0)
	var rect = shape.shape
	rect.size = Vector2(PIPE_WIDTH, bottom - top)
	body.position = Vector2(0, (top + bottom) / 2)


func _draw():
	var h = gap_height()
	var top_edge = round(gap_center - h / 2)
	var bottom_edge = round(gap_center + h / 2)
	draw_pipe(-60, top_edge, top_edge - RIM_HEIGHT)
	draw_pipe(bottom_edge, 520, bottom_edge)


func draw_pipe(top, bottom, cap_top):
	var half = PIPE_WIDTH / 2
	var body = Rect2(-half, round(top), PIPE_WIDTH, round(bottom - top))
	draw_rect(body, BODY)
	draw_rect(Rect2(body.position.x + 3, body.position.y, 8, body.size.y), HIGHLIGHT)
	draw_rect(Rect2(body.end.x - 11, body.position.y, 9, body.size.y), SHADE)
	draw_frame(body)

	var cap_width = PIPE_WIDTH + RIM_OVERHANG * 2
	var cap = Rect2(-half - RIM_OVERHANG, round(cap_top), cap_width, RIM_HEIGHT)
	draw_rect(cap, BODY)
	draw_rect(Rect2(cap.position.x + 3, cap.position.y, 8, RIM_HEIGHT), HIGHLIGHT)
	draw_rect(Rect2(cap.end.x - 11, cap.position.y, 9, RIM_HEIGHT), SHADE)
	draw_frame(cap)


func draw_frame(rect):
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), OUTLINE)
	draw_rect(Rect2(rect.position.x, rect.end.y - 1, rect.size.x, 1), OUTLINE)
	draw_rect(Rect2(rect.position.x, rect.position.y, 1, rect.size.y), OUTLINE)
	draw_rect(Rect2(rect.end.x - 1, rect.position.y, 1, rect.size.y), OUTLINE)
