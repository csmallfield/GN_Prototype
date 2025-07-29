# Gravity Nexus Prototype

A space exploration game built in Godot 4.4 featuring procedural planets, dynamic NPC traffic, and a rich universe configuration system.

## Universe Configuration Guide

This guide documents the universe configuration system that powers the Gravity Nexus game world. The entire universe is defined through the `data/universe.json` file, which controls star systems, celestial bodies, NPC traffic, visual effects, and planetary lighting.

## Table of Contents

- [Getting Started](#getting-started)
- [Universe Structure](#universe-structure)
- [System Configuration](#system-configuration)
- [Starfield Configuration](#starfield-configuration)
- [Traffic System](#traffic-system)
- [Celestial Bodies](#celestial-bodies)
- [Planet Animations](#planet-animations)
- [System Lighting Customization](#system-lighting-customization)
- [Government System](#government-system)
- [Complete Examples](#complete-examples)

## Getting Started

The universe is defined in `data/universe.json`. All changes to this file are loaded automatically when the game starts.

### Basic File Structure

```json
{
  "systems": {
    "system_id": { /* system configuration */ }
  },
  "governments": {
    "government_id": { /* government configuration */ }
  }
}
```

## Universe Structure

The `universe.json` file contains two main sections:

- **Systems**: Define star systems, their connections, and contents
- **Governments**: Define factions and their properties

## System Configuration

Each system in the universe can be configured with the following properties:

### Basic System Properties

```json
{
  "name": "System Display Name",
  "description": "Brief system description",
  "flavor_text": "Atmospheric description shown in hyperspace map",
  "background": "res://backgrounds/system_background.png",
  "connections": ["connected_system_1", "connected_system_2"]
}
```

**Properties:**
- `name` (string): Display name shown in the hyperspace map
- `description` (string): Brief description of the system
- `flavor_text` (string): Rich atmospheric text displayed when system is selected in hyperspace map
- `background` (string): Path to background image (optional)
- `connections` (array): List of system IDs that can be reached via hyperspace

## Starfield Configuration

Controls the animated background starfield for each system:

```json
{
  "starfield": {
    "BaseColor": [0.0, 0.0, 0.0],
    "StarLayers_Star_Density": 1.0,
    "StarLayers_Star_Brightness": 1.0,
    "StarLayers_Twinkle_Speed": 0.3
  }
}
```

**Properties:**
- `BaseColor` (array): RGB values [0.0-1.0] for background color
- `StarLayers_Star_Density` (float): Multiplier for star density (1.0 = normal, 2.0 = double density)
- `StarLayers_Star_Brightness` (float): Multiplier for star brightness (1.0 = normal)
- `StarLayers_Twinkle_Speed` (float, optional): Twinkle animation speed (0.0 = no twinkle)

## Traffic System

Controls NPC ship spawning and behavior:

```json
{
  "traffic": {
    "spawn_frequency": 15.0,
    "max_npcs": 5,
    "spawn_frequency_variance": 3.0,
    "npc_config": {
      "thrust_power": 500.0,
      "rotation_speed": 3.0,
      "max_velocity": 400.0,
      "visit_duration_range": [3.0, 8.0]
    }
  }
}
```

**Properties:**
- `spawn_frequency` (float): Base seconds between NPC spawns
- `max_npcs` (integer): Maximum number of NPCs in system simultaneously
- `spawn_frequency_variance` (float): Random variation in spawn timing (±seconds)
- `npc_config` (object): Configuration for NPC ship behavior
  - `thrust_power` (float): NPC ship acceleration force
  - `rotation_speed` (float): NPC turning speed
  - `max_velocity` (float): Maximum NPC ship speed
  - `visit_duration_range` (array): Min/max seconds NPCs spend at celestial bodies

## Celestial Bodies

Array of planets, stations, and other objects in the system:

```json
{
  "celestial_bodies": [
    {
      "id": "unique_planet_id",
      "name": "Planet Name",
      "type": "planet",
      "description": "Planet description",
      "position": { "x": 800, "y": -600 },
      "scale": 1.0,
      "can_land": true,
      "services": ["shipyard", "outfitter", "commodity_exchange"],
      "government": "confederation",
      "tech_level": 5,
      "population": 8000000000,
      "animations": {
        "uv_offset_x": {
          "type": "linear",
          "rate": 0.01
        }
      }
    }
  ]
}
```

### Basic Properties

**Required Properties:**
- `id` (string): Unique identifier used for planet library lookup
- `name` (string): Display name
- `type` (string): "planet" or "station"
- `description` (string): Descriptive text
- `position` (object): X/Y coordinates in system space
- `can_land` (boolean): Whether player can interact with this body

**Optional Properties:**
- `scale` (float): Visual scale multiplier (default: 1.0)
- `sprite` (string): Custom sprite path (for stations)
- `services` (array): Available services when landed
- `government` (string): Controlling government ID
- `tech_level` (integer): Technology level (1-7)
- `population` (integer): Population count

### Available Services

- `"shipyard"`: Ship purchasing and upgrades
- `"outfitter"`: Equipment and weapons
- `"commodity_exchange"`: Trading
- `"mission_computer"`: Mission board
- `"bar"`: Information and rumors

### Planet Types

The system supports procedurally generated planets using the planet library. Use these `id` values to get pre-configured planet appearances:

- `"earth"`: Earth-like blue/green planet
- `"mars"`: Mars-like red desert planet
- `"proxima_b"`: Alien world with unique coloring
- `"new_geneva"`: Terraformed colony world
- `"sirius_major"`: Wealthy trade world
- `"rigel_beta"`: Industrial planet
- `"vega_prime"`: Mining world
- `"default"`: Generic planet template

## Planet Animations

Planets support real-time parameter animations for dynamic visual effects:

```json
{
  "animations": {
    "parameter_name": {
      "type": "animation_type",
      "rate": 1.0,
      "amplitude": 0.2,
      "offset_x": 0.0,
      "offset_y": 0.0
    }
  }
}
```

### Animation Types

**Linear Motion:**
```json
{
  "uv_offset_x": {
    "type": "linear",
    "rate": 0.01
  }
}
```
- Continuous motion in one direction
- Good for planet rotation

**Sine Wave:**
```json
{
  "rim_light_intensity": {
    "type": "sine",
    "rate": 2.0,
    "amplitude": 0.2
  }
}
```
- Smooth oscillation starting at middle
- Good for breathing effects

**Cosine Wave:**
```json
{
  "light_intensity": {
    "type": "cosine",
    "rate": 1.0,
    "amplitude": 0.3
  }
}
```
- Smooth oscillation starting at maximum
- Good for phase-shifted effects

**Pulse Animation:**
```json
{
  "core_color": {
    "type": "pulse",
    "rate": 1.5,
    "amplitude": 0.4
  }
}
```
- Always positive pulsing (0 to 1 range)
- Good for energy effects

**Circular Motion:**
```json
{
  "light_direction": {
    "type": "circular",
    "rate": 0.3,
    "amplitude": 0.5,
    "offset_x": 0.0,
    "offset_y": 0.0
  }
}
```
- Circular motion for Vector2 parameters
- Good for orbiting light sources

### Animatable Parameters

Common planet shader parameters that can be animated:

**UV Controls:**
- `uv_offset_x`, `uv_offset_y`: Planet surface rotation
- `cloud_offset_x`, `cloud_offset_y`: Independent cloud rotation

**Lighting:**
- `light_intensity`: Sun brightness
- `rim_light_intensity`: Atmospheric glow
- `light_direction`: Moving light source

**Colors:**
- Any color parameter for hue shifting effects

**Atmospheric:**
- `cloud_sharpness`: Cloud definition
- `warp_strength`: Surface distortion

## System Lighting Customization

To apply consistent lighting to all planets within a system (simulating different star types), you need to modify the `apply_star_lighting` function in `scripts/CelestialBody.gd`.

### Modifying CelestialBody.gd

Open `scripts/CelestialBody.gd` and find the `apply_star_lighting` function (around line 120). Uncomment and modify the system-specific lighting code:

```gdscript
func apply_star_lighting(material: ShaderMaterial, system_id: String):
	"""Apply star-type-specific lighting"""
	match system_id:
		"sol_system":
			# Yellow star - warm light
			material.set_shader_parameter("light_color", Color(1.0, 0.95, 0.8))
			material.set_shader_parameter("ambient_color", Color(0.4, 0.6, 1.0))
			
		"sirius_system":
			# Blue-white star - cool bright light
			material.set_shader_parameter("light_color", Color(0.9, 0.95, 1.0))
			material.set_shader_parameter("light_intensity", 1.2)
			material.set_shader_parameter("ambient_color", Color(0.6, 0.7, 1.0))
			
		"antares_system":
			# Red supergiant - warm red light
			material.set_shader_parameter("light_color", Color(1.0, 0.7, 0.5))
			material.set_shader_parameter("ambient_color", Color(0.8, 0.4, 0.3))
			
		"rigel_system":
			# Blue supergiant - intense blue-white light
			material.set_shader_parameter("light_color", Color(0.8, 0.9, 1.0))
			material.set_shader_parameter("light_intensity", 1.4)
			material.set_shader_parameter("ambient_color", Color(0.5, 0.6, 1.0))
			
		"arcturus_system":
			# Red giant - warm orange light
			material.set_shader_parameter("light_color", Color(1.0, 0.8, 0.6))
			material.set_shader_parameter("ambient_color", Color(0.7, 0.5, 0.4))
			
		"vega_system":
			# Blue-white star - bright cool light
			material.set_shader_parameter("light_color", Color(0.9, 0.9, 1.0))
			material.set_shader_parameter("light_intensity", 1.1)
			
		_:
			# Default: no overrides
			pass
```

### Available Lighting Parameters

You can set any of these shader parameters for system-wide lighting:

- `light_color` (Color): RGB color of the star's light
- `light_intensity` (float): Brightness multiplier
- `ambient_color` (Color): Color of ambient lighting
- `ambient_light` (float): Ambient light intensity
- `rim_light_intensity` (float): Atmospheric rim lighting
- `rim_light_color` (Color): Color of atmospheric glow

### Star Type Examples

**Yellow Main Sequence (Sol-type):**
```gdscript
material.set_shader_parameter("light_color", Color(1.0, 0.95, 0.8))
material.set_shader_parameter("light_intensity", 1.0)
material.set_shader_parameter("ambient_color", Color(0.4, 0.6, 1.0))
```

**Blue Supergiant (Rigel-type):**
```gdscript
material.set_shader_parameter("light_color", Color(0.8, 0.9, 1.0))
material.set_shader_parameter("light_intensity", 1.4)
material.set_shader_parameter("ambient_color", Color(0.5, 0.6, 1.0))
```

**Red Giant (Arcturus-type):**
```gdscript
material.set_shader_parameter("light_color", Color(1.0, 0.8, 0.6))
material.set_shader_parameter("light_intensity", 0.85)
material.set_shader_parameter("ambient_color", Color(0.7, 0.5, 0.4))
```

**Binary Star System:**
```gdscript
material.set_shader_parameter("light_color", Color(0.95, 0.9, 0.85))
material.set_shader_parameter("light_intensity", 1.1)
material.set_shader_parameter("ambient_color", Color(0.5, 0.5, 0.7))
material.set_shader_parameter("ambient_light", 0.4)
```

## Government System

Define factions and their relationships:

```json
{
  "governments": {
    "confederation": {
      "name": "Terran Confederation",
      "description": "The unified government of human space",
      "color": "#0066CC",
      "starting_reputation": 0
    }
  }
}
```

**Properties:**
- `name` (string): Display name
- `description` (string): Government description
- `color` (string): Hex color code for UI elements
- `starting_reputation` (integer): Initial player standing

## Complete Examples

### High-Traffic Commercial System
```json
{
  "sirius_system": {
    "name": "Sirius System",
    "description": "A wealthy commercial system",
    "flavor_text": "The brightest star in Earth's night sky hosts one of humanity's most prosperous worlds. Corporate executives and luxury merchants conduct business beneath the brilliant white light of this binary star system.",
    "connections": ["alpha_centauri", "aldebaran_system"],
    "starfield": {
      "BaseColor": [0.1, 0.1, 0.15],
      "StarLayers_Star_Density": 0.8,
      "StarLayers_Star_Brightness": 1.4,
      "StarLayers_Twinkle_Speed": 0.15
    },
    "traffic": {
      "spawn_frequency": 6.0,
      "max_npcs": 6,
      "spawn_frequency_variance": 2.0,
      "npc_config": {
        "thrust_power": 550.0,
        "rotation_speed": 3.5,
        "max_velocity": 450.0,
        "visit_duration_range": [3.0, 6.0]
      }
    },
    "celestial_bodies": [
      {
        "id": "sirius_major",
        "name": "Sirius Major",
        "type": "planet",
        "description": "A prosperous trade world",
        "position": { "x": -600, "y": 1200 },
        "scale": 1.2,
        "can_land": true,
        "services": ["shipyard", "outfitter", "commodity_exchange", "mission_computer"],
        "government": "confederation",
        "tech_level": 5,
        "population": 150000000
      }
    ]
  }
}
```

### Remote Frontier Outpost
```json
{
  "deneb_system": {
    "name": "Deneb System",
    "description": "A remote frontier outpost",
    "flavor_text": "On the very edge of known space, this distant white supergiant marks the boundary of human exploration. Only the most adventurous traders and explorers brave the long journey to this isolated outpost.",
    "connections": ["arcturus_system", "capella_system", "antares_system"],
    "planet_overrides": {
      "light_color": [0.95, 0.95, 1.0],
      "light_intensity": 0.7,
      "ambient_color": [0.3, 0.3, 0.4],
      "ambient_light": 0.2
    },
    "traffic": {
      "spawn_frequency": 35.0,
      "max_npcs": 1,
      "spawn_frequency_variance": 15.0,
      "npc_config": {
        "thrust_power": 350.0,
        "rotation_speed": 2.0,
        "max_velocity": 300.0,
        "visit_duration_range": [8.0, 20.0]
      }
    },
    "celestial_bodies": [
      {
        "id": "deneb_outpost",
        "name": "Deneb Frontier Post",
        "type": "station",
        "description": "The edge of known space",
        "position": { "x": 800, "y": 800 },
        "sprite": "res://sprites/stations/mining_station.png",
        "can_land": true,
        "services": ["commodity_exchange", "bar"],
        "government": "independent",
        "tech_level": 2,
        "population": 8000
      }
    ]
  }
}
```

### Animated Planet Example
```json
{
  "earth": {
    "id": "earth",
    "name": "Earth",
    "type": "planet",
    "description": "The blue marble, humanity's homeworld",
    "position": { "x": 800, "y": -600 },
    "scale": 1.0,
    "can_land": true,
    "services": ["shipyard", "outfitter", "commodity_exchange", "mission_computer"],
    "government": "confederation",
    "tech_level": 5,
    "population": 8000000000,
    "animations": {
      "uv_offset_x": {
        "type": "linear", 
        "rate": 0.01
      },
      "cloud_offset_x": {
        "type": "linear", 
        "rate": 0.015
      },
      "rim_light_intensity": {
        "type": "sine", 
        "rate": 2.0, 
        "amplitude": 0.2
      }
    }
  }
}
```

## Implementation Priority

The override system processes parameters in this order:

1. **Planet Library Defaults** - Base planet appearance from library
2. **System Overrides** - Applied to all planets in the system  
3. **Individual Planet Settings** - Planet-specific `animations` override system settings
4. **Procedural Variations** - Random seed variations for uniqueness

This configuration system allows for rich, dynamic space systems with unique visual characteristics, varied NPC behavior, immersive atmospheric details, and consistent stellar lighting that makes each system feel authentic and alive.

## Getting Help

For questions about configuration or to report issues:
- Check the `data/universe.json` file for examples
- Review the planet library in `scenes/PlanetLibrary.tscn` for available planet types
- Examine existing system configurations for reference patterns

The universe configuration system is designed to be powerful yet accessible, allowing both simple tweaks and complex multi-system narratives.
