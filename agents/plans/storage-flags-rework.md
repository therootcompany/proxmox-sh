# Storage Flags Rework

- [x] Create plan
- [ ] Implement `--storage` as alias for `--extra-storage` in `bin/proxmox-create`
- [ ] Add new `--os-storage` flag for adjustable rootfs default
- [ ] Update help text (`fn_help`) to reflect new flags
- [ ] Update `fn_create_lxc` parameter usage
- [ ] Update default display output
- [ ] Commit with descriptive message
- [ ] Create and push PR

## Project and repository

- **Purpose**: Shell scripts to deploy Proxmox LXCs and expose them via Caddy
- **Local path**: `/Users/aj/.local/opt/proxmox-sh`
- **Git remote**: `https://github.com/therootcompany/proxmox-sh`
- **Current branch**: `main` (53591d7)
- **No uncommitted changes**

## Source map

```
bin/proxmox-create        Main LXC creation script (target of this work)
bin/proxmox-destroy       Teardown script (no changes)
bin/proxmox-shutdown      Shutdown script (no changes)
bin/caddy-add             Caddy config (no changes)
bin/env-switch            Env profile management (no changes)
provision-lxc             Legacy wrapper (no changes)
example.proxmox-sh.env    Environment example (no changes)
skills/                   Proxmox skills (no changes)
```

## Current implementation

### Storage handling (before)

- **`--storage` flag**: Sets `my_storage` variable (default `'0.1'` = 100MB extra volume)
  - Range: 1–250 GB
  - Passed to `fn_create_lxc` as `my_mp0_size` (8th parameter)
  - Used in `fn_create_lxc` for the `mp0` mount point (`/mnt/storage`)

- **Rootfs (OS storage)**: Hardcoded `my_fs_size=8` (8GB) in `fn_create_lxc`
  - Used in `--data-urlencode "rootfs=${my_fs_pool}:${my_fs_size},..."`
  - No flag to adjust this — every LXC gets 8GB root

### Function signature (current)

`fn_create_lxc` node vlan hostname pubkeys os_tmpl ram mp0_size cores vmid vmem

### Help text

Currently shows:
```
--storage 1    # 1-250 GB
```

## Configuration

### Relevant environment variables (no changes)

- `PROXMOX_FS_POOL` — storage pool for rootfs (currently 8GB)
- `PROXMOX_DATA_POOL` — storage pool for mp0 (extra storage)

### Flags to change

| Flag (current) | New name | Alias | Default | Range |
|---|---|---|---|---|
| `--storage <n>` | `--extra-storage <n>` | `--storage <n>` | 0.1 (100MB) | 0.1–250.0 GB (decimal) |
| _(none)_ | `--os-storage <n>` | _(none)_ | 8 | 0.2–50.0 GB (decimal) |

## Implementation plan

### File: `bin/proxmox-create`

#### 1. Change `--storage` handling to be an alias for `--extra-storage`

In the `case` statement, change:
```sh
--storage)
    my_storage="${1:-}"
```
to:
```sh
--extra-storage)
    my_extra_storage="${1:-}"
    if echo "${my_extra_storage} < 0.1 || ${my_extra_storage} > 250.0" | bc -l | grep -q 1; then
        echo "ERROR: --extra-storage must be between 0.1 and 250.0 (gigabytes)" >&2
        fn_help >&2
        return 1
    fi
    shift
    ;;
--storage)
    # Alias for --extra-storage
    my_extra_storage="${1:-}"
    if echo "${my_extra_storage} < 0.1 || ${my_extra_storage} > 250.0" | bc -l | grep -q 1; then
        echo "ERROR: --storage must be between 0.1 and 250.0 (gigabytes)" >&2
        fn_help >&2
        return 1
    fi
    shift
    ;;
```

#### 2. Add `--os-storage` flag

Add a new case clause:
```sh
--os-storage)
    my_os_storage="${1:-}"
    if echo "${my_os_storage} < 0.2 || ${my_os_storage} > 50.0" | bc -l | grep -q 1; then
        echo "ERROR: --os-storage must be between 0.2 and 50.0 (gigabytes)" >&2
        fn_help >&2
        return 1
    fi
    shift
    ;;
```

With default: `my_os_storage='8'` in the `main()` variable declarations.

#### 3. Pass `my_os_storage` to `fn_create_lxc`

Change the `fn_create_lxc` call:
```sh
# Before:
my_task_id="$(
    fn_create_lxc "${my_target_node}" "${PROXMOX_VLAN:-}" "${my_next_unit}" \
        "${my_hostname}" "${my_pubkeys}" "${my_os_tmpl}" "${my_ram}" \
        "${my_storage}" "${my_vcpus}" "${my_vcpu_limit}" "${my_vmid}"
)"

# After (add my_os_storage as 8th→7th param for rootfs, keep mp0 as 9th→10th):
my_task_id="$(
    fn_create_lxc "${my_target_node}" "${PROXMOX_VLAN:-}" "${my_next_unit}" \
        "${my_hostname}" "${my_pubkeys}" "${my_os_tmpl}" "${my_os_storage}" \
        "${my_ram}" "${my_storage}" "${my_vcpus}" "${my_vcpu_limit}" "${my_vmid}"
)"
```

#### 4. Update `fn_create_lxc` signature and body

New parameter order (add `my_rootfs_size` between os_tmpl and ram):
```sh
fn_create_lxc() { (
    my_target_node="${1}"
    my_vlan_param=""
    ...
    my_os_tmpl="${6}"
    my_rootfs_size="${7}"  # NEW: from --os-storage, default 8
    my_fs_size="${my_rootfs_size}"  # Use for rootfs
    my_memory="${8}"       # old my_ram, shift index
    my_mp0_size="${9}"     # old my_storage
    ...
```

Update the `rootfs` line:
```sh
--data-urlencode "rootfs=${my_fs_pool}:${my_fs_size},mountoptions=${my_fs_opts}" \
```

#### 5. Update `fn_help`

Change help output:
```
--storage 0.1        # 0.1-250 GB, extra mount at /mnt/storage (alias for --extra-storage)
--extra-storage 1    # 1-250 GB, extra mount at /mnt/storage
--os-storage 8       # 1-500 GB, rootfs size (default 8)
```

#### 6. Update default display

Change:
```
echo "    /mnt/storage:  ${my_storage}GB"
```
to:
```
echo "    Rootfs:        ${my_os_storage}GB"
if test "${my_storage}" != "0.1"; then
    echo "    /mnt/storage:  ${my_storage}GB"
fi
```

### No changes needed

- `provision-lxc` — does not pass storage flags
- `caddy-add` — unrelated to LXC storage
- `.env` files — no environment variable changes
- `skills/` — no skill changes

## Verification

After implementation:
1. `shellcheck bin/proxmox-create` passes
2. `--help` shows new flags correctly
3. `--storage 2` and `--extra-storage 2` behave identically
4. `--os-storage 16` sets 16GB rootfs (verify via API request printed to stderr)
5. Default 8GB rootfs still works without `--os-storage`

## Known limitations

- Shell arithmetic does not handle decimals well; `--storage 0.1` is allowed
  but comparisons use `bc -l`. Consider future: use integer MB instead of GB.
