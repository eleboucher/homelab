# renovate: datasource=docker depName=caddy
ARG CADDY_VERSION=2.11

FROM caddy:${CADDY_VERSION}-builder AS builder
RUN xcaddy build \
    --with github.com/mholt/caddy-l4

FROM caddy:${CADDY_VERSION}-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
