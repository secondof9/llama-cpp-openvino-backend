# LocalAI OpenVINO Llama.cpp Backend

This repository builds a LocalAI-compatible `llama-cpp` gRPC backend OCI artifact image compiled with **Intel OpenVINO** (`-DGGML_OPENVINO=ON`) and pushes it to GitHub Container Registry (GHCR).

Unlike a standalone `llama-server` container, LocalAI backend images are `FROM scratch` filesystem bundles containing `/run.sh`, LocalAI's compiled `grpc-server` binaries (`llama-cpp-cpu-all`, `llama-cpp-grpc`, `llama-cpp-rpc-server`), and self-contained `/lib` shared libraries (OpenVINO Runtime + plugins, `libggml-openvino.so`, OpenCL ICD, and Intel GPU/NPU Level Zero drivers).

## Features
- **OpenVINO Acceleration:** Optimized for Intel CPUs, iGPUs, dGPUs, and NPUs (`GGML_OPENVINO_DEVICE=CPU|GPU|NPU`).
- **Self-Contained LocalAI Backend Package:** Includes `run.sh`, `grpc-server` binaries, OpenVINO runtime plugins (`plugins.xml`), and Intel GPU/NPU drivers under `/lib`.
- **Automated CI/CD:** Builds and pushes to GHCR on every push to `main`.

## Image

```text
ghcr.io/secondof9/llama-cpp-openvino-backend:main
```

Tags: `main`, `latest`, `sha-<commit>`.

---

## Option 1: Install Directly in LocalAI (Simplest)

You can install this backend directly from the OCI image without configuring a gallery:

### Via REST API
```bash
curl -X POST http://localhost:8080/api/backends/install-external \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "ghcr.io/secondof9/llama-cpp-openvino-backend:main",
    "name": "llama-cpp-openvino",
    "alias": "llama-cpp"
  }'
```

### Via CLI
```bash
local-ai backends install "ghcr.io/secondof9/llama-cpp-openvino-backend:main" llama-cpp-openvino llama-cpp
```
*(The CLI syntax is `local-ai backends install <uri> <name> <alias>`. For OCI image URIs, specifying `<name>` is required.)*

---

## Option 2: Use as a LocalAI Backend Gallery

LocalAI can pull custom backends from a **backend gallery** YAML file hosted over HTTP/HTTPS.

> [!IMPORTANT]
> Setting `LOCALAI_BACKEND_GALLERIES` replaces LocalAI's default gallery list unless you include the default `localai` gallery entry alongside your custom one.

```bash
export LOCALAI_BACKEND_GALLERIES='[
  {"name":"localai","url":"github:mudler/LocalAI/backend/index.yaml@master"},
  {"name":"secondof9","url":"https://raw.githubusercontent.com/secondof9/llama-cpp-openvino-backend/main/backends/llama-cpp-openvino.yaml"}
]'
```

Then install via the Web UI (**Backends** -> search `llama-cpp-openvino`) or via API:

```bash
curl -X POST http://localhost:8080/api/backends/install/llama-cpp-openvino
```

---

## Environment Variables & Configuration

OpenVINO acceleration behavior is controlled via standard `GGML_OPENVINO_*` environment variables supported by `llama.cpp`'s OpenVINO backend:

| Variable | Values | Default | Description |
|---|---|---|---|
| `GGML_OPENVINO_DEVICE` | `CPU`, `GPU`, `GPU.0`, `GPU.1`, `NPU` | `CPU` | Target device for OpenVINO inference. Use `GPU` for Intel integrated or discrete graphics. |
| `GGML_OPENVINO_STATEFUL_EXECUTION` | `1`, `0` | `0` | Enables stateful KV-cache graph execution for improved inference performance and lower latency. |
| `GGML_OPENVINO_KV_CACHE_PRECISION` | `fp16`, `fp32` | `fp16` | Precision format for KV cache weights. |
| `GGML_OPENVINO_PRECISION` | `fp16`, `fp32` | `fp16` | Weight/activation precision for layers compiled by OpenVINO. |

Because LocalAI executes backend binaries (`run.sh`) as child processes, these environment variables can be configured either **globally on the LocalAI container** or **per model** in model configuration YAML files.

---

### Where to Place Environment Variables

#### 1. In `docker-compose.yaml` (Recommended for Docker Compose users)
Add the environment variables and pass through `/dev/dri` (for iGPU/Arc dGPU) or `/dev/accel` (for NPU):

```yaml
services:
  local-ai:
    image: localai/localai:latest
    container_name: local-ai
    environment:
      - GGML_OPENVINO_DEVICE=GPU
      - GGML_OPENVINO_STATEFUL_EXECUTION=1
    devices:
      - /dev/dri:/dev/dri       # Access to Intel iGPU / dGPU
      # - /dev/accel:/dev/accel # Uncomment if using an Intel NPU
    ports:
      - "8080:8080"
    volumes:
      - ./models:/build/models
```

#### 2. In `docker run` (CLI)
Pass them with `-e` and provide device access with `--device`:

```bash
docker run -d \
  --name localai \
  --device /dev/dri \
  -e GGML_OPENVINO_DEVICE=GPU \
  -e GGML_OPENVINO_STATEFUL_EXECUTION=1 \
  -p 8080:8080 \
  -v ./models:/build/models \
  localai/localai:latest
```

#### 3. In Model Configuration YAML (Per-Model Override)
If you want individual models to target different devices (for example, run one model on `GPU` and another on `NPU` or `CPU`), specify them in your model's YAML file (e.g. `models/my-model.yaml`):

```yaml
name: my-model
backend: llama-cpp-openvino
parameters:
  model: my-model.gguf
environment:
  - "GGML_OPENVINO_DEVICE=GPU"
  - "GGML_OPENVINO_STATEFUL_EXECUTION=1"
```

#### 4. In a `.env` File
If you run LocalAI via `docker-compose` or directly on a host with systemd / CLI, you can place them in a `.env` file:

```env
GGML_OPENVINO_DEVICE=GPU
GGML_OPENVINO_STATEFUL_EXECUTION=1
```
