extends Node2D

const TILE := 32.0
const MAP_W := 54
const MAP_H := 42
const VISION_TILES := 8.0
const WEAPONS := {
	"부엌칼": {"min": 7, "max": 13, "range": 1.35, "cooldown": 0.34, "crit": 0.12, "crit_mult": 1.8, "length": 10, "color": Color("bbc4c1")},
	"쇠파이프": {"min": 12, "max": 21, "range": 1.9, "cooldown": 0.58, "crit": 0.08, "crit_mult": 1.7, "length": 16, "color": Color("858e90")},
	"각목": {"min": 9, "max": 17, "range": 2.25, "cooldown": 0.78, "crit": 0.07, "crit_mult": 2.0, "length": 18, "color": Color("886b4b")}
}
const COLORS := {
	"grass": Color("26362f"), "grass_alt": Color("2b3b33"), "road": Color("343a3a"),
	"road_line": Color("72694f"), "accent": Color("d5ad61"), "blood": Color("843a38")
}

var hero := Vector2(18, 20)
var zombies: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var props: Array[Dictionary] = []
var camera_at := Vector2.ZERO
var stats := {"힘": 1, "민첩": 1, "지능": 1}
var xp := {"힘": 0, "민첩": 0, "지능": 0}
var hp := 100
var stamina := 100.0
var food := 4
var scrap := 5
var day := 1
var hired := false
var message := "서울역 광장에서 눈을 떴다. 살아남아라."
var sim_clock := 0.0
var bite_cooldown := 0.0
var attack_cooldown := 0.0
var swing_timer := 0.0
var attack_direction := Vector2.RIGHT
var aim_world := Vector2.RIGHT
var move_target := Vector2.ZERO
var click_move_active := false
var active_weapon := "쇠파이프"
var damage_numbers: Array[Dictionary] = []
var dark_material: ShaderMaterial
var status_label: Label
var mission_label: Label
var weapon_label: Label

func _ready() -> void:
	seed(802)
	aim_world = hero + Vector2(1, 0)
	for i in range(26):
		spawn_zombie(Vector2(randi_range(2, MAP_W - 3), randi_range(2, MAP_H - 3)))
	buildings = [
		{"p": Vector2(8, 9), "size": Vector2(4, 4), "name": "서울역", "color": Color("71453f")},
		{"p": Vector2(24, 6), "size": Vector2(5, 5), "name": "남산타워", "color": Color("786b4c")},
		{"p": Vector2(38, 9), "size": Vector2(6, 5), "name": "시청", "color": Color("47575a")},
		{"p": Vector2(6, 28), "size": Vector2(6, 5), "name": "용산 전자상가", "color": Color("415a50")},
		{"p": Vector2(29, 29), "size": Vector2(7, 5), "name": "한강 대피소", "color": Color("465943")},
		{"p": Vector2(43, 27), "size": Vector2(5, 6), "name": "국립중앙박물관", "color": Color("6b5a43")}
	]
	for i in range(65):
		props.append({"p": Vector2(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2)), "kind": ["tree", "car", "debris"][randi_range(0, 2)]})
	make_ui()
	make_darkness()
	get_viewport().size_changed.connect(update_camera)
	update_camera()

func make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(255, 0)
	layer.add_child(panel)
	var ui := VBoxContainer.new()
	panel.add_child(ui)
	var title := Label.new()
	title.text = "☠  서울: 마지막 생존자"
	title.add_theme_color_override("font_color", Color("ebc982"))
	title.add_theme_font_size_override("font_size", 19)
	ui.add_child(title)
	status_label = Label.new()
	ui.add_child(status_label)
	mission_label = Label.new()
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.custom_minimum_size.x = 228
	mission_label.add_theme_color_override("font_color", Color("d8d3b9"))
	ui.add_child(mission_label)
	var hint := Label.new()
	hint.text = "우클릭 이동  ·  좌클릭 공격\nWASD/방향키도 사용 가능  ·  E 상호작용"
	hint.add_theme_color_override("font_color", Color("aeb8a6"))
	ui.add_child(hint)
	for stat in ["힘", "민첩", "지능"]:
		var button := Button.new()
		button.text = "%s 경험치: %s   ·   훈련 +1" % [stat, xp[stat]]
		button.pressed.connect(func(): improve(stat))
		ui.add_child(button)
	var weapon_row := HBoxContainer.new()
	ui.add_child(weapon_row)
	for weapon_name in WEAPONS.keys():
		var button := Button.new()
		button.text = weapon_name
		button.pressed.connect(func(): equip_weapon(weapon_name))
		weapon_row.add_child(button)
	weapon_label = Label.new()
	weapon_label.add_theme_font_size_override("font_size", 11)
	weapon_label.add_theme_color_override("font_color", Color("c9c1aa"))
	ui.add_child(weapon_label)
	var actions := HBoxContainer.new()
	ui.add_child(actions)
	add_button(actions, "파밍 [F]", farm)
	add_button(actions, "건설 [B]", build)
	add_button(ui, "도움말 / 목표", func(): say("서울역·남산타워·시청을 탐험하세요. 어둠 속에서는 빛 안에 들어온 좀비만 보입니다."))
	update_ui()

