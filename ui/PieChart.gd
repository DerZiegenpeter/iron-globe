@tool
extends Control
class_name PieChart

@export var data: Dictionary = {}      # z.B. {"German worker": 980000, "German farmer": 620000}
@export var colors: Dictionary = {}
@export var radius: float = 90.0
@export var show_labels: bool = true

func _draw():
	if data.is_empty():
		return

	var total = 0.0
	for value in data.values():
		total += value

	if total <= 0:
		return

	var start_angle := -PI / 2.0
	var center := size / 2.0

	var i := 0
	for key in data.keys():
		var value = data[key]
		var angle = (value / total) * TAU
		var color = colors.get(key, Color.WHITE)

		# Slice zeichnen
		var points := [center]
		var steps := 48
		for s in range(steps + 1):
			var a = start_angle + angle * (float(s) / steps)
			points.append(center + Vector2(cos(a), sin(a)) * radius)

		draw_polygon(points, [color])

		# Optional: kleine Linie + Text (später erweiterbar)
		start_angle += angle
		i += 1
