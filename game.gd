extends Node2D

const TILE := 32
const MAP_W := 54
const MAP_H := 42
const COLORS := {"grass": Color("34483b"), "road": Color("414747"), "sidewalk": Color("777b6b"), "wall": Color("777065"), "roof": Color("9a5548"), "dark": Color("252e2c"), "accent": Color("d5ad61"), "blood": Color("8c3b35")}
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
var job := ""
var message := "서울역 광장에서 눈을 떴다. 살아남아라."
var sim_clock := 0.0
var ui: VBoxContainer
var status_label: Label
var mission_label: Label

func _ready() -> void:
	seed(802)
	for i in range(26): zombies.append(Vector2(randi_range(2, MAP_W - 3), randi_range(2, MAP_H - 3)))
	buildings = [
		{"p": Vector2(8, 9), "size": Vector2(4, 4), "name": "서울역", "color": Color("9b5147"), "kind": "역"},
		{"p": Vector2(24, 6), "size": Vector2(5, 5), "name": "남산타워", "color": Color("aa8f55"), "kind": "타워"},
		{"p": Vector2(38, 9), "size": Vector2(6, 5), "name": "시청", "color": Color("65767c"), "kind": "병원"},
		{"p": Vector2(6, 28), "size": Vector2(6, 5), "name": "용산 전자상가", "color": Color("52756c"), "kind": "상가"},
		{"p": Vector2(29, 29), "size": Vector2(7, 5), "name": "한강 대피소", "color": Color("587a59"), "kind": "대피소"},
		{"p": Vector2(43, 27), "size": Vector2(5, 6), "name": "국립중앙박물관", "color": Color("9a7850"), "kind": "박물관"}
	]
	for i in range(65): props.append({"p": Vector2(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2)), "kind": ["tree", "car", "debris"][randi_range(0, 2)]})
	make_ui()
	get_viewport().size_changed.connect(queue_redraw)

func make_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var panel := PanelContainer.new(); panel.position = Vector2(14, 14); panel.custom_minimum_size = Vector2(255, 0); layer.add_child(panel)
	ui = VBoxContainer.new(); panel.add_child(ui)
	var title := Label.new(); title.text = "☠  서울: 마지막 생존자"; title.add_theme_color_override("font_color", Color("ebc982")); title.add_theme_font_size_override("font_size", 19); ui.add_child(title)
	status_label = Label.new(); ui.add_child(status_label)
	mission_label = Label.new(); mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; mission_label.custom_minimum_size.x = 228; mission_label.add_theme_color_override("font_color", Color("d8d3b9")); ui.add_child(mission_label)
	var hint := Label.new(); hint.text = "이동  WASD / 방향키\n공격  Space   ·   상호작용  E"; hint.add_theme_color_override("font_color", Color("aeb8a6")); ui.add_child(hint)
	for stat in ["힘", "민첩", "지능"]:
		var b := Button.new(); b.text = "%s 경험치: %s   ·   훈련 +1" % [stat, xp[stat]]; b.pressed.connect(func(): improve(stat)); ui.add_child(b)
	var act := HBoxContainer.new(); ui.add_child(act)
	add_button(act, "파밍 [F]", farm); add_button(act, "건설 [B]", build)
	add_button(ui, "도움말 / 목표", func(): say("서울역·남산타워·시청을 탐험하세요. 지능으로 치료·수리·건설, 민첩으로 정찰·파밍, 힘으로 싸우세요. 고용은 E."))
	update_ui()

func add_button(parent: Node, label: String, callback: Callable) -> void:
	var b := Button.new(); b.text = label; b.pressed.connect(callback); parent.add_child(b)

