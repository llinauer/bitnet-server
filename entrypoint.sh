#!/usr/bin/env bash
set -euo pipefail

cd /opt/bitnet

BITNET_MODEL_DIR="${BITNET_MODEL_DIR:-/models/BitNet-b1.58-2B-4T}"
BITNET_HF_REPO="${BITNET_HF_REPO:-}"
BITNET_GGUF_HF_REPO="${BITNET_GGUF_HF_REPO:-microsoft/BitNet-b1.58-2B-4T-gguf}"
BITNET_QUANT_TYPE="${BITNET_QUANT_TYPE:-i2_s}"
BITNET_LOG_DIR="${BITNET_LOG_DIR:-/logs}"
BITNET_THREADS="${BITNET_THREADS:-$(nproc)}"
BITNET_CTX_SIZE="${BITNET_CTX_SIZE:-2048}"
BITNET_N_PREDICT="${BITNET_N_PREDICT:-4096}"
BITNET_TEMPERATURE="${BITNET_TEMPERATURE:-0.8}"
BITNET_HOST="${BITNET_HOST:-0.0.0.0}"
BITNET_PORT="${BITNET_PORT:-8080}"
BITNET_PROMPT="${BITNET_PROMPT:-}"
BITNET_USE_PRETUNED="${BITNET_USE_PRETUNED:-1}"
BITNET_MODEL_FILE="${BITNET_MODEL_FILE:-${BITNET_MODEL_DIR}/ggml-model-${BITNET_QUANT_TYPE}.gguf}"

mkdir -p "${BITNET_LOG_DIR}"

if [[ ! -x build/bin/llama-server ]]; then
  echo "Expected BitNet server binary at build/bin/llama-server, but it is missing." >&2
  exit 1
fi

if [[ ! -f "${BITNET_MODEL_FILE}" ]]; then
  echo "Expected model file at ${BITNET_MODEL_FILE}, but it is missing." >&2
  echo "Rebuild the image or mount a compatible model into ${BITNET_MODEL_DIR}." >&2
  exit 1
fi

server_args=(
  -m "${BITNET_MODEL_FILE}"
  -t "${BITNET_THREADS}"
  -c "${BITNET_CTX_SIZE}"
  -n "${BITNET_N_PREDICT}"
  --temperature "${BITNET_TEMPERATURE}"
  --host "${BITNET_HOST}"
  --port "${BITNET_PORT}"
)

if [[ -n "${BITNET_PROMPT}" ]]; then
  server_args+=(-p "${BITNET_PROMPT}")
fi

exec python3 run_inference_server.py "${server_args[@]}" "$@"
