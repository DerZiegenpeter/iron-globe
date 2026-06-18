extends Node

signal time_advanced(days: int)
signal day_passed
signal week_passed
signal month_passed

var current_day: int = 1
var current_month: int = 1
var current_year: int = 1946

var speed: int = 0
var paused: bool = true

var _time_accumulator: float = 0.0
var _seconds_per_day: float = 0.2

func _ready():
	paused = true
	speed = 0

func _process(delta: float):
	if paused or speed <= 0:
		return

	_time_accumulator += delta * speed

	while _time_accumulator >= _seconds_per_day:
		_time_accumulator -= _seconds_per_day
		advance_day(1)

func advance_day(days: int = 1):
	for i in range(days):
		current_day += 1
		if current_day > _days_in_month(current_month, current_year):
			current_day = 1
			current_month += 1
			if current_month > 12:
				current_month = 1
				current_year += 1

		day_passed.emit()
		if current_day % 7 == 0:
			week_passed.emit()
		if current_day == 1:
			month_passed.emit()

	time_advanced.emit(days)

func set_speed(new_speed: int):
	speed = new_speed
	paused = (speed == 0)

func toggle_pause():
	if speed == 0:
		set_speed(1)
	else:
		set_speed(0)

func get_date_string() -> String:
	return "%02d.%02d.%d" % [current_day, current_month, current_year]

func _days_in_month(month: int, year: int) -> int:
	if month == 2:
		return 29 if (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)) else 28
	elif month in [4, 6, 9, 11]:
		return 30
	else:
		return 31
