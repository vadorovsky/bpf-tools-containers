FROM debian:bullseye-slim as llvm
RUN apt-get update \
    && apt-get install -y \
    gnupg2 \
    wget
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN echo "deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-14 main" > /etc/apt/sources.list.d/llvm.list
RUN apt-get update \
    && apt-get install -y \
    libclang-14-dev \
    llvm-14-dev

FROM llvm as bpftool-build 
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
    zlib1g-dev
WORKDIR /usr/local/src
RUN git clone --branch v$VERSION --recurse-submodules https://github.com/libbpf/bpftool
WORKDIR /usr/local/src/bpftool/src
RUN CLANG=clang-14 LLVM_STRIP=llvm-strip-14 make

FROM llvm as bpftool
RUN apt-get update \
    && apt-get install -y \
    libbinutils \
    libc6 \
    libcap2 \
    libelf1 \
    zlib1g
COPY --from=bpftool-build /usr/local/src/bpftool/src/bpftool /usr/local/sbin
ENTRYPOINT [ "/usr/local/sbin/bpftool" ]

FROM bpftool-build as aya-gen-build
RUN apt-get install -y curl
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup install nightly
RUN rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
RUN rustup default nightly
RUN cargo install bindgen
RUN cargo install --git https://github.com/aya-rs/aya -- aya-gen

FROM bpftool as aya-gen
COPY --from=aya-gen-build /root/.cargo/bin/bindgen /usr/local/bin/bindgen
COPY --from=aya-gen-build /root/.cargo/bin/aya-gen /usr/local/bin/aya-gen
ENTRYPOINT [ "/usr/local/bin/aya-gen" ]
