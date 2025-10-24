# shellcheck disable=SC1090
. ~/.config/proxmox-sh/current.env

b_qm_id='1104024'
b_storage_pool='pool-ex1'
curl "https://${PROXMOX_HOST}/api2/json/nodes/pve3/qemu/${b_qm_id}/config" \
    -X 'PUT' \
    -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
    --data-raw "ide0=${b_storage_pool}%3Acloudinit&digest=f3b419be6f26e7163459e836e60c35e7f58b1af7"
