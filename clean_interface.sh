#!/bin/bash
# ----------------------------------------------------------------------
# name:         clean_interface
# version:      1.0
# createTime:   2018-05-10
# description:  清除容器删除后还残留的veth网卡
# github:       https://github.com/wanshaoyuan/script
# ---------------------------------------------------------------------
veth_in_use=()
veth_unused=()
veth_all=()
flag=0
function veth_interface_for_container() {
    local pid=$(docker inspect -f '{{.State.Pid}}' "${1}")
    mkdir -p /var/run/netns
    ln -sf /proc/$pid/ns/net "/var/run/netns/${1}"
    local index=$(ip netns exec "${1}" ip link show eth0 | head -n1 | awk -F 'if' '{print $2}'|awk -F ':' '{print $1}')
    ip link show | grep "^${index}:" | sed "s/${index}: \(.*\):.*/\1/"|awk -F '@' '{print $1}'
    rm -f "/var/run/netns/${1}"
}

for i in $(docker ps | grep Up | awk '{print $1}')
do
    if [ "$(veth_interface_for_container $i)" != "docker0" ];
    then
        veth_in_use+=($(veth_interface_for_container $i))
    fi
done

for i in $(ip link|grep veth|awk -F ":" '{print $2}'|awk -F '@' '{print $1}')
do
    veth_all+=($i)
done
for i in "${veth_all[@]}"
do
    for j in "${veth_in_use[@]}"
    do
       if [ "$i" == "$j" ];
       then       
         flag=1
         break;
       fi
    done
    if [ $flag -eq 0 ];
    then
       veth_unused+=($i)
    else
       flag=0
    fi
done
echo ${veth_unused[@]}

if [ "$1" == "-d" ];
then
   for i in "${veth_unused[@]}"
   do
      ip link set $i down
      ip link delete $i
   done
fi
