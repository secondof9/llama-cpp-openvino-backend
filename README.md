# LocalAI OpenVINO Llama.cpp Backend

This repository provides a CI/CD pipeline to build a custom Docker image of `llama.cpp` compiled with **Intel OpenVINO** support. The resulting image is automatically pushed to GitHub Container Registry (GHCR).

## Features
- **OpenVINO Acceleration:** Optimized for Intel CPUs, iGPUs, and NPUs.
- **Automated CI/CD:** Automatically builds and pushes to GHCR on every push to `main`.
- **API Ready:** Uses `llama-server` as the entrypoint, making it compatible with LocalAI.

## How to Use

### 1. Deployment via Docker
Pull the image from GHCR (replace `USER` and `REPO` with your details):
```bash
docker pull ghcr.io/USER/REPO:main
```

Run the container with Intel GPU passthrough:
```bash
docker run -d \
  --name localai-openvino \
  --device /dev/dri:/dev/dri \
  -p 8080:8080 \
  ghcr.io/USER/REPO:main \
  --model /path/to/your/model.gguf
```

### 2. Integration with LocalAI
To use this as a custom backend in LocalAI, add the image to your `docker-compose.yml` as a service and configure your model YAML to point to the `openvino-llama` alias.
