---
name: proxmox
description:
  Proxmox VM/LXC management index skill. Use when creating VMs, listing containers,
  managing Proxmox environments, or any Proxmox-related task. Load this first - it
  runs the doctor script and points to focused sub-skills.
---

**You (the agent)** run all scripts on behalf of the user. Each step produces
structured output with `# AGENT:` hints -- read them and act accordingly.
Only escalate to the user on actual roadblocks or decisions that need their input.
"The user" always means the person you're assisting.

## End-to-End Workflow

0. **Note issues** -- as you go, note anything confusing, missing, or wrong
1. **Doctor** -- validate environment, check connectivity
2. **Scan** -- list available pools, VMs, storages, SDN
3. **Confirm profile** -- pick or confirm the Proxmox account
4. **SSH pre-flight** -- ensure SSH config has the wildcard entry
5. **Choose template** -- pick the OS for the new VM
6. **Create VM** -- provision the LXC container (see `proxmox-create-vm` skill)
7. **DNS** -- map a friendly domain to the VM (see `proxmox-dns` skill)
8. **SSH verify** -- confirm SSH access, check DNS propagation
9. **Review** -- check your notes; suggest updates to scripts or skills

Steps 1-4 are startup/pre-flight. Steps 5-8 are the create flow.
Not every task needs all steps -- listing VMs only needs 1-3.

## Startup (run in order)

### 1. Doctor

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-doctor
```

On success (exit 0): proceed silently. On warnings (exit 2): mention relevant
WARNs but continue. On failure (exit 1): the user needs to provide 4 values:

1. `PROXMOX_HOST` -- API endpoint (from their admin)
2. `PROXMOX_TOKEN_ID` -- token identity (from their admin)
3. `PROXMOX_TOKEN_SECRET` -- token secret (from their admin)
4. `DIRECT_IP_DOMAIN` -- direct-IP domain suffix (from their admin)

Everything else can be discovered. Create a minimal env file with these 4,
then run env-defaults to fill in the rest:

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-env-defaults --env <file>
```

It queries the API and prints `SUGGEST` lines for every missing variable
(node, pool, vnet, template storage, default template, ID prefix).
See `~/.local/opt/proxmox-sh/example.proxmox-sh.env` for the full field list.

### 2. Scan all tokens

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-resources-all
```

Individual profile failures are fine. Output shows each token's pools,
storages, VMs, SDN zones, node grants. Don't dump the full output to the user;
summarize: N VMs running, pools available, any warnings.

For a single profile: `sh .../proxmox-sh-resources [--detail] [--env <file>]`
`--detail` adds node CPU/memory, vnet details, pool member counts, templates.

### 3. Confirm account

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-profiles
```

Present as a numbered pick list. Highlight which is `[current]`.
If only one profile exists, confirm it rather than making the user choose.
Switch with `env-switch proxmox-sh <profile-name>` if needed.

## Rules

- **Respect token permissions.** Advise when permissions are lacking. Investigate
  before concluding (pool propagation, node vs VM scope). Never bypass.
  MUST read `references/minimum-permissions.csv` on 403 errors, new token
  setup, or when advising what a token can/cannot do.
- **Agent runs all scripts.** Only escalate to the user on actual roadblocks.
- **MUST pass `--os vztmpl/...`** to `proxmox-create` (required in current version).
- **MUST get explicit permission** before touching `~/.ssh/config`.
- **Validate pool before create.** The env's `PROXMOX_RESOURCE_POOL` may not exist.
  Run `proxmox-sh-resources` and pick from the listed pools.

## VM Pre-flight

**OS selection:** systemd => Ubuntu, OpenRC/minimal => Alpine.
Flavor preference: user's own template > `bnna` variant > default.

**SSH config:** Check before creating a VM:

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-ssh-check
```

If missing, it prints the entry to add. MUST get explicit permission before
touching `~/.ssh/config`. Ask if they also want a friendly CNAME
(e.g. `feat-foo.example.com` -> `tls-10-11-xx-yy.<DIRECT_IP_DOMAIN>`).
If CNAME, also add a host-specific SSH entry:

```
Host feat-foo.example.com
    Hostname tls-10-11-xx-yy.<DIRECT_IP_DOMAIN>
    ProxyCommand sclient --alpn ssh %h
