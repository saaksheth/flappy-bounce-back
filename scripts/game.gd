extends Node2D

const MENU = 0
const READY = 1
const PLAYING = 2
const DYING = 3
const OVER = 4
const SETUP = 5
const RESULTS = 6

const GROUND_TOP = 416.0
const PIPE_SPEED = 135.0
const PIPE_INTERVAL = 1.55
const PIPE_CENTER_MIN = 142.0
const PIPE_CENTER_MAX = 294.0
const SPAWN_X = 340.0
const READY_POS = Vector2(72, 232)
const FIRST_PIPE_DELAY = 0.85
const LAND_DELAY = 0.45
const BOUNCE_GRACE = 0.5
const BEST_PATH = "user://flappy_best.cfg"
const ENTER_KEYS = [KEY_ENTER, KEY_KP_ENTER]

@onready var background = $Background
@onready var pipes = $Pipes
@onready var bird = $Bird
@onready var ground = $Ground
@onready var ui = $UI
@onready var flap_sound = $Sounds/Flap
@onready var score_sound = $Sounds/Score
@onready var hit_sound = $Sounds/Hit
@onready var die_sound = $Sounds/Die

var state = MENU
var score = 0
var best = 0
var mods = BirdMods.new()

var _gap_scale = 1.0
var _speed_scale = 1.0
var _grace = 0.0
var _last_upgrade = {}

var _rng = RandomNumberGenerator.new()
var _spawn_timer = 0.0
var _land_timer = 0.0
var _landed = false

var _tournament = false
var _players = []
var _scores = []
var _current = 0


func _ready():
	_rng.randomize()
	_load_progress()
	ui.solo_pressed.connect(_on_solo_pressed)
	ui.tournament_pressed.connect(_on_tournament_pressed)
	ui.reset_powers_pressed.connect(_on_reset_powers_pressed)
	ui.game_over_primary.connect(_on_game_over_primary)
	ui.menu_pressed.connect(_enter_menu)
	ui.play_again_pressed.connect(_restart_tournament)
	ui.tournament_started.connect(_on_tournament_started)
	_enter_menu()


func _unhandled_input(event):
	if event is InputEventKey and _is_fullscreen_toggle(event):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return

	var tapped = false
	if event.is_action_pressed("flap"):
		tapped = true
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tapped = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			tapped = true
	if not tapped:
		return
	get_viewport().set_input_as_handled()
	_on_tap()


func _is_fullscreen_toggle(key):
	if not key.pressed or key.echo:
		return false
	if key.physical_keycode == KEY_F11 or key.keycode == KEY_F11:
		return true
	if not key.alt_pressed:
		return false
	if key.keycode in ENTER_KEYS:
		return true
	if key.physical_keycode in ENTER_KEYS:
		return true
	return false


func _toggle_fullscreen():
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var mode = DisplayServer.window_get_mode()
	var is_full = false
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		is_full = true
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		is_full = true
	if is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_tap():
	if state == READY:
		_start_playing()
	elif state == PLAYING:
		_flap()
	elif state == OVER:
		if not _tournament:
			_start_ready()


func _physics_process(delta):
	if state == PLAYING:
		if _grace > 0:
			_grace = _grace - delta
			if _grace <= 0:
				_grace = 0
				bird.collision_mask = Bird.LAYER_ALL
		if bird.step(delta) != null:
			if not _try_bounce():
				_kill()
	elif state == DYING:
		if bird.step(delta) != null and not _landed:
			_landed = true
			_land_timer = LAND_DELAY


func _process(delta):
	if state == PLAYING:
		_spawn_timer = _spawn_timer - delta
		if _spawn_timer <= 0:
			_spawn_pipe()
			_spawn_timer = _spawn_timer + PIPE_INTERVAL / max(_speed_scale, 0.25)
		_move_pipes(delta)
	elif state == DYING:
		if _landed:
			_land_timer = _land_timer - delta
			if _land_timer <= 0:
				_show_game_over()


func _enter_menu():
	state = MENU
	_tournament = false
	_current = 0
	score = 0
	_landed = false
	_grace = 0
	_last_upgrade = {}
	_clear_pipes()
	ground.scrolling = true
	background.speed_scale = 1
	bird.reset(READY_POS)
	_apply_loadout()
	ui.hide_ready()
	ui.set_hud_visible(false)
	ui.set_score(0)
	ui.show_menu(best, mods.total_levels(), BirdMods.MAX_TOTAL)


func _on_solo_pressed():
	_tournament = false
	_current = 0
	_start_ready()


func _on_reset_powers_pressed():
	if state != MENU:
		return
	mods.reset()
	_save_progress()
	_enter_menu()


func _start_ready():
	state = READY
	score = 0
	_landed = false
	_land_timer = 0
	_grace = 0
	_clear_pipes()
	ground.scrolling = true
	background.speed_scale = 1
	bird.reset(READY_POS)
	_apply_loadout()
	ui.set_score(0)
	ui.set_hud_visible(true)

	var player_name = ""
	var hint = "SPACE · CLICK · TAP TO FLAP"
	if _tournament:
		player_name = _players[_current]
		hint = "PLAYER %d OF %d" % [_current + 1, _players.size()]

	if _tournament:
		ui.show_ready(player_name, hint, "")
	else:
		ui.show_ready(player_name, hint, mods.summary())


func _start_playing():
	state = PLAYING
	_spawn_timer = FIRST_PIPE_DELAY
	bird.begin_play()
	ui.hide_ready()
	_flap()


