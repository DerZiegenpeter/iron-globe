extends Node3D

@export var radius: float = 1000.0
@export var max_features: int = 10000
@export var border_color: Color = Color(0.0, 1.0, 0.4)
@export var border_emission: float = 3.5

# === LÄNDERNAMEN WIE IN PARADOX (HOI4/EU4) ===
# Groß, states-füllend, skaliert nach Gesamtgröße des Landes (basierend auf Controller in ownership.json)
@export var text_scale: float = 85.0          # Sehr hoch = starke Größenunterschiede (auch bei ähnlich großen Ländern)
@export var min_font_size: int = 42
@export var max_font_size: int = 2000
@export var label_offset: float = 1.004       # Deutlich näher an der Oberfläche (weniger "fliegen im Weltall")
@export var min_diameter_for_label: float = 95.0   # Mikrostaaten unter diesem Wert bekommen KEIN Label
@export var show_country_labels: bool = true
@export var show_province_labels: bool = false  # Fallback/Debug: einzelne Provinz-Namen

@onready var polygons_container: Node3D = get_node("../Polygons")

var region_data: Array = []
var region_polygons: Array = []   # Wichtig für ClickHandler.gd !

var title_font: FontFile = null

func _ready():
	title_font = load("res://fonts/Schluber.otf")
	if title_font == null:
		print("⚠️ Schriftart res://fonts/Schluber.otf nicht gefunden! Fallback wird verwendet.")
	load_regions()

func load_regions():
	var file_path = "res://data/states.geojson"
	if not FileAccess.file_exists(file_path):
		print("❌ states.geojson nicht gefunden!")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var features = json.data.get("features", [])
	print("Lade ", features.size(), " Regionen (States/Provinzen)...")

	region_data.clear()
	region_polygons.clear()
	
	var province_data: Dictionary = {}  # id -> geo + meta
	
	for idx in features.size():
		if idx >= max_features: break
		
		var feature = features[idx]
		var props = feature.get("properties", {})
		var geometry = feature.get("geometry", {})
		
		var region_id = idx + 1
		var region_name = props.get("NAME", props.get("name", ""))
		if region_name == "": continue
		
		var rings = _extract_rings(geometry)
		if rings.is_empty(): continue
		
		# === GRÜNE STATE-GRENZEN (bleibt erhalten für visuelles Feedback) ===
		var border_node = MeshInstance3D.new()
		border_node.name = "Border_%04d" % idx
		polygons_container.add_child(border_node)
		
		var border_st = SurfaceTool.new()
		border_st.begin(Mesh.PRIMITIVE_LINES)
		
		for ring in rings:
			for j in range(ring.size()):
				var p1 = lat_lon_to_vector3(ring[j][1], ring[j][0], radius)
				var p2 = lat_lon_to_vector3(ring[(j + 1) % ring.size()][1], ring[(j + 1) % ring.size()][0], radius)
				border_st.add_vertex(p1)
				border_st.add_vertex(p2)
		
		border_node.mesh = border_st.commit()
		
		var border_mat = StandardMaterial3D.new()
		border_mat.albedo_color = border_color
		border_mat.emission_enabled = true
		border_mat.emission = border_color * border_emission
		border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		border_node.material_override = border_mat
		
		# Store for later + ClickHandler
		var center = _get_ring_center(rings[0])
		province_data[region_id] = {
			"rings": rings,
			"center": center,           # Vector2(lon, lat)
			"local_name": region_name,
			"border": border_node
		}
		
		region_polygons.append({
			"id": region_id,
			"name": region_name,
			"rings": rings,
			"center": center
		})
		
		region_data.append({
			"id": region_id,
			"name": region_name,
			"border": border_node,
			"label": null
		})
	
	print("✅ ", province_data.size(), " Provinzen/States geladen und umrandet.")
	
	# === NEUE COUNTRY-LABELS (das eigentliche Ziel) ===
	var game_data = get_node_or_null("/root/GameData")
	if show_country_labels and game_data != null:
		_create_country_labels(province_data, game_data)
	elif show_province_labels:
		_create_fallback_province_labels(province_data)
	else:
		print("ℹ️ Keine Labels erstellt (show_country_labels=false).")

