#!/bin/bash

PATH='/sbin'

ALL="0:65535"
PA="1024:65535"
LAN="10.0.200.0/24"
LANVPN="192.168.100/24"
WAN1="0/0"
WAN2="0/0"
FW="0/0"
DMZ1="0/0"
DMZ2="0/0"

### politicas que bloqueiam qualquer tipo de conexão
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

### permite que a maquina FIREWALL ping loopback
iptables -A OUTPUT -p icmp -d 0/0 -j ACCEPT
iptables -A INPUT -p icmp -d 127.0.0.1 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

### permite que a maquina FIREWALL ping para o resto do mundo
iptables -A INPUT -p icmp -d $WAN1 -j ACCEPT
iptables -A INPUT -p icmp -d $WAN2 -j ACCEPT
iptables -A INPUT -p icmp -d $FW  -j ACCEPT

### permite que a maquina FIREWALL ping para o resto do mundo por nomes
iptables -A INPUT -p udp  --sport 53 -s 0/0 -d $WAN2 --dport $PA -j ACCEPT
iptables -A OUTPUT -p udp  --sport $PA -s $WAN2 -d 0/0 --dport 53 -j ACCEPT

### permite a passagem de pacotes pela porta http 
iptables -A INPUT -p tcp --sport 80 -s 0/0 -d $WAN2 --dport $PA -j ACCEPT
iptables -A OUTPUT -p tcp --sport $PA -s $WAN2 -d 0/0 --dport 80 -j ACCEPT

### permite que a maquina FIREWALL receba conexões remotas por SSH
iptables -A INPUT -p tcp -s 0/0  --sport $PA -d 0/0 --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp -s 0/0 --sport 22 -d 0/0 --dport $PA -j  ACCEPT

### habilita a passagem de pacotes da REDE local em direção ao mundo.
iptables -t nat -I POSTROUTING -o enp0s3 -s $LAN -j MASQUERADE

### habilita a passagem de pings da REDE para o mundo.
iptables -A FORWARD -p icmp -d $LAN -j ACCEPT
iptables -A FORWARD -p icmp -s $LAN -j ACCEPT

### habilita a resolução de nomes do mundo para a REDE.
iptables -A FORWARD -p udp --sport 53  -s 0/0  -d $LAN --dport $PA -j ACCEPT
iptables -A FORWARD -p udp --sport $PA -s $LAN -d 0/0 --dport 53 -j ACCEPT

### habilita a passagem e o uso dos protocolos comuns para as maquinas internas.
for serv_ext in  80 443 587 110 143 993 995 21 20 
do
iptables -A FORWARD -p tcp  --sport $serv_ext -s 0/0 -d $LAN --dport $PA -j ACCEPT
iptables -A FORWARD -p tcp  --sport $PA -s $LAN -d 0/0 --dport $serv_ext -j ACCEPT
done

### habilita a entrada/passagem/saida do NTP para maquina Firewal e maquinas internas
iptables -A INPUT -p udp -s 0/0 --sport 123 -d $WAN2 --dport 123 -j ACCEPT
iptables -A OUTPUT -p udp -s $WAN2 --sport 123 -d 0/0 --dport 123 -j ACCEPT

iptables -A FORWARD -p udp --sport 123 -s 0/0 -d $LAN --dport 123 -j ACCEPT
iptables -A FORWARD -p udp --sport 123 -s $LAN -d 0/0 --dport 123 -j ACCEPT

### habilita o redirecionamento de portas do SSH da maquina Firewall para as maquinas internas.
for ip in 2 3 4 5 6 
do 
iptables -A OUTPUT -p tcp -s 0/0  --sport $PA -d 192.168.200.$ip  --dport 5$ip'000' -j ACCEPT
iptables -A INPUT -p tcp  --sport 5$ip'000' -s 192.168.200.$ip  -d 0/0 --dport $PA -j  ACCEPT
iptables -A FORWARD -p tcp  --sport 5$ip'000' -s 192.168.200.$ip  -d 0/0 --dport $PA -j  ACCEPT
iptables -A FORWARD -p tcp --sport $PA -s 0/0 -d 192.168.200.$ip  --dport 5$ip'000' -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --sport $PA -s 0/0 -d $WAN1 --dport 5$ip'000' -j DNAT --to-destination 192.168.200.$ip':'5$ip'000'
done

iptables -t nat -A POSTROUTING -p tcp -d 0/0 --dport $PA -j MASQUERADE

############ INICIO DAS REGRAS AULA SERVIDOR DE DNS ############ 

