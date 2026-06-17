# Setup Guide

End-to-end instructions for setting up the homelab from a bare SD card.

## Prerequisites

Install on your Mac:

- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) (`brew install ansible`)
- [Terraform](https://developer.hashicorp.com/terraform/install) (`brew install terraform`)
- [SOPS](https://github.com/getsops/sops) (`brew install sops`)
- [age](https://github.com/FiloSottile/age) (`brew install age`)
- kubectl (`brew install kubectl`)

## Step 1: Flash the SD Card

1. Open Raspberry Pi Imager
2. Select **Raspberry Pi 4** as device
3. Select **Ubuntu Server 24.04 LTS (64-bit)** as OS
4. Configure in the customization screen:
   - Hostname: `pi`
   - Username and password
   - WiFi SSID and password (if not using ethernet)
   - Enable SSH (password authentication)
5. Flash and insert into the Pi

## Step 2: Boot and Verify Connectivity

1. Plug in the Pi and wait ~2 minutes for first boot (cloud-init runs)
2. Verify: `ping pi.local`
3. SSH in: `ssh <username>@pi.local`
4. Check RAM: `free -h`

## Step 3: Provision the Pi

On the **first run only**, SSH is still on port 22, so override the port:

```bash
cd ansible && ansible-playbook -i inventory.ini playbook.yml -e ansible_port=22
```

Subsequent runs use the default port 2222 from inventory:

```bash
make provision
```

The playbook:
- Hardens the OS (fail2ban, UFW on port 2222, disables password SSH + root login, static IP)
- Configures zram swap (SD card friendly)
- Installs K3s
- Installs raw WireGuard (hub-and-spoke on 10.0.0.0/24)
- Sets up Cloudflare DDNS for `home.siig.tech`
- Generates an age keypair for SOPS

> Note the WireGuard **public key** printed in the provisioning output — you'll need it for VPN clients.

## Step 4: Configure SSH on your Mac

Add to `~/.ssh/config` so subsequent SSH/scp commands target port 2222:

```
Host pi pi.local
    User kasper
    Port 2222
```

## Step 5: Configure Cloudflare DDNS

Before the DDNS service can update DNS:

1. In Cloudflare, create an A record for `home.siig.tech` pointing to any IP (it will be updated automatically).
2. Create an API token with **Zone → DNS → Edit** permission for the `siig.tech` zone.
3. Provide `cf_api_token` and `cf_zone_id` to Ansible — either via SOPS, `--extra-vars`, or inventory group vars. Re-run provisioning after configuring.

## Step 6: Configure Router

Manual router setup (one-time):

- Set a **static DHCP lease** for the Pi's MAC address → `192.168.1.142`
- Forward **UDP 51820** → `192.168.1.142` (WireGuard)
- Forward **TCP 2222** → `192.168.1.142` (optional, remote SSH)

## Step 7: Merge Kubeconfig

```bash
make kubeconfig
```

This backs up your existing kubeconfig, fetches the K3s config from the Pi, and merges it. Verify with:

```bash
kubectl config use-context pi
kubectl get nodes
```

## Step 8: Initialize Terraform

```bash
export TF_VAR_github_token="your-github-pat-here"
make init
```

The GitHub PAT needs `repo` scope.

## Step 9: Bootstrap Flux

```bash
make bootstrap
```

This runs `terraform apply` which installs Flux onto the K3s cluster and points it at this repo's `clusters/home/` path.

## Step 10: Configure SOPS

```bash
make sops-setup
```

Copy the age public key into `.sops.yaml`, commit, and push. Then create the Flux decryption secret:

```bash
make flux-sops-secret
```

## Step 11: Verify

```bash
kubectl get nodes                              # single node, Ready
kubectl get kustomizations -n flux-system      # all reconciled
kubectl get pods -n openclaw                   # openclaw running
ssh pi 'sudo wg show'                          # WireGuard running
```

## Disaster Recovery

If the SD card dies:
1. Flash a new SD card (Step 1-2)
2. First provision uses `-e ansible_port=22` (Step 3), subsequent ones default to 2222
3. Run `make bootstrap` (Step 9)
4. Restore the age private key from your backup to `/etc/sops/age/keys.txt`
5. Run `make flux-sops-secret` (Step 10)
6. Re-run provisioning to recreate the WireGuard server key, then re-add VPN peers

Total recovery time: ~15 minutes.
