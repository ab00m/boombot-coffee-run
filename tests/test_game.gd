extends SceneTree
var checks := 0
var failures := 0
const Game = preload("res://scripts/game.gd")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var game = Game.new()
	root.add_child(game)
	game.set_process(false)
	game.sound_enabled = false
	check(game.phase == Game.Phase.TITLE, "starts on title")
	game.start_game(42)
	check(game.beans.size() == 5 and game.obstacles.size() == 4, "spawn counts")
	var original: Array = game.beans.duplicate()
	game.start_game(42)
	check(game.beans == original, "seeded spawn reproducibility")
	for bean in game.beans:
		check(Game.FIELD.has_point(bean) and bean.distance_to(game.player) >= 65, "safe spawn")
	game.obstacles.clear()
	game.beans.clear()
	var initial: Vector2 = game.player
	for i in range(60):
		game.simulate(1.0 / 60, Vector2.RIGHT)
	check(absf(game.player.x - initial.x - Game.SPEED) < 0.02, "movement distance at 60 fps")
	game.start_game(42)
	game.obstacles.clear()
	game.beans.clear()
	for i in range(120):
		game.simulate(1.0 / 120, Vector2.RIGHT)
	check(absf(game.player.x - initial.x - Game.SPEED) < 0.02, "movement distance at 120 fps")
	game.player = initial
	game.simulate(0.1, Vector2.ONE)
	check(absf(game.player.distance_to(initial) - 29) < 0.01, "diagonal normalized")
	game.player = Vector2(900, 560)
	game.simulate(0.1, Vector2.ONE)
	check(game.player.x <= 884 and game.player.y <= 546, "arena clamp")
	game.start_game(42)
	game.obstacles.clear()
	game.beans.clear()
	game.beans.append(game.player)
	game.simulate(1.0 / 120, Vector2.ZERO)
	check(game.score == 1 and game.beans.size() == 1, "collect and respawn")
	game.obstacles.clear()
	game.obstacles.append({"pos": game.player, "vel": Vector2.ZERO})
	game.invincible = 0
	game.simulate(1.0 / 120, Vector2.ZERO)
	check(game.lives == 2, "collision costs one life")
	for i in range(60):
		game.simulate(1.0 / 120, Vector2.ZERO)
	check(game.lives == 2, "invulnerability prevents repeated damage")
	game.invincible = 0
	game.lives = 1
	game.simulate(1.0 / 120, Vector2.ZERO)
	check(game.phase == Game.Phase.OVER, "zero lives ends game")
	game.start_game(42)
	check(game.lives == 3 and game.score == 0 and game.remaining == 60 and game.particles.is_empty(), "restart resets state")
	game.phase = Game.Phase.PAUSED
	game.simulate(1, Vector2.RIGHT)
	check(game.remaining == 60 and game.player == initial, "pause freezes simulation")
	game.phase = Game.Phase.PLAYING
	game.remaining = 0.001
	game.simulate(1.0 / 120, Vector2.ZERO)
	check(game.phase == Game.Phase.OVER, "timer ends game")
	game.start_game(42)
	game.obstacles.clear()
	game.score = 19
	game.beans.clear()
	game.beans.append(game.player)
	game.simulate(1.0 / 120, Vector2.ZERO)
	check(game.phase == Game.Phase.WON and game.score == 20, "20 beans wins")
	game.start_game(42)
	for i in range(7201):
		game.invincible = 1
		game.simulate(1.0 / 120, Vector2.ZERO)
		for obstacle in game.obstacles:
			if not Game.FIELD.has_point(obstacle.pos):
				check(false, "obstacle escaped arena")
	check(game.phase == Game.Phase.OVER, "full deterministic round completes")
	game.queue_free()
	print("Coffee Run: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
