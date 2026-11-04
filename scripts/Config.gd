extends Node
class_name EchoConfigStore

const SYSTEM_PROMPT := "You are Ana, a friendly, empathetic, and natural-sounding Filipino companion. You speak conversational Tagalog/Taglish. You have emotions and a distinct personality. Keep your responses short, natural, and punchy (1-3 sentences) because your responses will be spoken out loud. Never use emojis or markdown formatting, just plain text."
const CONFIG_PATH := "user://echo_config.cfg"

var stt_provider := "openai" # openai or soniox
var openai_api_key := ""
var elevenlabs_api_key := ""
var elevenlabs_voice_id := "" # Choose a multilingual voice from your ElevenLabs account.
var llm_model := "gpt-4o-mini"
var stt_model := "whisper-1"
var ana_name := "Ana"

func _ready() -> void:
	_load_config()
	# Environment variables are useful for desktop development and CI. On Android,
	# use the private user://echo_config.cfg file (never commit real credentials).
	openai_api_key = _env_or("ECHO_OPENAI_API_KEY", openai_api_key)
	elevenlabs_api_key = _env_or("ECHO_ELEVENLABS_API_KEY", elevenlabs_api_key)
	elevenlabs_voice_id = _env_or("ECHO_ELEVENLABS_VOICE_ID", elevenlabs_voice_id)

func _env_or(key: String, fallback: String) -> String:
	var value := OS.get_environment(key)
	return fallback if value.is_empty() else value

func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	stt_provider = str(config.get_value("api", "stt_provider", stt_provider)).to_lower()
	openai_api_key = str(config.get_value("api", "openai_api_key", openai_api_key))
	elevenlabs_api_key = str(config.get_value("api", "elevenlabs_api_key", elevenlabs_api_key))
	elevenlabs_voice_id = str(config.get_value("api", "elevenlabs_voice_id", elevenlabs_voice_id))
	llm_model = str(config.get_value("api", "llm_model", llm_model))
	stt_model = str(config.get_value("api", "stt_model", stt_model))
	ana_name = str(config.get_value("companion", "name", ana_name))

func save_to_user_file() -> Error:
	var config := ConfigFile.new()
	config.set_value("api", "stt_provider", stt_provider)
	config.set_value("api", "openai_api_key", openai_api_key)
	config.set_value("api", "elevenlabs_api_key", elevenlabs_api_key)
	config.set_value("api", "elevenlabs_voice_id", elevenlabs_voice_id)
	config.set_value("api", "llm_model", llm_model)
	config.set_value("api", "stt_model", stt_model)
	config.set_value("companion", "name", ana_name)
	return config.save(CONFIG_PATH)

func missing_setting() -> String:
	if stt_provider != "openai":
		return "This build uses OpenAI Whisper for speech recognition"
	if openai_api_key.is_empty():
		return "OpenAI API key is missing for the companion"
	if elevenlabs_api_key.is_empty() or elevenlabs_voice_id.is_empty():
		return "ElevenLabs API key or voice ID is missing"
	return ""
