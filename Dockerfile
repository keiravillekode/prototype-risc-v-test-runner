# zig provides the whole RISC-V cross toolchain (clang compiler, integrated
# assembler, lld, and a musl libc built on demand), so a single stage suffices:
# no GNU cross-toolchain, no target sysroot, and no host libmpc/mpfr/gmp.
FROM ubuntu:24.04@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

ARG ZIG_VERSION=0.15.2

# make + python3 drive the build/parsing; qemu-user provides qemu-riscv32.
# curl + xz-utils + ca-certificates only serve to fetch and unpack zig, so we
# purge them again to keep the image small.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install --no-install-recommends \
        ca-certificates \
        curl \
        make \
        python3 \
        qemu-user \
        xz-utils \
    && curl -fsSL \
        "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
        -o /tmp/zig.tar.xz \
    && mkdir -p /opt/zig \
    && tar -xf /tmp/zig.tar.xz -C /opt/zig --strip-components=1 \
    && rm /tmp/zig.tar.xz \
    && DEBIAN_FRONTEND=noninteractive apt-get -y purge curl xz-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/zig:${PATH}"
# The global cache (musl libc.a + compiler_rt) is baked at build time and only
# read at run time; the per-compilation local cache must be writable, so it is
# pointed at /tmp, the one writable location under the read-only test harness.
ENV ZIG_GLOBAL_CACHE_DIR=/opt/zig-cache
ENV ZIG_LOCAL_CACHE_DIR=/tmp/zig-cache

# Warm the global cache with the exact flags the Makefile uses, so the first
# real solution build does not spend ~50 s compiling musl/compiler_rt. Building
# and running a tiny static executable populates every cached artifact.
RUN printf 'int main(void) { return 0; }\n' > /tmp/warm.c \
    && printf '\t.text\n\t.globl warm\nwarm:\n\tret\n' > /tmp/warm.S \
    && zig cc -target riscv32-linux-musl -std=c99 -c /tmp/warm.c -o /tmp/warm_c.o \
    && zig cc -target riscv32-linux-musl -c /tmp/warm.S -o /tmp/warm_s.o \
    && zig cc -target riscv32-linux-musl -static -o /tmp/warm /tmp/warm_c.o /tmp/warm_s.o \
    && qemu-riscv32 /tmp/warm \
    && rm -rf /tmp/warm.c /tmp/warm.S /tmp/warm_c.o /tmp/warm_s.o /tmp/warm "${ZIG_LOCAL_CACHE_DIR}"

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
