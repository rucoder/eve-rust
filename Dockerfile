ARG RUST_VERSION=1.85.1

FROM --platform=${BUILDPLATFORM} lfedge/eve-cross-compilers:fb809cfb1909752acb563e0b77cd3799534bce64 AS cross-compilers

FROM --platform=linux/arm64 alpine:3.16.9 AS target-sysroot-aarch64
RUN apk add --no-cache --allow-untrusted \
    alpine-baselayout \
    ca-certificates \
    busybox

FROM --platform=linux/riscv64 alpine:3.21.4 AS target-sysroot-riscv64
RUN apk add --no-cache --allow-untrusted \
    alpine-baselayout \
    ca-certificates \
    busybox

FROM --platform=${BUILDPLATFORM} alpine:3.16.9 AS alpine-base
ARG RUST_VERSION
RUN apk add --no-cache --allow-untrusted \
    alpine-baselayout \
    ca-certificates \
    curl \
    busybox \
    gcc



# Set up environment variables for rustup and cargo
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path --default-toolchain ${RUST_VERSION} --profile minimal

ENV TARGETS="x86_64-unknown-linux-musl aarch64-unknown-linux-musl x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu riscv64gc-unknown-linux-gnu"
RUN rustup target add ${TARGETS}

COPY --from=cross-compilers /packages /packages
RUN apk add --no-cache --allow-untrusted -X /packages "build-base-aarch64"
RUN apk add --no-cache --allow-untrusted -X /packages "build-base-riscv64"
RUN rm -rf /packages

#  aarch64-linux-musl-gcc
RUN ln -s /usr/bin/aarch64-alpine-linux-musl-gcc /usr/bin/aarch64-linux-musl-gcc

# install the cross-compilers libraries using chroot
RUN mkdir -p /tmp/target-sysroot-aarch64/etc/apk
RUN mkdir -p /tmp/target-sysroot-riscv64/etc/apk
# Manually configure chroot environment
RUN for arch in aarch64 riscv64; do \
    mkdir -p /tmp/target-sysroot-$arch/etc/apk && \
    echo "nameserver 8.8.8.8" > /tmp/target-sysroot-$arch/etc/resolv.conf; \
    done

COPY --from=target-sysroot-aarch64 / /tmp/target-sysroot-aarch64
COPY --from=target-sysroot-riscv64 / /tmp/target-sysroot-riscv64

ADD ./cross-gcc-lib-install.sh /usr/bin/cross-gcc-lib-install.sh
ENV GCC_LIBS="musl-dev libgcc libstdc++"
RUN cross-gcc-lib-install.sh


# # FROM tools-host AS target-amd64
# # ENV CARGO_BUILD_TARGET="x86_64-unknown-linux-musl"

# # FROM tools-host AS target-arm64
# # ENV CARGO_BUILD_TARGET="aarch64-unknown-linux-musl"

# # FROM tools-host AS target-riscv64
# # ENV CARGO_BUILD_TARGET="riscv64gc-unknown-linux-gnu"

# # FROM target-$TARGETARCH AS tools
# # RUN echo "Cargo target: $CARGO_BUILD_TARGET"

# # ADD config.toml /usr/local/cargo/
# # CARGO_BUILD_TARGET is respected by cargo install and other cargo commands
# # RUN cargo install --root /cargo-cross cargo-chef@0.1.71 cargo-sbom@0.9.1


# FROM --platform=${BUILDPLATFORM} lfedge/eve-alpine:0f2e0da38e30753c68410727a6cc269e57ff74f2 AS tools-cross-base
# ARG RUST_VERSION
# ENV BUILD_PKGS="alpine-baselayout ca-certificates curl clang musl-dev linux-headers make clang python3 git perl protoc gcc"
# RUN eve-alpine-deploy.sh

# # Set up environment variables for rustup and cargo
# ENV CARGO_HOME=/usr/local/cargo \
#     RUSTUP_HOME=/usr/local/rustup \
#     PATH=/usr/local/cargo/bin:$PATH

# RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path --default-toolchain ${RUST_VERSION}

# ENV TARGETS="x86_64-unknown-linux-musl aarch64-unknown-linux-musl x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu riscv64gc-unknown-linux-gnu"
# RUN rustup target add ${TARGETS}


# FROM scratch AS builder

# install the cross-compilers
# COPY --from=cross-compilers /packages /packages
# RUN apk add --no-cache --allow-untrusted -X /packages "build-base-aarch64"
# RUN apk add --no-cache --allow-untrusted -X /packages "build-base-riscv64"
# RUN rm -rf /packages

# # needed for cargo-chef and cargo-sbom, as well as many other compilations
# # RUN apk add musl-dev linux-headers make clang mold python3 git perl protoc

# # copy the cargo plugins from the tools stage
# # COPY --from=tools /cargo-cross /usr/local/cargo
# # we define target specific rustc flags for cross-compilation
# # ADD config.toml /usr/local/cargo/

# FROM --platform=linux/arm64 lfedge/eve-alpine:0f2e0da38e30753c68410727a6cc269e57ff74f2 AS target-sysroot-aarch64
# ENV PKGS="alpine-baselayout"
# RUN eve-alpine-deploy.sh

# FROM --platform=linux/riscv64 lfedge/eve-alpine:0f2e0da38e30753c68410727a6cc269e57ff74f2 AS target-sysroot-riscv64
# ENV PKGS="alpine-baselayout"
# RUN eve-alpine-deploy.sh

# FROM tools-cross-base AS cross-builder
# COPY --from=target-sysroot-aarch64 / /tmp/target-sysroot-aarch64
# COPY --from=target-sysroot-riscv64 / /tmp/target-sysroot-riscv64
# ADD ./cross-gcc-lib-install.sh /usr/bin/cross-gcc-lib-install.sh
# ENV GCC_LIBS="musl-dev libgcc libstdc++"
# RUN cross-gcc-lib-install.sh
