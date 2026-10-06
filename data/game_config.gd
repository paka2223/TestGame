extends RefCounted

const TILE := 32.0
const MAP_W := 54
const MAP_H := 42
const VISION_TILES := 8.0
const WALK_SPEED := 1.35
const RUN_SPEED := 3.2
const RUN_TRIGGER_SECONDS := 2.0
const SWING_DURATION := 0.28
const RELOAD_SECONDS := 1.25
const WEAPONS := {
	"부엌칼": {"min": 7, "max": 13, "range": 1.35, "cooldown": 0.34, "crit": 0.12, "crit_mult": 1.8, "length": 10, "color": Color("bbc4c1"), "ranged": false},
	"쇠파이프": {"min": 12, "max": 21, "range": 1.9, "cooldown": 0.58, "crit": 0.08, "crit_mult": 1.7, "length": 16, "color": Color("858e90"), "ranged": false},
	"각목": {"min": 9, "max": 17, "range": 2.25, "cooldown": 0.78, "crit": 0.07, "crit_mult": 2.0, "length": 18, "color": Color("886b4b"), "ranged": false},
	"권총": {"min": 18, "max": 31, "range": 9.0, "cooldown": 0.42, "crit": 0.10, "crit_mult": 1.8, "length": 14, "color": Color("5d6260"), "ranged": true, "ammo": "탄약", "magazine": 8},
	"활": {"min": 12, "max": 23, "range": 7.0, "cooldown": 0.72, "crit": 0.16, "crit_mult": 2.0, "length": 17, "color": Color("856344"), "ranged": true, "ammo": "화살", "magazine": 1}
}
const COLORS := {"grass": Color("26362f"), "grass_alt": Color("2b3b33"), "road": Color("343a3a"), "road_line": Color("72694f"), "accent": Color("d5ad61"), "blood": Color("843a38")}