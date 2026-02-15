#!/bin/sh
set -e
set -u

# shellcheck disable=SC1090
. ~/.config/proxmox-sh/current.env

# https://pve.proxmox.com/wiki/Cloud-Init_Support#_custom_cloud_init_configuration
# --cicustom "vendor=cephfs0-images:snippets/ubuntu-24-04-vendor.yaml"

# #cloud-config
# packages:
#   - qemu-guest-agent
#   runcmd:
#     - [ systemctl, start, qemu-guest-agent ]
#       - [ echo, "Custom vendor command executed" ]

# qm cloudinit dump 1104021 meta
# qm cloudinit dump 1104021 user
# qm cloudinit dump 1104021 network
#
# find /var/lib/cloud/
# sudo cat /var/lib/cloud/instances/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/vendor-data.txt
# sudo cat /var/lib/cloud/instances/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/user-data.txt
# ssh 'host' "cloud-init status --wait" | grep "status: done"
# qm agent 1104021 ping
# qm agent 1104021 exec cloud-init status --wait
# qm guest cmd 1104021 help
# qm guest cmd 1104021 fstrim
# qm guest cmd 1104021 get-osinfo
# qm guest cmd 1104021 get-fsinfo
# qm guest cmd 1104021 get-memory-blocks
# qm guest exec 1104021 ls /
# qm wait 1104021 # i.e. for a complete, cold, shutdown

# use scsi rather than ide for cloud init with UEFI bios
# https://grok.com/share/bGVnYWN5LWNvcHk%3D_9b933ad9-40b7-4c79-b91d-4f5048206895
# https://forum.proxmox.com/threads/cloud-init-using-ubuntu-24-04-minimal-image-does-not-work.153919/

# g_base_url='https://pvec-dc1.example.com/api2/json/nodes/pve3/qemu'
# g_vmid=1234

g_base_url="https://${PROXMOX_HOST}"

g_vmid=1104021
g_ip='10.11.4.121/24'
g_gw='10.11.4.1'
# g_image='noble-server-cloudimg-amd64.2025-08-05.qcow2'
g_image='ubuntu-24.04-minimal-cloudimg-amd64.2025-07-27_13.04.qcow2'
# g_image='generic_alpine-3.20.3-x86_64-bios-cloudinit-r0.qcow2'
g_name='ai-runner-1'
g_ssh_keys='ssh-ed25519%20AAAAC3NzaC1lZDI1NTE5AAAAIFtHxl7p%2F1ko1aTygdNa884u9Hl3PNPjCaMppDwpopbI%20aj%40biggoron-2024.ed.local'
g_ns='1.1.1.3'
g_pw='xxxx-xxxx-xxxx-xxxx'
curl --fail-with-body "${g_base_url}/api2/json/nodes/pve3/qemu" \
    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
    -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
    --data-urlencode "vmid=${g_vmid}" \
    --data-urlencode "name=${g_name}" \
    --data-urlencode "pool=${PROXMOX_RESOURCE_POOL}" \
    --data-urlencode 'onboot=1' \
    --data-urlencode 'ide2=none,media=cdrom' \
    --data-urlencode 'ostype=l26' \
    --data-urlencode 'machine=q35' \
    --data-urlencode 'bios=ovmf' \
    --data-urlencode 'scsihw=virtio-scsi-single' \
    --data-urlencode 'agent=1' \
    --data-urlencode "efidisk0=${PROXMOX_FS_POOL}:1,efitype=4m,pre-enrolled-keys=0" \
    --data-urlencode "scsi0=${PROXMOX_FS_POOL}:0,import-from=cephfs0-images:999/${g_image},format=qcow2,discard=on,ssd=on,iothread=on" \
    --data-urlencode "scsi1=${PROXMOX_DATA_POOL}:20,discard=on,ssd=on,iothread=on" \
    --data-urlencode 'sockets=2' \
    --data-urlencode 'cores=20' \
    --data-urlencode 'numa=1' \
    --data-urlencode 'cpu=x86-64-v2-AES' \
    --data-urlencode 'memory=49152' \
    --data-urlencode "net0=virtio,bridge=${PROXMOX_VNET},firewall=1" \
    --data-urlencode "scsi3=${PROXMOX_FS_POOL}:cloudinit" \
    --data-urlencode "cicustom=vendor=cephfs0-images:snippets/ubuntu-24-04-vendor.yaml" \
    --data-urlencode "ciuser=app" \
    --data-urlencode "cipassword=${g_pw}" \
    --data-urlencode "sshkeys=${g_ssh_keys}" \
    --data-urlencode "searchdomain=${PROXMOX_SEARCH_DOMAIN}" \
    --data-urlencode "nameserver=${g_ns}" \
    --data-urlencode "ipconfig0=ip=${g_ip},gw=${g_gw}"

# PUT https://pvec-slc1.bnna.net/api2/json/nodes/pve3/qemu/1104021/cloudinit
