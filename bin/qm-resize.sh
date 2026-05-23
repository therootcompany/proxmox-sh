#!/bin/sh
set -e
set -u

# shellcheck disable=SC1090
. ~/.config/proxmox-sh/current.env

g_base_url="https://${PROXMOX_HOST}"
g_qm_id='1104021'
g_disk='scsi0'
# g_size='+1G'
g_size='8G'

curl --fail-with-body "${g_base_url}/api2/json/nodes/pve3/qemu/${g_qm_id}/resize" \
    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
    -X 'PUT' \
    -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
    --data-urlencode "disk=${g_disk}" \
    --data-urlencode "size=${g_size}"
