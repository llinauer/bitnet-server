FROM ubuntu:24.04 AS bitnet-base

ARG DEBIAN_FRONTEND=noninteractive
ARG BITNET_REF=main
ARG BITNET_GGUF_HF_REPO=microsoft/BitNet-b1.58-2B-4T-gguf
ARG BITNET_MODEL_DIR=/models/BitNet-b1.58-2B-4T
ARG BITNET_HF_REPO=
ARG BITNET_QUANT_TYPE=i2_s
ARG BITNET_LOG_DIR=/logs
ARG BITNET_USE_PRETUNED=1

ENV APP_HOME=/opt/bitnet \
    PATH=/opt/bitnet/.venv/bin:${PATH} \
    BITNET_GGUF_HF_REPO=${BITNET_GGUF_HF_REPO} \
    BITNET_MODEL_DIR=${BITNET_MODEL_DIR} \
    BITNET_HF_REPO=${BITNET_HF_REPO} \
    BITNET_QUANT_TYPE=${BITNET_QUANT_TYPE} \
    BITNET_LOG_DIR=${BITNET_LOG_DIR} \
    BITNET_USE_PRETUNED=${BITNET_USE_PRETUNED} \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    cmake \
    curl \
    g++ \
    g++-14 \
    gcc-14 \
    git \
    libopenblas-dev \
    make \
    ninja-build \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/gcc /usr/local/bin/clang \
    && ln -sf /usr/bin/g++ /usr/local/bin/clang++

WORKDIR /opt

RUN git clone --recursive --branch "${BITNET_REF}" https://github.com/microsoft/BitNet.git "${APP_HOME}"

WORKDIR ${APP_HOME}

RUN python3 -m venv .venv \
    && .venv/bin/pip install --upgrade pip setuptools wheel \
    && .venv/bin/pip install -r requirements.txt \
    && .venv/bin/pip install "huggingface_hub[cli]"

FROM bitnet-base AS bitnet-debug

FROM bitnet-base AS final

RUN mkdir -p "${BITNET_MODEL_DIR}" "${BITNET_LOG_DIR}" \
    && if [[ -z "${BITNET_HF_REPO}" ]]; then \
        huggingface-cli download "${BITNET_GGUF_HF_REPO}" \
          --local-dir "${BITNET_MODEL_DIR}" \
          --local-dir-use-symlinks False; \
      fi \
    && setup_args=( \
        --model-dir "${BITNET_MODEL_DIR}" \
        --log-dir "${BITNET_LOG_DIR}" \
        --quant-type "${BITNET_QUANT_TYPE}" \
      ) \
    && if [[ -n "${BITNET_HF_REPO}" ]]; then \
        setup_args+=(--hf-repo "${BITNET_HF_REPO}"); \
      fi \
    && if [[ -n "${BITNET_HF_REPO}" ]] && [[ "${BITNET_USE_PRETUNED}" == "1" || "${BITNET_USE_PRETUNED}" == "true" ]]; then \
        setup_args+=(--use-pretuned); \
      fi \
    && python3 setup_env.py "${setup_args[@]}"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/logs"]

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
