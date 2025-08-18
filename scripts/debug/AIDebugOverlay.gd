# AIDebugOverlay.gd - Fixed version
extends CanvasLayer

var enabled: bool = false
var debug_control: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create a Control node for drawing
	debug_control = Control.new()
	debug_control.name = "DebugDrawing"
	debug_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(debug_control)
	
	# Connect the draw function
	debug_control.draw.connect(_on_draw)
	
	# Hide initially
	visible = false

func _input(event):
	if event.is_action_pressed("debug_toggle"):  # F12
		enabled = !enabled
		visible = enabled
		if enabled:
			debug_control.queue_redraw()

func _on_draw():
	if not enabled or not debug_control:
		return
	
	# Draw NPC states
	var npcs = get_tree().get_nodes_in_group("npc_ships")
	var font = ThemeDB.fallback_font
	var player = UniverseManager.player_ship
	
	if not player:
		return
	
	var camera = player.get_node_or_null("Camera2D")
	if not camera:
		return
	
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
			
		# Convert world position to screen position
		var screen_pos = camera.get_screen_transform() * npc.global_position
		
		# Get state text - handle the enum properly
		var state_text = "State: "
		if npc.has_method("get_current_state_name"):
			state_text += npc.get_current_state_name()
		else:
			# Convert enum to string
			state_text += NPCShip.AIState.keys()[npc.current_ai_state]
		
		# Draw the state
		debug_control.draw_string(font, screen_pos + Vector2(0, -40), 
			state_text, 
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.YELLOW)
		
		# Draw health bar
		if npc.has_method("get_hull_percent"):
			var hull_percent = npc.get_hull_percent()
			var bar_width = 40
			var bar_height = 4
			var bar_pos = screen_pos + Vector2(-bar_width/2, -30)
			
			# Background
			debug_control.draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color.RED)
			# Health
			debug_control.draw_rect(Rect2(bar_pos, Vector2(bar_width * hull_percent, bar_height)), Color.GREEN)

func _process(_delta):
	if enabled and debug_control:
		debug_control.queue_redraw()
