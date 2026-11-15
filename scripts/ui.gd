class_name UI
extends CanvasLayer

signal solo_pressed
signal tournament_pressed
signal reset_powers_pressed
signal game_over_primary
signal menu_pressed
signal play_again_pressed
signal tournament_started(players)

const MAX_PLAYERS = 8

const INK = Color("#4a2f12")
const INK_SOFT = Color("#94764f")
const CREAM = Color("#fff8e3")
const CREAM_EDGE = Color("#e2cf98")
const ORANGE = Color("#f2a33c")
const ORANGE_DARK = Color("#b96c14")
const GREEN = Color("#79bf3c")
const SAND_BUTTON = Color("#e8d9b0")

var _root
var _overlay
var _pages
var _page_roots = []

var _hud
var _score_label
var _score_value = -1
var _score_tween

var _ready_box
var _ready_name
var _ready_prompt
var _ready_hint
var _ready_mods
var _pulse_tween

var _menu_page
var _menu_best
var _menu_evolution

var _over_page
var _over_title
var _over_player
var _over_note
var _over_score
var _over_best
var _over_badge
var _over_mod
var _over_mod_desc
var _over_primary

var _setup_page
var _setup_list
var _setup_name
var _setup_hint
var _setup_start
var _draft = []

var _results_page
var _results_headline
var _results_list

var _flash
var _flash_tween


func _ready():
	layer = 5
	build()


func show_menu(best, evolution = 0, evolution_max = 18):
	hide_ready()
	_hud.visible = false
	_menu_best.text = "BEST  %d" % best
	_menu_evolution.text = "EVOLUTION  %d / %d" % [evolution, evolution_max]
	_menu_evolution.visible = evolution_max > 0
	_show_page(_menu_page)


func show_ready(player_name, hint, mods_line = ""):
	_hide_pages()
	_ready_box.visible = true
	_ready_name.text = player_name
	_ready_name.visible = player_name != ""
	_ready_hint.text = hint
	_ready_mods.text = mods_line
	_ready_mods.visible = mods_line != ""
	_start_pulse()


func hide_ready():
	_ready_box.visible = false
	_stop_pulse()


func set_hud_visible(value):
	_hud.visible = value


func set_score(value):
	if value == _score_value:
		return
	_score_value = value
	_score_label.text = str(value)
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_label.add_theme_font_size_override("font_size", 48)
	_score_tween = create_tween()
	_score_tween.tween_method(_set_score_size, 48.0, 40.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func show_game_over(score, best, new_best, player_label, note, primary_text, mod_line = "", mod_desc = ""):
	hide_ready()
	if mod_line != "":
		_over_title.text = "BOUNCE BACK"
	else:
		_over_title.text = "GAME OVER"
	_over_mod.text = mod_line
	_over_mod.visible = mod_line != ""
	_over_mod_desc.text = mod_desc
	_over_mod_desc.visible = mod_desc != ""
	_over_player.text = player_label
	_over_player.visible = player_label != ""
	_over_note.text = note
	_over_note.visible = note != ""
	_over_score.text = str(score)
	_over_best.text = "BEST  %d" % best
	_over_badge.visible = new_best
	_over_primary.text = primary_text
	_show_page(_over_page)


func show_setup(seed_players):
	hide_ready()
	_draft = seed_players.duplicate()
	_setup_name.text = ""
	_rebuild_draft()
	_show_page(_setup_page)


func show_results(rows, headline):
	hide_ready()
	_hud.visible = false
	_results_headline.text = headline
	for child in _results_list.get_children():
		_results_list.remove_child(child)
		child.queue_free()
	for row in rows:
		_results_list.add_child(make_result_row(row))
	_show_page(_results_page)


func flash(color = Color.WHITE, strength = 0.6):
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = color
	_flash.modulate.a = strength
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.35)


func build():
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	build_hud()
	build_ready()

	_overlay = ColorRect.new()
	_overlay.color = Color(0.18, 0.11, 0.05, 0.42)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_pages = Control.new()
	_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pages)
	_pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	build_menu()
	build_game_over()
	build_setup()
	build_results()

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 1)
	_flash.modulate = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func build_hud():
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	_root.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_score_label = make_label("0", 40, Color.WHITE, INK)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_score_label)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_top = 14
	_score_label.offset_bottom = 74


func build_ready():
	_ready_box = Control.new()
	_ready_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ready_box.visible = false
	_root.add_child(_ready_box)
	_ready_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ready_box.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 286
	column.offset_bottom = 384

	_ready_name = make_label("", 20, Color.WHITE, INK)
	_ready_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ready_name)

	_ready_prompt = make_label("TAP TO START", 18, Color.WHITE, INK)
	_ready_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ready_prompt)

	_ready_hint = make_label("", 10, Color.WHITE, INK)
	_ready_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ready_hint)

	_ready_mods = make_label("", 9, Color("#ffe9a8"), INK)
	_ready_mods.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ready_mods)


