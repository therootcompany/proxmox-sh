# [proxmox-sh](https://github.com/therootcompany/proxmox-sh)

Just some scripts for playing around with Proxmox

-   [.env](./example.env)
-   [provision-lxc](./provision-lxc)

    ```sh
    USAGE
        provision-lxc <hostname> [ssh-pubkey-or-file-or-url]

    EXAMPLE
        provision-lxc demo.example.com 'https://example.com/authorized_keys'
    ```

    -   [proxmox-create](./proxmox-create)

        ```sh
        USAGE
            proxmox-create <cidr> <hostname> [ssh-pubkey]

        EXAMPLE
            proxmox-create 192.168.0.100/24 example.com 'ssh-rsa AAAAB...xxxx me@example.local'
        ```

    -   [caddy-add-lxc](./caddy-add-lxc)

        ```sh
        USAGE
            caddy-add-lxc ct<id> <domain> <internal-ip> [proxy-port=80] [https]

        EXAMPLES
            caddy-add-lxc  pve1   pve1.example.com 192.168.0.103 8006 https
            caddy-add-lxc ct103 lxc103.example.com 192.168.0.103 80
            caddy-add-lxc ct103 lxc103.example.com 192.168.0.103

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
