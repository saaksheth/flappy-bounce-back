extends SceneTree

const STATE_MENU = 0
const STATE_READY = 1
const STATE_PLAYING = 2
const STATE_DYING = 3
const STATE_OVER = 4
const STATE_SETUP = 5
const STATE_RESULTS = 6

var _passed = 0
var _failed = 0


func _initialize():
	_run.call_deferred()


func _run():
	print("--- smoke test start ---")

	_check(String(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport",
		"the game renders at its native resolution")
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"upscaling uses nearest-neighbour")
	_check(Pixel.ellipse_rows(Vector2.ZERO, Vector2(4, 4)).size() > 0,
		"pixel shapes rasterise")

	_check(BirdMods.MAX_TOTAL == BirdMods.DEFS.size() * BirdMods.MAX_LEVEL,
		"mod table matches the advertised total")
	var fresh = BirdMods.new()
	var first = fresh.grant()
	_check(String(first.get("id", "")) == "bounce", "the first death grants a bounce")
	for i in range(BirdMods.MAX_TOTAL - 1):
		fresh.grant()
	_check(fresh.is_maxed(), "eighteen deaths max the bird out")
	_check(fresh.grant().is_empty(), "a maxed bird stops earning mods")
	var round_trip = BirdMods.new()
	round_trip.from_dict(fresh.to_dict())
	_check(round_trip.total_levels() == BirdMods.MAX_TOTAL, "the loadout survives a save round trip")
	var wiped = BirdMods.new()
	wiped.grant()
	wiped.grant()
	wiped.reset()
	_check(wiped.total_levels() == 0 and wiped.rotation == 0, "the loadout can be wiped")

	var packed = load("res://scenes/main.tscn")
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return

	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var ui = game.ui
	var bird = game.bird
	_check(game.state == STATE_MENU, "starts on the menu")
	_check(ui._menu_page.visible, "menu card is visible")
	_check(not ui._hud.visible, "hud hidden on the menu")
	var mods_at_start = game.mods.total_levels()
	_check(ui._menu_evolution.text.contains("/"), "menu shows evolution progress")

	_check(InputMap.has_action("flap"), "flap action exists")
	_check(InputMap.action_get_events("flap").size() == 3, "flap has space / W / up events")
	var space = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.keycode = KEY_SPACE
	space.pressed = true
	_check(space.is_action_pressed("flap"), "space triggers the flap action")

	await _press_space()
	_check(game.state == STATE_MENU, "space on the menu does not start a game")

	var play_button = _find_button(ui._menu_page, "PLAY")
	_check(play_button != null, "PLAY button exists")
	play_button.pressed.emit()
	await process_frame
	_check(game.state == STATE_READY, "PLAY opens the ready state")
	_check(ui._ready_box.visible, "ready prompt is visible")
	_check(not ui._menu_page.visible, "menu hidden while ready")

	await _press_space()
	await physics_frame
	_check(game.state == STATE_PLAYING, "space starts the round")

	await _autoplay(game, 2, 900)
	_check(game.score >= 2, "autopilot scores through pipes (score=%d)" % game.score)
	_check(ui._score_label.text == str(game.score), "hud score matches the score")
	_check(game.pipes.get_child_count() <= 4, "old pipes are recycled")

	game.bird.bounces_left = 1
	game.bird.position.y = 330
	game.bird.velocity = Vector2.ZERO
	var bounced = false
	for i in range(400):
		if game.state != STATE_PLAYING:
			break
		if game.bird.bounces_left == 0:
			bounced = true
			break
		await physics_frame
	_check(bounced, "the bird spends a bounce instead of dying")
	_check(game.state == STATE_PLAYING, "a bounce keeps the run alive")
	_check(game.bird.collision_mask == 0, "a bounce grants a moment of invulnerability")

	game.bird.bounces_left = 0
	game._grace = 0
	game.bird.collision_mask = Bird.LAYER_ALL

	for i in range(700):
		if game.state == STATE_OVER:
			break
		await physics_frame
	_check(game.state == STATE_OVER, "bird dies and the round settles")
	_check(ui._over_page.visible, "game over card is visible")
	_check(game.best >= game.score, "best score updated")
	_check(FileAccess.file_exists("user://flappy_best.cfg"), "best score is saved")
	_check(ui._over_primary.text == "RETRY", "solo game over offers retry")
	_check(game.mods.total_levels() == mods_at_start + 1 or mods_at_start == BirdMods.MAX_TOTAL,
		"a death grants one mod level")
	_check(ui._over_mod.visible, "game over announces the upgrade")
	_check(ui._over_title.text == "BOUNCE BACK", "game over celebrates the bounce back")
	var saved = ConfigFile.new()
	_check(saved.load("user://flappy_best.cfg") == OK and saved.has_section_key("mods", "loadout"),
		"the loadout is saved with the best score")

	ui._over_primary.pressed.emit()
	await process_frame
	_check(game.state == STATE_READY, "retry returns to the ready state")
	_check(game.score == 0, "retry resets the score")
	_check(game.pipes.get_child_count() == 0, "retry clears old pipes")
	_check(game.bird.bounces_left == game.mods.bounces(), "retry re-equips the mods")
	_check(is_equal_approx(game.bird.gravity, Bird.GRAVITY * game.mods.gravity_scale()),
		"mods change the bird's fall speed")
	_check(ui._ready_mods.text == game.mods.summary(), "ready screen shows the loadout")

	var back_button = _find_button(ui._over_page, "MENU")
	_check(back_button != null, "menu button exists on game over")

	var tournament_button = _find_button(ui._menu_page, "TOURNAMENT")
	_check(tournament_button != null, "TOURNAMENT button exists")
	game._enter_menu()
	await process_frame
	game._on_tournament_pressed()
	await process_frame
	_check(game.state == STATE_SETUP, "tournament opens the setup state")
	_check(is_equal_approx(game.bird.gravity, Bird.GRAVITY), "the tournament bird is stock")
	_check(game.bird.bounces_left == 0, "the tournament has no free bounces")
	_check(ui._setup_page.visible, "setup card is visible")

	ui._setup_name.text = "ada"
	ui._add_draft_player()
	ui._setup_name.text = "grace"
	ui._add_draft_player()
	ui._setup_name.text = "linus"
	ui._add_draft_player()
	_check(ui._draft.size() == 3, "three players added")
	_check(ui._draft[0] == "ADA", "player names are normalised")
	_check(not ui._setup_start.disabled, "start enabled with 3 players")

	ui._setup_start.pressed.emit()
	await process_frame
	_check(game.state == STATE_READY, "tournament starts at player 1")
	_check(game._scores.size() == 3, "one score slot per player")
	_check(ui._ready_name.text == "ADA", "ready screen names player 1")

	await _press_space()
	await _autoplay(game, 1, 600)
	for i in range(700):
		if game.state == STATE_OVER:
			break
		await physics_frame
	_check(game.state == STATE_OVER, "player 1 round ends")
	_check(ui._over_primary.text == "NEXT PLAYER", "player 1 hands over to player 2")
	_check(ui._over_player.text == "ADA", "game over names the player")

	ui._over_primary.pressed.emit()
	await process_frame
	_check(game.state == STATE_READY, "player 2 gets their turn")
	_check(ui._ready_name.text == "GRACE", "ready screen names player 2")

	await _press_space()
	for i in range(700):
		if game.state == STATE_OVER:
			break
		await physics_frame
	_check(game.state == STATE_OVER, "player 2 round ends")
	_check(ui._over_primary.text == "NEXT PLAYER", "player 2 hands over to player 3")

	ui._over_primary.pressed.emit()
	await process_frame
	_check(ui._ready_name.text == "LINUS", "ready screen names player 3")
	await _press_space()
	for i in range(700):
		if game.state == STATE_OVER:
			break
		await physics_frame
	_check(ui._over_primary.text == "SHOW RESULTS", "last player sees results action")

	ui._over_primary.pressed.emit()
	await process_frame
	_check(game.state == STATE_RESULTS, "results screen shown")
	_check(ui._results_page.visible, "results card is visible")
	_check(ui._results_list.get_child_count() == 3, "every player is ranked")
	_check(ui._results_headline.text.begins_with("WINNER:") or
		ui._results_headline.text.begins_with("TIED:"), "results name a winner")
	print("    headline: ", ui._results_headline.text)

	var again = _find_button(ui._results_page, "PLAY AGAIN")
	again.pressed.emit()
	await process_frame
	_check(game.state == STATE_READY, "play again restarts the tournament")
	_check(game._scores.size() == 3 and game._scores[0] == 0, "scores reset for a rematch")
	_check(ui._ready_name.text == "ADA", "rematch starts with the first player")

	var save_backup = FileAccess.get_file_as_bytes("user://flappy_best.cfg")
	var maxed_levels = {}
	for def in BirdMods.DEFS:
		maxed_levels[String(def["id"])] = BirdMods.MAX_LEVEL
	game.mods.from_dict({"levels": maxed_levels, "rotation": 0})
	_check(game.mods.total_levels() == BirdMods.MAX_TOTAL, "the loadout can be maxed out")
	game._enter_menu()
	await process_frame
	game._on_solo_pressed()
	await process_frame
	_check(game.state == STATE_READY, "the evolved bird is ready to fly")
	_check(game.bird.gravity < Bird.GRAVITY, "light bones slow the fall")
	_check(game.bird.bounces_left == BirdMods.MAX_LEVEL, "every bounce is banked")
	_check(game._gap_scale > 1, "wide gates open the pipes up")
	_check(ui._ready_mods.text.begins_with("6 MODS"), "ready screen shows the maxed loadout")
	await _press_space()
	await _autoplay(game, 3, 1500)
	_check(game.score >= 3, "an evolved bird still fits through pipes (score=%d)" % game.score)

	game._enter_menu()
	await process_frame
	_check(ui._menu_evolution.text.contains("18 / 18"), "menu shows the maxed evolution")
	var reset_button = _find_button(ui._menu_page, "RESET POWER-UPS")
	_check(reset_button != null, "reset power-ups button exists")
	var best_before_reset = game.best
	reset_button.pressed.emit()
	await process_frame
	_check(game.mods.total_levels() == 0, "reset power-ups clears every mod")
	_check(ui._menu_evolution.text.contains("0 / 18"), "menu evolution resets to zero")
	_check(game.best == best_before_reset, "reset keeps the best score")
	_check(is_equal_approx(game.bird.gravity, Bird.GRAVITY), "reset removes the old bird upgrades")
	var reset_config = ConfigFile.new()
	var reset_saved = reset_config.load("user://flappy_best.cfg") == OK
	var reset_levels = {}
	if reset_saved:
		reset_levels = reset_config.get_value("mods", "loadout", {}).get("levels", {})
	var reset_total = 0
	for def in BirdMods.DEFS:
		reset_total = reset_total + int(reset_levels.get(def["id"], 0))
	_check(reset_saved and reset_total == 0, "reset power-ups is saved")

	if save_backup.size() > 0:
		var restore = FileAccess.open("user://flappy_best.cfg", FileAccess.WRITE)
		restore.store_buffer(save_backup)
		restore.close()

	game._enter_menu()
	await process_frame
	_check(game.state == STATE_MENU, "menu reachable again")
	_check(bird.position.distance_to(Vector2(72, 232)) < 20, "bird idles on the start pad")

	for sound in game.get_node("Sounds").get_children():
		sound.stop()
	game.queue_free()
	await process_frame
	_finish()