func build_menu():
	var box = make_page()
	_menu_page = _page_roots.back()

	var title = make_label("FLAPPY", 34, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle = make_label("BIRD", 26, ORANGE_DARK)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_menu_best = make_label("BEST  0", 12, INK_SOFT)
	_menu_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_menu_best)

	_menu_evolution = make_label("", 9, INK_SOFT)
	_menu_evolution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_menu_evolution)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	var play = make_button("PLAY", GREEN)
	play.pressed.connect(on_play)
	box.add_child(play)

	var tournament = make_button("TOURNAMENT", ORANGE)
	tournament.pressed.connect(on_tournament)
	box.add_child(tournament)

	var reset_powers = make_button("RESET POWER-UPS", SAND_BUTTON, 11, INK)
	reset_powers.custom_minimum_size = Vector2(0, 30)
	reset_powers.pressed.connect(on_reset_powers)
	box.add_child(reset_powers)

	var hint = make_label("SPACE · CLICK · TAP TO FLAP", 9, INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func build_game_over():
	var box = make_page()
	_over_page = _page_roots.back()

	_over_title = make_label("GAME OVER", 24, INK)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_title)

	_over_player = make_label("", 12, ORANGE_DARK)
	_over_player.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_player)

	_over_score = make_label("0", 44, INK)
	_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_score)

	_over_best = make_label("BEST  0", 12, INK_SOFT)
	_over_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_best)

	_over_badge = make_label("NEW BEST!", 12, GREEN.darkened(0.15))
	_over_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_badge.visible = false
	box.add_child(_over_badge)

	_over_mod = make_label("", 11, GREEN.darkened(0.30))
	_over_mod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_mod.visible = false
	box.add_child(_over_mod)

	_over_mod_desc = make_label("", 9, INK_SOFT)
	_over_mod_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_mod_desc.visible = false
	box.add_child(_over_mod_desc)

	_over_note = make_label("", 9, INK_SOFT)
	_over_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_note)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	_over_primary = make_button("RETRY", ORANGE)
	_over_primary.pressed.connect(on_retry)
	box.add_child(_over_primary)

	var back = make_button("MENU", SAND_BUTTON, 13, INK)
	back.pressed.connect(on_menu)
	box.add_child(back)


