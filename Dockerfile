FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build essentials and dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \n    curl \
    wget \n    ca-certificates \n    && rm -rf /var/lib/apt/lists/*

# Install Intel OpenVINO Toolkit
# This uses the official Intel repository setup
RUN wget https://apt.repos.intel.com/intel-setup.deb && \
    dpkg -i intel-setup.deb && \
    apt-get update && \n    apt-get install -y intel-openvino-runtime libopenvino-dev && \n    rm intel-setup.deb

# Set working directory
WORKDIR /app

# Clone llama.cpp
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git .

# Build llama.cpp with OpenVINO support
# We use -j $(nproc) to use all available CPU cores for a faster build
RUN cmake -B build -DGGML_OPENVINO=ON && \
    cmake --build build --config Release -j $(nproc)

# The entrypoint is set to llama-server, which is the standard for LocalAI/API usage
ENTRYPOINT ["/app/build/bin/llama-server"]