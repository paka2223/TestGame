extends Node2D

const GameConfig = preload("res://data/game_config.gd")
var game: Variant

func setup(owner: Node) -> void:
	game = owner

func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("19221f"))
	# Inverse isometric projection expands a regular screen viewport into a much wider world rectangle.
	var margin := maxf(view.x / GameConfig.TILE, view.y / GameConfig.TILE) * 1.15
	var start_x := int(game.hero.x - margin)
	var end_x := int(game.hero.x + margin) + 1
	var start_y := int(game.hero.y - margin)
	var end_y := int(game.hero.y + margin) + 1
	for depth in range(start_x + start_y, end_x + end_y):
		for x in range(start_x, end_x):
			var y := depth - x
			if y < start_y or y >= end_y: continue
			var center := game.map_pixel(Vector2(x, y))
			var diamond := PackedVector2Array([center + Vector2(0, -8), center + Vector2(16, 0), center + Vector2(0, 8), center + Vector2(-16, 0)])
			var is_road := x in range(15, 18) or y in range(18, 21)
			var ground := GameConfig.COLORS.road if is_road else (GameConfig.COLORS.grass if (x + y) % 2 == 0 else GameConfig.COLORS.grass_alt)
			draw_colored_polygon(diamond, ground)
			if is_road and (x + y) % 3 == 0:
				draw_line(center + Vector2(-2, 0), center + Vector2(3, 0), GameConfig.COLORS.road_line, 1.5)
	# Sort game.props, landmarks and characters by their depth on the ground plane.
	# This lets the player walk behind a tree or building instead of always floating on top.
	var drawables: Array[Dictionary] = []
	for prop in game.props:
		var p: Vector2 = prop.p
		if absf(p.x - game.hero.x) <= margin and absf(p.y - game.hero.y) <= margin:
			drawables.append({"depth": p.x + p.y, "type": "prop", "data": prop})
	for building in game.buildings:
		var p: Vector2 = building.p
		var size: Vector2 = building.size
		if absf(p.x - game.hero.x) <= margin + 5 and absf(p.y - game.hero.y) <= margin + 5:
			drawables.append({"depth": p.x + p.y + size.x + size.y - 1, "type": "building", "data": building})
	for zombie in game.zombies:
		# Monsters outside the actual world-space lantern radius are fully concealed.
		var zombie_position: Vector2 = zombie.position
		if zombie_position.distance_to(game.hero) <= GameConfig.VISION_TILES:
			drawables.append({"depth": zombie_position.x + zombie_position.y, "type": "zombie", "data": zombie})
	drawables.append({"depth": game.hero.x + game.hero.y, "type": "hero", "data": game.hero})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for item in drawables:
		match item.type:
			"prop": draw_prop(game.map_pixel(item.data.p), item.data.kind)
			"building": draw_building(item.data)
			"zombie":
				draw_character(game.map_pixel(item.data.position), false, item.data.kind, item.data)
			"hero": draw_character(game.map_pixel(item.data), true, "", {})
	draw_attack_indicator()
	draw_hit_effects()
	draw_damage_numbers()
	if game.click_move_active:
		var marker := game.map_pixel(game.move_target)
		draw_shadow_ellipse(marker, Vector2(8, 4), Color(0.84, 0.76, 0.46, 0.5))
		draw_line(marker + Vector2(-8, 0), marker + Vector2(8, 0), Color("e5d192", 0.8), 1)

func draw_prop(center: Vector2, kind: String) -> void:
	draw_shadow_ellipse(center + Vector2(0, 5), Vector2(13, 5), Color(0.04, 0.055, 0.05, 0.65))
	match kind:
		"tree":
			draw_line(center + Vector2(0, -4), center + Vector2(0, -22), Color("443c31"), 6.0, true)
			draw_circle(center + Vector2(-4, -22), 9.0, Color("263b31"))
			draw_circle(center + Vector2(4, -25), 8.0, Color("344a39"))
			draw_circle(center + Vector2(-2, -29), 4.0, Color("526348"))
		"car":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -8), center + Vector2(0, -15), center + Vector2(15, -8), center + Vector2(0, -1)]), Color("465351"))
			draw_rect(Rect2(center + Vector2(-8, -17), Vector2(15, 10)), Color("34413e"))
			draw_rect(Rect2(center + Vector2(-5, -15), Vector2(5, 5)), Color("596663"))
			draw_rect(Rect2(center + Vector2(3, -14), Vector2(4, 5)), Color("594642"))
		_:
			draw_rect(Rect2(center + Vector2(-8, -4), Vector2(16, 5)), Color("555249"))
			draw_rect(Rect2(center + Vector2(-3, -9), Vector2(8, 6)), Color("625c50"))

