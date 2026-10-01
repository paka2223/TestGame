extends Node2D

const TILE := 32.0
const MAP_W := 54
const MAP_H := 42
const VISION_TILES := 8.0
const COLORS := {
	"grass": Color("26362f"), "grass_alt": Color("2b3b33"), "road": Color("343a3a"),
	"road_line": Color("72694f"), "accent": Color("d5ad61"), "blood": Color("843a38")
}

var hero := Vector2(18, 20)
var zombies: Array[Vector2] = []
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
var dark_material: ShaderMaterial
var status_label: Label
var mission_label: Label

func _ready() -> void:
	seed(802)
	for i in range(26):
		zombies.append(Vector2(randi_range(2, MAP_W - 3), randi_range(2, MAP_H - 3)))
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
	hint.text = "이동  WASD / 방향키\n공격  Space   ·   상호작용  E"
	hint.add_theme_color_override("font_color", Color("aeb8a6"))
	ui.add_child(hint)
	for stat in ["힘", "민첩", "지능"]:
		var button := Button.new()
		button.text = "%s 경험치: %s   ·   훈련 +1" % [stat, xp[stat]]
		button.pressed.connect(func(): improve(stat))
		ui.add_child(button)
	var actions := HBoxContainer.new()
	ui.add_child(actions)
	add_button(actions, "파밍 [F]", farm)
	add_button(actions, "건설 [B]", build)
	add_button(ui, "도움말 / 목표", func(): say("서울역·남산타워·시청을 탐험하세요. 어둠 속에서는 빛 안에 들어온 좀비만 보입니다."))
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
	stamina = minf(100.0, stamina + delta * (3.0 + stats["민첩"] * 0.7))
	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1
	if movement != Vector2.ZERO and stamina > 0:
		hero += movement.normalized() * delta * (2.4 + stats["민첩"] * 0.18)
		stamina = maxf(0, stamina - delta * 3.4 / maxf(1, stats["민첩"]))
	hero.x = clampf(hero.x, 1, MAP_W - 2)
	hero.y = clampf(hero.y, 1, MAP_H - 2)
	update_camera()
	if sim_clock >= 1.1:
		sim_clock = 0
		for i in range(zombies.size()):
			if zombies[i].distance_to(hero) < VISION_TILES + 2:
				zombies[i] += (hero - zombies[i]).normalized() * 0.24
				if zombies[i].distance_to(hero) < 0.85:
					if hired:
						zombies.remove_at(i)
						gain("힘", 8)
						break
					hp = maxi(0, hp - maxi(1, 5 - stats["힘"]))
					say("좀비가 시야 안까지 다가와 공격했다! 힘이 높을수록 피해를 덜 받는다.")
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
			"zombie": draw_character(map_pixel(item.data), false)
			"hero": draw_character(map_pixel(item.data), true)

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

func draw_character(center: Vector2, player: bool) -> void:
	var bob := 0.0 if player else sin(Time.get_ticks_msec() * 0.004 + center.x) * 1.0
	center.y += bob
	draw_ellipse(center + Vector2(0, 5), Vector2(11, 5), Color(0.025, 0.035, 0.03, 0.75))
	if player:
		# Small hood, backpack, mittens, bright face and oversized hair make a readable chibi silhouette.
		draw_rect(Rect2(center + Vector2(5, -12), Vector2(5, 8)), Color("735444"))
		draw_ellipse(center + Vector2(0, -6), Vector2(8, 10), Color("58756c"))
		draw_rect(Rect2(center + Vector2(-5, -2), Vector2(4, 7)), Color("8b6347"))
		draw_rect(Rect2(center + Vector2(2, -2), Vector2(4, 7)), Color("8b6347"))
		draw_ellipse(center + Vector2(0, -18), Vector2(10, 11), Color("b58a61"))
		draw_ellipse(center + Vector2(0, -23), Vector2(10, 7), Color("413732"))
		draw_rect(Rect2(center + Vector2(-7, -22), Vector2(3, 7)), Color("413732"))
		draw_rect(Rect2(center + Vector2(4, -19), Vector2(2, 3)), Color("292b29"))
		draw_rect(Rect2(center + Vector2(-1, -19), Vector2(2, 3)), Color("292b29"))
		draw_rect(Rect2(center + Vector2(-3, -12), Vector2(5, 2)), Color("935b4d"))
		draw_rect(Rect2(center + Vector2(-4, -6), Vector2(3, 2)), Color("b6c393"))
	else:
		draw_ellipse(center + Vector2(0, -7), Vector2(9, 9), Color("53644a"))
		draw_rect(Rect2(center + Vector2(-6, -4), Vector2(12, 9)), Color("494b3c"))
		draw_ellipse(center + Vector2(0, -17), Vector2(10, 10), Color("89906a"))
		draw_rect(Rect2(center + Vector2(-9, -21), Vector2(5, 3)), Color("394037"))
		draw_rect(Rect2(center + Vector2(4, -20), Vector2(6, 3)), Color("394037"))
		draw_rect(Rect2(center + Vector2(-5, -18), Vector2(3, 3)), COLORS.blood)
		draw_rect(Rect2(center + Vector2(3, -18), Vector2(3, 3)), COLORS.blood)
		draw_rect(Rect2(center + Vector2(-13, -7), Vector2(5, 4)), Color("89906a"))
		draw_rect(Rect2(center + Vector2(8, -7), Vector2(5, 4)), Color("89906a"))

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func attack() -> void:
	var best := -1
	var nearest := 1.25
	for i in range(zombies.size()):
		var distance := zombies[i].distance_to(hero)
		if distance < nearest:
			nearest = distance
			best = i
	if best >= 0:
		zombies.remove_at(best)
		gain("힘", 24)
		scrap += 1 + stats["힘"]
		say("좀비를 처치했다. 힘 경험치 +24, 고철 +%d." % (1 + stats["힘"]))
	else:
		say("사거리 안에 좀비가 없다.")
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
	say(message)
