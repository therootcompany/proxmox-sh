---
name: proxmox-create-vm
description:
  Create LXC containers and KVM cloud-init VMs on Proxmox with proxmox-create.
  Use when provisioning new containers or VMs, choosing sizing, or understanding
  VMID/IP assignment.
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

### Step 3: Confirm before creating

NEVER: Run `proxmox-create` without first presenting the plan to the user (hostname, template, RAM/vCPU/storage, active profile) and receiving explicit confirmation.

### Step 4: Run the command

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

## KVM Cloud-Init VMs (--kvm)

For cloud-init KVM VMs (private network; public 443 proxied by the TLS router):

```sh
proxmox-create --kvm debian13 <hostname>                    # image alias
proxmox-create --import 'sharedstor:import/<file>.qcow2' <hostname>
proxmox-create --kvm alpine24 --ciuser app <hostname>
```

- `--os`/`--ct`/`--template <name-or-vztmpl-path>` create an LXC container.
- `--kvm`/`--import <name-or-import-path>` create a KVM cloud-init VM
  (`debian13`, `debian12`, `alpine24`, `ubuntu24`, or
  `[storage:]import/<file>.qcow2`).
- The two are mutually exclusive: either a CT or a VM.
- Vendor template (e.g. QGA): `--civendor <image>` — the `--kvm <image>`
  (`debian13`, `debian12`, `alpine24`, `ubuntu24` → `civendor-<image>.yaml`
  from `PROXMOX_SNIPPET_STORAGE`), or `--civendor '<file>.yaml'` /
  `'storage-name:snippets/<file>.yaml'`; `--civendor none` disables it.
  `PROXMOX_VENDOR_SNIPPET` is the last fallback.
- `--ciuser <name>` creates a named cloud-init user (wheel + your keys);
  the default is `app` (PVE's own default, root, is unusable on Alpine —
  root refuses key auth). Privilege escalation on Alpine: no `sudo`
  binary, but `doas` works passwordless (wheel group, default doas.conf).
- **`runcmd` runs ONCE per disk.** Changing the vendor snippet and rebuilding
  the ISO re-runs config-stage modules but not `runcmd` — for snippet fixes,
  create a fresh guest, don't reboot.
- Log in as the `--ciuser` user (default `app`). Fresh disks change host
  keys (`ssh-keygen -R`).

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

1. **TLS certificate** -- `proxmox-create` initiates ACME issuance automatically.
   TLS issuance continues after `expect eof` returns -- the container is created
   but SSH via the `tls-` domain won't work until the cert is ready (~10-30s).
2. **DNS** -- Set up friendly domains (see `proxmox-dns` skill)
3. **SSH access** -- Wait for container init and TLS cert, then confirm:

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-ssh-wait <direct-ip-domain> [<friendly-domain>]
```

Phase 1: SSH on direct-IP with backoff (7s/15s/15s), auto-detects user (`root` standard, `app` bnna).
Phase 2: If friendly domain given, polls DNS propagation (max 20s).
On DNS WARN, verify CNAME (subdomain) or A+SRV (apex) records via domainpanel.
