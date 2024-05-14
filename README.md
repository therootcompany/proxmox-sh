# [proxmox-sh](https://github.com/therootcompany/proxmox-sh)

Scripts to quickly deploy LXCs with Proxmox and expose them with Caddy.

# Table of Contents

-   Install
-   Configure
    -   `env-switch`
-   Usage
    -   `proxmox-add` (to create an LXC)
    -   `caddy-add` (to expose LXC via TLS/HTTPS)
-   Generate an API Token
-   Grant Permissions to an API Token
-   Beta scripts

# Install

1. Clone to `~/.local/opt/proxmox-sh/`
    ```sh
    mkdir -p ~/.local/opt/
    git clone https://github.com/therootcompany/proxmox-sh.git ~/.local/opt/proxmox-sh
    ```
2. Add to `PATH`
    ```sh
    echo 'export PATH="$HOME/.local/opt/proxmox-sh/bin:$PATH"' >> ~/.config/envman/PATH.env
    export PATH="$HOME/.local/opt/proxmox-sh/bin:$PATH"
    ```
3. Initialize configs

    ```sh
    proxmox-sh-init
    ```

# How to Configure ENVs

Use `env-switch` to set the current profile for the scripts:

```sh
env-switch 'proxmox-sh' 'profile-1'
env-switch 'caddy-sh' 'profile-1'
```

See also:

-   [~/.local/opt/proxmox-sh/bin/env-switch](./bin/env-switch)
-   [~/.config/proxmox-sh/current.env](./example.proxmox-sh.env)
-   [~/.config/caddy-sh/current.env](./example.proxmox-sh.env)

# How to Create LXCs

```sh
proxmox-create
```

```text
USAGE
    proxmox-create <hostname> [ssh-pubkey-file-url-or-string]

EXAMPLE
    proxmox-create 'example1.1101.c.bnna.net' ~/.ssh/id_rsa.pub

DEFAULT SSH KEYS (only key comments are shown, for brevity)
    johndoe@macbook.local
    johndoe@macpro.local
    backuper@devops.com
```

See also: [~/.local/opt/proxmox-sh/bin/proxmox-create](./bin/proxmox-create)

# How to expose LXCs via Proxy:

```sh
caddy-add
```

```text
USAGE
    caddy-add <internal-ip> <domain> [--to-port=80] [--tls]

EXAMPLES
    caddy-add 192.168.0.103 pve1.example.com --to-port 8006 --tls
    caddy-add 192.168.0.103 lxc103.example.com --to-port 80
    caddy-add 192.168.0.103 lxc103.example.com

IMPORTANT
    BAD:  caddy run --config ./caddy.json # Will NOT persist!
    GOOD: caddy run --resume
```

See also: [~/.local/opt/proxmox-sh/bin/caddy-add](./bin/caddy-add)

# How to Get an API Token

Datacenter => Permissions => API Tokens

Note: `Privilege Separation` means that the API token must have its own permissions - it will not inherit from its owner.

## How to Grant an API Token Permissions

Datacenter => Permissions

Visually, the _Permissions_ link looks like a folder for a menu, but it's actually its own page.

# Beta Scripts

```sh
USAGE
    provision-lxc <hostname> [ssh-pubkey-or-file-or-url]

EXAMPLE
    provision-lxc demo.example.com 'https://example.com/authorized_keys'
```

See also: [provision-lxc](./provision-lxc)
