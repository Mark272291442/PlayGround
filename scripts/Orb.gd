extends Control

const ORB_SHADER: Shader = preload("res://assets/shaders/orb.gdshader")

var _mode := "idle"
var _mic_level := 0.0
var _voice_level := 0.0
var _time := 0.0
var _material: ShaderMaterial

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = ORB_SHADER
	material = _material

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
	if _material == null:
		return
	var viewport := size
	var center := viewport * 0.5
	var activity := maxf(_mic_level, _voice_level)
	var pulse := sin(_time * (3.4 if _mode == "speaking" else 2.0)) * 0.5 + 0.5
	var response := activity * 0.08 + (0.015 * pulse if _mode == "idle" else 0.0)
	var orb_diameter := clampf(viewport.x * 0.57, viewport.x * 0.50, minf(810.0, viewport.x * 0.75))
	orb_diameter *= 1.0 + response
	_material.set_shader_parameter("time", _time)
	_material.set_shader_parameter("activity", activity)
	var shader_diameter := orb_diameter / 0.72
	var rect := Rect2(center - Vector2.ONE * shader_diameter * 0.5, Vector2.ONE * shader_diameter)
	draw_rect(rect, Color.WHITE)
