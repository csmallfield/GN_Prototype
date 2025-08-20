shader_type canvas_item;

// Base Shape Controls
uniform float base_scale : hint_range(0.5, 8.0) = 3.0;
uniform float base_density : hint_range(0.0, 1.0) = 0.6;
uniform float base_softness : hint_range(0.0, 3.0) = 0.5;
uniform float base_octaves : hint_range(1.0, 6.0) = 6.0;
uniform float base_lacunarity : hint_range(0.1, 10.0) = 2.75;
uniform float base_gain : hint_range(0.1, 0.9) = 0.5;

// Internal Structure Controls
uniform float structure_scale : hint_range(0.5, 20.0) = 10.0;
uniform float structure_strength : hint_range(0.0, 2.0) = 0.75;
uniform float structure_contrast : hint_range(0.1, 10.0) = 1.25;
uniform float structure_octaves : hint_range(1.0, 6.0) = 3.0;
uniform float structure_lacunarity : hint_range(0.1, 10.0) = 2.0;
uniform float structure_gain : hint_range(0.1, 0.9) = 0.5;

// Wispy Details
uniform float wispy_scale : hint_range(0.0, 50.0) = 8.0;
uniform float wispy_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wispy_octaves : hint_range(1.0, 6.0) = 6.0;
uniform float wispy_lacunarity : hint_range(0.1, 10.0) = 2.0;
uniform float wispy_gain : hint_range(0.1, 0.9) = 0.5;

// Edge Controls
uniform float edge_falloff : hint_range(0.1, 10.0) = 1.5;
uniform float edge_irregularity : hint_range(0.0, 10.0) = 4;
uniform float hard_edge_mix : hint_range(0.0, 1.0) = 0.0;

// Colors for different layers
uniform vec4 nebula_base_color : source_color = vec4(0.1, 0.2, 0.6, 1.0);
uniform vec4 structure_color : source_color = vec4(0.8, 0.3, 0.5, 1.0);
uniform vec4 wispy_color : source_color = vec4(0.3, 0.5, 0.9, 1.0);
uniform vec4 edge_color : source_color = vec4(0.2, 0.5, 0.8, 1.0);

// Color Blending
uniform float color_blend_smoothness : hint_range(0.1, 5.0) = 1;
uniform float overall_brightness : hint_range(0.0, 5.0) = 1;

// Star Controls
uniform float star_density : hint_range(0.0, 1.0) = 0.475;
uniform float star_scale : hint_range(0.1, 5.0) = 1.0;
uniform float star_brightness : hint_range(0.0, 3.0) = 1.5;
uniform float star_size_variation : hint_range(0.0, 1.0) = 0.7;

// Star Distribution
uniform float cluster_scale : hint_range(0.5, 10.0) = 3.0;
uniform float cluster_strength : hint_range(0.0, 1.0) = 0.4;
uniform float scatter_randomness : hint_range(0.0, 5.0) = 1;
uniform float star_organic_mask_scale : hint_range(0.1, 20.0) = 4.0;
uniform float star_organic_mask_strength : hint_range(0.0, 1.0) = 0.7;

// Star Appearance
uniform float star_core_size : hint_range(0.1, 2.0) = 0.5;
uniform vec4 star_core_color : source_color = vec4(1.0, 0.9, 0.8, 1.0);

// Star Glow System
uniform float star_glow_size : hint_range(0.1, 50.0) = 1.0;
uniform float star_glow_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float star_glow_softness : hint_range(0.1, 20.0) = 2.0;
uniform vec4 star_glow_color : source_color = vec4(0.8, 0.6, 1.0, 1.0);
uniform float star_glow_blend_mode : hint_range(0.0, 3.0) = 1.0;

// Star Blending
uniform float star_nebula_interaction : hint_range(0.0, 1.0) = 0.6;
uniform float star_blend_mode : hint_range(0.0, 3.0) = 0.0;

