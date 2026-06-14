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
2. Verify: `ping pi`
3. SSH in: `ssh <username>@pi`
4. Check RAM: `free -h`

## Step 3: Provision the Pi

```bash
make provision
```

This runs the Ansible playbook which:
- Hardens the OS (fail2ban, UFW, disable password SSH)
- Configures zram swap (SD card friendly)
- Installs K3s
- Installs WireGuard via PiVPN
- Generates an age keypair for SOPS

## Step 4: Merge Kubeconfig

```bash
make kubeconfig
```

This backs up your existing kubeconfig, fetches the K3s config from the Pi, and merges it. Verify with:

```bash
kubectl config use-context pi
kubectl get nodes
```

## Step 5: Initialize Terraform

```bash
export TF_VAR_github_token="your-github-pat-here"
make init
```

The GitHub PAT needs `repo` scope.

## Step 6: Bootstrap Flux

```bash
make bootstrap
```

This runs `terraform apply` which installs Flux onto the K3s cluster and points it at this repo's `clusters/home/` path.

## Step 7: Configure SOPS

```bash
make sops-setup
```

Copy the age public key into `.sops.yaml`, commit, and push. Then create the Flux decryption secret:

```bash
make flux-sops-secret
```

## Step 8: Verify

```bash
kubectl get nodes                              # single node, Ready
kubectl get kustomizations -n flux-system      # all reconciled
kubectl get pods -n openclaw                   # openclaw running
pivpn status                                   # (via SSH) WireGuard running
```

## Disaster Recovery

If the SD card dies:
1. Flash a new SD card (Step 1-2)
2. Run `make provision` (Step 3)
3. Run `make bootstrap` (Step 6)
4. Restore the age private key from your backup to `/etc/sops/age/keys.txt`
5. Run `make flux-sops-secret` (Step 7)

Total recovery time: ~15 minutes.
