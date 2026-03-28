# Apex Domain DNS (A + SRV)

Apex domains (`example.com`, not `app.example.com`) cannot use CNAME.
Use A record for the IP plus SRV for TLS Router service routing.

Prefer CNAME for subdomains. Use A+SRV only when an apex domain is required.

## Create Records

```sh
cd ~/Agents/domainpanel

# A record with the VM's actual IP
go run ./cmd/domainpanel/ -create-host example.com \
    -type A \
    -data 10.11.4.209

# SRV record for HTTP routing via TLS router
# NOTE: Some DNS providers enforce RFC 2782 which requires the SRV target
# to be within the zone. The target becomes <DIRECT_IP_DOMAIN>.<APEX_DOMAIN>.
# The TLS Router knows to strip the apex suffix to interpret the direct-IP domain.
go run ./cmd/domainpanel/ -create-host _http._tcp.example.com \
    -type SRV \
    -data "10 1 3080 tls-10-11-4-209.<DIRECT_IP_DOMAIN>.example.com"
```

## Rules

- SRV targets must be direct-IP domains the TLS router trusts (`*.<DIRECT_IP_DOMAIN>`).
- Port MUST be a pre-defined TLS Router port. The TLS Router does not allow
  arbitrary ports for dynamic configuration -- this is a security measure.
- The SRV target may need `.<APEX_DOMAIN>` appended depending on DNS provider
  RFC 2782 enforcement. The TLS Router strips the apex suffix automatically.

## SRV Record Format

SRV data is a single string: `<priority> <weight> <port> <target>`

```sh
go run ./cmd/domainpanel/ -create-host _http._tcp.example.com \
    -type SRV \
    -data "10 1 3080 tls-10-11-4-209.<DIRECT_IP_DOMAIN>.example.com"
```

## Allowed Services and Ports

Port MUST be one of these pre-defined TLS Router ports:

| Service | Name | Port | Origin | Notes |
|---------|------|------|--------|-------|
| HTTP | `_http._tcp` | 3080 | 80+3000 | Caddy proxy (most common) |
| Raw TLS | `_http._tcp` | 443 | passthrough | Direct TLS passthrough |
| H2 | `_h2._tcp` | 443 | passthrough | HTTP/2 direct |
| SSH | `_ssh._tcp` | 22 | standard | SSH access |
| PostgreSQL | `_postgresql._tcp` | 15432 | 5432+10000 | Database |
| MQTT | `_mqtt._tcp` | 11883 | 1883+10000 | Message broker |

Port offset pattern: internal port = external port + 10000 (ensuring manual
configuration before exposure). Exceptions: HTTP (3080) and SSH (22).