func draw_building(building: Dictionary) -> void:
	var p: Vector2 = building.p
	var size: Vector2 = building.size
	var building_color: Color = building.color
	var corners := [p + Vector2(-0.5, -0.5), p + Vector2(size.x - 0.5, -0.5), p + size - Vector2(0.5, 0.5), p + Vector2(-0.5, size.y - 0.5)]
	var base := PackedVector2Array()
	for corner in corners: base.append(game.map_pixel(corner))
	var height := 24.0 + size.y * 2.0
	var top := PackedVector2Array()
	for point in base: top.append(point + Vector2(0, -height))
	draw_shadow_ellipse((base[2] + base[3]) * 0.5 + Vector2(0, 6), Vector2(size.x * 17.0, 11), Color(0.04, 0.05, 0.045, 0.75))
	draw_colored_polygon(PackedVector2Array([base[1], base[2], top[2], top[1]]), building_color.darkened(0.32))
	draw_colored_polygon(PackedVector2Array([base[2], base[3], top[3], top[2]]), building_color.darkened(0.18))
	draw_colored_polygon(top, building_color)
	draw_line(top[0], top[1], building_color.lightened(0.12), 2)
	var sign_pos: Vector2 = top[0] + Vector2(0, -3)
	draw_string(ThemeDB.fallback_font, sign_pos, building.name, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color("dfcfac"))
	if building.name == "남산타워":
		var tower_base: Vector2 = (top[0] + top[1] + top[2] + top[3]) / 4.0
		draw_rect(Rect2(tower_base + Vector2(-2, -37), Vector2(4, 34)), Color("756e59"))
		draw_rect(Rect2(tower_base + Vector2(-8, -43), Vector2(16, 8)), Color("b99d67"))
		draw_rect(Rect2(tower_base + Vector2(-2, -50), Vector2(4, 8)), Color("94624f"))

