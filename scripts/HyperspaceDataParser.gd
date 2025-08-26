# =============================================================================
# HYPERSPACE DATA PARSER - Loads and parses Gephi CSV exports
# =============================================================================
extends RefCounted
class_name HyperspaceDataParser

# Parsed data structures
var nodes_data: Array[Dictionary] = []
var edges_data: Array[Dictionary] = []
var nodes_by_id: Dictionary = {}

# Coordinate bounds for normalization
var coord_bounds: Dictionary = {
	"min_x": 0.0, "max_x": 0.0,
	"min_y": 0.0, "max_y": 0.0,
	"width": 0.0, "height": 0.0
}

func load_csv_files(nodes_path: String, edges_path: String) -> bool:
	"""Load and parse both CSV files"""
	print("Loading hyperspace data from CSV files...")
	
	if not load_nodes_csv(nodes_path):
		return false
		
	if not load_edges_csv(edges_path):
		return false
	
	calculate_coordinate_bounds()
	build_node_lookup()
	
	print("✅ Successfully loaded ", nodes_data.size(), " nodes and ", edges_data.size(), " edges")
	return true

func load_nodes_csv(path: String) -> bool:
	"""Load nodes from CSV file"""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open nodes CSV: " + path)
		return false
	
	var csv_content = file.get_as_text()
	file.close()
	
	nodes_data = parse_csv_content(csv_content, true)
	
	if nodes_data.is_empty():
		push_error("No nodes data parsed from CSV")
		return false
	
	print("Loaded ", nodes_data.size(), " nodes from CSV")
	return true

func load_edges_csv(path: String) -> bool:
	"""Load edges from CSV file"""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open edges CSV: " + path)
		return false
	
	var csv_content = file.get_as_text()
	file.close()
	
	edges_data = parse_csv_content(csv_content, false)
	
	if edges_data.is_empty():
		push_error("No edges data parsed from CSV")
		return false
	
	print("Loaded ", edges_data.size(), " edges from CSV")
	return true

