# 1) Builder stage: compile magic‑wormhole + deps
FROM python:3.11-alpine AS builder

# enable community repo for wireguard-tools
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

# install build deps
RUN apk add --no-cache \
      build-base \
      libffi-dev \
      openssl-dev \
      rust \
      cargo \
      wireguard-tools \
      iproute2

# install Python deps into /install
RUN pip install --upgrade pip && \
    pip install --prefix=/install magic-wormhole

# 2) Final stage: slim runtime
FROM python:3.11-alpine

# runtime OS tools with iptables and resolvconf support
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk add --no-cache \
      wireguard-tools \
      iproute2 \
      curl \
      iptables \
      openresolv

# copy pre-built Python packages
COPY --from=builder /install /usr/local

# copy and make entrypoint executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