// Basic noise function
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// Enhanced FBM with configurable parameters
float fbm_configurable(vec2 uv, float scale_mult, float oct, float lac, float g) {
    float value = 0.0;
    float amplitude = 0.5;
    vec2 p = uv * scale_mult;

    int max_octaves = int(oct);
    for (int i = 0; i < max_octaves; i++) {
        value += amplitude * noise(p);
        amplitude *= g;
        p *= lac;
    }

    return value * 0.5 + 0.5;
}

// Base nebula shape - irregular cloud
float get_base_shape(vec2 uv) {
    float base = fbm_configurable(uv, base_scale, base_octaves, base_lacunarity, base_gain);

    // Make it more cloud-like with soft threshold
    float shape = smoothstep(base_density - base_softness, base_density + base_softness, base);

    // Add some overall falloff from center
    vec2 center = uv - vec2(0.5);
    float dist_falloff = 1.0 - smoothstep(0.2, 0.8, length(center) * edge_falloff);

    return shape * dist_falloff;
}

// Internal structure - creates visible density variations
float get_internal_structure(vec2 uv) {
    float structure = fbm_configurable(uv + vec2(100.0, 50.0), structure_scale,
                                      structure_octaves, structure_lacunarity, structure_gain);

    // Apply contrast to make structure more visible
    structure = pow(structure, 1.0 / structure_contrast);

    return structure * structure_strength;
}

// Wispy details - fine tendrils and filaments
float get_wispy_details(vec2 uv) {
    float wispy = fbm_configurable(uv + vec2(200.0, 300.0), wispy_scale,
                                  wispy_octaves, wispy_lacunarity, wispy_gain);

    // Make wispy features more thread-like
    wispy = abs(wispy - 0.5) * 2.0;
    wispy = 1.0 - wispy;
    wispy = pow(wispy, 3.0);

    return wispy * wispy_strength;
}

// Edge irregularity
float get_edge_variation(vec2 uv) {
    if (edge_irregularity <= 0.0) return 1.0;

    float edge_noise = fbm_configurable(uv + vec2(400.0, 500.0), base_scale * 2.0, 3.0, 2.0, 0.5);
    edge_noise = (edge_noise - 0.5) * edge_irregularity + 1.0;

    return clamp(edge_noise, 0.0, 2.0);
}

// Star generation functions
float star_noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

float get_star_clusters(vec2 uv) {
    float cluster_pattern = fbm_configurable(uv + vec2(1000.0, 2000.0), cluster_scale, 3.0, 2.0, 0.5);
    cluster_pattern = pow(cluster_pattern, 1.5);
    return mix(1.0, cluster_pattern, cluster_strength);
}

float get_star_organic_mask(vec2 uv) {
    float mask_noise = fbm_configurable(uv + vec2(5000.0, 6000.0), star_organic_mask_scale, 3.0, 2.0, 0.5);
    return mix(1.0, mask_noise, star_organic_mask_strength);
}

float generate_star_cores(vec2 uv) {
    // Scale UV for star grid
    vec2 star_uv = uv * 50.0 * star_scale;
    vec2 grid_id = floor(star_uv);
    vec2 grid_uv = fract(star_uv);

    // Add randomness to star positions within grid cells
    vec2 star_offset = vec2(
        star_noise(grid_id) - 0.5,
        star_noise(grid_id + vec2(100.0, 200.0)) - 0.5
    ) * scatter_randomness;

    vec2 star_pos = grid_uv + star_offset;

    // Check if this cell should have a star - FIXED: higher star_density = more stars
    float cell_random = star_noise(grid_id + vec2(300.0, 400.0));
    float cluster_influence = get_star_clusters(grid_id / (50.0 * star_scale));
    float organic_mask = get_star_organic_mask(grid_id / (50.0 * star_scale));

    // Combine all influences - now star_density works intuitively
    float star_threshold = (1.0 - star_density) / (cluster_influence * organic_mask + 0.1);

    if (cell_random > star_threshold) {
        return 0.0; // No star in this cell
    }

    // Calculate distance to star center
    vec2 center_offset = star_pos - vec2(0.5);
    float dist_to_star = length(center_offset);

    // Vary star size
    float size_random = star_noise(grid_id + vec2(500.0, 600.0));
    float star_size = mix(0.5, 1.0, size_random * star_size_variation + (1.0 - star_size_variation));

    // Create tight star core
    float core_size = 0.015 * star_size * star_core_size;
    float star_core = 1.0 - smoothstep(0.0, core_size, dist_to_star);

    return star_core;
}

