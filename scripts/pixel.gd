class_name Pixel
extends RefCounted


static func ellipse_rows(center, radius):
	var rows = []
	var cx = round(center.x)
	var cy = round(center.y)
	var rx = radius.x
	var ry = radius.y
	if rx < 0.5:
		rx = 0.5
	if ry < 0.5:
		ry = 0.5

	for y in range(floori(cy - ry), ceili(cy + ry)):
		var dy = (y + 0.5 - cy) / ry
		if abs(dy) >= 1:
			continue
		var half = rx * sqrt(1 - dy * dy)
		var left = round(cx - half)
		var right = round(cx + half)
		var width = right - left
		if width < 1:
			width = 1
		rows.append(Rect2(left, y, width, 1))
	return rows


static func ring_rows(center, radius, thickness):
	var rows = []
	var cx = round(center.x)
	var cy = round(center.y)
	var outer = radius
	if outer < 1:
		outer = 1
	if thickness < 1:
		thickness = 1
	var inner = outer - thickness
	if inner < 0:
		inner = 0

	for y in range(floori(cy - outer), ceili(cy + outer)):
		var dy = (y + 0.5 - cy) / outer
		if abs(dy) >= 1:
			continue
		var half = outer * sqrt(1 - dy * dy)
		var hole = 0.0
		var inner_dy = abs(y + 0.5 - cy)
		if inner > 0 and inner_dy < inner:
			hole = inner * sqrt(1 - (inner_dy / inner) * (inner_dy / inner))
		var left_out = round(cx - half)
		var right_out = round(cx + half)
		var left_in = round(cx - hole)
		var right_in = round(cx + hole)
		if left_in > left_out:
			rows.append(Rect2(left_out, y, left_in - left_out, 1))
		if right_out > right_in:
			rows.append(Rect2(right_in, y, right_out - right_in, 1))
	return rows
