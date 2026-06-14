# Connecting from macOS

## Prerequisites

- WireGuard installed on the Pi (done via `make provision`)
- WireGuard client on your Mac: install from the [App Store](https://apps.apple.com/us/app/wireguard/id1451685025) or `brew install wireguard-tools`

## Generate a Client Profile

SSH into the Pi and create a profile:

```bash
ssh kasper@pi.local
sudo pivpn add
```

Enter a name for the client (e.g., `macbook`). This generates a config file at `/home/kasper/configs/<name>.conf`.

## Transfer the Config

Copy the config to your Mac:

```bash
scp kasper@pi.local:~/configs/macbook.conf ~/Desktop/macbook.conf
```

## Import into WireGuard

### Option A: WireGuard App (GUI)

1. Open the WireGuard app
2. Click **Import Tunnel(s) from File**
3. Select the `.conf` file
4. Click **Activate** to connect

### Option B: CLI

```bash
sudo wg-quick up ~/Desktop/macbook.conf
```

To disconnect:

```bash
sudo wg-quick down ~/Desktop/macbook.conf
```

For a persistent setup, move the config:

```bash
sudo cp ~/Desktop/macbook.conf /etc/wireguard/pi.conf
sudo wg-quick up pi
```

## Verify Connection

```bash
# Check WireGuard status
sudo wg show

# Ping the Pi's WireGuard IP
ping 10.6.0.1

# Access K8s API over VPN
kubectl --context pi get nodes
```

## Port Forwarding

To access the Pi's WireGuard from outside your home network, forward UDP port **51820** on your router to the Pi's local IP. Check your router admin page for the Pi's IP if needed.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Can't connect | Is UDP 51820 forwarded on your router? Is the Pi's WireGuard service running? (`ssh pi.local 'sudo wg show'`) |
| Connected but can't reach Pi | Check `AllowedIPs` in client config — should include `10.6.0.0/24` at minimum |
| DNS not resolving | Check the `DNS` line in your client config — defaults to `1.1.1.1` |
| Handshake but no traffic | Check IP forwarding on Pi: `sysctl net.ipv4.ip_forward` should return `1` |
