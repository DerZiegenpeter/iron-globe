extends Node

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var camera = get_viewport().get_camera_3d()
		if not camera:
			return
			
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 5000
		
		var space_state = get_viewport().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			var clicked_node = result.collider.get_parent()
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(clicked_node)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_handle_right_click(clicked_node, result.position)

func _handle_left_click(node):
	# Alle vorherigen Selektionen aufheben
	for entity in get_tree().get_nodes_in_group("ground_entities"):
		if entity.has_method("deselect"):
			entity.deselect()
	
	if node is GroundEntity:
		node.select()
		# Zur Gruppe "selected" hinzufügen (für Rechtsklick)
		get_tree().call_group("selected", "deselect")
		node.add_to_group("selected", true)

func _handle_right_click(node, click_world_pos):
	var selected_nodes = get_tree().get_nodes_in_group("selected")
	if selected_nodes.size() > 0:
		var selected = selected_nodes[0]
		if selected is GroundEntity:
			# Einfache Position auf der Kugel berechnen
			var new_pos = click_world_pos.normalized() * 1002.0
			var new_lat = rad_to_deg(asin(new_pos.y / 1002.0))
			var new_lon = rad_to_deg(atan2(new_pos.x, new_pos.z))
			
			selected.move_to(new_lat, new_lon)
			print("Bewegung befohlen:", selected.entity_name, "→", new_lat, new_lon)
