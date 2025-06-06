#!/bin/bash
set -euox pipefail

vm_name=${1:-nexus}; shift || true
interface_name=${1:-lo}; shift || true

mkdir -p shared
vagrant ssh-config $vm_name >shared/$vm_name-ssh-config.conf
exec wireshark \
    -o "gui.window_title:$vm_name $interface_name" \
    -k \
    -d 'tcp.port==6001,http' \
    -d 'tcp.port==6002,http' \
    -d 'tcp.port==6003,http' \
    -d 'tcp.port==8081,http' \
    -i <(ssh -F shared/$vm_name-ssh-config.conf $vm_name "sudo tcpdump -s 0 -U -n -i $interface_name -w - not port 22")
