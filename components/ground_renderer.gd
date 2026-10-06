extends Node2D

const GameConfig = preload("res://data/game_config.gd")
var game: Variant

func setup(owner: Node) -> void:
	game = owner
	position = -game.camera_at
	queue_redraw()

func _draw() -> void:
	# Static terrain is cached by CanvasItem after its first draw. The parent position
	# follows the camera, so the ground does not need to be rebuilt every frame.
	for y in range(GameConfig.MAP_H):
		for x in range(GameConfig.MAP_W):
			var center: Vector2 = game.project_world(Vector2(x, y))
			var diamond := PackedVector2Array([
				center + Vector2(0, -8), center + Vector2(16, 0),
				center + Vector2(0, 8), center + Vector2(-16, 0)
			])
			var is_road := x in range(15, 18) or y in range(18, 21)
			var ground: Color = GameConfig.COLORS.road if is_road else (GameConfig.COLORS.grass if (x + y) % 2 == 0 else GameConfig.COLORS.grass_alt)
			draw_colored_polygon(diamond, ground)
			if is_road and (x + y) % 3 == 0:
				draw_line(center + Vector2(-2, 0), center + Vector2(3, 0), GameConfig.COLORS.road_line, 1.5)