func draw_character(center: Vector2, player: bool, zombie_kind: String, zombie_data: Dictionary) -> void:
	draw_shadow_ellipse(center + Vector2(0, 5), Vector2(11, 4), Color(0.025, 0.03, 0.025, 0.9))
	if player:
		# Muted workwear, layered cloth, a field pack and small face details read as a survivor at game scale.
		draw_line(center + Vector2(4, -17), center + Vector2(6, -7), Color("443b31"), 5.0, true)
		draw_line(center + Vector2(-4, -17), center + Vector2(-6, -7), Color("514338"), 5.0, true)
		draw_rect(Rect2(center + Vector2(-7, -7), Vector2(6, 5)), Color("242724"))
		draw_rect(Rect2(center + Vector2(2, -7), Vector2(7, 5)), Color("242724"))
		draw_shadow_ellipse(center + Vector2(0, -22), Vector2(8, 9), Color("454c3d"))
		draw_line(center + Vector2(-7, -27), center + Vector2(-9, -19), Color("4d4a3a"), 4.0, true)
		draw_line(center + Vector2(7, -27), center + Vector2(9, -19), Color("4d4a3a"), 4.0, true)
		draw_rect(Rect2(center + Vector2(-8, -27), Vector2(3, 5)), Color("777251"))
		draw_rect(Rect2(center + Vector2(2, -27), Vector2(4, 5)), Color("777251"))
		draw_rect(Rect2(center + Vector2(-8, -27), Vector2(16, 3)), Color("3d4439"))
		draw_circle(center + Vector2(0, -32), 7.0, Color("a37b5c"))
	# Held weapon is angled toward the aiming direction; its length changes with the selected weapon.
	if player:
		var weapon: Dictionary = GameConfig.WEAPONS[game.active_weapon]
		var hand := center + Vector2(7, -24)
		var swing_progress := 1.0 - clampf(game.swing_timer / SWING_DURATION, 0.0, 1.0)
		var swing_angle := game.attack_direction.angle() + (lerpf(-0.85, 0.85, swing_progress) if game.swing_timer > 0 else 0.0)
		var swing_direction := Vector2(cos(swing_angle), sin(swing_angle))
		var screen_direction := game.project_world(game.hero + swing_direction) - game.project_world(game.hero)
		var weapon_vector := screen_direction.normalized() * float(weapon.length)
		var weapon_end := hand + weapon_vector
		if game.active_weapon == "권총":
			var gun_tip := hand + weapon_vector
			draw_line(hand, gun_tip, Color("272b2a"), 5.0, true)
			draw_line(hand + Vector2(0, -1), gun_tip + Vector2(0, -1), weapon.color, 2.5, true)
			draw_line(hand + weapon_vector * 0.38, hand + weapon_vector * 0.18 + Vector2(1, 5), Color("39312a"), 3.0, true)
		elif game.active_weapon == "활":
			var bow_perpendicular := Vector2(-weapon_vector.y, weapon_vector.x).normalized()
			var bow_points := PackedVector2Array([hand + bow_perpendicular * 5, hand + weapon_vector * 0.35 + bow_perpendicular * 9, weapon_end + bow_perpendicular * 3, weapon_end - bow_perpendicular * 3, hand + weapon_vector * 0.35 - bow_perpendicular * 9, hand - bow_perpendicular * 5])
			draw_polyline(bow_points, weapon.color, 3.0, true)
			draw_line(hand, weapon_end, Color("d8ceb2"), 1.0, true)
		elif game.active_weapon == "각목":
			draw_line(hand, weapon_end, Color("493a2b"), 5)
			draw_line(hand + Vector2(-1, -1), weapon_end + Vector2(-1, -1), weapon.color, 2)
		elif game.active_weapon == "쇠파이프":
			draw_line(hand, weapon_end, Color("43494a"), 4)
			draw_line(hand + Vector2(-1, -1), weapon_end + Vector2(-1, -1), weapon.color, 2)
		else:
			draw_line(hand, hand + weapon_vector * 0.45, Color("51443a"), 3)
			draw_line(hand + weapon_vector * 0.45, weapon_end, weapon.color, 2)
		if game.swing_timer > 0 and not weapon.ranged:
			var trail_color := Color(0.93, 0.82, 0.59, clampf(game.swing_timer / SWING_DURATION, 0.0, 1.0) * 0.85)
			var trail_center := center + Vector2(0, -23)
			var trail_points := PackedVector2Array()
			for arc_index in range(9):
				var angle := swing_angle - 0.46 + 0.92 * float(arc_index) / 8.0
				var arc_dir := Vector2(cos(angle), sin(angle))
				trail_points.append(trail_center + (game.project_world(game.hero + arc_dir) - game.project_world(game.hero)).normalized() * float(weapon.length + 6))
			draw_polyline(trail_points, trail_color, 2.0)
	if not player:
		var runner := zombie_kind == "러너"
		var shirt := Color("4e493d") if not runner else Color("50453f")
		var skin := Color("75785d") if not runner else Color("87705b")
		draw_line(center + Vector2(-3, -16), center + Vector2(-4, -5), Color("39392f"), 4.0, true)
		draw_line(center + Vector2(3, -16), center + Vector2(4, -5), Color("39392f"), 4.5, true)
		draw_shadow_ellipse(center + Vector2(0, -22), Vector2(8, 8), shirt)
		draw_line(center + Vector2(-6, -25), center + Vector2(-9, -18), shirt.darkened(0.16), 4.0, true)
		draw_line(center + Vector2(6, -25), center + Vector2(9, -18), shirt.darkened(0.18), 4.0, true)
		draw_circle(center + Vector2(0, -30), 6.2, skin)
		draw_rect(Rect2(center + Vector2(-7, -36), Vector2(9, 4)), Color("4b493a"))
		draw_rect(Rect2(center + Vector2(-4, -31), Vector2(2, 2)), Color("2d2925"))
		draw_rect(Rect2(center + Vector2(3, -32), Vector2(2, 2)), GameConfig.COLORS.blood)
		draw_rect(Rect2(center + Vector2(-7, -23), Vector2(4, 3)), GameConfig.COLORS.blood)
		draw_rect(Rect2(center + Vector2(2, -19), Vector2(3, 2)), Color("81765b"))
		if runner:
			draw_rect(Rect2(center + Vector2(-3, -34), Vector2(7, 2)), Color("956a54"))
		draw_zombie_healthbar(center, zombie_data, runner)

