extends Node2D
## A self-contained, asset-free arcade game. All distances are logical pixels.
const FIELD := Rect2(52, 122, 856, 448)
const SPEED := 290.0
const PLAYER_RADIUS := 18.0
const GOAL := 20
const ROUND_SECONDS := 60.0
const NAVY := Color("10203a")
const BLUE := Color("87cce8")
const ORANGE := Color("ffab67")
const CREAM := Color("fff5df")
const MUTED := Color("a2b5c9")
enum Phase { TITLE, PLAYING, PAUSED, OVER, WON }
var phase := Phase.TITLE
var player := FIELD.get_center()
var beans: Array[Vector2] = []
var obstacles: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var score := 0
var best := 0
var lives := 3
var remaining := ROUND_SECONDS
var invincible := 0.0
var elapsed := 0.0
var shake := 0.0
var font: Font = ThemeDB.fallback_font
var sound_enabled := true
var audio: AudioStreamPlayer

func _ready() -> void:
	rng.randomize()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	var saved := ConfigFile.new()
	if saved.load("user://coffee_run.cfg") == OK:
		best = maxi(0, int(saved.get_value("score", "best", 0)))
	queue_redraw()

func start_game(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	phase = Phase.PLAYING
	player = FIELD.get_center()
	score = 0
	lives = 3
	remaining = ROUND_SECONDS
	invincible = 1.5
	elapsed = 0.0
	shake = 0.0
	particles.clear()
	beans.clear()
	obstacles.clear()
	for i in range(4):
		var pos := Vector2(130 + i * 230, 180 if i % 2 == 0 else 510)
		obstacles.append({"pos": pos, "vel": Vector2(85 + i * 12, 65 - i * 7) * (-1 if i % 2 else 1)})
	for i in range(5):
		spawn_bean()
	queue_redraw()

func spawn_bean() -> void:
	# Try random positions, then a grid fallback. Never create an unavoidable pickup.
	for attempt in range(160):
		var p := Vector2(rng.randf_range(82, 878), rng.randf_range(152, 540))
		if safe_bean_position(p):
			beans.append(p)
			return
	for y in range(155, 540, 45):
		for x in range(85, 878, 45):
			var p := Vector2(x, y)
			if safe_bean_position(p):
				beans.append(p)
				return

func safe_bean_position(p: Vector2) -> bool:
	if p.distance_to(player) < 65:
		return false
	for obstacle in obstacles:
		if p.distance_to(obstacle.pos) < 70:
			return false
	for bean in beans:
		if p.distance_to(bean) < 48:
			return false
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M:
		sound_enabled = not sound_enabled
	elif event.keycode in [KEY_ENTER, KEY_SPACE]:
		if phase in [Phase.TITLE, Phase.OVER, Phase.WON]:
			start_game()
	elif event.keycode == KEY_R:
		start_game()
	elif event.keycode in [KEY_ESCAPE, KEY_P]:
		if phase == Phase.PLAYING:
			phase = Phase.PAUSED
		elif phase == Phase.PAUSED:
			phase = Phase.PLAYING
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == Phase.PLAYING:
		phase = Phase.PAUSED
		queue_redraw()

func _process(delta: float) -> void:
	if phase == Phase.PLAYING:
		var direction := Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
		# Bound catch-up to avoid teleporting after a long OS stall; substeps prevent tunneling.
		var step_left := minf(delta, 0.1)
		while step_left > 0.00001 and phase == Phase.PLAYING:
			var step := minf(step_left, 1.0 / 120.0)
			simulate(step, direction)
			step_left -= step
	queue_redraw()

func simulate(delta: float, direction: Vector2) -> void:
	if phase != Phase.PLAYING:
		return
	elapsed += delta
	remaining = maxf(0, remaining - delta)
	invincible = maxf(0, invincible - delta)
	shake = maxf(0, shake - delta)
	player += direction.limit_length() * SPEED * delta
	player = player.clamp(FIELD.position + Vector2.ONE * 24, FIELD.end - Vector2.ONE * 24)
	for obstacle in obstacles:
		var pos: Vector2 = obstacle.pos + obstacle.vel * delta * (1 + score * 0.024)
		if pos.x < 78 or pos.x > 882:
			obstacle.vel.x *= -1
		if pos.y < 148 or pos.y > 544:
			obstacle.vel.y *= -1
		obstacle.pos = pos.clamp(Vector2(78, 148), Vector2(882, 544))
		if invincible <= 0 and player.distance_to(obstacle.pos) < PLAYER_RADIUS + 22:
			lives -= 1
			invincible = 1.5
			shake = 0.22
			burst(player, ORANGE)
			tone(150, 0.12)
			if lives <= 0:
				finish(false)
				return
	for i in range(beans.size() - 1, -1, -1):
		if player.distance_to(beans[i]) < PLAYER_RADIUS + 12:
			burst(beans[i], Color("ffc97f"))
			beans.remove_at(i)
			score += 1
			tone(550 + score * 18, 0.075)
			if score >= GOAL:
				finish(true)
				return
			spawn_bean()
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].pos += particles[i].vel * delta
		if particles[i].life <= 0:
			particles.remove_at(i)
	if remaining <= 0:
		finish(false)

func finish(won: bool) -> void:
	phase = Phase.WON if won else Phase.OVER
	if score > best:
		best = score
		var saved := ConfigFile.new()
		saved.set_value("score", "best", best)
		if saved.save("user://coffee_run.cfg") != OK:
			push_warning("Could not save best score; this run is still playable.")

func burst(p: Vector2, color: Color) -> void:
	for i in range(10):
		particles.append({"pos": p, "vel": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(45, 150), "life": 0.45, "color": color})

