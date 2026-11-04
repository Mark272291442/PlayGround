extends Control

var _mode := "idle"
var _mic_level := 0.0
var _voice_level := 0.0
var _time := 0.0

func set_mode(mode: String) -> void:
	_mode = mode
	queue_redraw()

func set_levels(mic: float, voice: float) -> void:
	_mic_level = clampf(mic, 0.0, 1.0)
	_voice_level = clampf(voice, 0.0, 1.0)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var viewport := get_viewport_rect().size
	var center := Vector2(viewport.x * 0.5, viewport.y * 0.505)
	var active := maxf(_mic_level, _voice_level)
	var pulse := sin(_time * (3.4 if _mode == "speaking" else 2.0)) * 0.5 + 0.5
	var idle_breath := 0.015 * pulse if _mode == "idle" else 0.0
	var response := active * 0.14 + idle_breath + (0.025 * pulse if _mode == "speaking" else 0.0)
	var radius := 104.0 * (1.0 + response)
	var cyan := Color("70e8df")
	var blue := Color("7286ff")
	var pink := Color("ff88c4") if _mode == "speaking" else cyan

	# Layered soft halos keep the visualizer lightweight on mobile.
	_draw_glow(center, radius * 2.05, Color(blue.r, blue.g, blue.b, 0.025 + active * 0.05))
	_draw_glow(center, radius * 1.62, Color(cyan.r, cyan.g, cyan.b, 0.035 + active * 0.07))
	_draw_glow(center, radius * 1.28, Color(pink.r, pink.g, pink.b, 0.045 + active * 0.08))
	draw_circle(center, radius * 1.04, Color(0.30, 0.77, 0.85, 0.09))
	draw_circle(center, radius, Color(0.16, 0.28, 0.47, 0.88))
	draw_circle(center + Vector2(-radius * 0.22, -radius * 0.23), radius * 0.70, Color(0.30, 0.48, 0.68, 0.50))
	draw_circle(center + Vector2(-radius * 0.29, -radius * 0.35), radius * 0.47, Color(0.42, 0.64, 0.82, 0.25))
	draw_circle(center + Vector2(-radius * 0.28, -radius * 0.38), radius * 0.18, Color(0.80, 0.96, 1.0, 0.14))

	var ring_color := Color(cyan.r, cyan.g, cyan.b, 0.46 + active * 0.4)
	draw_arc(center, radius * (1.12 + pulse * 0.035 + active * 0.13), 0.0, TAU, 96, ring_color, 2.0 + active * 2.0, true)
	if _mode == "listening" or _mode == "speaking":
		var wave := radius * (1.32 + fmod(_time * 0.28, 0.22))
		draw_arc(center, wave, 0.0, TAU, 96, Color(cyan.r, cyan.g, cyan.b, 0.16 * (1.0 - fmod(_time * 0.28, 0.22) / 0.22)), 2.0, true)

func _draw_glow(center: Vector2, diameter: float, color: Color) -> void:
	draw_circle(center, diameter * 0.5, color)
