extends CanvasLayer

const GameConfig = preload("res://data/game_config.gd")
var game: Variant
var status_label: Label
var mission_label: Label
var weapon_label: Label
var minimap_view: Control
var inventory_panel: PanelContainer
var inventory_label: Label
var region_label: Label

func setup(owner: Node) -> void:
	game = owner

func build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(226, 0)
	add_child(panel)
	var panel_stack := VBoxContainer.new()
	panel.add_child(panel_stack)
	var panel_header := HBoxContainer.new()
	panel_stack.add_child(panel_header)
	var title := Label.new()
	title.text = "☠  서울: 마지막 생존자"
	title.add_theme_color_override("font_color", Color("ebc982"))
	title.add_theme_font_size_override("font_size", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_header.add_child(title)
	var fold_button := Button.new()
	fold_button.text = "접기"
	fold_button.add_theme_font_size_override("font_size", 10)
	fold_button.pressed.connect(func(): _toggle_description(fold_button))
	panel_header.add_child(fold_button)
	var ui := VBoxContainer.new()
	ui.add_theme_constant_override("separation", 3)
	panel_stack.add_child(ui)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	ui.add_child(status_label)
	region_label = Label.new()
	region_label.add_theme_font_size_override("font_size", 10)
	ui.add_child(region_label)
	mission_label = Label.new()
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.custom_minimum_size.x = 200
	mission_label.add_theme_font_size_override("font_size", 10)
	mission_label.add_theme_color_override("font_color", Color("d8d3b9"))
	ui.add_child(mission_label)
	var hint := Label.new()
	hint.text = "우클릭 이동 · 좌클릭 공격\n방향 2초 유지 → 달리기\n1–5 무기 · R 장전 · H 치료 · Tab 가방"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("aeb8a6"))
	ui.add_child(hint)
	for stat in ["힘", "민첩", "지능"]:
		var button := Button.new()
		button.text = "%s 경험치: %s   ·   훈련 +1" % [stat, game.xp[stat]]
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(func(): game.improve(stat))
		ui.add_child(button)
	var weapon_row := HBoxContainer.new()
	ui.add_child(weapon_row)
	for weapon_name in GameConfig.WEAPONS.keys():
		var button := Button.new()
		button.text = weapon_name
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(func(): game.combat.call("equip_weapon", weapon_name))
		weapon_row.add_child(button)
	weapon_label = Label.new()
	weapon_label.add_theme_font_size_override("font_size", 10)
	weapon_label.add_theme_color_override("font_color", Color("c9c1aa"))
	ui.add_child(weapon_label)
	var actions := HBoxContainer.new()
	ui.add_child(actions)
	add_button(actions, "파밍 [F]", game.farm)
	add_button(actions, "건설 [B]", game.build)
	add_button(ui, "인벤토리 [Tab]", toggle_inventory)
	add_button(ui, "도움말 / 목표", func(): game.say("서울역·남산타워·시청을 탐험하세요. 어둠 속에서는 빛 안에 들어온 좀비만 보입니다."))
	for child in ui.get_children():
		if child is Button: child.add_theme_font_size_override("font_size", 10)
	inventory_panel = PanelContainer.new()
	inventory_panel.anchor_left = 0.5
	inventory_panel.anchor_top = 0.5
	inventory_panel.anchor_right = 0.5
	inventory_panel.anchor_bottom = 0.5
	inventory_panel.offset_left = -180
	inventory_panel.offset_top = -145
	inventory_panel.offset_right = 180
	inventory_panel.offset_bottom = 145
	inventory_panel.visible = false
	add_child(inventory_panel)
	var inventory_stack := VBoxContainer.new()
	inventory_panel.add_child(inventory_stack)
	var inventory_title := Label.new()
	inventory_title.text = "생존자 가방  ·  장비 선택"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_title.add_theme_font_size_override("font_size", 16)
	inventory_stack.add_child(inventory_title)
	inventory_label = Label.new()
	inventory_label.add_theme_font_size_override("font_size", 12)
	inventory_stack.add_child(inventory_label)
	var inventory_weapons := HBoxContainer.new()
	inventory_stack.add_child(inventory_weapons)
	for weapon_name in GameConfig.WEAPONS.keys():
		var equip_button := Button.new()
		equip_button.text = weapon_name
		equip_button.add_theme_font_size_override("font_size", 11)
		equip_button.pressed.connect(func(): game.combat.call("equip_weapon", weapon_name))
		inventory_weapons.add_child(equip_button)
	add_button(inventory_stack, "닫기 [Tab]", toggle_inventory)
	var minimap_frame := PanelContainer.new()
	minimap_frame.anchor_left = 1.0
	minimap_frame.anchor_right = 1.0
	minimap_frame.offset_left = -204
	minimap_frame.offset_right = -14
	minimap_frame.offset_top = 14
	minimap_frame.offset_bottom = 214
	add_child(minimap_frame)
	var minimap_stack := VBoxContainer.new()
	minimap_frame.add_child(minimap_stack)
	var minimap_title := Label.new()
	minimap_title.text = "서울 · 주변 지도"
	minimap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_title.add_theme_color_override("font_color", Color("ebc982"))
	minimap_stack.add_child(minimap_title)
	minimap_view = Control.new()
	minimap_view.custom_minimum_size = Vector2(174, 164)
	minimap_view.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap_view.draw.connect(_draw_minimap.bind(minimap_view))
	minimap_stack.add_child(minimap_view)
	refresh()