func draw_zombie_healthbar(center: Vector2, zombie: Dictionary, runner: bool) -> void:
	var width := 30.0
	var ratio := clampf(float(zombie.hp) / float(zombie.max_hp), 0.0, 1.0)
	var bar := center + Vector2(-width * 0.5, -45)
	draw_rect(Rect2(bar - Vector2(1, 1), Vector2(width + 2, 5)), Color("171816"))
	draw_rect(Rect2(bar, Vector2(width, 3)), Color("582d29"))
	draw_rect(Rect2(bar, Vector2(width * ratio, 3)), Color("bd5747") if runner else Color("8c9860"))
	draw_string(ThemeDB.fallback_font, center + Vector2(-25, -47), "%s  %d/%d" % ["RUN" if runner else "ZED", zombie.hp, zombie.max_hp], HORIZONTAL_ALIGNMENT_CENTER, 50, 8, Color("ded4bb"))

func draw_attack_indicator() -> void:
	var weapon: Dictionary = GameConfig.WEAPONS[game.active_weapon]
	var center := game.map_pixel(game.hero)
	if weapon.ranged:
		var end_point := game.map_pixel(game.hero + game.attack_direction * float(weapon.range))
		if game.shot_timer <= 0: draw_line(center + Vector2(0, -24), end_point + Vector2(0, -24), Color(0.95, 0.82, 0.53, 0.35), 1.0, true)
		draw_arc(end_point + Vector2(0, -24), 5.0, 0, TAU, 24, Color("f0d28a", 0.8), 1.5, true)
		if game.shot_timer > 0:
			var alpha := clampf(game.shot_timer / 0.16, 0.0, 1.0)
			draw_line(game.map_pixel(game.shot_from) + Vector2(0, -24), game.map_pixel(game.shot_to) + Vector2(0, -24), Color(game.shot_color, alpha), 2.5, true)
		return
	if game.swing_timer <= 0: return
	var radius: float = float(weapon.range)
	var base_angle := atan2(game.attack_direction.y, game.attack_direction.x)
	var points := PackedVector2Array([center])
	for i in range(13):
		var angle := base_angle - 0.82 + 1.64 * float(i) / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		points.append(game.map_pixel(game.hero + direction * radius))
	var alpha := minf(0.32, game.swing_timer * 1.4)
	draw_colored_polygon(points, Color(0.96, 0.73, 0.35, alpha))
	var outline := PackedVector2Array()
	for point in points.slice(1): outline.append(point)
	draw_polyline(outline, Color(0.95, 0.79, 0.47, minf(0.85, game.swing_timer * 3.5)), 2.0)

func draw_damage_numbers() -> void:
	for damage in game.damage_numbers:
		var position: Vector2 = game.map_pixel(damage.position) + Vector2(0, -12.0 - (1.0 - damage.time_left) * 20.0)
		var label := "%d%s" % [damage.amount, "!" if damage.critical else ""]
		var color := Color("ffe2a1") if damage.critical else Color("f1ede2")
		draw_string_outline(ThemeDB.fallback_font, position, label, HORIZONTAL_ALIGNMENT_CENTER, 42, 14, 3, Color("25211e"))
		draw_string(ThemeDB.fallback_font, position, label, HORIZONTAL_ALIGNMENT_CENTER, 42, 14, color)

func draw_hit_effects() -> void:
	for effect in game.hit_effects:
		var progress := 1.0 - clampf(float(effect.time_left) / 0.28, 0.0, 1.0)
		var center := game.map_pixel(effect.position) + Vector2(0, -4)
		var color := Color("ffe194") if effect.critical else Color("f5e7c8")
		color.a = 1.0 - progress
		var radius := 5.0 + progress * 11.0
		draw_arc(center, radius, 0, TAU, 20, color, 2.0)
		draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), color, 2.0)
		draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), color, 2.0)

func draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
