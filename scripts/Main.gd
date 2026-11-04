extends Control

const SILENCE_SECONDS := 0.85
const MAX_UTTERANCE_SECONDS := 12.0
const SPEECH_THRESHOLD_DB := -38.0
const BARGE_THRESHOLD_DB := -32.0
const BARGE_HOLD_SECONDS := 0.16
const WHISPER_URL := "https://api.openai.com/v1/audio/transcriptions"
const CHAT_URL := "https://api.openai.com/v1/chat/completions"

var _status: Label
var _hint: Label
var _end_button: Button
var _orb: Control
var _player: AudioStreamPlayer
var _mic_player: AudioStreamPlayer
var _recorder: AudioEffectRecord
var _mic_bus := -1
var _voice_bus := -1
var _mic_capture: AudioEffectCapture
var _state := "starting"
var _muted := false
var _mic_permission_granted := false
var _call_ended := false
var _speech_seconds := 0.0
var _silence_seconds := 0.0
var _barge_seconds := 0.0
var _generation := 0
var _conversation: Array[Dictionary] = []
var _error_tone: AudioStreamPlayer

func _ready() -> void:
	_build_ui()
	_setup_audio()
	_conversation.append({"role": "system", "content": _persona_prompt()})
	if not OS.has_feature("mobile"):
		print("ECHO: configure credentials in user://echo_config.cfg; see README.md")
	var missing := EchoConfig.missing_setting()
	if not missing.is_empty():
		_end_button.text = "SETUP NEEDED"
		_end_button.disabled = true
		_set_state("setup", "Add API credentials to start")
		_hint.text = "See README for private setup"
	else:
		_mic_permission_granted = _start_mic()
		if _mic_permission_granted:
			_set_state("listening", "Say hello to Ana")
		else:
			_show_mic_permission_error()

func _persona_prompt() -> String:
	return EchoConfig.SYSTEM_PROMPT.replace("You are Ana", "You are %s" % EchoConfig.ana_name)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background_material := ShaderMaterial.new()
	background_material.shader = load("res://assets/shaders/background.gdshader")
	background.material = background_material
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var brand := Label.new()
	brand.text = "E C H O"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 36)
	brand.add_theme_color_override("font_color", Color("9aa8c3"))
	brand.set_anchors_preset(Control.PRESET_TOP_WIDE)
	brand.offset_top = 108
	brand.offset_bottom = 153
	add_child(brand)

	var companion := Label.new()
	companion.text = EchoConfig.ana_name
	companion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	companion.add_theme_font_size_override("font_size", 108)
	companion.add_theme_color_override("font_color", Color("f4f6ff"))
	companion.set_anchors_preset(Control.PRESET_TOP_WIDE)
	companion.offset_top = 276
	companion.offset_bottom = 414
	add_child(companion)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 42)
	_status.add_theme_color_override("font_color", Color("aab7cf"))
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top = 450
	_status.offset_bottom = 510
	add_child(_status)

	_orb = Control.new()
	_orb.set_script(load("res://scripts/Orb.gd"))
	_orb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb.z_index = 1
	add_child(_orb)

	_hint = Label.new()
	_hint.text = "Your call is private to you"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 39)
	_hint.add_theme_color_override("font_color", Color("7786a3"))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -510
	_hint.offset_bottom = -465
	add_child(_hint)

	_end_button = Button.new()
	_end_button.text = "END CALL"
	_end_button.custom_minimum_size = Vector2(630, 180)
	_end_button.add_theme_font_size_override("font_size", 39)
	_end_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_end_button.anchor_left = 0.5
	_end_button.anchor_right = 0.5
	_end_button.offset_left = -315
	_end_button.offset_right = 315
	_end_button.offset_top = -390
	_end_button.offset_bottom = -210
	_end_button.pressed.connect(_on_end_pressed)
	add_child(_end_button)

	var caption := Label.new()
	caption.text = "A VOICE COMPANION · FILIPINO & ENGLISH"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_color", Color("52617d"))
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -190
	caption.offset_bottom = -150
	add_child(caption)

	_player = AudioStreamPlayer.new()
	_player.bus = "ECHO Voice"
	_player.finished.connect(_on_voice_finished)
	add_child(_player)
	_error_tone = AudioStreamPlayer.new()
	add_child(_error_tone)

