#!/usr/bin/env bash
set -u

port_file="${PORT_FORWARDED:-/tmp/gluetun/forwarded_port}"
api="${HTTP_S:-http}://${QBITTORRENT_SERVER:-localhost}:${QBITTORRENT_PORT:-8080}/api/v2"

update_port() {
    local port preferences
    [[ -r "$port_file" ]] || return 0
    port=$(cat "$port_file")
    # Gluetun clears this file when its port mapping is lost.
    [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] || return 0
    (( port <= 65535 )) || return 0

    # Localhost authentication bypass is enabled in qBittorrent.
    preferences=$(curl --fail --silent --show-error --connect-timeout 5 --max-time 10 "$api/app/preferences") || return 1
    if grep -Eq '"listen_port"[[:space:]]*:[[:space:]]*'"$port"'([,}[:space:]])' <<< "$preferences"; then
        return 0
    fi
    curl --fail --silent --show-error --connect-timeout 5 --max-time 10 \
        --data-urlencode "json={\"listen_port\":$port}" "$api/app/setPreferences" || return 1
    printf 'Updated qBittorrent listening port to %s\n' "$port"
}

while true; do
    update_port || printf 'Could not update qBittorrent port; retrying in 10 seconds\n' >&2
    sleep 10
done
