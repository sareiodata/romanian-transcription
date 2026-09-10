# Romanian transcription

Local transcription, speaker A/B labels, word timestamps, and audio playback.
Uses Canary Q8 and GPU 0 when available; automatically falls back to CPU if
CUDA packages or the NVIDIA driver are unavailable. Models unload after each job.

## Install (Linux x86-64)

Node.js 18+, FFmpeg, Python 3 + venv, curl and tar are required. On Ubuntu 24.04:

```bash
sudo apt-get update
sudo apt-get install -y nodejs ffmpeg python3-venv curl ca-certificates tar
./install.sh
./start.sh
```

Open **http://localhost:8124**. API: **http://localhost:8322**.
Stop with `./stop.sh`. Use `./install.sh --cpu` to skip CUDA installation.
For GPU use, install a compatible NVIDIA driver separately (`nvidia-smi` must work).
The installer downloads CrispASR 0.8.31, Canary Q8 and WeSpeaker; CUDA libraries
are installed locally, without changing system Python. Allow several GB of disk space.
Models, binaries, uploads and logs are excluded from Git.

## Usage

```bash
./transcribe.sh recording.mp3
TRANSCRIPT_DEVICE=cpu ./transcribe.sh recording.mp3
./start-web.sh                    # foreground web app
./start-transcription-server.sh   # foreground API
```

API: `POST /v1/audio/transcriptions` (multipart `file`), `POST /inference`,
and `GET /health`. API requests are serialized and start a temporary backend.
Web and API queues are independent. Default language is Romanian.

`TRANSCRIPT_DEVICE=cpu` forces CPU; otherwise CUDA is detected automatically.
`TRANSCRIPT_MODEL` selects another Canary filename inside `models/`, or an absolute path.
`TRANSCRIPT_PORT` / `TRANSCRIPT_API_PORT` change ports;
`TRANSCRIPT_HOST` / `TRANSCRIPT_API_HOST` change bind addresses.
`start.sh` binds both services to `0.0.0.0` for LAN access; there is no authentication.
Set both host variables to `127.0.0.1` for local-only access.
Progress and ETA are estimates, refined after completed jobs.

Greedy decoding is intentional: this CrispASR release's beam search breaks
speaker labels and timestamps. Close the page or choose Delete to release uploaded audio.
Stop services before reinstalling dependencies.

Tests (no model downloads required): `node --test tests/*.test.js`.

Dependencies have their own licenses:
[CrispASR](https://github.com/CrispStrobe/CrispASR),
[Canary](https://huggingface.co/cstr/canary-1b-v2-GGUF),
[WeSpeaker](https://huggingface.co/cstr/wespeaker-resnet34-lm-GGUF), and
[NVIDIA runtime libraries](https://pypi.org/project/nvidia-cuda-runtime-cu12/).