func _setup_audio() -> void:
	_mic_bus = AudioServer.get_bus_index("ECHO Mic")
	if _mic_bus < 0:
		_mic_bus = AudioServer.bus_count
		AudioServer.add_bus(_mic_bus)
		AudioServer.set_bus_name(_mic_bus, "ECHO Mic")
		AudioServer.set_bus_send(_mic_bus, "Master")
		AudioServer.set_bus_volume_db(_mic_bus, -60.0) # Do not monitor the caller through the speakers.
	_voice_bus = AudioServer.get_bus_index("ECHO Voice")
	if _voice_bus < 0:
		_voice_bus = AudioServer.bus_count
		AudioServer.add_bus(_voice_bus)
		AudioServer.set_bus_name(_voice_bus, "ECHO Voice")
		AudioServer.set_bus_send(_voice_bus, "Master")
	_mic_capture = AudioEffectCapture.new()
	_mic_capture.buffer_length = 0.25
	AudioServer.add_bus_effect(_mic_bus, _mic_capture)
	_recorder = AudioEffectRecord.new()
	_recorder.format = AudioStreamWAV.FORMAT_16_BITS
	_recorder.set_recording_active(false)
	AudioServer.add_bus_effect(_mic_bus, _recorder)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "ECHO Mic"
	add_child(_mic_player)

func _start_mic() -> bool:
	if OS.has_feature("android") and not OS.request_permissions():
		return false
	if not _mic_player.playing:
		_mic_player.play()
	return true

func _show_mic_permission_error() -> void:
	_mic_permission_granted = false
	_end_button.text = "ALLOW MIC"
	_set_state("permission", "Microphone permission is required")
	_hint.text = "Allow microphone access in Android Settings, then tap to retry"

func _process(delta: float) -> void:
	if _call_ended or _muted or not _mic_permission_granted or _mic_bus < 0:
		return
	var mic_amplitude := _read_mic_amplitude()
	var level_db := linear_to_db(maxf(mic_amplitude, 0.00001))
	var voice_db := AudioServer.get_bus_peak_volume_left_db(_voice_bus, 0) if _voice_bus >= 0 else -80.0
	_orb.call("set_levels", clampf((level_db + 55.0) / 45.0, 0.0, 1.0), clampf((voice_db + 55.0) / 45.0, 0.0, 1.0))
	if _state == "speaking":
		if level_db > BARGE_THRESHOLD_DB:
			_barge_seconds += delta
		else:
			_barge_seconds = 0.0
		if _barge_seconds >= BARGE_HOLD_SECONDS:
			_barge_in()
		return
	if _state != "listening" and _state != "capturing":
		return
	if _state == "listening":
		if level_db > SPEECH_THRESHOLD_DB:
			_begin_capture()
	else:
		_speech_seconds += delta
		if level_db > SPEECH_THRESHOLD_DB:
			_silence_seconds = 0.0
		else:
			_silence_seconds += delta
		if _silence_seconds >= SILENCE_SECONDS or _speech_seconds >= MAX_UTTERANCE_SECONDS:
			_finish_capture()

func _read_mic_amplitude() -> float:
	if _mic_capture == null:
		return 0.0
	var available := _mic_capture.get_frames_available()
	if available <= 0:
		return 0.0
	var frames := _mic_capture.get_buffer(mini(available, 4096))
	var sum_squared := 0.0
	for frame in frames:
		sum_squared += frame.length_squared()
	return sqrt(sum_squared / maxf(float(frames.size()), 1.0))

func _begin_capture() -> void:
	_speech_seconds = 0.0
	_silence_seconds = 0.0
	_recorder.set_recording_active(false)
	_recorder.set_recording_active(true)
	_state = "capturing"
	_orb.call("set_mode", "listening")
	_set_state("capturing", "Listening…")

func _finish_capture() -> void:
	_recorder.set_recording_active(false)
	var wav := _recorder.get_recording()
	_state = "transcribing"
	_speech_seconds = 0.0
	_silence_seconds = 0.0
	_set_state("transcribing", "One moment…")
	if wav == null or wav.data.is_empty():
		_set_state("listening", "I didn’t catch that. Try again")
		return
	if wav.data.size() < 5000:
		_set_state("listening", "I didn’t catch that. Try again")
		return
	var wav_bytes := _wav_bytes(wav)
	_transcribe_openai(wav_bytes)