func _autoplay(game, target_score, max_frames):
	for i in range(max_frames):
		if game.state != STATE_PLAYING or game.score >= target_score:
			return
		_autopilot(game)
		await physics_frame


func _autopilot(game):
	var bird = game.bird
	var gap_center = 210.0
	var gap_height = PipePair.GAP_HEIGHT
	var nearest = null
	for child in game.pipes.get_children():
		var pipe = child as PipePair
		if pipe == null:
			continue
		if pipe.position.x + PipePair.PIPE_WIDTH / 2 > bird.position.x - 12:
			if nearest == null or pipe.position.x < nearest.position.x:
				nearest = pipe
	if nearest != null:
		gap_center = nearest.gap_center
		gap_height = nearest.gap_height()

	var room = gap_height / 2 - 12
	var rise = (bird.flap_speed * bird.flap_speed) / (2 * bird.gravity)
	var target = gap_center + clamp(rise - room + 8, 4, room - 4)
	if bird.position.y > target:
		game._flap()


func _press_space():
	var down = InputEventKey.new()
	down.physical_keycode = KEY_SPACE
	down.keycode = KEY_SPACE
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up = InputEventKey.new()
	up.physical_keycode = KEY_SPACE
	up.keycode = KEY_SPACE
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _find_button(node, text):
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found = _find_button(child, text)
		if found != null:
			return found
	return null


func _check(condition, label):
	if condition:
		_passed = _passed + 1
		print("PASS  ", label)
	else:
		_failed = _failed + 1
		print("FAIL  ", label)


func _finish():
	print("--- smoke test done: %d passed, %d failed ---" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)
