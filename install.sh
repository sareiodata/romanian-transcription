#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$root/bin:$PATH"
[[ $# -eq 0 || ( $# -eq 1 && "$1" == --cpu ) ]] || { echo 'Usage: ./install.sh [--cpu]' >&2; exit 2; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Linux x86-64 is required.' >&2; exit 1; }
for tool in curl tar python3 node ffmpeg; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. See README.md prerequisites." >&2; exit 1; }
done
node -e 'if (Number(process.versions.node.split(".")[0]) < 18) process.exit(1)' || { echo 'Node.js 18+ required.' >&2; exit 1; }
mkdir -p "$root/bin" "$root/models"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
release='https://github.com/CrispStrobe/CrispASR/releases/download/v0.8.31'
install_runtime() {
  local asset="$1" destination="$2"
  curl -fL --retry 3 "$release/$asset" -o "$tmp/runtime.tar.gz" || return 1
  mkdir -p "$destination"
  tar -xzf "$tmp/runtime.tar.gz" --strip-components=1 -C "$destination" || return 1
}
echo 'Installing CPU runtime (also used as fallback)...'
install_runtime crispasr-linux-x86_64.tar.gz "$root/bin/crispasr-cpu"
if [[ "${1:-}" != --cpu ]] && command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
  echo 'Installing optional CUDA runtime and local NVIDIA libraries...'
  if install_runtime crispasr-linux-x86_64-cuda.tar.gz "$root/bin/crispasr" &&
     python3 -m venv "$root/.install-venv" &&
     "$root/.install-venv/bin/pip" install --upgrade --target "$root/.cuda" nvidia-cuda-runtime-cu12==12.8.90 nvidia-cublas-cu12==12.8.4.1; then
    echo 'CUDA dependencies installed.'
  else
    echo 'CUDA setup unavailable; the CPU runtime is ready.' >&2
  fi
fi
download_model() {
  local url="$1" name="$2"
  if [[ ! -s "$root/models/$name" ]]; then
    curl -fL --retry 3 "$url" -o "$tmp/model.gguf"
    mv "$tmp/model.gguf" "$root/models/$name"
  fi
}
download_model 'https://huggingface.co/cstr/canary-1b-v2-GGUF/resolve/f4a12db73daa964aa56a188826682f6b11fdc960/canary-1b-v2-q8_0.gguf' canary-1b-v2-q8_0.gguf
download_model 'https://huggingface.co/cstr/wespeaker-resnet34-lm-GGUF/resolve/main/wespeaker-resnet34-lm.gguf' wespeaker-resnet34-lm.gguf
node -e 'console.log("Ready:", require(process.argv[1]).selectRuntime().label)' "$root/runtime.js"
echo 'Start: ./start.sh  |  Web: http://localhost:8124'