func tone(hz: float, duration: float) -> void:
	if not sound_enabled or not is_instance_valid(audio):
		return
	var data := PackedByteArray()
	var count := int(22050 * duration)
	data.resize(count * 2)
	for i in range(count):
		var value := int(sin(TAU * hz * i / 22050.0) * 6500 * (1.0 - float(i) / count))
		data.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = data
	audio.stream = wav
	audio.play()

func label(text: String, p: Vector2, size: int, color: Color = CREAM) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(text: String, y: float, size: int, color: Color = CREAM) -> void:
	label(text, Vector2((960 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), size, color)

func panel(rect: Rect2, color: Color, radius: int = 18) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func bean(p: Vector2) -> void:
	draw_circle(p + Vector2(0, 4), 15, Color(0, 0, 0, 0.16))
	draw_set_transform(p, -0.45, Vector2(0.75, 1))
	draw_circle(Vector2.ZERO, 15, ORANGE)
	draw_arc(Vector2(-9, 0), 11, -1.2, 1.2, 12, Color("805036"), 3, true)
	draw_set_transform(Vector2.ZERO)

func dog(p: Vector2, scale_factor: float = 1.0) -> void:
	draw_set_transform(p, 0, Vector2.ONE * scale_factor)
	draw_circle(Vector2(0, 14), 24, Color(0, 0, 0, 0.2))
	draw_circle(Vector2(-22, 4), 12, Color("d9eafa"))
	draw_circle(Vector2(-22, 1), 8, CREAM)
	draw_circle(Vector2.ZERO, 23, CREAM)
	draw_colored_polygon(PackedVector2Array([Vector2(-21,-10), Vector2(-19,-35), Vector2(-3,-18)]), CREAM)
	draw_colored_polygon(PackedVector2Array([Vector2(21,-10), Vector2(19,-35), Vector2(3,-18)]), CREAM)
	draw_colored_polygon(PackedVector2Array([Vector2(-17,-15), Vector2(-17,-27), Vector2(-9,-18)]), Color("e4b7a0"))
	draw_colored_polygon(PackedVector2Array([Vector2(17,-15), Vector2(17,-27), Vector2(9,-18)]), Color("e4b7a0"))
	draw_circle(Vector2(-9,-5), 3, NAVY)
	draw_circle(Vector2(9,-5), 3, NAVY)
	draw_circle(Vector2(0,3), 4, NAVY)
	draw_arc(Vector2(0,6), 7, 0.15, PI - 0.15, 12, NAVY, 2, true)
	panel(Rect2(-17, 17, 34, 8), BLUE, 4)
	draw_circle(Vector2(0,22), 4, ORANGE)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), NAVY)
	label("BOOMBOT", Vector2(52, 48), 15, ORANGE)
	label("Coffee Run", Vector2(52, 86), 32)
	label("BEANS  %02d / %d" % [score, GOAL], Vector2(336, 67), 23, ORANGE)
	label("%02d:%02d" % [int(ceil(remaining)) / 60, int(ceil(remaining)) % 60], Vector2(590, 67), 27)
	label("LIVES  " + str(lives), Vector2(757, 67), 22, BLUE)
	panel(FIELD, Color("1b3550"), 22)
	for x in range(76, 900, 32):
		for y in range(146, 560, 32):
			draw_circle(Vector2(x, y), 1, Color("29465f"))
	for p in beans:
		bean(p + Vector2(0, sin(elapsed * 4 + p.x) * 2))
	for obstacle in obstacles:
		var p: Vector2 = obstacle.pos
		draw_circle(p + Vector2(0, 5), 25, Color(0, 0, 0, 0.16))
		draw_circle(p, 23, Color("e47c61"))
		draw_arc(p, 15, 0, TAU, 30, Color("ffb89a"), 2, true)
		draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), CREAM, 3, true)
		draw_line(p + Vector2(7, -7), p + Vector2(-7, 7), CREAM, 3, true)
	for particle in particles:
		var col: Color = particle.color
		col.a = particle.life / 0.45
		draw_circle(particle.pos, 3, col)
	if phase != Phase.TITLE and (invincible <= 0 or int(elapsed * 14) % 2 == 0):
		dog(player + Vector2(sin(elapsed * 90) * shake * 15, 0))
	label("WASD / ARROWS  Move     P / ESC  Pause     R  Restart", Vector2(52, 608), 16, MUTED)
	label("M  Sound " + ("on" if sound_enabled else "off"), Vector2(772, 608), 16, MUTED)
	if phase != Phase.PLAYING:
		draw_rect(Rect2(0, 104, 960, 478), Color(0.025, 0.06, 0.12, 0.79))
		panel(Rect2(176, 148, 608, 394), Color("213e58"), 24)
		if phase == Phase.TITLE:
			dog(Vector2(480, 218), 1.6)
			centered("A little dog. A big coffee mission.", 300, 28)
			centered("Collect 20 beans in 60 seconds.", 345, 22, BLUE)
			centered("Dodge the coral hazards. You have 3 lives.", 382, 20, MUTED)
			centered("ARROWS / WASD to move", 422, 18, MUTED)
			centered("ENTER / SPACE to start", 485, 24, ORANGE)
		elif phase == Phase.PAUSED:
			centered("Taking a coffee break", 285, 34)
			centered("P / ESC to resume", 354, 24, ORANGE)
			centered("Your timer is paused.", 402, 20, MUTED)
		else:
			centered("Coffee mission complete!" if phase == Phase.WON else "One more coffee run?", 265, 34)
			centered("%d / %d beans collected" % [score, GOAL], 326, 28, ORANGE)
			centered("Best run: %d beans" % best, 371, 22, BLUE)
			centered("ENTER / SPACE / R to play again", 460, 22)