func _process(delta: float) -> void:
	sim_clock += delta
	stamina = minf(100.0, stamina + delta * (3.0 + stats["민첩"] * 0.7))
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if v != Vector2.ZERO and stamina > 0:
		# Quarter-view travel axes: each cardinal input traces a 2:1 isometric slope.
		var iso := Vector2(v.x - v.y, (v.x + v.y) * 0.5).normalized()
		hero += iso * delta * (2.4 + stats["민첩"] * 0.18)
		stamina = maxf(0, stamina - delta * 3.4 / maxf(1, stats["민첩"]))
	hero.x = clampf(hero.x, 1, MAP_W - 2); hero.y = clampf(hero.y, 1, MAP_H - 2)
	var view := get_viewport_rect().size
	camera_at = Vector2(hero.x * TILE - view.x / 2, hero.y * TILE - view.y / 2)
	if sim_clock >= 1.1:
		sim_clock = 0
		for i in range(zombies.size()):
			if zombies[i].distance_to(hero) < 9:
				zombies[i] += (hero - zombies[i]).normalized() * 0.24
				if zombies[i].distance_to(hero) < 0.85:
					if hired:
						zombies.remove_at(i); gain("힘", 8); break
					hp = maxi(0, hp - maxi(1, 5 - stats["힘"])); say("좀비에게 공격받았다! 힘이 높을수록 피해를 덜 받는다.")
					if hp == 0: hp = 100; hero = Vector2(18, 20); food = maxi(0, food - 1); say("정신을 잃었다. 서울역 대피소에서 깨어났다. 식량 -1.")
					break
		update_ui()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: attack()
			KEY_E: interact()
			KEY_F: farm()
			KEY_B: build()

func map_pixel(p: Vector2) -> Vector2:
	return p * TILE - camera_at

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), COLORS.grass)
	var start_x := maxi(0, int(camera_at.x / TILE)); var end_x := mini(MAP_W, int((camera_at.x + size.x) / TILE) + 2)
	var start_y := maxi(0, int(camera_at.y / TILE)); var end_y := mini(MAP_H, int((camera_at.y + size.y) / TILE) + 2)
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var p := map_pixel(Vector2(x, y)); var road := (x in range(15, 18) or y in range(18, 21))
			draw_rect(Rect2(p, Vector2(TILE, TILE)), COLORS.road if road else (Color("405142") if (x + y) % 2 == 0 else COLORS.grass))
			if road and (x + y) % 3 == 0: draw_rect(Rect2(p + Vector2(13, 15), Vector2(7, 2)), Color("a6a38b"))
	for prop in props:
		var p: Vector2 = prop.p
		if p.x < start_x or p.x > end_x or p.y < start_y or p.y > end_y: continue
		var xy := map_pixel(p)
		match prop.kind:
			"tree":
				draw_rect(Rect2(xy + Vector2(12, 16), Vector2(7, 12)), Color("69553d")); draw_rect(Rect2(xy + Vector2(4, 4), Vector2(24, 15)), Color("405f44"))
			"car":
				draw_rect(Rect2(xy + Vector2(3, 11), Vector2(26, 13)), Color("5f7370")); draw_rect(Rect2(xy + Vector2(9, 7), Vector2(13, 6)), Color("78918b")); draw_rect(Rect2(xy + Vector2(5, 22), Vector2(5, 3)), Color("252c2b"))
			_: draw_rect(Rect2(xy + Vector2(7, 22), Vector2(19, 4)), Color("716a56"))
	for b in buildings:
		var p: Vector2 = b.p; var w: Vector2 = b.size; var xy := map_pixel(p)
		draw_rect(Rect2(xy + Vector2(6, 7), w * TILE), Color("202a28")); draw_rect(Rect2(xy + Vector2(0, 0), w * TILE), b.color)
		draw_rect(Rect2(xy + Vector2(5, 6), w * TILE - Vector2(12, 14)), Color("4c5650")); draw_rect(Rect2(xy + Vector2(10, 12), Vector2(12, 15)), Color("d5ad61"))
		draw_string(ThemeDB.fallback_font, xy + Vector2(0, -5), b.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("efe0be"))
	for z in zombies:
		var xy := map_pixel(z)
		if xy.x < -30 or xy.x > size.x + 30 or xy.y < -30 or xy.y > size.y + 30: continue
		draw_rect(Rect2(xy + Vector2(9, 11), Vector2(15, 18)), Color("78845c")); draw_rect(Rect2(xy + Vector2(8, 4), Vector2(17, 12)), Color("8c9970")); draw_rect(Rect2(xy + Vector2(11, 8), Vector2(3, 3)), COLORS.blood)
	var hpbar := map_pixel(hero)
	draw_rect(Rect2(hpbar + Vector2(4, 5), Vector2(24, 26)), Color("27312b")); draw_rect(Rect2(hpbar + Vector2(7, 7), Vector2(18, 12)), Color("e1b66f")); draw_rect(Rect2(hpbar + Vector2(7, 20), Vector2(18, 9)), Color("586e79")); draw_rect(Rect2(hpbar + Vector2(11, 9), Vector2(10, 7)), Color("d9c78f"))
	for z in zombies:
		if z.distance_to(hero) < 1.7: draw_line(map_pixel(z) + Vector2(15, 20), hpbar + Vector2(15, 18), Color("9e5144", 0.4), 1)

