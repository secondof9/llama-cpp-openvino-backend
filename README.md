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
local-ai backends install "ghcr.io/secondof9/llama-cpp-openvino-backend:main"
```

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

## Selecting the OpenVINO Device (CPU / GPU / NPU)

Pass the OpenVINO device environment variables to your LocalAI container (and pass through `/dev/dri` for Intel iGPU/dGPU or `/dev/accel` for Intel NPU):

```bash
docker run -d \
  --name localai \
  --device /dev/dri \
  -e GGML_OPENVINO_DEVICE=GPU \
  -e GGML_OPENVINO_STATEFUL_EXECUTION=1 \
  -e LOCALAI_BACKEND_GALLERIES='[{"name":"localai","url":"github:mudler/LocalAI/backend/index.yaml@master"},{"name":"secondof9","url":"https://raw.githubusercontent.com/secondof9/llama-cpp-openvino-backend/main/backends/llama-cpp-openvino.yaml"}]' \
  -p 8080:8080 \
  localai/localai:latest
```
