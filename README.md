# bitnet-server

Container image for serving [Microsoft BitNet](https://github.com/microsoft/BitNet) through the bundled inference server.

## What This Repo Contains

- `Containerfile` builds an Ubuntu 24.04 image with GCC, CMake, Python, OpenBLAS, the BitNet source tree, and a prepared model.
- The image clones `microsoft/BitNet` at build time using the `BITNET_REF` build argument.
- `entrypoint.sh` validates the baked-in artifacts and launches `run_inference_server.py`.

## Build

```bash
docker build -f Containerfile -t bitnet-server .
```

To build from a different BitNet branch or tag:

```bash
docker build -f Containerfile --build-arg BITNET_REF=main -t bitnet-server .
```

By default, the image build also:

- downloads `microsoft/BitNet-b1.58-2B-4T-gguf`
- stores it in `/models/BitNet-b1.58-2B-4T`
- runs `setup_env.py` for quantization type `i2_s`

You can override those build-time defaults:

```bash
docker build \
  -f Containerfile \
  --build-arg BITNET_GGUF_HF_REPO=microsoft/BitNet-b1.58-2B-4T-gguf \
  --build-arg BITNET_MODEL_DIR=/models/BitNet-b1.58-2B-4T \
  --build-arg BITNET_QUANT_TYPE=i2_s \
  -t bitnet-server .
```

If you need to debug `setup_env.py` with persistent host logs, build the pre-setup stage instead:

```bash
docker build -f Containerfile --target bitnet-debug -t bitnet-debug .
```

Then run the setup manually in a regular container with `/logs` bind-mounted:

```bash
mkdir -p logs

docker run --rm -it \
  -v "$(pwd)/logs:/logs" \
  bitnet-debug \
  bash
```

Inside that container, run:

```bash
cd /opt/bitnet

huggingface-cli download "microsoft/BitNet-b1.58-2B-4T-gguf" \
  --local-dir "/models/BitNet-b1.58-2B-4T" \
  --local-dir-use-symlinks False

python3 setup_env.py \
  --model-dir "/models/BitNet-b1.58-2B-4T" \
  --log-dir "/logs" \
  --quant-type "i2_s"
```

If `setup_env.py` fails there, the generated files in `./logs` remain on the host after the container exits.

The image does not patch upstream `setup_env.py`. Instead it provides `clang` and `clang++` as symlinks to GCC and G++, because the current upstream BitNet tree fails under Clang 18 on Ubuntu 24.04.

## Run

The container exposes port `8080` and declares one volume:

- `/logs` for setup logs

Example:

```bash
docker run --rm -p 8080:8080 -v "$(pwd)/logs:/logs" bitnet-server
```

This was verified against the built image: the container starts successfully and serves HTTP on port `8080`.

The image relies on its default entrypoint at `/usr/local/bin/entrypoint.sh`. If you override it with `--entrypoint=/bin/sh`, the bootstrap step is skipped.

At startup, the entrypoint expects these build artifacts to already exist:

- `build/bin/llama-server`
- `${BITNET_MODEL_DIR}/ggml-model-${BITNET_QUANT_TYPE}.gguf`

If either artifact is missing, the container exits with an error instead of downloading or rebuilding anything at runtime.

It then launches:

```bash
python3 run_inference_server.py ...
```

## Configuration

The container is configured through environment variables.

| Variable | Default | Description |
| --- | --- | --- |
| `BITNET_MODEL_DIR` | `/models/BitNet-b1.58-2B-4T` | Directory used by BitNet setup and inference. |
| `BITNET_HF_REPO` | empty | Optional supported Hugging Face repo passed to `setup_env.py --hf-repo`. |
| `BITNET_GGUF_HF_REPO` | `microsoft/BitNet-b1.58-2B-4T-gguf` | GGUF repo used during image build when `BITNET_HF_REPO` is not set. |
| `BITNET_QUANT_TYPE` | `i2_s` | Quantization suffix used for setup and model file selection. |
| `BITNET_LOG_DIR` | `/logs` | Directory for setup logs. |
| `BITNET_THREADS` | `$(nproc)` | Thread count passed to the inference server. |
| `BITNET_CTX_SIZE` | `2048` | Context size passed as `-c`. |
| `BITNET_N_PREDICT` | `4096` | Max generated tokens passed as `-n`. |
| `BITNET_TEMPERATURE` | `0.8` | Sampling temperature. |
| `BITNET_HOST` | `0.0.0.0` | Bind address for the server. |
| `BITNET_PORT` | `8080` | Listen port for the server. |
| `BITNET_PROMPT` | empty | Optional prompt passed as `-p`. |
| `BITNET_USE_PRETUNED` | `1` | Adds `--use-pretuned` during image build only when `BITNET_HF_REPO` is set to a supported BitNet repo. |
| `BITNET_MODEL_FILE` | `${BITNET_MODEL_DIR}/ggml-model-${BITNET_QUANT_TYPE}.gguf` | Explicit model file path used by the server. |

Example with custom settings:

```bash
docker run --rm -p 8080:8080 \
  -v "$(pwd)/logs:/logs" \
  -e BITNET_THREADS=8 \
  -e BITNET_CTX_SIZE=4096 \
  bitnet-server
```

## Runtime Behavior

- The working directory inside the container is `/opt/bitnet`.
- The Python virtual environment lives at `/opt/bitnet/.venv`.
- The image includes `huggingface_hub[cli]`, which is used during the image build to fetch GGUF weights when needed.
- The image also includes `make`, because upstream `setup_env.py` relies on CMake's default Unix Makefiles generator.
- Extra arguments provided to `docker run ... bitnet-server <args>` are forwarded to `run_inference_server.py`.

## Files

- [Containerfile](/home/linauerl/Documents/Projects/taranis/bots/bitnet_test/bitnet-server/Containerfile)
- [entrypoint.sh](/home/linauerl/Documents/Projects/taranis/bots/bitnet_test/bitnet-server/entrypoint.sh)