func _create_country_labels(province_data: Dictionary, game_data: Node):
	if not game_data.get("province_to_controller") or not game_data.get("nations"):
		print("❌ GameData hat keine province_to_controller oder nations. Bitte GameData.gd prüfen.")
		return
	
	var country_groups: Dictionary = {}  # controller_code -> {name, color, points: Array[Vector3]}
	
	for id in province_data.keys():
		var pid: int = id as int
		var controller: String = str(game_data.province_to_controller.get(pid, "UNK")).to_upper().strip_edges()
		if controller == "" or controller == "UNK":
			continue
		
		if not country_groups.has(controller):
			var nation: Dictionary = game_data.nations.get(controller, {})
			country_groups[controller] = {
				"name": nation.get("name", controller),
				"color": nation.get("color", "#e0e0e0"),
				"points": []
			}
		
		var pdata: Dictionary = province_data[id]
		for ring in pdata.rings:
			for pt in ring:
				var v3: Vector3 = lat_lon_to_vector3(pt[1], pt[0], radius)
				country_groups[controller].points.append(v3)
	
	print("🌍 Gruppiere ", country_groups.size(), " Länder nach Controller...")
	
	var labels_created: int = 0
	for ctrl in country_groups.keys():
		var grp: Dictionary = country_groups[ctrl]
		if grp.points.size() < 4:
			continue
		
		# === ZENTRUM BERECHNEN (Centroid der gesamten kontrollierten Fläche) ===
		var sum: Vector3 = Vector3.ZERO
		for p in grp.points:
			sum += p
		var centroid: Vector3 = sum / grp.points.size()
		var len_val: float = centroid.length()
		if len_val < 1.0:
			continue
		centroid = centroid.normalized() * radius
		
		# === GRÖSSE BERECHNEN (maximale Ausdehnung = "states füllend") ===
		var max_dist: float = 0.0
		for p in grp.points:
			max_dist = max(max_dist, (p - centroid).length())
		var diam: float = max_dist * 2.0
		
		if diam < min_diameter_for_label:
			continue   # Zu kleine Länder (Liechtenstein, Monaco, etc.) bekommen kein Label → sauberes Bild
		
		# Starke, nicht-lineare Skalierung für sichtbare Größenunterschiede
		var raw := diam * text_scale * 0.75
		var font_size: int = clamp( int( pow(raw, 1.05) ), min_font_size, max_font_size )
		
		# Sehr kleiner dynamischer Zuschlag, damit große Labels nicht zu weit weg fliegen
		var dynamic_offset := label_offset + (font_size / 22000.0)
		var label_pos: Vector3 = centroid * dynamic_offset
		
		# === LABEL3D ERSTELLEN (Paradox-Style: groß, prominent, farbig) ===
		var text_node := Label3D.new()
		text_node.name = "CountryLabel_" + ctrl
		text_node.text = grp.name
		if title_font != null:
			text_node.font = title_font
		text_node.font_size = font_size
		text_node.outline_size = int(font_size * 0.13) + 8   # Stärkerer schwarzer Outline für gute Lesbarkeit auf Schwarz
		# === WEISSE SCHRIFT MIT STARKEM SCHWARZEN OUTLINE (besser lesbar auf dunklem Globus) ===
		text_node.modulate = Color.WHITE
		text_node.outline_modulate = Color.BLACK
		text_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text_node.no_depth_test = true
		text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_node.position = label_pos
		
		polygons_container.add_child(text_node)
		labels_created += 1
	
	print("✅ ", labels_created, " LÄNDERNAMEN erstellt (wie in HOI4/Paradox).")
	print("   Skalierung: text_scale=%.1f | min=%d max=%d | offset=%.3f (starke Unterschiede + nah an der Oberfläche)" % [text_scale, min_font_size, max_font_size, label_offset])
	print("   Controller aus ownership.json bestimmt Position & Zugehörigkeit.")

func _create_fallback_province_labels(province_data: Dictionary):
	# Alte Logik als Fallback (kleine per-State Labels)
	print("⚠️ Fallback: Erstelle kleine Provinz-Labels (nicht empfohlen).")
	for id in province_data:
		var pdata = province_data[id]
		var text_node := Label3D.new()
		text_node.text = pdata.local_name
		if title_font: text_node.font = title_font
		text_node.font_size = 60
		text_node.outline_size = 8
		text_node.modulate = Color(0.4, 1.0, 0.5)
		text_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text_node.no_depth_test = true
		text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var c = pdata.center
		var pos = lat_lon_to_vector3(c.y, c.x, radius) * 1.004
		text_node.position = pos
		polygons_container.add_child(text_node)

func _extract_rings(geometry: Dictionary) -> Array:
	var rings = []
	var coords = geometry.get("coordinates", [])
	var t = geometry.get("type", "")
	
	if t == "MultiPolygon":
		for poly in coords:
			if poly.size() > 0: rings.append(poly[0])
	elif t == "Polygon":
		if coords.size() > 0: rings.append(coords[0])
	return rings

func _get_ring_center(ring: Array) -> Vector2:
	var sum = Vector2.ZERO
	for p in ring:
		sum += Vector2(p[0], p[1])  # (lon, lat)
	return sum / ring.size()

func lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
