# Connecting from macOS

## Prerequisites

- WireGuard installed on the Pi (done via `make provision`)
- WireGuard client on your Mac: install from the [App Store](https://apps.apple.com/us/app/wireguard/id1451685025) or `brew install wireguard-tools`
- Pi's WireGuard public key (printed during provisioning, or fetch via `ssh pi 'sudo cat /etc/wireguard/public.key'`)

## Generate Client Keys

On the Mac:

```bash
wg genkey | tee client-private.key | wg pubkey > client-public.key
```

Keep `client-private.key` secret — it never leaves your Mac.

## Create Client Config

Create `pi.conf`:

```ini
[Interface]
PrivateKey = <contents-of-client-private.key>
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <pi-public-key-from-provision-output>
Endpoint = home.siig.tech:51820
AllowedIPs = 10.0.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
```

Pick a unique `Address` per client (`10.0.0.2/32`, `10.0.0.3/32`, ...).

## Add the Client as a Peer on the Pi

```bash
ssh pi
sudo wg set wg0 peer <client-public-key> allowed-ips 10.0.0.2/32
```

`wg set` adds the peer at runtime but doesn't persist across reboots. To make it permanent, also append to `/etc/wireguard/wg0.conf`:

```ini
[Peer]
PublicKey = <client-public-key>
AllowedIPs = 10.0.0.2/32
```

## Import into WireGuard

### Option A: WireGuard App (GUI)

1. Open the WireGuard app
2. Click **Import Tunnel(s) from File**
3. Select `pi.conf`
4. Click **Activate** to connect

### Option B: CLI

```bash
sudo wg-quick up ./pi.conf
```

To disconnect:

```bash
sudo wg-quick down ./pi.conf
```

For a persistent setup, move the config:

```bash
sudo cp pi.conf /etc/wireguard/pi.conf
sudo wg-quick up pi
```

## QR Code for Mobile Clients

For phones, render the config as a QR code that the WireGuard mobile app can scan:

```bash
qrencode -t ansiutf8 < client.conf
```

## Verify Connection

```bash
# Check WireGuard status (Mac side)
sudo wg show

# Ping the Pi's WireGuard IP
ping 10.0.0.1

# Access K8s API over VPN
kubectl --context pi get nodes
```

## Router Setup

For external connectivity, forward **UDP 51820** to the Pi's LAN IP (`192.168.1.142`). DNS is handled by Cloudflare DDNS keeping `home.siig.tech` pointed at your current public IP.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Can't connect | Is UDP 51820 forwarded on your router? Is the Pi's WireGuard service running? (`ssh pi 'sudo wg show'`) Does `home.siig.tech` resolve to your current public IP? (`dig home.siig.tech`) |
| Connected but can't reach Pi | Check `AllowedIPs` in client config — should include `10.0.0.0/24` at minimum |
| DNS not resolving | Check the `DNS` line in your client config — defaults to `1.1.1.1` |
| Handshake but no traffic | Check IP forwarding on Pi: `sysctl net.ipv4.ip_forward` should return `1` |
| Peer drops after Pi reboot | Make sure the peer is appended to `/etc/wireguard/wg0.conf`, not just added via `wg set` |