float generate_star_glow(vec2 uv, float pixel_size) {
    float total_glow = 0.0;

    // Sample multiple grid cells around current position for glow
    vec2 star_uv = uv * 50.0 * star_scale;
    vec2 current_grid = floor(star_uv);

    // Check a 5x5 area around current position for nearby stars
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 check_grid = current_grid + vec2(float(x), float(y));

            // Check if this grid cell has a star
            float cell_random = star_noise(check_grid + vec2(300.0, 400.0));
            float cluster_influence = get_star_clusters(check_grid / (50.0 * star_scale));
            float organic_mask = get_star_organic_mask(check_grid / (50.0 * star_scale));
            float star_threshold = (1.0 - star_density) / (cluster_influence * organic_mask + 0.1);

            if (cell_random <= star_threshold) {
                // This cell has a star, calculate its position
                vec2 star_offset = vec2(
                    star_noise(check_grid) - 0.5,
                    star_noise(check_grid + vec2(100.0, 200.0)) - 0.5
                ) * scatter_randomness;

                vec2 star_grid_pos = fract(check_grid / (50.0 * star_scale)) + star_offset / (50.0 * star_scale);
                vec2 star_world_pos = check_grid / (50.0 * star_scale);

                // Calculate distance from current pixel to this star
                vec2 star_actual_pos = star_world_pos + (star_offset / (50.0 * star_scale));
                float dist_to_star = distance(uv, star_actual_pos);

                // Create glow based on pixel distance
                float glow_radius_world = (star_glow_size * pixel_size) / 1000.0; // Convert to world space
                float glow = 1.0 - smoothstep(0.0, glow_radius_world, dist_to_star);
                glow = pow(glow, star_glow_softness);

                // Vary glow intensity per star
                float size_random = star_noise(check_grid + vec2(500.0, 600.0));
                float star_size = mix(0.5, 1.0, size_random * star_size_variation + (1.0 - star_size_variation));

                total_glow += glow * star_glow_intensity * star_size;
            }
        }
    }

    return clamp(total_glow, 0.0, 1.0);
}

// Blending mode functions
vec3 blend_add(vec3 base, vec3 overlay, float strength) {
    return base + overlay * strength;
}

vec3 blend_screen(vec3 base, vec3 overlay, float strength) {
    vec3 result = 1.0 - (1.0 - base) * (1.0 - overlay);
    return mix(base, result, strength);
}

vec3 blend_overlay(vec3 base, vec3 overlay, float strength) {
    vec3 result = mix(
        2.0 * base * overlay,
        1.0 - 2.0 * (1.0 - base) * (1.0 - overlay),
        step(0.5, base)
    );
    return mix(base, result, strength);
}

vec3 blend_color_dodge(vec3 base, vec3 overlay, float strength) {
    vec3 result = base / (1.0 - overlay + 0.001);
    return mix(base, result, strength);
}

vec3 apply_star_blending(vec3 nebula_color, vec3 star_color, float star_alpha, float blend_mode, float interaction) {
    vec3 result = nebula_color;

    if (star_alpha > 0.001) {
        int mode = int(blend_mode);
        if (mode == 0) {
            result = blend_add(nebula_color, star_color, star_alpha * interaction);
        } else if (mode == 1) {
            result = blend_screen(nebula_color, star_color, star_alpha * interaction);
        } else if (mode == 2) {
            result = blend_overlay(nebula_color, star_color, star_alpha * interaction);
        } else if (mode == 3) {
            result = blend_color_dodge(nebula_color, star_color, star_alpha * interaction);
        }
    }

    return result;
}