func spawn_zombie(spawn_at: Vector2) -> void:
	var runner := randf() < 0.28
	var max_health := randi_range(20, 32) if runner else randi_range(36, 58)
	zombies.append({
		"position": spawn_at,
		"kind": "러너" if runner else "일반",
		"max_hp": max_health,
		"hp": max_health,
		"speed": 3.0 if runner else 1.0
	})

func equip_weapon(weapon_name: String) -> void:
	if not WEAPONS.has(weapon_name): return
	active_weapon = weapon_name
	var weapon: Dictionary = WEAPONS[active_weapon]
	say("%s 장착 · 사거리 %.2f · 피해 %d–%d" % [active_weapon, weapon.range, weapon.min, weapon.max])
	update_ui()

func make_darkness() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 light_center = vec2(0.5, 0.5);
uniform vec2 view_size = vec2(960.0, 600.0);
uniform float radius_px = 240.0;
uniform float ambient = 0.18;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	vec2 pixel_delta = (SCREEN_UV - light_center) * view_size;
	float distance_to_light = length(pixel_delta);
	float light = 1.0 - smoothstep(radius_px * 0.68, radius_px, distance_to_light);
	float exposure = mix(ambient, 1.0, light);
	vec3 warm_light = vec3(0.24, 0.16, 0.09) * light * 0.45;
	COLOR = vec4(scene.rgb * exposure + warm_light, scene.a);
}
"""
	dark_material = ShaderMaterial.new()
	dark_material.shader = shader
	var darkness_layer := CanvasLayer.new()
	darkness_layer.layer = 1
	add_child(darkness_layer)
	var overlay := ColorRect.new()
	overlay.name = "FieldOfView"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.material = dark_material
	darkness_layer.add_child(overlay)

func add_button(parent: Node, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)

func project_world(point: Vector2) -> Vector2:
	# A 2:1 diamond ground plane: each world axis recedes at a different screen angle.
	return Vector2((point.x - point.y) * TILE * 0.5, (point.x + point.y) * TILE * 0.25)

func map_pixel(point: Vector2) -> Vector2:
	return project_world(point) - camera_at

func update_camera() -> void:
	var view := get_viewport_rect().size
	camera_at = project_world(hero) - view * 0.5
	if dark_material:
		dark_material.set_shader_parameter("light_center", (project_world(hero) - camera_at) / view)
		dark_material.set_shader_parameter("view_size", view)
		dark_material.set_shader_parameter("radius_px", VISION_TILES * TILE * 0.72)
	queue_redraw()

func _process(delta: float) -> void:
	sim_clock += delta
	bite_cooldown = maxf(0.0, bite_cooldown - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	swing_timer = maxf(0.0, swing_timer - delta)
	stamina = minf(100.0, stamina + delta * (3.0 + stats["민첩"] * 0.7))
	for i in range(damage_numbers.size() - 1, -1, -1):
		damage_numbers[i].time_left -= delta
		if damage_numbers[i].time_left <= 0: damage_numbers.remove_at(i)
	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1
	if movement != Vector2.ZERO and stamina > 0:
		click_move_active = false
		movement = movement.normalized()
	elif click_move_active:
		var to_target := move_target - hero
		if to_target.length() < 0.12:
			click_move_active = false
		else:
			movement = to_target.normalized()
	if movement != Vector2.ZERO and stamina > 0:
		var step := delta * (2.4 + stats["민첩"] * 0.18)
		if click_move_active:
			var remaining := move_target.distance_to(hero)
			if remaining <= step:
				hero = move_target
				click_move_active = false
			else:
				hero += movement * step
		else:
			hero += movement * step
		stamina = maxf(0, stamina - delta * 3.4 / maxf(1, stats["민첩"]))
	hero.x = clampf(hero.x, 1, MAP_W - 2)
	hero.y = clampf(hero.y, 1, MAP_H - 2)
	update_camera()
	if sim_clock >= 0.2:
		var zombie_step := sim_clock
		sim_clock = 0
		for i in range(zombies.size()):
			var zombie_position: Vector2 = zombies[i].position
			var distance := zombie_position.distance_to(hero)
			if distance < VISION_TILES + 4:
				var zombie_direction := (hero - zombie_position).normalized()
				zombie_position += zombie_direction * float(zombies[i].speed) * zombie_step
				zombies[i].position = zombie_position
				if zombie_position.distance_to(hero) < 0.85 and bite_cooldown <= 0:
					if hired:
						zombies.remove_at(i)
						gain("힘", 8)
						bite_cooldown = 0.8
						break
					hp = maxi(0, hp - maxi(1, 5 - stats["힘"]))
					bite_cooldown = 0.9
					say("%s 좀비의 공격! 힘이 높을수록 피해를 덜 받는다." % zombies[i].kind)
					if hp == 0:
						hp = 100
						hero = Vector2(18, 20)
						food = maxi(0, food - 1)
						say("정신을 잃었다. 서울역 대피소에서 깨어났다. 식량 -1.")
					break
		update_ui()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: attack()
			KEY_E: interact()
			KEY_F: farm()
			KEY_B: build()
			KEY_1: equip_weapon("부엌칼")
			KEY_2: equip_weapon("쇠파이프")
			KEY_3: equip_weapon("각목")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		aim_world = screen_to_world(event.position)
	elif event is InputEventMouseButton and event.pressed:
		var world_target := screen_to_world(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			move_target = Vector2(clampf(world_target.x, 1, MAP_W - 2), clampf(world_target.y, 1, MAP_H - 2))
			click_move_active = true
			update_ui()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			aim_world = world_target
			click_move_active = false
			attack()

func screen_to_world(screen_position: Vector2) -> Vector2:
	var delta := screen_position + camera_at - project_world(hero)
	return Vector2(delta.x / TILE + delta.y / (TILE * 0.5), delta.y / (TILE * 0.5) - delta.x / TILE)

func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("19221f"))
	# Inverse isometric projection expands a regular screen viewport into a much wider world rectangle.
	var margin := maxf(view.x / TILE, view.y / TILE) * 1.15
	var start_x := maxi(0, int(hero.x - margin))
	var end_x := mini(MAP_W, int(hero.x + margin) + 1)
	var start_y := maxi(0, int(hero.y - margin))
	var end_y := mini(MAP_H, int(hero.y + margin) + 1)
	for depth in range(start_x + start_y, end_x + end_y):
		for x in range(start_x, end_x):
			var y := depth - x
			if y < start_y or y >= end_y: continue
			var center := map_pixel(Vector2(x, y))
			var diamond := PackedVector2Array([center + Vector2(0, -8), center + Vector2(16, 0), center + Vector2(0, 8), center + Vector2(-16, 0)])
			var is_road := x in range(15, 18) or y in range(18, 21)
			var ground := COLORS.road if is_road else (COLORS.grass if (x + y) % 2 == 0 else COLORS.grass_alt)
			draw_colored_polygon(diamond, ground)
			if is_road and (x + y) % 3 == 0:
				draw_line(center + Vector2(-2, 0), center + Vector2(3, 0), COLORS.road_line, 1.5)
	# Sort props, landmarks and characters by their depth on the ground plane.
	# This lets the player walk behind a tree or building instead of always floating on top.
	var drawables: Array[Dictionary] = []
	for prop in props:
		var p: Vector2 = prop.p
		if absf(p.x - hero.x) <= margin and absf(p.y - hero.y) <= margin:
			drawables.append({"depth": p.x + p.y, "type": "prop", "data": prop})
	for building in buildings:
		var p: Vector2 = building.p
		var size: Vector2 = building.size
		if absf(p.x - hero.x) <= margin + 5 and absf(p.y - hero.y) <= margin + 5:
			drawables.append({"depth": p.x + p.y + size.x + size.y - 1, "type": "building", "data": building})
	for zombie in zombies:
		# Monsters outside the actual world-space lantern radius are fully concealed.
		if zombie.distance_to(hero) <= VISION_TILES:
			drawables.append({"depth": zombie.x + zombie.y, "type": "zombie", "data": zombie})
	drawables.append({"depth": hero.x + hero.y, "type": "hero", "data": hero})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for item in drawables:
		match item.type:
			"prop": draw_prop(map_pixel(item.data.p), item.data.kind)
			"building": draw_building(item.data)
			"zombie":
				draw_character(map_pixel(item.data.position), false, item.data.kind, item.data)
			"hero": draw_character(map_pixel(item.data), true, "", {})
	draw_attack_indicator()
	draw_damage_numbers()
	if click_move_active:
		var marker := map_pixel(move_target)
		draw_ellipse(marker, Vector2(8, 4), Color(0.84, 0.76, 0.46, 0.5))
		draw_line(marker + Vector2(-8, 0), marker + Vector2(8, 0), Color("e5d192", 0.8), 1)

func draw_prop(center: Vector2, kind: String) -> void:
	draw_ellipse(center + Vector2(0, 5), Vector2(13, 5), Color(0.04, 0.055, 0.05, 0.65))
	match kind:
		"tree":
			draw_rect(Rect2(center + Vector2(-3, -15), Vector2(7, 19)), Color("443c31"))
			draw_rect(Rect2(center + Vector2(-10, -26), Vector2(20, 15)), Color("263b31"))
			draw_rect(Rect2(center + Vector2(-7, -30), Vector2(13, 8)), Color("344a39"))
			draw_rect(Rect2(center + Vector2(-5, -23), Vector2(4, 4)), Color("526348"))
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
	for corner in corners: base.append(map_pixel(corner))
	var height := 24.0 + size.y * 2.0
	var top := PackedVector2Array()
	for point in base: top.append(point + Vector2(0, -height))
	draw_ellipse((base[2] + base[3]) * 0.5 + Vector2(0, 6), Vector2(size.x * 17.0, 11), Color(0.04, 0.05, 0.045, 0.75))
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
	draw_ellipse(center + Vector2(0, 5), Vector2(11, 4), Color(0.025, 0.03, 0.025, 0.9))
	if player:
		# Muted workwear, layered cloth, a field pack and small face details read as a survivor at game scale.
		draw_rect(Rect2(center + Vector2(6, -17), Vector2(5, 10)), Color("443b31"))
		draw_rect(Rect2(center + Vector2(-6, -17), Vector2(5, 10)), Color("514338"))
		draw_rect(Rect2(center + Vector2(-7, -7), Vector2(6, 5)), Color("242724"))
		draw_rect(Rect2(center + Vector2(2, -7), Vector2(7, 5)), Color("242724"))
		draw_rect(Rect2(center + Vector2(-7, -30), Vector2(15, 15)), Color("454c3d"))
		draw_rect(Rect2(center + Vector2(-9, -29), Vector2(4, 10)), Color("4d4a3a"))
		draw_rect(Rect2(center + Vector2(7, -29), Vector2(4, 10)), Color("4d4a3a"))
		draw_rect(Rect2(center + Vector2(-8, -27), Vector2(3, 5)), Color("777251"))
		draw_rect(Rect2(center + Vector2(2, -27), Vector2(4, 5)), Color("777251"))
		draw_rect(Rect2(center + Vector2(-8, -27), Vector2(16, 3)), Color("3d4439"))
		draw_rect(Rect2(center + Vector2(-7, -38), Vector2(14, 11)), Color("a37b5c"))
	# Held weapon is angled toward the aiming direction; its length changes with the selected weapon.
	if player:
		var weapon: Dictionary = WEAPONS[active_weapon]
		var hand := center + Vector2(7, -24)
	var screen_direction := project_world(hero + attack_direction) - project_world(hero)
	var weapon_vector := screen_direction.normalized() * float(weapon.length)
		var weapon_end := hand + weapon_vector
		if active_weapon == "각목":
			draw_line(hand, weapon_end, Color("493a2b"), 5)
			draw_line(hand + Vector2(-1, -1), weapon_end + Vector2(-1, -1), weapon.color, 2)
		elif active_weapon == "쇠파이프":
			draw_line(hand, weapon_end, Color("43494a"), 4)
			draw_line(hand + Vector2(-1, -1), weapon_end + Vector2(-1, -1), weapon.color, 2)
		else:
			draw_line(hand, hand + weapon_vector * 0.45, Color("51443a"), 3)
			draw_line(hand + weapon_vector * 0.45, weapon_end, weapon.color, 2)
	if not player:
		var runner := zombie_kind == "러너"
		var shirt := Color("4e493d") if not runner else Color("50453f")
		var skin := Color("75785d") if not runner else Color("87705b")
		draw_rect(Rect2(center + Vector2(-4, -16), Vector2(4, 11)), Color("39392f"))
		draw_rect(Rect2(center + Vector2(2, -16), Vector2(5, 11)), Color("39392f"))
		draw_rect(Rect2(center + Vector2(-7, -27), Vector2(14, 12)), shirt)
		draw_rect(Rect2(center + Vector2(-9, -26), Vector2(4, 9)), shirt.darkened(0.16))
		draw_rect(Rect2(center + Vector2(6, -24), Vector2(4, 10)), shirt.darkened(0.18))
		draw_rect(Rect2(center + Vector2(-6, -35), Vector2(12, 11)), skin)
		draw_rect(Rect2(center + Vector2(-7, -36), Vector2(9, 4)), Color("4b493a"))
		draw_rect(Rect2(center + Vector2(-4, -31), Vector2(2, 2)), Color("2d2925"))
		draw_rect(Rect2(center + Vector2(3, -32), Vector2(2, 2)), COLORS.blood)
		draw_rect(Rect2(center + Vector2(-7, -23), Vector2(4, 3)), COLORS.blood)
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
	if swing_timer <= 0: return
	var weapon: Dictionary = WEAPONS[active_weapon]
	var center := map_pixel(hero)
	var radius: float = float(weapon.range)
	var base_angle := atan2(attack_direction.y, attack_direction.x)
	var points := PackedVector2Array([center])
	for i in range(13):
		var angle := base_angle - 0.82 + 1.64 * float(i) / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		points.append(map_pixel(hero + direction * radius))
	var alpha := minf(0.32, swing_timer * 1.4)
	draw_colored_polygon(points, Color(0.96, 0.73, 0.35, alpha))
	var outline := PackedVector2Array()
	for point in points.slice(1): outline.append(point)
	draw_polyline(outline, Color(0.95, 0.79, 0.47, minf(0.85, swing_timer * 3.5)), 2.0)

func draw_damage_numbers() -> void:
	for damage in damage_numbers:
		var position: Vector2 = map_pixel(damage.position) + Vector2(0, -12.0 - (1.0 - damage.time_left) * 20.0)
		var label := "%d%s" % [damage.amount, "!" if damage.critical else ""]
		var color := Color("ffe2a1") if damage.critical else Color("f1ede2")
		draw_string_outline(ThemeDB.fallback_font, position, label, HORIZONTAL_ALIGNMENT_CENTER, 42, 14, 3, Color("25211e"))
		draw_string(ThemeDB.fallback_font, position, label, HORIZONTAL_ALIGNMENT_CENTER, 42, 14, color)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func attack() -> void:
	if attack_cooldown > 0: return
	var weapon: Dictionary = WEAPONS[active_weapon]
	attack_cooldown = float(weapon.cooldown)
	swing_timer = 0.25
	attack_direction = (aim_world - hero).normalized()
	if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
	var best := -1
	var nearest := float(weapon.range)
	for i in range(zombies.size()):
		var offset: Vector2 = zombies[i].position - hero
		var distance := offset.length()
		if distance > nearest or distance <= 0.001: continue
		if offset.normalized().dot(attack_direction) < 0.38: continue
		nearest = distance
		best = i
	if best >= 0:
		var zombie: Dictionary = zombies[best]
		var amount := randi_range(int(weapon.min), int(weapon.max))
		var critical := randf() < float(weapon.crit)
		if critical: amount = int(round(amount * float(weapon.crit_mult)))
		amount = maxi(1, int(round(amount * (1.0 + maxf(0, stats["힘"] - 1) * 0.12))))
		zombie.hp -= amount
		damage_numbers.append({"position": zombie.position, "amount": amount, "critical": critical, "time_left": 1.0})
		if zombie.hp <= 0:
			zombies.remove_at(best)
			gain("힘", 24)
			scrap += 1 + stats["힘"]
			say("%s 좀비 처치 · %d 피해%s · 고철 +%d" % [zombie.kind, amount, " 치명타" if critical else "", 1 + stats["힘"]])
		else:
			zombie.position += attack_direction * 0.28
			zombie.hp = maxi(0, zombie.hp)
			zombies[best] = zombie
			say("%s 좀비에게 %d 피해%s · 체력 %d/%d" % [zombie.kind, amount, " 치명타" if critical else "", zombie.hp, zombie.max_hp])
	else:
		say("공격 범위 안에 좀비가 없다. 마우스를 향해 휘둘렀다.")
	update_ui()

func farm() -> void:
	if stamina < 12:
		say("기력이 부족하다. 잠시 쉬어 가자.")
		return
	stamina -= 12
	food += 1
	scrap += 1
	gain("민첩", 12)
	say("폐허에서 식량과 고철을 찾았다. 민첩 경험치 +12.")
	update_ui()

func build() -> void:
	if scrap < 3:
		say("건설에는 고철 3개가 필요하다.")
		return
	scrap -= 3
	gain("지능", 18)
	hp = mini(100, hp + 10)
	say("지능을 발휘해 방어 바리케이드를 만들었다. 지능 경험치 +18, 체력 +10.")
	update_ui()

func interact() -> void:
	var closest := 99.0
	for building in buildings:
		var p: Vector2 = building.p
		var size: Vector2 = building.size
		var distance := Vector2(p.x + size.x / 2.0, p.y + size.y / 2.0).distance_to(hero)
		if distance < closest: closest = distance
	if closest < 5:
		if not hired:
			hired = true
			say("전직 군인 용병이 합류했다. 파티 보조 전투가 시작된다.")
		elif stats["지능"] >= 3:
			hp = mini(100, hp + 40)
			gain("지능", 10)
			say("응급처치에 성공했다. 지능 전문가의 치료 효과 +40.")
		else:
			hp = mini(100, hp + 16)
			gain("지능", 8)
			say("대피소 의료품으로 치료했다. 체력 +16. 지능 3이면 응급처치를 배운다.")
	else:
		say("건물 가까이에서 E를 누르면 용병을 고용하거나 치료할 수 있다.")
	update_ui()

func gain(stat: String, amount: int) -> void:
	xp[stat] += amount
	if xp[stat] >= stats[stat] * 50:
		xp[stat] -= stats[stat] * 50
		stats[stat] += 1
		say("%s 능력이 성장했다!" % stat)

func improve(stat: String) -> void:
	stats[stat] += 1
	say("훈련으로 %s +1. 능력은 활동 경험치로도 성장한다." % stat)
	update_ui()

func say(text: String) -> void:
	message = text
	if mission_label:
		mission_label.text = "날짜 %d  ·  %s\n%s" % [day, message, "파티: 용병 동료" if hired else "파티: 혼자 생존 중"]

func update_ui() -> void:
	if not status_label: return
	var role := ""
	if stats["지능"] >= 3: role = "\n전문: 응급처치·차량수리·건설"
	status_label.text = "HP %d/100  ·  기력 %d/100\n힘 %d  민첩 %d  지능 %d%s\n식량 %d  ·  고철 %d  ·  좀비 %d" % [hp, int(stamina), stats["힘"], stats["민첩"], stats["지능"], role, food, scrap, zombies.size()]
	if weapon_label:
		var weapon: Dictionary = WEAPONS[active_weapon]
		weapon_label.text = "장비: %s  피해 %d-%d\n사거리 %.2fm · 속도 %.2fs · 치명타 %d%%" % [active_weapon, weapon.min, weapon.max, weapon.range, weapon.cooldown, int(weapon.crit * 100.0)]
	say(message)