func _flap():
	bird.flap()
	flap_sound.play()


func _kill():
	state = DYING
	_grace = 0
	bird.die()
	ground.scrolling = false
	background.speed_scale = 0
	hit_sound.play()
	die_sound.play()
	ui.flash()


func _show_game_over():
	state = OVER
	var new_best = false
	if score > best:
		new_best = true
		best = score

	_last_upgrade = {}
	if not _tournament:
		_last_upgrade = mods.grant()
	if new_best or not _tournament:
		_save_progress()

	var mod_line = ""
	var mod_desc = ""
	if not _tournament:
		if _last_upgrade.is_empty():
			mod_line = "BIRD FULLY EVOLVED"
			mod_desc = "EVERY MOD AT LV %d" % BirdMods.MAX_LEVEL
		else:
			mod_line = "NEW MOD · %s LV %d" % [String(_last_upgrade["name"]), int(_last_upgrade["level"])]
			mod_desc = String(_last_upgrade["desc"])

	var player_label = ""
	var note = ""
	var primary = "RETRY"
	if _tournament:
		_scores[_current] = score
		player_label = _players[_current]
		note = "PLAYER %d OF %d" % [_current + 1, _players.size()]
		if _current + 1 < _players.size():
			primary = "NEXT PLAYER"
		else:
			primary = "SHOW RESULTS"

	ui.show_game_over(score, best, new_best, player_label, note, primary, mod_line, mod_desc)


func _on_game_over_primary():
	if state != OVER:
		return
	if not _tournament:
		_start_ready()
	elif _current + 1 < _players.size():
		_current = _current + 1
		_start_ready()
	else:
		_show_results()


func _on_tournament_pressed():
	state = SETUP
	_tournament = true
	score = 0
	_landed = false
	_grace = 0
	_last_upgrade = {}
	_clear_pipes()
	ground.scrolling = true
	background.speed_scale = 1
	bird.reset(READY_POS)
	_apply_loadout()
	ui.hide_ready()
	ui.set_hud_visible(false)
	ui.show_setup(_players)


func _on_tournament_started(players):
	if players.size() < 2:
		return
	_players = players.duplicate()
	_scores = []
	for i in range(_players.size()):
		_scores.append(0)
	_tournament = true
	_current = 0
	_start_ready()


func _restart_tournament():
	if _players.size() < 2:
		_enter_menu()
		return
	_scores = []
	for i in range(_players.size()):
		_scores.append(0)
	_tournament = true
	_current = 0
	_start_ready()


func _show_results():
	state = RESULTS
	var rows = []
	for i in range(_players.size()):
		rows.append({"name": _players[i], "score": _scores[i], "place": 1})

	for row in rows:
		var place = 1
		for other in rows:
			if int(other["score"]) > int(row["score"]):
				place = place + 1
		row["place"] = place

	rows.sort_custom(_sort_rows_desc)

	var top_score = int(rows[0]["score"])
	var winners = []
	for row in rows:
		if int(row["score"]) == top_score:
			winners.append(String(row["name"]))

	var headline = "WINNER: " + winners[0]
	if winners.size() > 1:
		headline = "TIED: " + " & ".join(winners)

	ui.hide_ready()
	ui.set_hud_visible(false)
	ui.show_results(rows, headline)


func _sort_rows_desc(a, b):
	if int(a["score"]) != int(b["score"]):
		return int(a["score"]) > int(b["score"])
	return String(a["name"]) < String(b["name"])


func _apply_loadout():
	if _tournament:
		_gap_scale = 1
		_speed_scale = 1
		bird.apply_mods(1, 1, 1, 0, 0)
	else:
		_gap_scale = mods.gap_scale()
		_speed_scale = mods.speed_scale()
		bird.apply_mods(mods.gravity_scale(), mods.flap_scale(), mods.hitbox_scale(), mods.bounces(), mods.total_levels())


func _try_bounce():
	if _tournament:
		return false
	if not bird.bounce():
		return false
	_grace = BOUNCE_GRACE
	bird.collision_mask = 0
	flap_sound.play()
	ui.flash(Color("#9beeff"), 0.34)
	return true


func _clear_pipes():
	for pair in pipes.get_children():
		pipes.remove_child(pair)
		pair.queue_free()


func _spawn_pipe():
	var pair = PipePair.new()
	pair.configure(_rng.randf_range(PIPE_CENTER_MIN, PIPE_CENTER_MAX), _gap_scale)
	pair.position = Vector2(SPAWN_X, 0)
	pipes.add_child(pair)


func _move_pipes(delta):
	for pair in pipes.get_children():
		var pipe = pair as PipePair
		if pipe == null:
			continue
		pipe.position.x = pipe.position.x - PIPE_SPEED * _speed_scale * delta
		if not pipe.scored and pipe.position.x + PipePair.PIPE_WIDTH / 2 < bird.position.x:
			pipe.scored = true
			score = score + 1
			ui.set_score(score)
			score_sound.play()
		if pipe.position.x < -80:
			pipes.remove_child(pipe)
			pipe.queue_free()


func _load_progress():
	var config = ConfigFile.new()
	if config.load(BEST_PATH) != OK:
		return
	best = int(config.get_value("scores", "best", 0))
	if best < 0:
		best = 0
	mods.from_dict(config.get_value("mods", "loadout", {}))


func _save_progress():
	var config = ConfigFile.new()
	config.load(BEST_PATH)
	config.set_value("scores", "best", best)
	config.set_value("mods", "loadout", mods.to_dict())
	config.save(BEST_PATH)
