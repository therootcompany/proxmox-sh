# [proxmox-sh](https://github.com/therootcompany/proxmox-sh)

Just some scripts for playing around with Proxmox

-   [.env](./example.env)
-   [proxmox-lxc-create](./proxmox-lxc-create)

    ```sh
    USAGE
        proxmox-create <cidr> <hostname> [ssh-pubkey]

    EXAMPLE
        proxmox-create 192.168.0.10/24 example.com 'ssh-rsa AAAAB...xxxx me@example.local'
    ```

# How to Get an API Token

Datacenter => Permissions => API Tokens

Note: `Privilege Separation` means that the API token must have its own permissions - it will not inherit from its owner.

## How to Grant an API Token Permissions

Datacenter => Permissions

Visually, the _Permissions_ link looks like a folder for a menu, but it's actually its own page.
