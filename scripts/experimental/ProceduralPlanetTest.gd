# =============================================================================
# PROCEDURAL PLANET TEST - Verify procedural planets work correctly
# =============================================================================
# ProceduralPlanetTest.gd
extends Node2D

func _ready():
	# Test creating different planet types
	test_earth_like_planet()
	test_mars_like_planet()
	test_alien_planet()
	test_random_planet()

func test_earth_like_planet():
	var earth_data = {
		"id": "earth",
		"name": "Earth",
		"type": "planet",
		"description": "Test Earth-like planet",
		"position": {"x": 0, "y": 0},
		"scale": 1.0,
		"can_land": true
	}
	
	var celestial_body = preload("res://scenes/CelestialBody.tscn").instantiate()
	celestial_body.celestial_data = earth_data
	celestial_body.position = Vector2(-600, 0)
	add_child(celestial_body)

func test_mars_like_planet():
	var mars_data = {
		"id": "mars",
		"name": "Mars",
		"type": "planet",
		"description": "Test Mars-like planet",
		"position": {"x": 0, "y": 0},
		"scale": 0.8,
		"can_land": true
	}
	
	var celestial_body = preload("res://scenes/CelestialBody.tscn").instantiate()
	celestial_body.celestial_data = mars_data
	celestial_body.position = Vector2(0, 0)
	celestial_body.scale = Vector2(0.8, 0.8)
	add_child(celestial_body)

func test_alien_planet():
	var alien_data = {
		"id": "proxima_b",
		"name": "New Geneva",
		"type": "planet",
		"description": "Test alien planet",
		"position": {"x": 0, "y": 0},
		"scale": 1.1,
		"can_land": true
	}
	
	var celestial_body = preload("res://scenes/CelestialBody.tscn").instantiate()
	celestial_body.celestial_data = alien_data
	celestial_body.position = Vector2(600, 0)
	celestial_body.scale = Vector2(1.1, 1.1)
	add_child(celestial_body)

func test_random_planet():
	var random_data = {
		"id": "test_random",
		"name": "Random Planet",
		"type": "planet",
		"description": "Test random planet generation",
		"position": {"x": 0, "y": 0},
		"scale": 0.9,
		"can_land": true
	}
	
	var celestial_body = preload("res://scenes/CelestialBody.tscn").instantiate()
	celestial_body.celestial_data = random_data
	celestial_body.position = Vector2(0, -600)
	celestial_body.scale = Vector2(0.9, 0.9)
	add_child(celestial_body)

func _input(event):
	if event.is_action_pressed("regenerate_planets
	"):
		# Regenerate planets with new random seeds
		get_tree().reload_current_scene()
