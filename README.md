# ECHO — Ana, voice-only companion

A minimal Godot 4 portrait Android voice companion. There is no text-chat interface: a central animated orb, call status, and one End/Start Call button make up the call screen. The voice loop is online: OpenAI Whisper transcription → OpenAI chat completions → ElevenLabs speech synthesis.

## Run

1. Open this folder in Godot 4.3 or later.
2. Add API credentials to `user://echo_config.cfg` on the device (format below), or set the listed environment variables for desktop runs.
3. Run `Main.tscn` from the editor. Grant microphone permission when Android asks.
4. Export using the Android preset in `export_presets.cfg`. The export preset enables Internet and microphone permissions.

Godot's `user://` path is private app storage. Create `echo_config.cfg` there using the Godot editor's application data folder for your OS, or install a debug build and write the file into the app's user data directory. Keys are deliberately not included in the repository. Desktop environment variables: `ECHO_OPENAI_API_KEY`, `ECHO_ELEVENLABS_API_KEY`, and `ECHO_ELEVENLABS_VOICE_ID`.

Example `user://echo_config.cfg`:

```ini
[api]
stt_provider="openai"
openai_api_key="YOUR_OPENAI_KEY"
elevenlabs_api_key="YOUR_ELEVENLABS_KEY"
elevenlabs_voice_id="YOUR_MULTILINGUAL_VOICE_ID"
llm_model="gpt-4o-mini"
stt_model="whisper-1"

[companion]
name="Ana"
```

Select a multilingual ElevenLabs voice that can speak Filipino/Tagalog. This project sends `language_code: fil` with `eleven_multilingual_v2`; voice availability and language behavior depend on your ElevenLabs account. OpenAI Whisper is selected instead of Soniox for the initial implementation because it works with a simple recorded-utterance HTTP request.

## Included foundation

- Portrait call UI with an animated orb that reacts to microphone capture and the AI voice output bus.
- Microphone stream plus `AudioEffectRecord` PCM capture, voice-activity/silence detection, and a 12-second utterance cap.
- OpenAI Whisper multipart WAV upload, short-context GPT chat requests, and ElevenLabs MP3 playback.
- Barge-in detection: voice activity while Ana is speaking stops playback and starts a fresh recording.
- Per-user config/environment loading; no real API keys are hardcoded.
- Request timeouts, stale-request cancellation, readable warnings, and a local error chime/status phrase when the network fails.

## Notes / production checklist

- API secrets shipped in a mobile client can be extracted. The per-user config avoids committing keys, but a production public app should proxy provider requests through a backend with rate limits and user authentication.
- The network-error phrase is presented in the status area and a local chime is played. A truly spoken offline recovery prompt requires bundling a licensed prerecorded audio asset; remote TTS cannot speak when the network itself is unavailable.
- Mic VAD and speaker-to-mic echo vary by device. Tune thresholds in `scripts/Main.gd` and test with headphones plus the actual Android hardware.
- No real API call can be tested without provider credentials and an Android microphone. The project is configured to run in the Godot editor and export as an Android app once credentials and export templates are installed.
