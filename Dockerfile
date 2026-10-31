# ============================================================================
# Stage 1: Builder
# Uses LocalAI's pre-built Ubuntu 24.04 gRPC builder base image which already
# includes /opt/grpc (v1.65.0), protoc, CMake, ccache, and build tools.
# ============================================================================
ARG BUILDER_BASE_IMAGE=quay.io/go-skynet/ci-cache:base-grpc-amd64
FROM ${BUILDER_BASE_IMAGE} AS builder

ARG OPENVINO_VERSION_MAJOR=2026.4.1
ARG OPENVINO_VERSION_FULL=2026.4.1.22982.07f9c262b05

# Intel GPU driver versions (https://github.com/intel/compute-runtime/releases)
ARG IGC_VERSION=v2.41.5
ARG IGC_VERSION_FULL=2_2.41.5+22716
ARG COMPUTE_RUNTIME_VERSION=26.35.39758.10
ARG COMPUTE_RUNTIME_VERSION_FULL=26.35.39758.10-0
ARG IGDGMM_VERSION=22.10.0

# Intel NPU driver versions (https://github.com/intel/linux-npu-driver/releases)
ARG NPU_DRIVER_VERSION=v1.38.0
ARG NPU_DRIVER_FULL=v1.38.0.20260910-34487311128
ARG LIBZE1_VERSION=1.32.0-1~24.04~ppa1

ARG LOCALAI_REPO=https://github.com/mudler/LocalAI.git
ARG LOCALAI_VERSION=master
ARG TARGETARCH=amd64

ENV DEBIAN_FRONTEND=noninteractive

