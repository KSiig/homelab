# Homelab

GitOps-managed Raspberry Pi 4 homelab running K3s, WireGuard, and OpenClaw.

## Architecture

```
┌─────────────────────────────────────────┐
│  Raspberry Pi 4 (Ubuntu Server ARM64)   │
│                                         │
│  ┌─ Host ─────────────────────────────┐ │
│  │  WireGuard VPN (PiVPN)             │ │
│  │  K3s (single-node)                 │ │
│  │                                    │ │
│  │  ┌─ K3s Cluster ────────────────┐  │ │
│  │  │  Flux CD (GitOps)            │  │ │
│  │  │  Traefik (ingress)           │  │ │
│  │  │  OpenClaw (service discovery)│  │ │
│  │  └─────────────────────────────┘  │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
         ▲
         │ UDP 51820 (WireGuard)
         │ TCP 6443 (K8s API)
         │
    ┌────┴────┐
    │ Macbook │
    └─────────┘
```

## Tooling

| Tool | Purpose |
|------|---------|
| Ansible | Machine provisioning (OS hardening, K3s, WireGuard) |
| Terraform | Flux CD bootstrap onto K3s |
| Flux CD | GitOps reconciliation of K8s manifests |
| SOPS + age | Secret encryption in git |

## Quick Start

See [docs/00-start-here/setup-guide.md](docs/00-start-here/setup-guide.md) for the full setup guide.

```bash
make provision   # Ansible: provision the Pi
make kubeconfig  # Merge Pi kubeconfig into local
make init        # Terraform: initialize
make bootstrap   # Terraform: install Flux
make sops-setup  # Display age public key for .sops.yaml
```

## Repository Structure

```
ansible/          # Machine provisioning playbooks and roles
terraform/        # Flux bootstrap configuration
clusters/home/    # Flux cluster definitions (GitOps entrypoint)
k8s/              # Kubernetes manifests (managed by Flux)
docs/             # Documentation
```

## Documentation

| Section | Description |
|---------|-------------|
| [Setup Guide](docs/00-start-here/setup-guide.md) | End-to-end setup from bare SD card |
| [VPN Connection](docs/10-vpn/connecting-from-macos.md) | Connect to the homelab VPN from macOS |
