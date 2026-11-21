extends Node

signal cash_changed(amount: int)
signal deliveries_changed(total: int)

const SAVE_PATH := "user://petersburg_save.json"

var cash: int = 0
var deliveries_completed: int = 0
var total_earned: int = 0
var best_times: Dictionary = {}
var loaded_from_save := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

func load_game() -> void:
	var data := SaveSystem.load_data()
	if data.is_empty():
		return
	loaded_from_save = true
	cash = maxi(0, int(data.get("cash", 0)))
	deliveries_completed = maxi(0, int(data.get("deliveries_completed", 0)))
	total_earned = maxi(0, int(data.get("total_earned", 0)))
	var times: Variant = data.get("best_times", {})
	if typeof(times) == TYPE_DICTIONARY:
		best_times = (times as Dictionary).duplicate(true)

func save_game() -> void:
	SaveSystem.save_data({
		"cash": cash,
		"deliveries_completed": deliveries_completed,
		"total_earned": total_earned,
		"best_times": best_times
	})

func add_cash(amount: int) -> void:
	cash = maxi(0, cash + amount)
	cash_changed.emit(cash)

func complete_delivery(title: String, reward: int, seconds: float) -> void:
	cash += reward
	total_earned += reward
	deliveries_completed += 1
	var previous := float(best_times.get(title, 0.0))
	if previous <= 0.0 or seconds < previous:
		best_times[title] = seconds
	cash_changed.emit(cash)
	deliveries_changed.emit(deliveries_completed)
	save_game()

func new_game() -> void:
	cash = 0
	deliveries_completed = 0
	total_earned = 0
	best_times.clear()
	loaded_from_save = false
	SaveSystem.delete_save()
	cash_changed.emit(cash)
	deliveries_changed.emit(deliveries_completed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_game()
