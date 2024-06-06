#!/bin/bash

# 安装必要的软件包
yum install -y epel-release
yum install -y xl2tpd libreswan

# 配置IPsec
cat <<EOF > /etc/ipsec.conf
version 2.0

config setup
    protostack=netkey
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v6:fd00::/8,%v6:fe80::/10
    oe=off
    interfaces=%defaultroute

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev1
    authby=secret
    type=transport

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%defaultroute
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
EOF

echo ": PSK \"YourSecretKeyHere\"" > /etc/ipsec.secrets

# 配置xl2tpd
cat <<EOF > /etc/xl2tpd/xl2tpd.conf
[lac ipsec-psk]
lns = 171.15.130.125
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

cat <<EOF > /etc/ppp/options.l2tpd.client
require-mschap-v2
refuse-eap
noccp
noauth
idle 1800
mtu 1410
mru 1410
defaultroute
usepeerdns
debug
lock
connect-delay 5000
EOF

# 添加额外IP地址的路由和iptables规则
declare -a extra_ips=("171.15.130.31" "171.15.131.141" "YourAdditionalIP1" "YourAdditionalIP2")

for ip in "${extra_ips[@]}"
do
    ip addr add $ip/32 dev eth0
    ip route add $ip/32 dev eth0
    iptables -t nat -A POSTROUTING -s $ip/32 -o eth0 -j MASQUERADE
done

# 启动服务
systemctl restart ipsec
systemctl restart xl2tpd

echo "L2TP/IPsec VPN配置完成。"
