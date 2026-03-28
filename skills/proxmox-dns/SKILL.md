---
name: proxmox-dns
description:
  DNS record management for Proxmox VMs using domainpanel. Use when mapping domains
  to VMs, creating direct-IP CNAMEs, setting up A+SRV for apex domains, or listing
  existing records. Covers domainpanel CLI, record type selection, and TLS router integration.
---

## Prerequisites

MUST: Run `proxmox-sh-doctor` first (see `proxmox` index skill) to confirm the
`DIRECT_IP_DOMAIN` value and list running VMs with their IPs.

**DNS tool:** Check if domainpanel is available:

```sh
test -d ~/Agents/domainpanel && echo "OK" || echo "MISSING"
```

If available, check `~/Agents/domainpanel/config.tsv` for configured accounts.

If domainpanel is NOT available, ask the user for:
1. Their DNS host/registrar (e.g. Cloudflare, Name.com, Route53)
2. An API token for that provider

Then create the DNS records via the provider's API with curl. Most common
providers accept a simple POST to create CNAME records. The agent should
look up the provider's API docs and construct the curl call.

## Direct-IP Domain Pattern

Every Proxmox VM IP maps to two DNS-resolvable domains automatically:

```
IP 10.11.4.209 -> tls-10-11-4-209.<DIRECT_IP_DOMAIN>   (HTTPS proxy to port 3080)
IP 10.11.4.209 -> tcp-10-11-4-209.<DIRECT_IP_DOMAIN>   (raw TCP proxy to port 443)
```

- `tls-` prefix: TLS-terminated HTTP, proxied to port 3080 with `X-Forwarded-*` headers
- `tcp-` prefix: Raw TLS passthrough to port 443

`DIRECT_IP_DOMAIN` comes from the active proxmox-sh env profile (e.g., `<DIRECT_IP_DOMAIN>`).

## Workflow: Map a Domain to a VM

### Step 1: Compute the direct-IP domain

Convert the VM's IP to a direct-IP domain:

```sh
# IP: 10.11.4.209
# Direct-IP: tls-10-11-4-209.<DIRECT_IP_DOMAIN>
```

Formula: replace dots with dashes, prepend `tls-`, append `.<DIRECT_IP_DOMAIN>`.

### Step 2: Create records

Use the dns-add script -- it auto-detects subdomain vs apex:

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-dns-add <friendly-domain> <direct-ip-domain>
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-dns-add app.example.com tls-10-11-4-209.<DIRECT_IP_DOMAIN>
```

For ccTLDs or other multi-part apex domains (e.g. `example.co.uk`):

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-dns-add example.co.uk tls-10-11-4-209.<DIRECT_IP_DOMAIN> --apex
```

For raw TCP passthrough (port 443), use `tcp-` instead of `tls-`:

```sh
sh ~/Agents/skills/proxmox/scripts/proxmox-sh-dns-add app.example.com tcp-10-11-4-209.<DIRECT_IP_DOMAIN>
```

If domainpanel is not available, the script prints the records needed and
instructs the agent to ask for DNS host + API token.

MUST: Read `./references/apex-domains.md` when the user needs a bare apex domain
and you need to understand the SRV record format, port rules, or RFC 2782 details.

### Step 4: Verify

```sh
cd ~/Agents/domainpanel

# List records for the zone
go run ./cmd/domainpanel/ -records -tsv | grep example.com

# Or check via dig
dig +short CNAME app.example.com
dig +short A example.com
```

## domainpanel CLI Reference

All commands run from `~/Agents/domainpanel/`:

```sh
# List all DNS records
go run ./cmd/domainpanel/ -records

# List as TSV (machine-parseable)
go run ./cmd/domainpanel/ -records -tsv

# Create a record
go run ./cmd/domainpanel/ -create-host <FQDN> -type <TYPE> -data <VALUE> [-ttl <SECONDS>]

# Create or update a record
go run ./cmd/domainpanel/ -update-host <FQDN> -type <TYPE> -data <VALUE> [-ttl <SECONDS>]

# Update when multiple records of same type exist
go run ./cmd/domainpanel/ -update-host <FQDN> -type <TYPE> -data <NEW> -match-data <OLD>

# Delete a record
go run ./cmd/domainpanel/ -delete-host <FQDN> [-type <TYPE>]
# -type ALL deletes all record types

# Bulk import from file
go run ./cmd/domainpanel/ -import records.tsv [-dry-run]
```

Default TTL: 300 seconds. Default type: A.

## Zone Discovery

domainpanel infers the zone from the FQDN and configured accounts. You do not
specify zones separately — just use the full hostname:

```sh
# domainpanel figures out that example.com is the zone
go run ./cmd/domainpanel/ -create-host app.example.com -type A -data 1.2.3.4
```

If the zone is not managed by any configured account, the command will error.

## Updating and Deleting Records

```sh
# Update an existing record (creates if missing)
go run ./cmd/domainpanel/ -update-host app.example.com -type CNAME \
    -data tls-10-11-8-50.<DIRECT_IP_DOMAIN>

# When multiple records of the same type exist, use -match-data
go run ./cmd/domainpanel/ -update-host app.example.com -type A \
    -data 10.11.8.50 -match-data 10.11.4.209

# Delete
go run ./cmd/domainpanel/ -delete-host app.example.com -type CNAME
```

Note: `libdns SetRecords` replaces the entire RRset for `(name, type)`. Use
`-match-data` for targeted single-record updates.

## DNS Health Check

After creating records, use dnscheck to validate:

```sh
cd ~/Agents/domainpanel

# Export current records
go run ./cmd/domainpanel/ -records -tsv > records.tsv

# Run health checks (SPF, DMARC, MX, CAA, dangling CNAMEs)
go run ./cmd/dnscheck/

# Preview auto-fixes
go run ./cmd/dnscheck/ -fix --dry-run
```

## Related Skills

- `proxmox-create-vm` — Create VMs (do this before DNS)
- `proxmox` — Index skill with doctor script (run first)