func attack() -> void:
	var best := -1; var dist := 1.25
	for i in range(zombies.size()):
		var d := zombies[i].distance_to(hero)
		if d < dist: dist = d; best = i
	if best >= 0:
		zombies.remove_at(best); gain("힘", 24); scrap += 1 + stats["힘"]; say("좀비를 처치했다. 힘 경험치 +24, 고철 +%d." % (1 + stats["힘"]))
	else: say("사거리 안에 좀비가 없다.")
	update_ui()

func farm() -> void:
	if stamina < 12: say("기력이 부족하다. 잠시 쉬어 가자."); return
	stamina -= 12; food += 1; scrap += 1; gain("민첩", 12); say("폐허에서 식량과 고철을 찾았다. 민첩 경험치 +12."); update_ui()

func build() -> void:
	if scrap < 3: say("건설에는 고철 3개가 필요하다."); return
	scrap -= 3; gain("지능", 18); hp = mini(100, hp + 10); say("지능을 발휘해 방어 바리케이드를 만들었다. 지능 경험치 +18, 체력 +10."); update_ui()

func interact() -> void:
	var closest := 99.0
	for b in buildings:
		var d := Vector2(b.p.x + b.size.x / 2.0, b.p.y + b.size.y / 2.0).distance_to(hero)
		if d < closest: closest = d
	if closest < 5:
		if not hired: hired = true; say("전직 군인 용병이 합류했다. 파티 보조 전투가 시작된다.")
		elif stats["지능"] >= 3: hp = mini(100, hp + 40); gain("지능", 10); say("응급처치에 성공했다. 지능 전문가의 치료 효과 +40.")
		else: hp = mini(100, hp + 16); gain("지능", 8); say("대피소 의료품으로 치료했다. 체력 +16. 지능 3이면 응급처치를 배운다.")
	else: say("건물 가까이에서 E를 누르면 용병을 고용하거나 치료할 수 있다.")
	update_ui()

func gain(stat: String, amount: int) -> void:
	xp[stat] += amount
	if xp[stat] >= stats[stat] * 50:
		xp[stat] -= stats[stat] * 50; stats[stat] += 1; say("%s 능력이 성장했다!" % stat)

func improve(stat: String) -> void:
	stats[stat] += 1; say("훈련으로 %s +1. 능력은 활동 경험치로도 성장한다." % stat); update_ui()

func say(text: String) -> void:
	message = text
	if mission_label: mission_label.text = "날짜 %d  ·  %s\n%s" % [day, message, "파티: 용병 동료" if hired else "파티: 혼자 생존 중"]

func update_ui() -> void:
	if not status_label: return
	var role := ""
	if stats["지능"] >= 3: role = "\n전문: 응급처치·차량수리·건설"
	status_label.text = "HP %d/100  ·  기력 %d/100\n힘 %d  민첩 %d  지능 %d%s\n식량 %d  ·  고철 %d  ·  좀비 %d" % [hp, int(stamina), stats["힘"], stats["민첩"], stats["지능"], role, food, scrap, zombies.size()]
	say(message)
