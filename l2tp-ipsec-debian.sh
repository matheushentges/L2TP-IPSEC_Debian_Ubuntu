#!/bin/bash
# Requirements
# debian/ubuntu

apt-get -y update
apt-get -y install strongswan xl2tpd libstrongswan-standard-plugins libstrongswan-extra-plugins

VPN_SERVER_IP=$(whiptail --title "IP DO SERVIDOR" --inputbox "Digite o IP do server da sua VPN" --fb 10 60 3>&1 1>&2 2>&3);
VPN_IPSEC_PSK=$(whiptail --title "IPSEC_PSK" --inputbox "Digite a sua senha IPSEC-PSK" --fb 10 60 3>&1 1>&2 2>&3);
VPN_USER=$(whiptail --title "Usuario" --inputbox "Digite o seu usuario da VPN" --fb 10 60 3>&1 1>&2 2>&3);
VPN_PASSWORD=$(whiptail --title "Password" --inputbox "Digite a senha do seu usuario da VPN" --fb 10 60 3>&1 1>&2 2>&3);

cat > /etc/ipsec.conf <<EOF
config setup
conn VPN1
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  keyexchange=ikev1
  authby=secret
  ike=aes128-sha1-modp2048!
  esp=aes128-sha1-modp2048!
conn VPN1
  keyexchange=ikev1
  left=%defaultroute
  auto=add
  authby=secret
  type=transport
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_SERVER_IP
EOF

cat > /etc/ipsec.secrets <<EOF
$VPN_SERVER_IP : PSK "$VPN_IPSEC_PSK"
EOF

chmod 600 /etc/ipsec.secrets

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac VPN1]
lns = $VPN_SERVER_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
mtu 1280
mru 1280
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name $VPN_USER
password $VPN_PASSWORD
EOF

chmod 600 /etc/ppp/options.l2tpd.client

service strongswan restart
service xl2tpd restart

cat > /usr/local/bin/start-vpn <<EOF
#!/bin/bash
(service strongswan start ;
sleep 2 ;
service xl2tpd start) && (
ipsec up VPN1
echo "c VPN1" > /var/run/xl2tpd/l2tp-control
sleep 5
#ip route add 10.0.0.0/24 dev ppp0
)
EOF
chmod +x /usr/local/bin/start-vpn

cat > /usr/local/bin/stop-vpn <<EOF
#!/bin/bash
(echo "d myvpn" > /var/run/xl2tpd/l2tp-control
ipsec down myvpn) && (
service xl2tpd stop ;
service strongswan stop)
EOF
chmod +x /usr/local/bin/stop-vpn

echo "Para iniciar sua VPN digite: start-vpn"
echo "Para parar sua VPN digite: stop-vpn"
