#!/bin/bash

PATH='/sbin'

### politicas que aceitam qualquer tipo de conexão
iptables -P OUTPUT ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT

### limpar as regras das tabelas nat e filter 
iptables -t nat -F
iptables -t filter -F