func build_setup():
	var box = make_page()
	_setup_page = _page_roots.back()

	var title = make_label("TOURNAMENT", 22, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle = make_label("PASS & PLAY · 2 TO 8 PLAYERS", 9, INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_setup_list = VBoxContainer.new()
	_setup_list.add_theme_constant_override("separation", 3)
	box.add_child(_setup_list)

	var add_row = HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	box.add_child(add_row)

	_setup_name = LineEdit.new()
	_setup_name.placeholder_text = "PLAYER NAME"
	_setup_name.max_length = 10
	_setup_name.custom_minimum_size = Vector2(0, 30)
	_setup_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_name.add_theme_font_size_override("font_size", 12)
	_setup_name.add_theme_color_override("font_color", INK)
	_setup_name.add_theme_color_override("caret_color", INK)
	_setup_name.add_theme_color_override("font_placeholder_color", INK_SOFT)
	_setup_name.add_theme_stylebox_override("normal", field_style(CREAM_EDGE))
	_setup_name.add_theme_stylebox_override("focus", field_style(ORANGE))
	_setup_name.text_submitted.connect(on_name_submitted)
	add_row.add_child(_setup_name)

	var add_button = make_button("ADD", GREEN, 11)
	add_button.custom_minimum_size = Vector2(58, 30)
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_button.pressed.connect(on_add)
	add_row.add_child(add_button)

	_setup_hint = make_label("ADD AT LEAST 2 PLAYERS", 9, INK_SOFT)
	_setup_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_setup_hint)

	_setup_start = make_button("START", ORANGE)
	_setup_start.pressed.connect(on_start)
	box.add_child(_setup_start)

	var back = make_button("BACK", SAND_BUTTON, 13, INK)
	back.pressed.connect(on_menu)
	box.add_child(back)


func build_results():
	var box = make_page()
	_results_page = _page_roots.back()

	var title = make_label("FINAL STANDINGS", 16, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_results_headline = make_label("", 13, ORANGE_DARK)
	_results_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_results_headline)

	_results_list = VBoxContainer.new()
	_results_list.add_theme_constant_override("separation", 4)
	box.add_child(_results_list)

	var again = make_button("PLAY AGAIN", GREEN)
	again.pressed.connect(on_play_again)
	box.add_child(again)

	var back = make_button("MENU", SAND_BUTTON, 13, INK)
	back.pressed.connect(on_menu)
	box.add_child(back)


func make_page():
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	_pages.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_roots.append(center)

	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(236, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(0)
	style.set_border_width_all(4)
	style.border_color = CREAM_EDGE
	style.shadow_color = Color(0.22, 0.13, 0.04, 0.30)
	style.shadow_size = 3
	style.shadow_offset = Vector2(4, 5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	return box


func make_label(text, size, color, outline = Color(0, 0, 0, 0)):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if outline.a > 0:
		label.add_theme_constant_override("outline_size", 7)
		label.add_theme_color_override("font_outline_color", outline)
	return label


func make_button(text, background, size = 15, text_color = Color.WHITE):
	var button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_stylebox_override("normal", button_style(background, background.darkened(0.30)))
	button.add_theme_stylebox_override("hover", button_style(background.lightened(0.10), background.darkened(0.30)))
	button.add_theme_stylebox_override("pressed", button_style(background.darkened(0.12), background.darkened(0.34)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func button_style(background, edge):
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(0)
	style.border_width_bottom = 4
	style.border_color = edge
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func field_style(edge):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.75)
	style.set_corner_radius_all(0)
	style.set_border_width_all(2)
	style.border_color = edge
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func make_result_row(row):
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)

	var place = make_label(_place_text(int(row.get("place", 1))), 11, INK_SOFT)
	place.custom_minimum_size = Vector2(28, 0)
	line.add_child(place)

	var name_label = make_label(String(row.get("name", "")), 13, INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)

	var score_label = make_label(str(int(row.get("score", 0))), 15, ORANGE_DARK)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(score_label)

	return line


func on_play():
	solo_pressed.emit()


func on_tournament():
	tournament_pressed.emit()


func on_reset_powers():
	reset_powers_pressed.emit()


func on_retry():
	game_over_primary.emit()


func on_menu():
	menu_pressed.emit()


func on_play_again():
	play_again_pressed.emit()


func on_name_submitted(_text):
	_add_draft_player()


func on_add():
	_add_draft_player()


func on_start():
	if _draft.size() < 2:
		return
	tournament_started.emit(_draft)


func _add_draft_player():
	if _draft.size() >= MAX_PLAYERS:
		_setup_name.text = ""
		return
	var name = _setup_name.text.strip_edges()
	if name == "":
		name = "PLAYER %d" % (_draft.size() + 1)
	name = name.to_upper()

	var final_name = name
	var suffix = 2
	while _draft.has(final_name):
		final_name = "%s %d" % [name.substr(0, 8), suffix]
		suffix = suffix + 1

	_draft.append(final_name)
	_setup_name.text = ""
	_rebuild_draft()


func _remove_draft_player(index):
	if index < 0 or index >= _draft.size():
		return
	_draft.remove_at(index)
	_rebuild_draft()


func _rebuild_draft():
	for child in _setup_list.get_children():
		_setup_list.remove_child(child)
		child.queue_free()

	if _draft.is_empty():
		var empty = make_label("NO PLAYERS YET", 10, INK_SOFT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_setup_list.add_child(empty)
	else:
		for i in range(_draft.size()):
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)

			var name_label = make_label("%d. %s" % [i + 1, _draft[i]], 13, INK)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)

			var remove_button = make_button("X", SAND_BUTTON, 10, INK)
			remove_button.custom_minimum_size = Vector2(24, 22)
			remove_button.size_flags_horizontal = Control.SIZE_SHRINK_END
			remove_button.pressed.connect(_remove_draft_player.bind(i))
			row.add_child(remove_button)

			_setup_list.add_child(row)

	_setup_start.disabled = _draft.size() < 2
	if _draft.size() < 2:
		_setup_hint.text = "ADD AT LEAST 2 PLAYERS"
	else:
		_setup_hint.text = "%d PLAYERS READY" % _draft.size()


func _place_text(place):
	if place == 1:
		return "1ST"
	if place == 2:
		return "2ND"
	if place == 3:
		return "3RD"
	return "%dTH" % place


func _show_page(page):
	for root in _page_roots:
		root.visible = false
	_overlay.visible = true
	page.visible = true


func _hide_pages():
	for root in _page_roots:
		root.visible = false
	_overlay.visible = false


func _set_score_size(size):
	_score_label.add_theme_font_size_override("font_size", int(size))


func _start_pulse():
	_stop_pulse()
	_ready_prompt.modulate = Color(1, 1, 1, 1)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_ready_prompt, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_ready_prompt, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _stop_pulse():
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	_ready_prompt.modulate = Color(1, 1, 1, 1)
