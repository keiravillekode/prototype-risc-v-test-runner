FROM ubuntu:24.04

# install packages required to run the tests
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install --no-install-recommends \
        gcc-riscv64-linux-gnu \
        libc6-riscv64-cross \
        make \
        python3 \
        qemu-user \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
