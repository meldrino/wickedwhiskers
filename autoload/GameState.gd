extends Node

const MAX_LIVES := 9
const DAY_SECONDS := 7200.0

const TRAP_STRING_COST := 1
const TRAP_STICK_COST := 2
const TRAP_STONE_COST := 2
const LADDER_STRING_COST := 1
const LADDER_STICK_COST := 2
const ROD_STRING_COST := 1
const ROD_STICK_COST := 1

const TRADE_GOLD := 10
const TOWN_GOLD_TARGET := 30

var string_count := 0
var stick_count := 0
var stone_count := 0
var has_fishing_rod := false
var food_count := 0
var gold := 0
var lives := MAX_LIVES

var combo := 123
var shed_unlocked := false
var has_keys := false

var trap_placed := false
var ladder_placed := false

var mouse_caught := false
var bird_caught := false
var catfood_used := false

var shed_string_taken := false
var shed_key_taken := false
var spawn_near_shed := false

var quest := "meet"
var first_dawn := false
var chase_active := false
var cinematic_active := false

var day_index := 1
var day_time := 0.0
var is_day := false
var hunger := 1.0
var tiredness := 0.0

var _toast_cd := {}


func _ready() -> void:
	new_game()


func new_game() -> void:
	string_count = 0
	stick_count = 0
	# TEMP TEST KIT (Andy, 2026-08-24): boot with rod materials so the
	# fishing cutaway can be tested without gathering. Revert to 0/0.
	string_count = 1
	stick_count = 1
	stone_count = 0
	has_fishing_rod = false
	food_count = 0
	gold = 0
	lives = MAX_LIVES
	combo = randi_range(100, 999)
	shed_unlocked = false
	has_keys = false
	trap_placed = false
	ladder_placed = false
	mouse_caught = false
	bird_caught = false
	catfood_used = false
	shed_string_taken = false
	shed_key_taken = false
	spawn_near_shed = false
	quest = "meet"
	first_dawn = false
	chase_active = false
	cinematic_active = false
	day_index = 1
	day_time = 0.0
	is_day = false
	hunger = 1.0
	tiredness = 0.0


func total_catches() -> int:
	var n := 0
	if mouse_caught:
		n += 1
	if bird_caught:
		n += 1
	return n


func add_string(n: int) -> void:
	string_count += n


func add_sticks(n: int) -> void:
	stick_count += n


func add_stones(n: int) -> void:
	stone_count += n


func add_food(n: int) -> void:
	food_count += n


func can_afford_trap() -> bool:
	return string_count >= TRAP_STRING_COST and stick_count >= TRAP_STICK_COST and stone_count >= TRAP_STONE_COST


func can_afford_ladder() -> bool:
	return string_count >= LADDER_STRING_COST and stick_count >= LADDER_STICK_COST


func spend_trap() -> void:
	string_count -= TRAP_STRING_COST
	stick_count -= TRAP_STICK_COST
	stone_count -= TRAP_STONE_COST


func spend_ladder() -> void:
	string_count -= LADDER_STRING_COST
	stick_count -= LADDER_STICK_COST


func can_afford_rod() -> bool:
	return string_count >= ROD_STRING_COST and stick_count >= ROD_STICK_COST


func spend_rod() -> void:
	string_count -= ROD_STRING_COST
	stick_count -= ROD_STICK_COST
	has_fishing_rod = true


func materials_status() -> String:
	var has_string := string_count >= 1
	var has_sticks := stick_count >= 2
	if not has_string and not has_sticks:
		return "none"
	if has_string and has_sticks:
		return "full"
	return "half"


func trap_materials_status() -> String:
	var has_string := string_count >= TRAP_STRING_COST
	var has_sticks := stick_count >= TRAP_STICK_COST
	var has_stones := stone_count >= TRAP_STONE_COST
	if not has_string and not has_sticks and not has_stones:
		return "none"
	if has_string and has_sticks and has_stones:
		return "full"
	return "half"


func eat_food() -> bool:
	if food_count <= 0:
		return false
	food_count -= 1
	hunger = 1.0
	return true


func lose_life(reason: String) -> bool:
	lives -= 1
	hunger = 1.0
	tiredness = 0.0
	if lives <= 0:
		Hud.toast("That was life %d of 9... you're out. Wicked Whiskers is reborn. %s" % [0, reason])
		return true
	Hud.toast("Cat-astrophe! You lose a life. (%d/%d) %s" % [lives, MAX_LIVES, reason])
	return false


func toast_cooldown(key: String, text: String, cd_ms := 2000) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_toast_cd.get(key, 0)) > cd_ms:
		_toast_cd[key] = now
		Hud.toast(text)
		return true
	return false
