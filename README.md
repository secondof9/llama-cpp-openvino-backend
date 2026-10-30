# LocalAI OpenVINO Llama.cpp Backend

This repository builds a custom Docker image of `llama.cpp` compiled with **Intel OpenVINO** support and pushes it to GitHub Container Registry (GHCR). It is designed to be used as a custom backend for [LocalAI](https://localai.io/).

## Features
- **OpenVINO Acceleration:** Optimized for Intel CPUs, iGPUs, dGPUs, and NPUs.
- **Automated CI/CD:** Builds and pushes to GHCR on every push to `main`.
- **LocalAI-ready:** Exposes `llama-server`, compatible with LocalAI's backend interface.

## Image

```
ghcr.io/secondof9/llama-cpp-openvino-backend:main
```

Tags: `main`, `sha-<commit>`.

---

## Option 1: Use as a LocalAI backend gallery (recommended)

LocalAI can pull custom backends from a **backend gallery** — a simple YAML file hosted over HTTP/HTTPS.

### 1. Point LocalAI at this repo's gallery YAML

```bash
export LOCALAI_BACKEND_GALLERIES='[{"name":"secondof9","url":"https://raw.githubusercontent.com/secondof9/llama-cpp-openvino-backend/main/backends/llama-cpp-openvino.yaml"}]'
```

The YAML file (`backends/llama-cpp-openvino.yaml`) defines:

```yaml
- name: "llama-cpp-openvino"
  description: "llama.cpp backend with Intel OpenVINO acceleration"
  uri: "ghcr.io/secondof9/llama-cpp-openvino-backend:main"
  alias: "llama-cpp"
  tags:
    - "llm"
    - "text-generation"
    - "openvino"
    - "intel"
```

### 2. Access the image

The image is now **public** — no authentication required. Anyone can pull it directly:

```bash
docker pull ghcr.io/secondof9/llama-cpp-openvino-backend:main
```

Gallery files never contain secrets. If you ever prefer to keep the image private instead, you can revert it (note: GitHub does not allow reverting a public package back to private) and supply credentials instead — see below.

### 3. Keep it private — add credentials (optional)

If you keep the image private, create a `credentials.yaml`:

```yaml
- match: ghcr.io/secondof9
  username: secondof9
  password: <your GitHub PAT or GHCR token>
```

Then run LocalAI with:

```bash
local-ai run --credentials-file credentials.yaml
```

---

## Option 2: Run the image directly

Pull the image:

```bash
docker pull ghcr.io/secondof9/llama-cpp-openvino-backend:main
```

Run it with Intel GPU passthrough:

```bash
docker run -d \
  --name localai-openvino \
  --device /dev/dri:/dev/dri \
  -p 8080:8080 \
  ghcr.io/secondof9/llama-cpp-openvino-backend:main \
  --model /path/to/your/model.gguf
```