func _transcribe_openai(audio: PackedByteArray) -> void:
	var boundary := "EchoBoundary" + str(Time.get_ticks_usec())
	var body := PackedByteArray()
	_append_text(body, "--%s\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n%s\r\n" % [boundary, EchoConfig.stt_model])
	_append_text(body, "--%s\r\nContent-Disposition: form-data; name=\"language\"\r\n\r\n%s\r\n" % [boundary, "tl"])
	_append_text(body, "--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"utterance.wav\"\r\nContent-Type: audio/wav\r\n\r\n" % boundary)
	body.append_array(audio)
	_append_text(body, "\r\n--%s--\r\n" % boundary)
	var headers := PackedStringArray(["Authorization: Bearer " + EchoConfig.openai_api_key, "Content-Type: multipart/form-data; boundary=" + boundary])
	_send_request(WHISPER_URL, headers, body, "stt_openai")

func _send_to_llm(transcript: String) -> void:
	if transcript.strip_edges().is_empty():
		_set_state("listening", "I didn’t catch that. Try again")
		return
	_conversation.append({"role": "user", "content": transcript})
	# Keep a short rolling context to avoid excessive cost and latency.
	if _conversation.size() > 11:
		_conversation = [_conversation[0]] + _conversation.slice(_conversation.size() - 9)
	var payload := {"model": EchoConfig.llm_model, "messages": _conversation, "temperature": 0.8, "max_tokens": 120}
	var body := JSON.stringify(payload).to_utf8_buffer()
	var headers := PackedStringArray(["Authorization: Bearer " + EchoConfig.openai_api_key, "Content-Type: application/json"])
	_set_state("thinking", "Thinking of what to say…")
	_send_request(CHAT_URL, headers, body, "llm")

func _request_tts(text: String) -> void:
	var url := "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % EchoConfig.elevenlabs_voice_id.uri_encode()
	var payload := {
		"text": text,
		"model_id": "eleven_multilingual_v2",
		"language_code": "fil",
		"voice_settings": {"stability": 0.38, "similarity_boost": 0.78, "style": 0.55, "use_speaker_boost": true}
	}
	var headers := PackedStringArray(["xi-api-key: " + EchoConfig.elevenlabs_api_key, "Content-Type: application/json", "Accept: audio/mpeg"])
	_set_state("synthesizing", "Let me say that…")
	_send_request(url, headers, JSON.stringify(payload).to_utf8_buffer(), "tts")

func _send_request(url: String, headers: PackedStringArray, body: PackedByteArray, purpose: String) -> void:
	_generation += 1
	var token := _generation
	var http := HTTPRequest.new()
	http.timeout = 35.0
	http.body_size_limit = 16 * 1024 * 1024
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(purpose, token, http))
	var err := http.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_handle_network_error("Could not start network request")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, purpose: String, token: int, http: HTTPRequest) -> void:
	http.queue_free()
	if token != _generation or _call_ended:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var details := body.get_string_from_utf8()
		if details.length() > 240:
			details = details.left(240)
		push_warning("ECHO %s request failed (%s): %s" % [purpose, response_code, details])
		_handle_network_error("Network hiccup")
		return
	match purpose:
		"stt_openai":
			var parsed := _parse_json(body)
			_send_to_llm(str(parsed.get("text", "")))
		"llm":
			var parsed := _parse_json(body)
			var choices: Array = parsed.get("choices", [])
			if choices.is_empty():
				_handle_network_error("Ana couldn’t respond")
				return
			var reply := str(choices[0].get("message", {}).get("content", "")).strip_edges()
			if reply.is_empty():
				_handle_network_error("Ana couldn’t respond")
				return
			_conversation.append({"role": "assistant", "content": reply})
			_request_tts(reply)
		"tts":
			_play_tts(body)

func _parse_json(data: PackedByteArray) -> Dictionary:
	var value: Variant = JSON.parse_string(data.get_string_from_utf8())
	return value if value is Dictionary else {}

