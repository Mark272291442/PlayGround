# ECHO — Ana, voice-only companion

A minimal Godot 4 portrait Android voice companion. There is no text-chat interface: a central animated orb, call status, and one End/Start Call button make up the call screen. The voice loop is online: OpenAI Whisper transcription → OpenAI chat completions → ElevenLabs speech synthesis.

## Clone, open, and export an Android APK

Do the export on a computer with Godot installed; install and test the resulting APK on your Android phone.

1. Clone the repository and open it in Godot 4.3 or later:
   ```sh
   git clone https://github.com/Mark272291442/PlayGround.git
   cd PlayGround
   ```
   In Godot, choose **Import** and select this folder (the folder containing `project.godot`).
2. In Godot, open **Editor > Manage Export Templates** and install the templates matching your Godot version.
3. Install Android Studio and its Android SDK, plus OpenJDK 17. In Godot's **Editor > Editor Settings > Export > Android**, set the Java SDK Path and Android SDK Path to those installations.
4. Open **Project > Export**, select the **Android** preset, and choose **Export Project**. Export a debug APK to `build/echo-android.apk` (create `build/` first if the file chooser requires it). The preset enables Internet and `RECORD_AUDIO` permissions.
5. Install the APK on a connected Android device with USB debugging enabled:
   ```sh
   adb install -r build/echo-android.apk
   ```
6. Create `echo_config.cfg` on the computer using the example below. For this debug build, copy it into the app's private Godot `user://` directory with:
   ```sh
   adb shell run-as com.example.echo sh -c 'cat > files/echo_config.cfg' < echo_config.cfg
   ```
   This `run-as` method is for a debuggable APK; a release APK is not accessible this way. The package name is `com.example.echo` in the included export preset. Keep the config file and keys private. Relaunch ECHO and grant microphone access when prompted. If access was denied, enable it in Android Settings and tap **ALLOW MIC** to retry.

For desktop runs, set `ECHO_OPENAI_API_KEY`, `ECHO_ELEVENLABS_API_KEY`, and `ECHO_ELEVENLABS_VOICE_ID` in the environment. Godot's `user://` path is private app storage; credentials are deliberately not included in this repository.

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
