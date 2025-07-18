# wg-wormhole

A Dockerized WireGuard+Magic‑Wormhole helper that:
- Generates server & client configs
- Auto-detects your public IP
- Hands off the client config via Wormhole

## Build

docker build -t wg-wormhole .

##Usage

#Server

docker run --rm -it \
  --privileged --network host --device /dev/net/tun -v /etc/wireguard:/etc/wireguard -e WG_NETWORK=10.0.0.0/24 wg-wormhole send

#Client

docker run --rm -it --privileged --network host --device /dev/net/tun -v /etc/wireguard:/etc/wireguard wg-wormhole receive <wormhole-code>