# Install build & OpenCL dependencies required by GGML_OPENVINO
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        wget \
        curl \
        git \
        cmake \
        ninja-build \
        build-essential \
        ccache \
        patchelf \
        libtbb12 \
        libtbb-dev \
        libgomp1 \
        libssl-dev \
        libjpeg-dev \
        zlib1g-dev \
        ocl-icd-opencl-dev \
        ocl-icd-libopencl1 \
        opencl-headers \
        opencl-clhpp-headers \
        intel-opencl-icd && \
    rm -rf /var/lib/apt/lists/*

# Install Intel OpenVINO Runtime & Dev Toolkit for Ubuntu 24.04 (cached download)
RUN --mount=type=cache,target=/var/cache/openvino,sharing=locked \
    mkdir -p /opt/intel && \
    TGZ=/var/cache/openvino/openvino_toolkit_ubuntu24_${OPENVINO_VERSION_FULL}_x86_64.tgz && \
    if [ ! -f "$TGZ" ]; then \
        wget -q -O "$TGZ" \
            "https://storage.openvinotoolkit.org/repositories/openvino/packages/${OPENVINO_VERSION_MAJOR}/linux/openvino_toolkit_ubuntu24_${OPENVINO_VERSION_FULL}_x86_64.tgz"; \
    fi && \
    tar -xf "$TGZ" -C /opt/intel/ && \
    mv "/opt/intel/openvino_toolkit_ubuntu24_${OPENVINO_VERSION_FULL}_x86_64" "/opt/intel/openvino_${OPENVINO_VERSION_MAJOR}" && \
    ln -sfn "/opt/intel/openvino_${OPENVINO_VERSION_MAJOR}" /opt/intel/openvino && \
    if [ -x /opt/intel/openvino/install_dependencies/install_openvino_dependencies.sh ]; then \
        echo "Y" | /opt/intel/openvino/install_dependencies/install_openvino_dependencies.sh || true; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Install Intel GPU (Compute Runtime + IGC) and NPU Level Zero drivers so they can
# be packaged into /lib for self-contained execution inside LocalAI (cached downloads)
RUN --mount=type=cache,target=/var/cache/intel-drivers,sharing=locked \
    set -eux; \
    cd /var/cache/intel-drivers; \
    for url in \
        "https://github.com/intel/intel-graphics-compiler/releases/download/${IGC_VERSION}/intel-igc-core-${IGC_VERSION_FULL}_amd64.deb" \
        "https://github.com/intel/intel-graphics-compiler/releases/download/${IGC_VERSION}/intel-igc-opencl-${IGC_VERSION_FULL}_amd64.deb" \
        "https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-ocloc_${COMPUTE_RUNTIME_VERSION_FULL}_amd64.deb" \
        "https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-opencl-icd_${COMPUTE_RUNTIME_VERSION_FULL}_amd64.deb" \
        "https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/libigdgmm12_${IGDGMM_VERSION}_amd64.deb" \
        "https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/libze-intel-gpu1_${COMPUTE_RUNTIME_VERSION_FULL}_amd64.deb" \
        "https://snapshot.ppa.launchpadcontent.net/kobuk-team/intel-graphics/ubuntu/20260830T100000Z/pool/main/l/level-zero-loader/libze1_${LIBZE1_VERSION}_amd64.deb"; do \
        deb_file=$(basename "$url"); \
        [ -f "$deb_file" ] || wget -q -O "$deb_file" "$url"; \
    done; \
    npu_tgz="linux-npu-driver-${NPU_DRIVER_FULL}-ubuntu2404.tar.gz"; \
    [ -f "$npu_tgz" ] || wget -q -O "$npu_tgz" "https://github.com/intel/linux-npu-driver/releases/download/${NPU_DRIVER_VERSION}/linux-npu-driver-${NPU_DRIVER_FULL}-ubuntu2404.tar.gz"; \
    mkdir -p /tmp/intel-drivers && cd /tmp/intel-drivers; \
    cp /var/cache/intel-drivers/*.deb .; \
    tar -xf "/var/cache/intel-drivers/${npu_tgz}"; \
    apt-get update && apt-get install -y --no-install-recommends ./*.deb && \
    cd / && rm -rf /tmp/intel-drivers /var/lib/apt/lists/*

ENV OpenVINO_DIR=/opt/intel/openvino

# Make pre-built gRPC available in /usr/local where LocalAI's CMake expects it
RUN cp -a /opt/grpc/. /usr/local/

# Clone LocalAI repository to build its llama-cpp gRPC backend wrapper
RUN git clone --depth 1 --branch "${LOCALAI_VERSION}" "${LOCALAI_REPO}" /LocalAI

WORKDIR /LocalAI/backend/cpp/llama-cpp

# Compile LocalAI's llama-cpp gRPC server targets with OpenVINO enabled:
# - llama-cpp-cpu-all (dynamic ggml backends including libggml-openvino.so + CPU variants)
# - llama-cpp-grpc (distributed RPC support)
# - llama-cpp-rpc-server
# Uses BuildKit ccache mount to persist compiled objects across builds.
# Note: setupvars.sh references unbound variables ($python_version), so source it before enabling `set -u`.
RUN --mount=type=cache,target=/root/.ccache,sharing=locked \
    bash -c "source ${OpenVINO_DIR}/setupvars.sh && \
    set -euxo pipefail && \
    export CCACHE_DIR=/root/.ccache && \
    ccache --max-size=5G || true && \
    export CMAKE_ARGS='-DGGML_OPENVINO=ON -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache' && \
    make llama-cpp-cpu-all && \
    make llama-cpp-grpc && \
    make llama-cpp-rpc-server && \
    ccache -s || true"

# Run LocalAI's standard packaging script (copies run.sh, binaries, lib/ld.so, system libs, and ggml-shared-libs)
RUN bash -c "source ${OpenVINO_DIR}/setupvars.sh && make -BC /LocalAI/backend/cpp/llama-cpp package"

# Bundle OpenVINO runtime libraries, plugins.xml, OpenCL ICD, and Intel GPU/NPU Level Zero drivers into package/lib
RUN bash -c 'set -exo pipefail; \
    source /LocalAI/scripts/build/package-gpu-libs.sh /LocalAI/backend/cpp/llama-cpp/package/lib; \
    # 1. Copy OpenVINO runtime libraries and plugins.xml (required for dynamic plugin discovery) \
    cp -avf ${OpenVINO_DIR}/runtime/lib/intel64/*.so* /LocalAI/backend/cpp/llama-cpp/package/lib/; \
    if [ -f "${OpenVINO_DIR}/runtime/lib/intel64/plugins.xml" ]; then \
        cp -avf "${OpenVINO_DIR}/runtime/lib/intel64/plugins.xml" /LocalAI/backend/cpp/llama-cpp/package/lib/; \
    fi; \
    # 2. Copy Intel GPU / NPU Level Zero & OpenCL runtime libraries \
    for drv_pattern in \
        "/usr/lib/x86_64-linux-gnu/libOpenCL.so*" \
        "/usr/lib/x86_64-linux-gnu/libze_loader.so*" \
        "/usr/lib/x86_64-linux-gnu/libze_intel_gpu.so*" \
        "/usr/lib/x86_64-linux-gnu/libze_intel_npu.so*" \
        "/usr/lib/x86_64-linux-gnu/libnpu_driver_compiler.so*" \
        "/usr/lib/x86_64-linux-gnu/libigc.so*" \
        "/usr/lib/x86_64-linux-gnu/libigdfcl.so*" \
        "/usr/lib/x86_64-linux-gnu/libigdgmm.so*" \
        "/usr/lib/x86_64-linux-gnu/intel-opencl/libigdrcl.so*"; do \
        copy_libs_glob "$drv_pattern"; \
    done; \
    # 3. Sweep transitive ELF dependencies for all bundled .so files and binaries \
    for bin in /LocalAI/backend/cpp/llama-cpp/package/llama-cpp-*; do \
        [ -f "$bin" ] && copy_elf_deps "$bin"; \
    done; \
    sweep_transitive_deps /LocalAI/backend/cpp/llama-cpp/package/lib; \
    # 4. Register Intel OpenCL ICD relative to $CURDIR/lib in run.sh if not already set \
    if [ -e /LocalAI/backend/cpp/llama-cpp/package/lib/libigdrcl.so ]; then \
        mkdir -p /LocalAI/backend/cpp/llama-cpp/package/etc/OpenCL/vendors; \
        echo "libigdrcl.so" > /LocalAI/backend/cpp/llama-cpp/package/etc/OpenCL/vendors/intel.icd; \
        sed -i "/export LD_LIBRARY_PATH=/a \\\tif [ -z \"\${OCL_ICD_VENDORS:-}\" ] && [ -d \"\$CURDIR/etc/OpenCL/vendors\" ]; then export OCL_ICD_VENDORS=\"\$CURDIR/etc/OpenCL/vendors\"; fi" /LocalAI/backend/cpp/llama-cpp/package/run.sh; \
    fi'

# ============================================================================
# Stage 2: Final LocalAI Backend Artifact Image (FROM scratch)
# LocalAI extracts the root filesystem of this image into its backends directory
# and executes /run.sh at the root.
# ============================================================================
FROM scratch

COPY --from=builder /LocalAI/backend/cpp/llama-cpp/package/. ./