func _draw_minimap(canvas: Control) -> void:
	var size := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("202925"))
	var road_x := size.x * 16.5 / GameConfig.MAP_W
	var road_y := size.y * 19.5 / GameConfig.MAP_H
	canvas.draw_rect(Rect2(Vector2(road_x - 3, 0), Vector2(6, size.y)), Color("484c47"))
	canvas.draw_rect(Rect2(Vector2(0, road_y - 3), Vector2(size.x, 6)), Color("484c47"))
	for building in game.buildings:
		var p: Vector2 = building.p
		var marker := Vector2(p.x / GameConfig.MAP_W * size.x, p.y / GameConfig.MAP_H * size.y)
		canvas.draw_rect(Rect2(marker - Vector2(2, 2), Vector2(4, 4)), Color("bc995d"))
	for zombie in game.zombies:
		var p: Vector2 = zombie.position
		if p.distance_to(game.hero) > GameConfig.VISION_TILES: continue
		var marker := Vector2(p.x / GameConfig.MAP_W * size.x, p.y / GameConfig.MAP_H * size.y)
		canvas.draw_circle(marker, 2.5, Color("c85348"))
	var hero_marker := Vector2(game.hero.x / GameConfig.MAP_W * size.x, game.hero.y / GameConfig.MAP_H * size.y)
	canvas.draw_circle(hero_marker, 4.0, Color("f0e4b8"))
	canvas.draw_arc(hero_marker, 7.0, 0.0, TAU, 24, Color("e4d19b", 0.7), 1.0)
	if game.click_move_active:
		var target_marker := Vector2(game.move_target.x / GameConfig.MAP_W * size.x, game.move_target.y / GameConfig.MAP_H * size.y)
		canvas.draw_circle(target_marker, 3.0, Color("9dbb76"))

func add_button(parent: Node, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)

func _toggle_description(button: Button) -> void:
	var details := button.get_parent().get_parent().get_child(1) as Control
	details.visible = not details.visible
	button.text = "펼치기" if not details.visible else "접기"

func toggle_inventory() -> void:
	if not inventory_panel: return
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible: refresh()

func redraw_minimap() -> void:
	if minimap_view: minimap_view.queue_redraw()

func display_message(text: String) -> void:
	if mission_label:
		mission_label.text = "날짜 %d · %s\n%s" % [game.day, text, "파티: 용병 동료" if game.hired else "파티: 혼자 생존 중"]

func refresh() -> void:
	if not status_label: return
	status_label.text = "HP %d  기력 %d  ·  %s\n힘 %d  민첩 %d  지능 %d" % [game.hp, int(game.stamina), "달리기" if game.running else "걷기", game.stats["힘"], game.stats["민첩"], game.stats["지능"]]
	if region_label: region_label.text = "%s   [%d, %d]" % [game._region_name(), game.region_coords.x, game.region_coords.y]
	if weapon_label:
		var weapon: Dictionary = GameConfig.WEAPONS[game.active_weapon]
		var ammo_text := ""
		if weapon.ranged:
			ammo_text = "\n탄창 %d/%d · 예비 %d%s" % [game.ammo_in_mag[game.active_weapon], weapon.magazine, game.ammo_reserve[weapon.ammo], " · 장전 중" if game.reload_timer > 0 else ""]
		weapon_label.text = "장비: %s  피해 %d-%d\n사거리 %.1f · 치명타 %d%%%s" % [game.active_weapon, weapon.min, weapon.max, weapon.range, int(weapon.crit * 100.0), ammo_text]
	if inventory_label:
		inventory_label.text = "보유품\n식량   %d\n고철   %d\n의약품   %d (H 사용)\n탄약   %d  (탄창 %d)\n화살   %d  (탄창 %d)\n\n장비: %s%s" % [game.food, game.scrap, game.medkits, game.ammo_reserve["탄약"], game.ammo_in_mag["권총"], game.ammo_reserve["화살"], game.ammo_in_mag["활"], game.active_weapon, "\n장전 중" if game.reload_timer > 0 else ""]
	display_message(game.message)
