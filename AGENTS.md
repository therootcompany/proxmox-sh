# proxmox-sh

Proxmox VM/LXC management skills and scripts for agent-assisted deploys.

## Setup

Skills should be symlinked into the agent's global skills directory so they
are discoverable. If the symlinks are missing, suggest creating them.

The three skill directories to link:

```
skills/proxmox
skills/proxmox-create-vm
skills/proxmox-dns
```

## Structure

```
skills/
  proxmox/              Index skill (load first)
    scripts/            Shell scripts (agent runs these, not the user)
    references/         On-demand reference files
  proxmox-create-vm/    VM creation sub-skill
  proxmox-dns/          DNS management sub-skill
    references/         Apex domain reference (loaded on demand)
```

## Conventions

- Scripts output TSV with `# section` headers and `# AGENT:` inline hints
- Skills target 32k-context mid-tier/on-device agents
- Agent runs all scripts directly; only escalates to the user on roadblocks
- Script output is hidden from the user; agent must reformat into response text