vec3 apply_glow_blending(vec3 base_color, vec3 glow_color, float glow_alpha, float blend_mode) {
    vec3 result = base_color;

    if (glow_alpha > 0.001) {
        int mode = int(blend_mode);
        if (mode == 0) {
            result = blend_add(base_color, glow_color, glow_alpha);
        } else if (mode == 1) {
            result = blend_screen(base_color, glow_color, glow_alpha);
        } else if (mode == 2) {
            result = blend_overlay(base_color, glow_color, glow_alpha);
        } else if (mode == 3) {
            result = blend_color_dodge(base_color, glow_color, glow_alpha);
        }
    }

    return result;
}

// Color mixing based on noise layers
vec3 mix_nebula_colors(float base, float structure, float wispy, float edge_var) {
    vec3 color = nebula_base_color.rgb;

    float structure_mix = smoothstep(0.3, 0.7, structure) * color_blend_smoothness;
    color = mix(color, structure_color.rgb, structure_mix);

    float wispy_mix = smoothstep(0.4, 0.8, wispy) * color_blend_smoothness;
    color = mix(color, wispy_color.rgb, wispy_mix);

    float edge_mix = (1.0 - edge_var) * 0.3 * color_blend_smoothness;
    color = mix(color, edge_color.rgb, edge_mix);

    return color;
}

void fragment() {
    vec2 uv = UV;

    // Calculate approximate pixel size for glow scaling
    float pixel_size = length(fwidth(uv)) * 1000.0; // Approximate pixel size

    // Generate nebula first
    float base_shape = get_base_shape(uv);
    float structure = get_internal_structure(uv);
    float wispy = get_wispy_details(uv);
    float edge_var = get_edge_variation(uv);

    float combined_density = base_shape + (structure * base_shape) + (wispy * base_shape);
    combined_density = clamp(combined_density, 0.0, 1.0);
    combined_density *= edge_var;

    float soft_alpha = combined_density;
    float hard_alpha = step(0.1, combined_density);
    float nebula_alpha = mix(soft_alpha, hard_alpha, hard_edge_mix);

    vec3 nebula_color = mix_nebula_colors(base_shape, structure, wispy, edge_var);

    // Generate stars (cores and glow separately)
    float star_cores = generate_star_cores(uv);
    float star_glow = generate_star_glow(uv, pixel_size);

    // Stars can extend slightly beyond nebula for glow effect
    star_cores *= nebula_alpha; // Cores strictly within nebula
    // Allow glow to extend beyond nebula boundaries but fade it
    star_glow *= mix(0.3, 1.0, nebula_alpha); // Glow can extend beyond but is reduced

    // Create star colors
    vec3 star_core_color_final = star_core_color.rgb * star_brightness;
    vec3 star_glow_color_final = star_glow_color.rgb;

    // Start with nebula
    vec3 final_color = nebula_color;
    float final_alpha = nebula_alpha;

    // Add star glow first (broader, softer)
    final_color = apply_glow_blending(final_color, star_glow_color_final, star_glow, star_glow_blend_mode);

    // Add star cores on top (sharp, bright)
    final_color = apply_star_blending(final_color, star_core_color_final, star_cores,
                                     star_blend_mode, star_nebula_interaction);

    // Stars contribute to alpha, glow can extend nebula boundaries slightly
    float star_alpha_contribution = star_cores + (star_glow * 0.5);
    final_alpha = max(nebula_alpha, star_alpha_contribution);

    // Apply brightness
    final_color *= overall_brightness * final_alpha;

    COLOR = vec4(final_color, final_alpha);
}