extends Node

const GameConfig = preload("res://data/game_config.gd")
var game: Variant

func setup(owner: Node) -> void:
	game = owner

func equip_weapon(weapon_name: String) -> void:
	if not GameConfig.WEAPONS.has(weapon_name): return
	game.active_weapon = weapon_name
	var weapon: Dictionary = GameConfig.WEAPONS[game.active_weapon]
	game.say("%s 장착 · 사거리 %.2f · 피해 %d–%d" % [game.active_weapon, weapon.range, weapon.min, weapon.max])
	game.update_ui()

func reload_weapon() -> void:
	var weapon: Dictionary = GameConfig.WEAPONS[game.active_weapon]
	if not weapon.ranged:
		game.say("근접 무기는 장전할 필요가 없다.")
		return
	if game.reload_timer > 0:
		game.say("장전 중이다.")
		return
	var ammo_kind: String = weapon.ammo
	var current_rounds: int = game.ammo_in_mag[game.active_weapon]
	var missing := int(weapon.magazine) - current_rounds
	if missing <= 0:
		game.say("탄창이 이미 가득 차 있다.")
		return
	if game.ammo_reserve[ammo_kind] <= 0:
		game.say("%s이(가) 부족하다. 파밍으로 보충할 수 있다." % ammo_kind)
		return
	game.reload_timer = GameConfig.RELOAD_SECONDS
	game.reloading_weapon = game.active_weapon
	game.say("%s 장전 중…" % game.active_weapon)

func _finish_reload() -> void:
	if game.reloading_weapon.is_empty(): return
	var weapon: Dictionary = GameConfig.WEAPONS[game.reloading_weapon]
	var ammo_kind: String = weapon.ammo
	var missing := int(weapon.magazine) - int(game.ammo_in_mag[game.reloading_weapon])
	var loaded := mini(missing, int(game.ammo_reserve[ammo_kind]))
	game.ammo_in_mag[game.reloading_weapon] += loaded
	game.ammo_reserve[ammo_kind] -= loaded
	game.reload_timer = 0.0
	game.say("%s 장전 완료 · 탄창 %d발" % [game.reloading_weapon, game.ammo_in_mag[game.reloading_weapon]])
	game.reloading_weapon = ""
	game.update_ui()

func attack() -> void:
	if game.attack_cooldown > 0: return
	var weapon: Dictionary = GameConfig.WEAPONS[game.active_weapon]
	if weapon.ranged:
		if game.reload_timer > 0:
			game.say("장전이 끝날 때까지 기다려 주세요.")
			return
		if game.ammo_in_mag[game.active_weapon] <= 0:
			game.say("탄창이 비었다. R 키를 눌러 장전하세요.")
			return
	game.attack_cooldown = float(weapon.cooldown)
	game.swing_timer = 0.0 if weapon.ranged else GameConfig.SWING_DURATION
	game.attack_direction = (game.aim_world - game.hero).normalized()
	if game.attack_direction == Vector2.ZERO: game.attack_direction = Vector2.RIGHT
	if weapon.ranged: game.ammo_in_mag[game.active_weapon] -= 1
	var best := -1
	var nearest := float(weapon.range)
	var cursor_best := -1
	var cursor_error := 27.0
	for i in range(game.zombies.size()):
		var offset: Vector2 = game.zombies[i].position - game.hero
		var distance := offset.length()
		if distance > float(weapon.range) or distance <= 0.001: continue
		var zombie_screen: Vector2 = game.map_pixel(game.zombies[i].position) + Vector2(0, -27)
		var pointer_distance: float = game.aim_screen.distance_to(zombie_screen)
		if pointer_distance < cursor_error:
			cursor_error = pointer_distance
			cursor_best = i
		if offset.normalized().dot(game.attack_direction) >= 0.38 and distance < nearest:
			nearest = distance
			best = i
	if cursor_best >= 0:
		best = cursor_best
		game.attack_direction = (game.zombies[best].position - game.hero).normalized()
	if weapon.ranged:
		game.shot_from = game.hero
		game.shot_to = game.zombies[best].position if best >= 0 else game.hero + game.attack_direction * float(weapon.range)
		game.shot_color = Color("f5d78d") if game.active_weapon == "권총" else Color("b4d28e")
		game.shot_timer = 0.16
	if best >= 0:
		var zombie: Dictionary = game.zombies[best]
		var amount := randi_range(int(weapon.min), int(weapon.max))
		var critical := randf() < float(weapon.crit)
		if critical: amount = int(round(amount * float(weapon.crit_mult)))
		amount = maxi(1, int(round(amount * (1.0 + maxf(0, game.stats["힘"] - 1) * 0.12))))
		zombie.hp -= amount
		game.damage_numbers.append({"position": zombie.position, "amount": amount, "critical": critical, "time_left": 1.0})
		game.hit_effects.append({"position": zombie.position, "critical": critical, "time_left": 0.28})
		if zombie.hp <= 0:
			_drop_loot(zombie.position)
			game.zombies.remove_at(best)
			game.gain("힘", 24)
			game.scrap += 1 + game.stats["힘"]
			game.say("%s 좀비 처치 · %d 피해%s · 고철 +%d" % [zombie.kind, amount, " 치명타" if critical else "", 1 + game.stats["힘"]])
		elif not weapon.ranged:
			zombie.position += game.attack_direction * 0.28
			zombie.hp = maxi(0, zombie.hp)
			game.zombies[best] = zombie
			game.say("%s 좀비에게 %d 피해%s · 체력 %d/%d" % [zombie.kind, amount, " 치명타" if critical else "", zombie.hp, zombie.max_hp])
		else:
			zombie.hp = maxi(0, zombie.hp)
			game.zombies[best] = zombie
			game.say("%s 명중 · %d 피해%s · 체력 %d/%d" % [zombie.kind, amount, " 치명타" if critical else "", zombie.hp, zombie.max_hp])
	else:
		game.say("공격 범위 안에 좀비가 없다. 마우스를 향해 휘둘렀다.")
	game.update_ui()

func _drop_loot(position: Vector2) -> void:
	var pool := ["고철", "고철", "식량", "탄약", "화살", "의약품"]
	var drop_count := 1 + (1 if randf() < 0.18 else 0)
	for _drop_index in range(drop_count):
		var kind: String = pool[randi_range(0, pool.size() - 1)]
		var amount := randi_range(1, 2) if kind in ["고철", "식량", "화살"] else 1
		game.loot_drops.append({"position": position, "kind": kind, "amount": amount})