### Para que o firewall use a DMZ1 para resolver nomes
iptables -A INPUT -p udp --sport 53 -s $DMZ1 -d $FW --dport $PA -j ACCEPT
iptables -A OUTPUT -p udp --sport $PA -s $FW -d $DMZ1 --dport 53 -j ACCEPT

### Passagem de pacotes do dns interno para o mundo
iptables -A FORWARD -p udp --sport 53 -s $DMZ1  -d 0/0 --dport $PA -j  ACCEPT
iptables -A FORWARD -p udp --sport $PA -s 0/0 -d $DMZ1  --dport 53 -j ACCEPT

### Redirecionamento da porta 53 na maquina Firewall para DMZ1
iptables -t nat -A PREROUTING -p udp --sport $PA -s 0/0 -d $WAN1 --dport 53 -j DNAT --to-destination $DMZ1:53

############ FIM DAS REGRAS AULA SERVIDOR DE DNS ############ 


############ INICIO DAS REGRAS AULA SERVIDOR WEB ############ 

### Liberar no Firewall passagem de pacotes para o servidor WEB
for httpports in  80 443 
do
iptables -A FORWARD -p tcp  --sport $httpports -s $DMZ1 -d 0/0 --dport $PA -j ACCEPT
iptables -A FORWARD -p tcp  --sport $PA -s 0/0 -d $DMZ1 --dport $httpports -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --sport $PA -s 0/0 -d $WAN1 --dport $httpports -j DNAT --to-destination $DMZ1:$httpports
done

############ FIM DAS REGRAS AULA SERVIDOR WEB ############ 


############ INICIO DAS REGRAS AULA FTP ############ 

### Libera no Firewall a passagem de pacotes para o servidor FTP porta 21 
iptables -A FORWARD -p tcp  --sport 21 -s $DMZ1 -d 0/0 --dport $PA -j  ACCEPT
iptables -A FORWARD -p tcp --sport $PA -s 0/0 -d $DMZ1 --dport 21 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --sport $PA -s 0/0 -d $WAN1 --dport 21 -j DNAT --to-destination $DMZ1:21

### Libera no Firewall a passagem de pacotes para o servidor FTP porta 20 
iptables -A FORWARD -p tcp  --sport 20 -s $DMZ1 -d 0/0 --dport 0:65535 -j  ACCEPT
iptables -A FORWARD -p tcp --sport  0:65535 -s 0/0 -d $DMZ1 --dport 20 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --sport 0:65535 -s 0/0 -d $WAN1 --dport 20 -j DNAT --to-destination $DMZ1:20

############ FIM DAS REGRAS AULA FTP ############ 


############ INICIO DAS REGRAS AULA SERVIDOR DE EMAIL ############ 

### Liberar no Firewall passagem de pacotes para o servidor de Email
for mailports in  25 110 143 993 995 
do
iptables -A FORWARD -p tcp  --sport $mailports -s $DMZ1 -d 0/0 --dport $PA -j ACCEPT
iptables -A FORWARD -p tcp  --sport $PA -s 0/0 -d $DMZ1 --dport $mailports -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --sport $PA -s 0/0 -d $WAN1 --dport $mailports -j DNAT --to-destination $DMZ1:$mailports
done

############ FIM DAS REGRAS AULA SERVIDOR DE EMAIL ############ 


############ INICIO DAS REGRAS AULA OPENLDAP ############ 

### permite que a maquina FIREWALL receba pedidos de autenticação no LDAP
iptables -A OUTPUT -p tcp -s 0/0 --sport $PA -d $LAN --dport 389 -j ACCEPT
iptables -A INPUT -p tcp -s $LAN --sport 389 -d 0/0 --dport $PA -j ACCEPT

### permite que a maquina FIREWALL receba conexões no Proxy
iptables -A INPUT -p tcp -s $LAN --sport $PA -d $FW --dport 3128 -j ACCEPT
iptables -A OUTPUT -p tcp -s $FW --sport 3128 -d $LAN --dport $PA -j  ACCEPT

### permite que a maquina FIREWALL faça redirecionamento da porta 80 para 3128
iptables -t nat -A PREROUTING -p tcp -s $LAN --dport 80 -j DNAT --to-destination $FW:3128

############ FIM DAS REGRAS AULA OPENLDAP ############ 


############ INICIO DAS REGRAS AULA OPENVPN ############ 

### permite que a maquina FIREWALL receba conexões VPN
iptables -A INPUT -i tun0 -j ACCEPT
iptables -A OUTPUT -o tun0 -j ACCEPT

iptables -A INPUT -p udp --dport 5000 -j ACCEPT
iptables -A OUTPUT -p udp --sport 5000 -j ACCEPT

iptables -A FORWARD -i eth0 -o tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT

############ FIM DAS REGRAS AULA OPENVPN ############
