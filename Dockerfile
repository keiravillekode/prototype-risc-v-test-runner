# Ubuntu does not package a 32-bit RISC-V Linux toolchain, so we fetch a
# prebuilt riscv32 glibc cross-toolchain (which also bundles qemu-riscv32).
FROM ubuntu:24.04@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b AS toolchain

ARG TOOLCHAIN_RELEASE=2026.06.06
ARG TOOLCHAIN_ASSET=riscv32-glibc-ubuntu-24.04-gcc.tar.xz

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
    && curl -fsSL \
        "https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${TOOLCHAIN_RELEASE}/${TOOLCHAIN_ASSET}" \
        -o /tmp/toolchain.tar.xz \
    && tar -xf /tmp/toolchain.tar.xz -C /opt \
    && rm /tmp/toolchain.tar.xz \
    # Prune everything we never use (we only compile C, assemble, and link) to
    # keep the final image smaller: docs, the rv64 qemu, the C++/Fortran/LTO
    # compiler backends, and the non-C language drivers + bundled gdb.
    && rm -rf \
        /opt/riscv/share/doc \
        /opt/riscv/share/man \
        /opt/riscv/share/info \
        /opt/riscv/share/locale \
        /opt/riscv/bin/qemu-riscv64 \
    && rm -f \
        /opt/riscv/libexec/gcc/riscv32-unknown-linux-gnu/*/cc1plus \
        /opt/riscv/libexec/gcc/riscv32-unknown-linux-gnu/*/f951 \
        /opt/riscv/libexec/gcc/riscv32-unknown-linux-gnu/*/lto1 \
        /opt/riscv/bin/riscv32-unknown-linux-gnu-c++ \
        /opt/riscv/bin/riscv32-unknown-linux-gnu-g++ \
        /opt/riscv/bin/riscv32-unknown-linux-gnu-gfortran \
        /opt/riscv/bin/riscv32-unknown-linux-gnu-lto-dump \
        /opt/riscv/bin/riscv32-unknown-linux-gnu-gdb \
        /opt/riscv/bin/riscv32-unknown-linux-gnu-gdb-add-index


FROM ubuntu:24.04@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

# make + python3 drive the test build/parsing; the lib* packages are the host
# shared libraries the prebuilt gcc binaries link against at runtime.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install --no-install-recommends \
        make \
        python3 \
        libmpc3 \
        libmpfr6 \
        libgmp10 \
        zlib1g \
        libzstd1 \
        libglib2.0-0t64 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=toolchain /opt/riscv /opt/riscv
ENV PATH="/opt/riscv/bin:${PATH}"

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
