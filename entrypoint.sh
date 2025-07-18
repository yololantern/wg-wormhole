#!/bin/sh
set -e

# default WireGuard network (CIDR), override with WG_NETWORK
WG_NETWORK=${WG_NETWORK:-10.0.0.0/24}

# parse network and mask
NETWORK_BASE=$(echo "$WG_NETWORK" | cut -d'/' -f1)
PREFIX_LEN=$(echo "$WG_NETWORK" | cut -d'/' -f2)

# derive interface addresses (.1 for server, .2 for client)
SERVER_IP=$(echo "$NETWORK_BASE" | awk -F. '{print $1"."$2"."$3".1"}')
CLIENT_IP=$(echo "$NETWORK_BASE" | awk -F. '{print $1"."$2"."$3".2"}')

WG_DIR=/etc/wireguard
TMP_CLIENT_CONF=/tmp/client.conf

# helper functions
genkey() { wg genkey; }
pubkey() { echo "$1" | wg pubkey; }

case "$1" in
  send)
    # determine Endpoint: auto‑detect or override via ENDPOINT env
    if [ -z "$ENDPOINT" ]; then
      echo "No ENDPOINT set—fetching public IP..."
      PUBLIC_IP=$(curl -fsSL https://api.ipify.org)
      [ -z "$PUBLIC_IP" ] && { echo "ERROR: couldn't fetch IP; set ENDPOINT manually" >&2; exit 1; }
      EPT="${PUBLIC_IP}:51820"
    else
      EPT="$ENDPOINT"
    fi

    umask 077
    # generate keypairs
    S_PRIV=$(genkey); S_PUB=$(pubkey "$S_PRIV")
    C_PRIV=$(genkey); C_PUB=$(pubkey "$C_PRIV")

    # server config
    cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = ${SERVER_IP}/${PREFIX_LEN}
ListenPort = 51820
PrivateKey = $S_PRIV

[Peer]
PublicKey = $C_PUB
AllowedIPs = ${CLIENT_IP}/32
EOF

    # client config (no DNS to avoid resolvconf issues)
    cat > "$TMP_CLIENT_CONF" <<EOF
[Interface]
Address = ${CLIENT_IP}/${PREFIX_LEN}
PrivateKey = $C_PRIV

[Peer]
PublicKey = $S_PUB
Endpoint = $EPT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    chmod 600 "$TMP_CLIENT_CONF"
    wg-quick up wg0

    echo "=== Magic‑Wormhole code (share with peer) ==="
    wormhole send "$TMP_CLIENT_CONF"
    ;;

  receive)
    CODE="$2"
    [ -z "$CODE" ] && { echo "Usage: $0 receive <wormhole-code>" >&2; exit 1; }

    echo "Using code: $CODE"
    wormhole receive --accept-file --output-file "$WG_DIR/wg0.conf" "$CODE"
    chmod 600 "$WG_DIR/wg0.conf"

    echo "Config received! Bringing up WireGuard..."
    wg-quick up wg0
    ;;

  *)
    exec "$@"
    ;;
esac