```

**proxmox-create** writes to `/dev/tty` which fails without a terminal.
Wrap with expect: `expect -c 'spawn proxmox-create ...; expect eof'`
See `proxmox-create-vm` sub-skill for flags, sizing, VMID/IP scheme.

## Post-Create

After `proxmox-create` succeeds, three things happen in order:

### 1. DNS setup

Ask the user if they want a friendly domain. Present:
- The `DIRECT_IP_DOMAIN` from the env (already working, no DNS needed)
- Managed DNS zones (from `domainpanel -records -tsv | cut -f1 | sort -u`)
- A suggested name like `<slug>-<octet>.<zone>` (e.g. `dev-209.example.com`)

Then run the dns-add script (see `proxmox-dns` sub-skill for full details):

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-dns-add <friendly-domain> <direct-ip-domain>
```

The script auto-detects subdomain vs apex, checks domainpanel availability,
and prints `# AGENT:` hints for every decision point. If domainpanel is missing
or the zone isn't managed, it tells you to ask the user for their DNS provider
and API token.

### 2. SSH readiness

Container init continues after Proxmox reports the task as complete. The
ssh-wait script handles the backoff timing automatically:

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-ssh-wait <direct-ip-domain> [<friendly-domain>]
```

Phase 1: SSH on direct-IP with backoff (7s/15s/15s), auto-detects user
(`root` for standard templates, `app` for bnna/custom templates).
Phase 2: If friendly domain given, polls DNS propagation via SSH (max 20s).

### 3. Summary

After ssh-wait succeeds, present the user a summary:
- CTID, OS, SSH user
- Direct-IP domain (always works)
- Friendly domain (if set)
- SSH command: `ssh <user>@<domain>`

On DNS WARN: verify the record was created correctly using domainpanel.
Subdomain: check CNAME. Apex: check A + SRV records.

## Quick Reference

**Direct-IP domains:** IP `10.11.4.209` becomes:

- `tls-10-11-4-209.<DIRECT_IP_DOMAIN>` -- HTTPS proxy to port 3080
- `tcp-10-11-4-209.<DIRECT_IP_DOMAIN>` -- raw TCP proxy to port 443

**TLS Router (ALPN-based forwarding):** The TLS router inspects ALPN to route
traffic. Internal ports are typically external port + 10000, ensuring services
require manual configuration before exposure:

| Protocol | ALPN | Container port | Why offset |
|----------|------|---------------|------------|
| HTTPS | `http/1.1`, `h2` | 3080 | 80 + 3000 |
| SSH | `ssh` | 22 | standard |
| PostgreSQL | `postgresql` | 15432 | 5432 + 10000 |
| MySQL | `mysql` | 13306 | 3306 + 10000 |
| MQTT | `mqtt` | 11883 | 1883 + 10000 |
| Raw TLS | (none) | 443 | passthrough |

**DNS for friendly domains:**

Subdomain (most common) -- CNAME to `tls-` direct-IP domain:

```
CNAME  app.example.com  tls-10-11-4-209.<DIRECT_IP_DOMAIN>
```

Apex domain (SHOULD, more complex -- only when apex is required):

```
A      example.com            10.11.4.209
SRV    _http._tcp.example.com 10 1 3080 tls-10-11-4-209.<DIRECT_IP_DOMAIN>.example.com
```

SRV target appends `.<APEX_DOMAIN>` due to RFC 2782 enforcement by some DNS
providers. The TLS Router strips the apex suffix. Port MUST be a pre-defined
TLS Router port (see `proxmox-dns` skill for full list).

**VMID scheme:** `<PREFIX><3-digit-index>` -- prefix `1104` + index `209` =
VMID `1104209`, IP `10.11.4.209`.

**Pool conventions:** `*-active`, `*-dev`, `*-prod`, `*-offline`.

## Sub-skills

| Skill | When |
|-------|------|
| `proxmox-create-vm` | Creating LXC containers |
| `proxmox-dns` | DNS record management (domainpanel) |

## proxmox-sh Tools

Installed at `~/.local/opt/proxmox-sh/`, commands in `bin/`:

| Command | Purpose |
|---------|---------|
| `proxmox-create` | Create LXC containers |
| `env-switch` | Switch active environment profile |
| `proxmox-sh-init` | Initialize config dirs and example env |
| `proxmox-sh-update` | Git pull latest proxmox-sh |
| `caddy-add` | Add reverse proxy routes via Caddy API |

