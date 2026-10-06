extends Node2D

const GameConfig = preload("res://data/game_config.gd")

var hero := Vector2(18, 20)
var zombies: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var props: Array[Dictionary] = []
var camera_at := Vector2.ZERO
var stats := {"힘": 1, "민첩": 1, "지능": 1}
var xp := {"힘": 0, "민첩": 0, "지능": 0}
var hp := 100
var medkits := 1
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
var hit_effects: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []
var held_direction := Vector2.ZERO
var held_direction_time := 0.0
var running := false
var run_release_timer := 0.0
var aim_screen := Vector2.ZERO
var ammo_reserve := {"탄약": 32, "화살": 16}
var ammo_in_mag := {"권총": 8, "활": 1}
var reload_timer := 0.0
var reloading_weapon := ""
var shot_timer := 0.0
var shot_from := Vector2.ZERO
var shot_to := Vector2.ZERO
var shot_color := Color.WHITE
var region_coords := Vector2i.ZERO
var region_states: Dictionary = {}
var dark_material: ShaderMaterial
var world_renderer: Node2D
var ground_renderer: Node2D
var combat: Node
var hud: CanvasLayer

func _ready() -> void:
	world_renderer = get_node("WorldRenderer") as Node2D
	ground_renderer = get_node("GroundRenderer") as Node2D
	combat = get_node("CombatSystem") as Node
	hud = get_node("HUD") as CanvasLayer
	hud.call("setup", self)
	combat.call("setup", self)
	world_renderer.call("setup", self)
	ground_renderer.call("setup", self)
	seed(802)
	aim_world = hero + Vector2(1, 0)
	for i in range(26):
		spawn_zombie(Vector2(randi_range(2, GameConfig.MAP_W - 3), randi_range(2, GameConfig.MAP_H - 3)))
	buildings = [
		{"p": Vector2(8, 9), "size": Vector2(4, 4), "name": "서울역", "color": Color("71453f")},
		{"p": Vector2(24, 6), "size": Vector2(5, 5), "name": "남산타워", "color": Color("786b4c")},
		{"p": Vector2(38, 9), "size": Vector2(6, 5), "name": "시청", "color": Color("47575a")},
		{"p": Vector2(6, 28), "size": Vector2(6, 5), "name": "용산 전자상가", "color": Color("415a50")},
		{"p": Vector2(29, 29), "size": Vector2(7, 5), "name": "한강 대피소", "color": Color("465943")},
		{"p": Vector2(43, 27), "size": Vector2(5, 6), "name": "국립중앙박물관", "color": Color("6b5a43")}
	]
	for i in range(65):
		props.append({"p": Vector2(randi_range(1, GameConfig.MAP_W - 2), randi_range(1, GameConfig.MAP_H - 2)), "kind": ["tree", "car", "debris"][randi_range(0, 2)]})
	hud.call("build_ui")
	make_darkness()
	aim_screen = get_viewport_rect().size * 0.5 + Vector2(100, 0)
	get_viewport().size_changed.connect(update_camera)
	update_camera()

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

func _region_name() -> String:
	if region_coords == Vector2i.ZERO: return "서울역 일대"
	var directions := ""
	if region_coords.y < 0: directions += "북부 "
	if region_coords.y > 0: directions += "남부 "
	if region_coords.x < 0: directions += "서부 "
	if region_coords.x > 0: directions += "동부 "
	return "%s폐허 %d-%d구역" % [directions, abs(region_coords.x) + 1, abs(region_coords.y) + 1]

func _change_region(direction: Vector2i) -> void:
	region_states[region_coords] = {"zombies": zombies.duplicate(true), "buildings": buildings.duplicate(true), "props": props.duplicate(true)}
	region_coords += direction
	if region_states.has(region_coords):
		var saved: Dictionary = region_states[region_coords]
		zombies = saved.zombies.duplicate(true)
		buildings = saved.buildings.duplicate(true)
		props = saved.props.duplicate(true)
	else:
		zombies.clear()
		buildings.clear()
		props.clear()
		var seed_value: int = abs(region_coords.x * 73856093 + region_coords.y * 19349663 + 802)
		seed(seed_value)
		for index in range(20):
			spawn_zombie(Vector2(randi_range(2, GameConfig.MAP_W - 3), randi_range(2, GameConfig.MAP_H - 3)))
		for index in range(65):
			props.append({"p": Vector2(randi_range(1, GameConfig.MAP_W - 2), randi_range(1, GameConfig.MAP_H - 2)), "kind": ["tree", "car", "debris"][randi_range(0, 2)]})
		buildings = [
			{"p": Vector2(23, 16), "size": Vector2(6, 5), "name": "폐허 구역", "color": Color("4f5550")},
			{"p": Vector2(randi_range(6, 40), randi_range(6, 28)), "size": Vector2(4, 4), "name": "버려진 건물", "color": Color("655148")}
		]
	if direction.x > 0: hero.x = 1.5
	elif direction.x < 0: hero.x = GameConfig.MAP_W - 2.5
	if direction.y > 0: hero.y = 1.5
	elif direction.y < 0: hero.y = GameConfig.MAP_H - 2.5
	click_move_active = false
	message = "%s에 진입했다. 구역 가장자리로 이동하면 인접 지역으로 이어진다." % _region_name()
	update_ui()

