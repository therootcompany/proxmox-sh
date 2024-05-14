# [proxmox-sh](https://github.com/therootcompany/proxmox-sh)

Scripts to quickly deploy LXCs with Proxmox and expose them with Caddy.

# Table of Contents

-   Install
-   ENVs
-   `proxmox-add` (to create an LXC)
-   `caddy-add` (to expose LXC via TLS/HTTPS)
-   Generate an API Token
-   Grant Permissions to an API Token
-   Beta scripts

# Install

```sh
mkdir -p ~/.local/opt/
git clone https://github.com/therootcompany/proxmox-sh.git ~/.local/opt/proxmox-sh

echo 'export PATH="$HOME/.local/opt/proxmox-sh/bin:$PATH"' >> ~/.config/envman/PATH.env
export PATH="$HOME/.local/opt/proxmox-sh/bin:$PATH"
```

# ENVs & Scripts

-   [~/.config/proxmox-sh/current.env](./example.env)

    ```sh
    mkdir -p ~/.config/proxmox-sh/
    chmod 0700 ~/.config/proxmox-sh/

    cp -RPp ./example.env ~/.config/proxmox-sh/bnna.env
    chmod 0600 ~/.config/proxmox-sh/bnna.env

    env-switch 'proxmox-sh' 'bnna'
    ```

-   [~/.local/opt/proxmox-sh/bin/proxmox-create](./proxmox-create)

    ```sh
    USAGE
        proxmox-create <cidr> <hostname> [ssh-pubkey]

    EXAMPLE
        proxmox-create 192.168.0.100/24 example.com 'ssh-rsa AAAAB...xxxx me@example.local'
    ```

-   [~/.local/opt/proxmox-sh/bin/caddy-add](./caddy-add)

        ```sh
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

# How to Get an API Token

Datacenter => Permissions => API Tokens

Note: `Privilege Separation` means that the API token must have its own permissions - it will not inherit from its owner.

## How to Grant an API Token Permissions

Datacenter => Permissions

Visually, the _Permissions_ link looks like a folder for a menu, but it's actually its own page.

# Beta Scripts

-   [provision-lxc](./provision-lxc)

    ```sh
    USAGE
        provision-lxc <hostname> [ssh-pubkey-or-file-or-url]

    EXAMPLE
        provision-lxc demo.example.com 'https://example.com/authorized_keys'
    ```