func parse_csv_content(content: String, is_nodes: bool) -> Array[Dictionary]:
	"""Parse CSV content into array of dictionaries"""
	var lines = content.split("\n")
	if lines.size() < 2:
		push_error("CSV file has insufficient data")
		return []
	
	# Parse header
	var headers = parse_csv_line(lines[0])
	var data: Array[Dictionary] = []
	
	# Parse data lines
	for i in range(1, lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue
			
		var values = parse_csv_line(line)
		if values.size() != headers.size():
			continue  # Skip malformed lines
		
		var record = {}
		for j in range(headers.size()):
			var header = headers[j]
			var value = values[j]
			
			# Convert numeric values
			record[header] = convert_csv_value(value, header, is_nodes)
		
		data.append(record)
	
	return data

func parse_csv_line(line: String) -> Array[String]:
	"""Parse a CSV line handling quoted values"""
	var values: Array[String] = []
	var current_value = ""
	var in_quotes = false
	var i = 0
	
	while i < line.length():
		var char = line[i]
		
		if char == '"' and (i == 0 or line[i-1] != '\\'):
			in_quotes = !in_quotes
		elif char == ',' and not in_quotes:
			values.append(current_value.strip_edges())
			current_value = ""
		else:
			current_value += char
		
		i += 1
	
	# Don't forget the last value
	values.append(current_value.strip_edges())
	
	return values

func convert_csv_value(value: String, header: String, is_nodes: bool):
	"""Convert CSV string values to appropriate types"""
	# Handle empty values
	if value.is_empty() or value == "null":
		return null
	
	# Remove quotes if present
	if value.begins_with('"') and value.ends_with('"'):
		value = value.substr(1, value.length() - 2)
	
	# Convert based on header type
	if is_nodes:
		return convert_node_value(value, header)
	else:
		return convert_edge_value(value, header)

func convert_node_value(value: String, header: String):
	"""Convert node-specific values"""
	match header:
		"Id", "population", "crimelevel", "corruptionlevel":
			return value.to_int()
		"X", "Y", "Size":
			return value.to_float()
		"ishub", "isexceptional":
			return value.to_lower() == "true"
		_:
			return value

func convert_edge_value(value: String, header: String):
	"""Convert edge-specific values"""
	match header:
		"Source", "Target", "Id", "Weight", "piracyrisk":
			return value.to_int()
		"Label":
			return value.to_float() if value.is_valid_float() else value
		_:
			return value

func calculate_coordinate_bounds():
	"""Calculate the bounds of all node coordinates"""
	if nodes_data.is_empty():
		return
	
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	
	for node in nodes_data:
		var x = node.get("X", 0.0)
		var y = node.get("Y", 0.0)
		
		min_x = min(min_x, x)
		max_x = max(max_x, x)
		min_y = min(min_y, y)
		max_y = max(max_y, y)
	
	coord_bounds = {
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
		"width": max_x - min_x,
		"height": max_y - min_y
	}
	
	print("Coordinate bounds: X(", min_x, " to ", max_x, ") Y(", min_y, " to ", max_y, ")")

func build_node_lookup():
	"""Build a lookup dictionary for nodes by ID"""
	nodes_by_id.clear()
	for node in nodes_data:
		var id = node.get("Id", -1)
		if id != -1:
			nodes_by_id[id] = node

func get_node_by_id(id: int) -> Dictionary:
	"""Get node data by ID"""
	return nodes_by_id.get(id, {})

func normalize_coordinates_to_rect(target_rect: Rect2) -> Dictionary:
	"""Normalize all coordinates to fit within target rectangle"""
	var normalized = {"nodes": [], "bounds": coord_bounds}
	
	for node in nodes_data:
		var x = node.get("X", 0.0)
		var y = node.get("Y", 0.0)
		
		# Normalize to 0-1 range
		var norm_x = (x - coord_bounds.min_x) / coord_bounds.width
		var norm_y = (y - coord_bounds.min_y) / coord_bounds.height
		
		# Scale to target rectangle
		var final_x = target_rect.position.x + norm_x * target_rect.size.x
		var final_y = target_rect.position.y + norm_y * target_rect.size.y
		
		var normalized_node = node.duplicate()
		normalized_node["normalized_x"] = final_x
		normalized_node["normalized_y"] = final_y
		
		normalized.nodes.append(normalized_node)
	
	return normalized

func get_node_color(node: Dictionary) -> Color:
	"""Get node color from CSV data or default"""
	var color_str = node.get("Color", "#FFFFFF")
	if color_str.begins_with("#") and color_str.length() >= 7:
		return Color.html(color_str)
	return Color.WHITE

func get_edge_color(edge: Dictionary) -> Color:
	"""Get edge color based on travel safety"""
	var safety = edge.get("travelsafety", "")
	match safety:
		"Safe":
			return Color.GREEN
		"Mostly Safe":
			return Color.YELLOW
		"Dangerous":
			return Color.ORANGE
		"Very Dangerous":
			return Color.RED
		"Extremely Dangerous":
			return Color.DARK_RED
		_:
			return Color.GRAY

func get_node_display_name(node: Dictionary) -> String:
	"""Get a display-friendly name for the node"""
	var label = node.get("Label", "")
	if not label.is_empty():
		return label
	return "Node " + str(node.get("Id", "?"))

# Debug methods
func print_sample_data():
	"""Print sample data for debugging"""
	print("=== SAMPLE NODES ===")
	for i in range(min(3, nodes_data.size())):
		print("Node ", i, ": ", nodes_data[i])
	
	print("=== SAMPLE EDGES ===")
	for i in range(min(3, edges_data.size())):
		print("Edge ", i, ": ", edges_data[i])
	
	print("=== COORDINATE BOUNDS ===")
	print(coord_bounds)

func get_stats() -> Dictionary:
	"""Get statistics about the loaded data"""
	return {
		"node_count": nodes_data.size(),
		"edge_count": edges_data.size(),
		"coordinate_bounds": coord_bounds,
		"has_data": not nodes_data.is_empty() and not edges_data.is_empty()
	}
