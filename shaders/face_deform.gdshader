shader_type canvas_item;

// Control point positions (UV coordinates)
uniform vec2 left_eye_center = vec2(0.35, 0.35);
uniform vec2 right_eye_center = vec2(0.65, 0.35);
uniform vec2 mouth_center = vec2(0.50, 0.70);
uniform vec2 nose_tip = vec2(0.50, 0.55);
uniform vec2 left_ear = vec2(0.10, 0.50);
uniform vec2 right_ear = vec2(0.90, 0.50);

// Control point scales (driven by script)
uniform vec2 left_eye_scale = vec2(1.0, 1.0);
uniform vec2 right_eye_scale = vec2(1.0, 1.0);
uniform vec2 mouth_scale = vec2(1.0, 1.0);
uniform vec2 nose_scale = vec2(1.0, 1.0);
uniform vec2 left_ear_scale = vec2(1.0, 1.0);
uniform vec2 right_ear_scale = vec2(1.0, 1.0);

// Control point translations (driven by script)
uniform vec2 left_eye_translation = vec2(0.0, 0.0);
uniform vec2 right_eye_translation = vec2(0.0, 0.0);
uniform vec2 mouth_translation = vec2(0.0, 0.0);
uniform vec2 nose_translation = vec2(0.0, 0.0);
uniform vec2 left_ear_translation = vec2(0.0, 0.0);
uniform vec2 right_ear_translation = vec2(0.0, 0.0);

// Inner radius - area that gets 100% deformation (protected area)
uniform float eye_inner_radius: hint_range(0.0, 0.2) = 0.04;
uniform float mouth_inner_radius: hint_range(0.0, 0.2) = 0.06;
uniform float nose_inner_radius: hint_range(0.0, 0.2) = 0.02;
uniform float ear_inner_radius: hint_range(0.0, 0.2) = 0.02;

// Outer radius - edge of deformation influence
uniform float eye_outer_radius: hint_range(0.01, 0.3) = 0.12;
uniform float mouth_outer_radius: hint_range(0.01, 0.3) = 0.16;
uniform float nose_outer_radius: hint_range(0.01, 0.3) = 0.08;
uniform float ear_outer_radius: hint_range(0.01, 0.3) = 0.07;

// Falloff curve for the transition zone
uniform float eye_falloff: hint_range(0.0, 5.0) = 2.0;
uniform float mouth_falloff: hint_range(0.0, 5.0) = 2.0;
uniform float nose_falloff: hint_range(0.0, 5.0) = 2.0;
uniform float ear_falloff: hint_range(0.0, 5.0) = 2.0;

// Debug and utility
uniform bool show_control_points = true;
uniform float point_size: hint_range(0.005, 0.05) = 0.015;
uniform bool show_inner_areas = true;
uniform bool show_outer_areas = true;

// Helper function with inner/outer radius support
vec2 apply_control_point_advanced(vec2 uv, vec2 control_pos, vec2 scale, vec2 translation, float inner_radius, float outer_radius, float falloff) {
    if (outer_radius <= 0.0) return uv;
    
    float dist = distance(uv, control_pos);
    
    // No influence beyond outer radius
    if (dist > outer_radius) return uv;
    
    float influence;
    
    // Full influence within inner radius (protected area)
    if (dist <= inner_radius) {
        influence = 1.0;
    }
    // Gradual falloff between inner and outer radius
    else {
        float transition_zone = outer_radius - inner_radius;
        if (transition_zone > 0.0) {
            float transition_progress = (dist - inner_radius) / transition_zone;
            influence = 1.0 - pow(transition_progress, falloff);
        } else {
            influence = 1.0; // If inner == outer, full influence
        }
    }
    
    // Calculate deformation relative to control point
    vec2 offset_from_control = uv - control_pos;
    
    // Apply scaling
    vec2 scaled_offset = offset_from_control * mix(vec2(1.0), scale, influence);
    
    // Apply translation
    vec2 translated_offset = scaled_offset + translation * influence;
    
    // Return deformed position
    return control_pos + translated_offset;
}

