---
name: proxmox-create-vm
description:
  Create LXC containers on Proxmox with proxmox-create. Use when provisioning new VMs,
  choosing sizing, or understanding VMID/IP assignment.
---

## Creating an LXC Container

### Step 1: Read defaults from the active env

```sh
grep -E 'PROXMOX_TEMPLATE_DEFAULT|PROXMOX_TARGET_NODE|PROXMOX_ID_PREFIX' \
    ~/.config/proxmox-sh/current.env
```

### Step 2: Choose the OS template

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-templates
```

Present the numbered list to the user. Guide the choice:

- **systemd required** (most services) => Ubuntu
- **OpenRC / minimal** (static sites, simple daemons) => Alpine
- Prefer: `custom` > `bnna` variant > `standard`
- The `default` tag marks the env's `PROXMOX_TEMPLATE_DEFAULT`

### Step 3: Run the command

MUST: Always pass `--os` with a full `vztmpl/...` path.

Wrap with `expect` to provide a pty (`proxmox-create` writes to `/dev/tty`):

```sh
expect -c 'spawn proxmox-create <hostname> \
    --os <PROXMOX_TEMPLATE_DEFAULT> \
    --storage <gb> --ram <mb> --vcpus <n>; \
    expect eof'
```

Output shows the assigned CTID, IP, and direct-IP domains. Example:

```
CTID:    1104209
IP:      10.11.4.209/24
Direct:  tls-10-11-4-209.<DIRECT_IP_DOMAIN>
```

**Common errors:**

- **403 on pool** -- the env's `PROXMOX_RESOURCE_POOL` doesn't exist or isn't
  accessible. Run `proxmox-sh-resources` and pick from the listed pools.
- **500 on create** -- usually a storage or network config issue. Check that
  the VNET/bridge and storage pool exist on the target node.
- **"already exists"** -- the VMID is taken. `proxmox-create` auto-increments,
  so this is rare. If it happens, retry.

## Container Layout

- `/` (rootfs) -- 8 GB, fixed, from `PROXMOX_FS_POOL`
- `/mnt/storage` -- `--storage` size, from `PROXMOX_DATA_POOL`

The `--storage` flag sets `/mnt/storage` size, not rootfs.

## Standard Sizing

| Tier | RAM | vCPU | Storage | Use case |
|------|-----|------|---------|----------|
| Minimal | 512 MB | 1 | 1 GB | Static sites, simple services |
| Dev | 2048 MB | 2 | 10 GB | Development instances |
| Standard | 4096 MB | 2 | 20 GB | Production services |
| Heavy | 8192 MB | 4 | 50 GB | Databases, build servers |

## VMID and IP Assignment

VMIDs are auto-assigned: `<PROXMOX_ID_PREFIX><3-digit-index>`.
The index maps to the last IP octet:

```
Prefix: 1104, Next index: 209
VMID:   1104209
IP:     10.11.4.209/24
GW:     10.11.4.1
```

## Post-Creation

1. **TLS certificate** -- `proxmox-create` initiates ACME issuance automatically
2. **DNS** -- Set up friendly domains (see `proxmox-dns` skill)
3. **SSH access** -- Wait for container init, then confirm:

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-ssh-wait <direct-ip-domain> [<friendly-domain>]
```

Phase 1: SSH on direct-IP with backoff (7s/15s/15s), auto-detects user (`root` standard, `app` bnna).
Phase 2: If friendly domain given, polls DNS propagation (max 20s).
On DNS WARN, verify CNAME (subdomain) or A+SRV (apex) records via domainpanel.