func make_darkness() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 light_center = vec2(0.5, 0.5);
uniform vec2 view_size = vec2(960.0, 600.0);
uniform float radius_px = 240.0;
uniform float ambient = 0.18;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
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

func project_world(point: Vector2) -> Vector2:
	# A 2:1 diamond ground plane: each world axis recedes at a different screen angle.
	return Vector2((point.x - point.y) * GameConfig.TILE * 0.5, (point.x + point.y) * GameConfig.TILE * 0.25)

func map_pixel(point: Vector2) -> Vector2:
	return project_world(point) - camera_at

func update_camera() -> void:
	var view := get_viewport_rect().size
	camera_at = project_world(hero) - view * 0.5
	if ground_renderer:
		ground_renderer.position = -camera_at
	if dark_material:
		dark_material.set_shader_parameter("light_center", (project_world(hero) - camera_at) / view)
		dark_material.set_shader_parameter("view_size", view)
		dark_material.set_shader_parameter("radius_px", GameConfig.VISION_TILES * GameConfig.TILE * 0.72)
	world_renderer.queue_redraw()

func _process(delta: float) -> void:
	sim_clock += delta
	bite_cooldown = maxf(0.0, bite_cooldown - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	swing_timer = maxf(0.0, swing_timer - delta)
	shot_timer = maxf(0.0, shot_timer - delta)
	if reload_timer > 0:
		reload_timer = maxf(0.0, reload_timer - delta)
		if reload_timer == 0.0: combat.call("_finish_reload")
	stamina = minf(100.0, stamina + delta * (3.0 + stats["민첩"] * 0.7))
	for i in range(damage_numbers.size() - 1, -1, -1):
		damage_numbers[i].time_left -= delta
		if damage_numbers[i].time_left <= 0: damage_numbers.remove_at(i)
	for i in range(hit_effects.size() - 1, -1, -1):
		hit_effects[i].time_left -= delta
		if hit_effects[i].time_left <= 0: hit_effects.remove_at(i)
	for i in range(loot_drops.size() - 1, -1, -1):
		if loot_drops[i].position.distance_to(hero) <= 0.75:
			_collect_drop(i)
	var keyboard_move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard_move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard_move.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard_move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard_move.y += 1
	var movement := Vector2.ZERO
	var keyboard_control := keyboard_move != Vector2.ZERO
	if keyboard_control:
		keyboard_move = keyboard_move.normalized()
		if not running:
			if keyboard_move.is_equal_approx(held_direction):
				held_direction_time += delta
			else:
				held_direction = keyboard_move
				held_direction_time = 0.0
			if held_direction_time >= GameConfig.RUN_TRIGGER_SECONDS:
				running = true
		else:
			held_direction = keyboard_move
		movement = keyboard_move
	else:
		if running:
			run_release_timer += delta
			if run_release_timer > 0.22:
				running = false
				held_direction = Vector2.ZERO
				held_direction_time = 0.0
		else:
			held_direction = Vector2.ZERO
			held_direction_time = 0.0
	if keyboard_control: run_release_timer = 0.0
	if keyboard_control:
		click_move_active = false
	elif click_move_active:
		var to_target := move_target - hero
		if to_target.length() < 0.12:
			click_move_active = false
		else:
			movement = to_target.normalized()
	if movement != Vector2.ZERO and stamina > 0:
		var move_speed: float = GameConfig.RUN_SPEED if keyboard_control and running else GameConfig.WALK_SPEED
		move_speed += float(stats["민첩"] - 1) * 0.10
		var step: float = delta * move_speed
		if click_move_active:
			var remaining := move_target.distance_to(hero)
			if remaining <= step:
				hero = move_target
				click_move_active = false
			else:
				hero += movement * step
		else:
			hero += movement * step
		stamina = maxf(0, stamina - delta * (8.0 if keyboard_control and running else 1.0) / maxf(1, stats["민첩"]))
	if hero.x < 1.0: _change_region(Vector2i(-1, 0))
	elif hero.x > GameConfig.MAP_W - 2: _change_region(Vector2i(1, 0))
	elif hero.y < 1.0: _change_region(Vector2i(0, -1))
	elif hero.y > GameConfig.MAP_H - 2: _change_region(Vector2i(0, 1))
	hero.x = clampf(hero.x, 1, GameConfig.MAP_W - 2)
	hero.y = clampf(hero.y, 1, GameConfig.MAP_H - 2)
	update_camera()
	if swing_timer <= 0 and shot_timer <= 0:
		aim_world = screen_to_world(aim_screen)
		if not aim_world.is_equal_approx(hero): attack_direction = (aim_world - hero).normalized()
	hud.call("redraw_minimap")
	if sim_clock >= 0.2:
		var zombie_step := sim_clock
		sim_clock = 0
		for i in range(zombies.size()):
			var zombie_position: Vector2 = zombies[i].position
			var distance := zombie_position.distance_to(hero)
			if distance < GameConfig.VISION_TILES + 4:
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
			KEY_SPACE: combat.call("attack")
			KEY_E: interact()
			KEY_F: farm()
			KEY_B: build()
			KEY_1: combat.call("equip_weapon", "부엌칼")
			KEY_2: combat.call("equip_weapon", "쇠파이프")
			KEY_3: combat.call("equip_weapon", "각목")
			KEY_4: combat.call("equip_weapon", "권총")
			KEY_5: combat.call("equip_weapon", "활")
			KEY_R: combat.call("reload_weapon")
			KEY_H: use_medicine()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		hud.call("toggle_inventory")
		get_viewport().set_input_as_handled()
		hud.call("toggle_inventory")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		aim_screen = event.position
		aim_world = screen_to_world(event.position)
		attack_direction = (aim_world - hero).normalized()
	elif event is InputEventMouseButton and event.pressed:
		aim_screen = event.position
		var world_target := screen_to_world(event.position)
		aim_world = world_target
		attack_direction = (aim_world - hero).normalized()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			move_target = Vector2(clampf(world_target.x, 0, GameConfig.MAP_W), clampf(world_target.y, 0, GameConfig.MAP_H))
			click_move_active = true
			update_ui()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			aim_world = world_target
			click_move_active = false
			combat.call("attack")

func screen_to_world(screen_position: Vector2) -> Vector2:
	var delta := screen_position + camera_at - project_world(hero)
	var world_offset := Vector2(delta.x / GameConfig.TILE + delta.y / (GameConfig.TILE * 0.5), delta.y / (GameConfig.TILE * 0.5) - delta.x / GameConfig.TILE)
	return hero + world_offset

func farm() -> void:
	if stamina < 12:
		say("기력이 부족하다. 잠시 쉬어 가자.")
		return
	stamina -= 12
	food += 1
	scrap += 1
	if randf() < 0.35: ammo_reserve["탄약"] += randi_range(1, 4)
	if randf() < 0.25: ammo_reserve["화살"] += randi_range(1, 3)
	gain("민첩", 12)
	say("폐허 파밍 완료 · 식량 +1, 고철 +1. 탄약이나 화살도 찾았을 수 있다. 민첩 경험치 +12.")
	update_ui()

func _collect_drop(index: int) -> void:
	var drop: Dictionary = loot_drops[index]
	var amount: int = int(drop.amount)
	match String(drop.kind):
		"고철": scrap += amount
		"식량": food += amount
		"탄약": ammo_reserve["탄약"] += amount
		"화살": ammo_reserve["화살"] += amount
		"의약품": medkits += amount
	loot_drops.remove_at(index)
	say("아이템 획득 · %s x%d" % [drop.kind, amount])
	update_ui()

func use_medicine() -> void:
	if medkits <= 0:
		say("보유한 의약품이 없다.")
		return
	if hp >= 100:
		say("체력이 가득 차 있다.")
		return
	medkits -= 1
	hp = mini(100, hp + 35)
	say("응급 의약품을 사용했다. 체력 +35.")
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
	hud.call("display_message", text)

func update_ui() -> void:
	hud.call("refresh")