vec2 apply_all_deformations(vec2 uv) {
    vec2 final_uv = uv;
    
    // Apply each control point with inner/outer radius
    final_uv = apply_control_point_advanced(final_uv, left_eye_center, left_eye_scale, left_eye_translation, eye_inner_radius, eye_outer_radius, eye_falloff);
    final_uv = apply_control_point_advanced(final_uv, right_eye_center, right_eye_scale, right_eye_translation, eye_inner_radius, eye_outer_radius, eye_falloff);
    final_uv = apply_control_point_advanced(final_uv, mouth_center, mouth_scale, mouth_translation, mouth_inner_radius, mouth_outer_radius, mouth_falloff);
    final_uv = apply_control_point_advanced(final_uv, nose_tip, nose_scale, nose_translation, nose_inner_radius, nose_outer_radius, nose_falloff);
    final_uv = apply_control_point_advanced(final_uv, left_ear, left_ear_scale, left_ear_translation, ear_inner_radius, ear_outer_radius, ear_falloff);
    final_uv = apply_control_point_advanced(final_uv, right_ear, right_ear_scale, right_ear_translation, ear_inner_radius, ear_outer_radius, ear_falloff);
    
    return final_uv;
}

void fragment() {
    vec2 deformed_uv = apply_all_deformations(UV);
    
    // Sample the texture at deformed coordinates
    vec4 tex_color = texture(TEXTURE, deformed_uv);
    
    // Debug visualization
    if (show_control_points || show_inner_areas || show_outer_areas) {
        // Define control points and their properties for debug rendering
        vec2 points[6] = vec2[](left_eye_center, right_eye_center, mouth_center, nose_tip, left_ear, right_ear);
        float inner_radii[6] = float[](eye_inner_radius, eye_inner_radius, mouth_inner_radius, nose_inner_radius, ear_inner_radius, ear_inner_radius);
        float outer_radii[6] = float[](eye_outer_radius, eye_outer_radius, mouth_outer_radius, nose_outer_radius, ear_outer_radius, ear_outer_radius);
        vec3 colors[6] = vec3[](vec3(1.0, 0.3, 0.3), vec3(1.0, 0.3, 0.3), vec3(0.3, 1.0, 0.3), vec3(0.3, 0.3, 1.0), vec3(1.0, 1.0, 0.3), vec3(1.0, 1.0, 0.3));
        
        for (int i = 0; i < 6; i++) {
            float dist_to_point = distance(UV, points[i]);
            
            // Draw control point dots
            if (show_control_points && dist_to_point < point_size) {
                tex_color = mix(tex_color, vec4(colors[i], 1.0), 0.9);
            }
            
            // Draw inner radius circles (solid protected area)
            if (show_inner_areas && inner_radii[i] > 0.0) {
                float inner_edge = abs(dist_to_point - inner_radii[i]);
                if (inner_edge < 0.003) {
                    tex_color = mix(tex_color, vec4(colors[i], 1.0), 0.8);
                }
                // Fill inner area with subtle tint
                if (dist_to_point < inner_radii[i]) {
                    tex_color = mix(tex_color, vec4(colors[i], 0.1), 0.3);
                }
            }
            
            // Draw outer radius circles (falloff boundary)
            if (show_outer_areas && outer_radii[i] > 0.0) {
                float outer_edge = abs(dist_to_point - outer_radii[i]);
                if (outer_edge < 0.002) {
                    tex_color = mix(tex_color, vec4(colors[i], 0.6), 0.5);
                }
                // Show transition zone with gradient
                if (dist_to_point > inner_radii[i] && dist_to_point < outer_radii[i]) {
                    float transition_zone = outer_radii[i] - inner_radii[i];
                    if (transition_zone > 0.0) {
                        float transition_progress = (dist_to_point - inner_radii[i]) / transition_zone;
                        float alpha = (1.0 - transition_progress) * 0.15;
                        tex_color = mix(tex_color, vec4(colors[i], alpha), alpha);
                    }
                }
            }
        }
    }
    
    COLOR = tex_color;
}