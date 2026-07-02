# Ubuntu does not package a 32-bit RISC-V Linux toolchain, so we fetch a
# prebuilt riscv32 musl cross-toolchain. (Unlike the glibc bundle, the musl
# bundle ships no qemu, so qemu-riscv32 comes from the qemu-user apt package.)
FROM ubuntu:24.04@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b AS toolchain

ARG TOOLCHAIN_RELEASE=2026.06.06
ARG TOOLCHAIN_ASSET=riscv32-musl-ubuntu-24.04-gcc.tar.xz

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
    # keep the final image smaller: docs, the C++/LTO compiler backends, and
    # the non-C language drivers + bundled gdb.
    && rm -rf \
        /opt/riscv/share/doc \
        /opt/riscv/share/man \
        /opt/riscv/share/info \
        /opt/riscv/share/locale \
    && rm -f \
        /opt/riscv/libexec/gcc/riscv32-unknown-linux-musl/*/cc1plus \
        /opt/riscv/libexec/gcc/riscv32-unknown-linux-musl/*/lto1 \
        /opt/riscv/bin/riscv32-unknown-linux-musl-c++ \
        /opt/riscv/bin/riscv32-unknown-linux-musl-g++ \
        /opt/riscv/bin/riscv32-unknown-linux-musl-gfortran \
        /opt/riscv/bin/riscv32-unknown-linux-musl-lto-dump \
        /opt/riscv/bin/riscv32-unknown-linux-musl-gdb \
        /opt/riscv/bin/riscv32-unknown-linux-musl-gdb-add-index \
    # We link solutions with -static, so the target sysroot's shared libraries
    # and dynamic loader are never used; drop them.
    && find /opt/riscv/sysroot -name '*.so*' -delete


FROM ubuntu:24.04@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

# make + python3 drive the test build/parsing; qemu-user provides qemu-riscv32
# (the musl toolchain bundle does not); the lib* packages are the host shared
# libraries the prebuilt gcc binaries link against at runtime.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install --no-install-recommends \
        make \
        python3 \
        qemu-user \
        libmpc3 \
        libmpfr6 \
        libgmp10 \
        zlib1g \
        libzstd1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=toolchain /opt/riscv /opt/riscv
ENV PATH="/opt/riscv/bin:${PATH}"

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
