FROM debian:bullseye-slim as build 
ARG VERSION=6.8.0
RUN apt-get update \
    && apt-get install -y \
    binutils-dev \
    build-essential \
    libbfd-dev \
    libc6-dev \
    libcap-dev \
    libelf-dev \
    git \
    pkg-config \
    software-properties-common \
    wget \
    zlib1g-dev
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"
WORKDIR /usr/local/src
RUN git clone --branch v$VERSION --recurse-submodules https://github.com/libbpf/bpftool
WORKDIR /usr/local/src/bpftool/src
RUN CLANG=clang-14 LLVM_STRIP=llvm-strip-14 make

FROM debian:bullseye-slim
RUN apt-get update \
    && apt-get install -y \
    libbinutils \
    libc6 \
    libcap2 \
    libelf1 \
    zlib1g
COPY --from=build /usr/local/src/bpftool/src/bpftool /usr/local/sbin
ENTRYPOINT [ "/usr/local/sbin/bpftool" ]