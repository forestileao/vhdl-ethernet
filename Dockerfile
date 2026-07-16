# SPDX-License-Identifier: MIT

FROM debian:stable-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ghdl make python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