func _play_tts(data: PackedByteArray) -> void:
	var stream := AudioStreamMP3.new()
	stream.data = data
	_player.stream = stream
	_state = "speaking"
	_barge_seconds = 0.0
	_orb.call("set_mode", "speaking")
	_set_state("speaking", "Ana is speaking")
	_player.play()

func _on_voice_finished() -> void:
	if _state == "speaking" and not _call_ended:
		_set_state("listening", "I’m here")

func _barge_in() -> void:
	_generation += 1 # Ignore any stale network response if barge-in raced a request.
	_player.stop()
	_recorder.set_recording_active(false)
	_recorder.set_recording_active(true)
	_state = "capturing"
	_speech_seconds = 0.0
	_silence_seconds = 0.0
	_barge_seconds = 0.0
	_orb.call("set_mode", "listening")
	_set_state("capturing", "Go ahead, I’m listening")

func _handle_network_error(message: String) -> void:
	if _call_ended:
		return
	_player.stop()
	_state = "listening"
	_orb.call("set_mode", "idle")
	_set_state("listening", "Pasensya na, nawalan ako ng signal")
	_hint.text = "Check your connection and API settings"
	_play_error_chime()
	push_warning("ECHO: %s" % message)

func _play_error_chime() -> void:
	# A short local signal still works when the network is unavailable. The spoken
	# recovery phrase is shown in the call status; cache an OGG for spoken fallback
	# if an offline spoken prompt is required by your deployment.
	var sample_rate := 22050
	var samples := PackedByteArray()
	for i in range(int(sample_rate * 0.18)):
		var envelope := 1.0 - float(i) / float(sample_rate * 0.18)
		var sample := int(sin(TAU * 520.0 * float(i) / sample_rate) * 7000.0 * envelope)
		samples.append(sample & 0xff)
		samples.append((sample >> 8) & 0xff)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = samples
	_error_tone.stream = wav
	_error_tone.play()

func _wav_bytes(source: AudioStreamWAV) -> PackedByteArray:
	var pcm := source.data
	var channels := 2 if source.stereo else 1
	var rate := source.mix_rate
	var bytes_per_sample := 2 if source.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var wav := PackedByteArray()
	_append_text(wav, "RIFF")
	_append_u32(wav, 36 + pcm.size())
	_append_text(wav, "WAVEfmt ")
	_append_u32(wav, 16)
	_append_u16(wav, 1)
	_append_u16(wav, channels)
	_append_u32(wav, rate)
	_append_u32(wav, rate * channels * bytes_per_sample)
	_append_u16(wav, channels * bytes_per_sample)
	_append_u16(wav, bytes_per_sample * 8)
	_append_text(wav, "data")
	_append_u32(wav, pcm.size())
	wav.append_array(pcm)
	return wav

func _append_text(target: PackedByteArray, text: String) -> void:
	target.append_array(text.to_utf8_buffer())

func _append_u16(target: PackedByteArray, value: int) -> void:
	target.append(value & 0xff)
	target.append((value >> 8) & 0xff)

func _append_u32(target: PackedByteArray, value: int) -> void:
	for shift in [0, 8, 16, 24]:
		target.append((value >> shift) & 0xff)

func _set_state(next_state: String, message: String) -> void:
	_state = next_state
	if is_instance_valid(_status):
		_status.text = message
	if is_instance_valid(_orb):
		var mode := "speaking" if next_state == "speaking" else ("listening" if next_state in ["listening", "capturing"] else "thinking")
		_orb.call("set_mode", mode)
	if next_state == "listening":
		_hint.text = "Your call is private to you"

func _on_end_pressed() -> void:
	if _call_ended or not _mic_permission_granted:
		if not _start_mic():
			_show_mic_permission_error()
			return
		_mic_permission_granted = true
		_call_ended = false
		_generation += 1
		_end_button.text = "END CALL"
		_hint.text = "Your call is private to you"
		_set_state("listening", "Say hello to Ana")
		return
	_call_ended = true
	_generation += 1
	_recorder.set_recording_active(false)
	_mic_player.stop()
	_player.stop()
	_error_tone.stop()
	_state = "ended"
	_orb.call("set_mode", "idle")
	_end_button.text = "START CALL"
	_set_state("ended", "Call ended")
	_hint.text = "Tap to call Ana again"
