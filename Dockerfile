FROM openvino/ubuntu22_dev:latest

# Set working directory
WORKDIR /app

# Clone llama.cpp
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git .

# Build llama.cpp with OpenVINO support
RUN cmake -B build -DGGML_OPENVINO=ON && \
    cmake --build build --config Release -j $(nproc)

# The entrypoint is set to llama-server
ENTRYPOINT ["/app/build/bin/llama-server"]
