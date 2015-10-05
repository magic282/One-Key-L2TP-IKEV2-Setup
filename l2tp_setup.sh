#! /bin/sh
#===============================================================================================
#   System Required:  Debian or Ubuntu
#   Description:  Install L2TP for Debian or Ubuntu
#===============================================================================================


echo "#######################################################"
echo "L2TP service for Debian"
echo
echo "Easy to install & add new account."
echo "only tested on Debian 7 x64/x32 and Debian 8 64."
echo "PS:Please make sure you are using root account."
echo "#######################################################"
echo
echo
echo "#################################"
echo "What do you want to do:"
echo "1) Install l2tp"
echo "2) Add an account"
echo "#################################"

read x
if test $x -eq 1; then
    echo "Please set the secretkey(Pre Shared Key):"
    read k

    echo
    echo "##################"
    echo "What type is your VPS?"
    echo "1) OpenVZ"
    echo "2) others"
    echo "##################"
    read v
    
    insPath=/root/l2tpInstall
    mkdir -p $insPath
    # Get ip address
    IP=`ifconfig | grep 'inet addr:'| grep -v '127.0.0.*' | cut -d: -f2 | awk '{ print $1}' | head -1`;

    echo
    echo "##################################"
    echo "Downloading the component"
    echo "##################################"
    apt-get update
    apt-get install libpam0g-dev libssl-dev make gcc
    
    ipsecConf=
    strongswanConf=
    ipsecSecrets=
    ipsecD=
    isInApt="$(apt-cache search strongswan | wc -l)"
    isInApt=0 # I don't know why the strongswan from apt repo does not work here T_T
    if test $isInApt -gt 0; then
	echo "#################################"
	echo "Strongswan is found in apt source."
	echo "#################################"
	apt-get install strongswan
	ipsecConf=/etc/ipsec.conf
	strongswanConf=/etc/strongswan.conf
	ipsecSecrets=/etc/ipsec.secrets
	ipsecD=/etc/ipsec.d
    else
	echo "#################################"
	echo "Install Strongswan from source."	
	echo "#################################"
	ipsecConf=/usr/local/etc/ipsec.conf
	strongswanConf=/usr/local/etc/strongswan.conf
	ipsecSecrets=/usr/local/etc/ipsec.secrets
	ipsecD=/usr/local/etc/ipsec.d
	cd /tmp
	wget https://download.strongswan.org/strongswan-5.2.2.tar.gz
        tar xzf strongswan*.tar.gz
	cd strongswan-*


	if test $v -eq 1; then
	    ./configure  --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 --enable-eap-tls --enable-eap-ttls --enable-eap-peap  --enable-eap-tnc --enable-eap-dynamic --enable-eap-radius --enable-xauth-eap --enable-xauth-pam  --enable-dhcp  --enable-openssl  --enable-addrblock --enable-unity --enable-certexpire --enable-radattr --enable-tools --enable-openssl --disable-gmp --enable-kernel-libipsec
	elif test $v -eq 2; then
	    ./configure  --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 --enable-eap-tls --enable-eap-ttls --enable-eap-peap --enable-eap-tnc --enable-eap-dynamic --enable-eap-radius --enable-xauth-eap --enable-xauth-pam  --enable-dhcp  --enable-openssl  --enable-addrblock --enable-unity --enable-certexpire --enable-radattr --enable-tools --enable-openssl --disable-gmp
	fi
	
	make && make install
    fi
    
    ipsec version

    if test $? -ne 0; then
	echo "ipsec install failed. Please check the log."
	echo "Error."
	exit
    fi

    echo
    echo "##################"
    echo "Generating certs"
    echo "##################"


    cd /root/l2tpInstall
    ipsec pki --gen --outform pem > ca.pem
    ipsec pki --self --in ca.pem --dn "C=com, O=myvpn, CN=$IP VPN CA" --ca --outform pem >ca.cert.pem
    ipsec pki --gen --outform pem > server.pem
    ipsec pki --pub --in server.pem | ipsec pki --issue --cacert ca.cert.pem --cakey ca.pem --dn "C=com, O=myvpn, CN=$IP" --san="$IP" --flag serverAuth --flag ikeIntermediate --outform pem > server.cert.pem
    ipsec pki --gen --outform pem > client.pem
    ipsec pki --pub --in client.pem | ipsec pki --issue --cacert ca.cert.pem --cakey ca.pem --dn "C=com, O=myvpn, CN=$IP VPN Client" --outform pem > client.cert.pem
    echo
    echo "##################"
    echo "Please set a password to export the key"
    echo "##################"
    openssl pkcs12 -export -inkey client.pem -in client.cert.pem -name "client" -certfile ca.cert.pem -caname "$IP VPN CA"  -out client.cert.p12

    cp -r ca.cert.pem $ipsecD/cacerts/
    cp -r server.cert.pem $ipsecD/certs/
    cp -r server.pem $ipsecD/private/
    cp -r client.cert.pem $ipsecD/certs/
    cp -r client.pem  $ipsecD/private/


    echo
    echo "##################"
    echo "Set up IPsec"
    echo "##################"
    mv $ipsecConf $ipsecConf.bac 2>/dev/null
    cat > $ipsecConf  <<END
config setup
    uniqueids=never 

conn iOS_cert
    keyexchange=ikev1
    # strongswan version >= 5.0.2, compatible with iOS 6.0,6.0.1
    fragmentation=yes
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn android_xauth_psk
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    leftsubnet=0.0.0.0/0
    right=%any
    rightauth=psk
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    auto=add

conn networkmanager-strongswan
    keyexchange=ikev2
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn windows7
    keyexchange=ikev2
    ike=aes256-sha1-modp1024! 
    rekey=no
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    auto=add
END

    echo
    echo "##################"
    echo "Set up Strongswan"
    echo "##################"

    mv $strongswanConf $strongswanConf.bac 2>/dev/null
    cat > $strongswanConf <<END
charon {
    load_modular = yes
    duplicheck.enable = no
    compress = yes
    plugins {
        include strongswan.d/charon/*.conf
    }
    dns1 = 8.8.8.8
    dns2 = 8.8.4.4
    nbns1 = 8.8.8.8
    nbns2 = 8.8.4.4
}
include strongswan.d/*.conf
END

    echo
    echo "##################"
    echo "Set up PSK"
    echo "##################"

    mv $ipsecSecrets $ipsecSecrets.bac 2>/dev/null
    cat > $ipsecSecrets <<END
: RSA server.pem
: PSK "$k"
: XAUTH "$k"
END

    echo
    echo "################################"
    echo "Set up forwarding and firewall"
    echo "################################"

    echo "echo 1 > /proc/sys/net/ipv4/ip_forward" >> /etc/init.d/rc.local
    echo "/usr/local/sbin/ipsec start" >> /etc/init.d/rc.local
    netCard=
    if test $v -eq 1; then
	netCard=venet0
    elif test $v -eq 2; then
	netCard=eth0
    fi

    iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -s 10.31.0.0/24  -j ACCEPT
    iptables -A FORWARD -s 10.31.1.0/24  -j ACCEPT
    iptables -A FORWARD -s 10.31.2.0/24  -j ACCEPT
    iptables -A INPUT -i $netCard -p esp -j ACCEPT
    iptables -A INPUT -i $netCard -p udp --dport 500 -j ACCEPT
    iptables -A INPUT -i $netCard -p tcp --dport 500 -j ACCEPT
    iptables -A INPUT -i $netCard -p udp --dport 4500 -j ACCEPT
    iptables -A INPUT -i $netCard -p udp --dport 1701 -j ACCEPT
    iptables -A INPUT -i $netCard -p tcp --dport 1723 -j ACCEPT
    iptables -A FORWARD -j REJECT
    iptables -t nat -A POSTROUTING -s 10.31.0.0/24 -o $netCard -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 10.31.1.0/24 -o $netCard -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 10.31.2.0/24 -o $netCard -j MASQUERADE
    
    iptables --table nat --append POSTROUTING --jump MASQUERADE

    iptables-save > /etc/iptables.rules
    cat > /etc/network/if-up.d/iptables<<EOF
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF
    chmod +x /etc/network/if-up.d/iptables

    echo
    echo "################################################"
    echo "Success!"
    echo "Use this to connect your L2TP service."
    echo "IP: $IP"
    echo "Secretkey: $k"
    echo "CA cert: /root/l2tpInstall/ca.cert.pem"
    echo "Don't forget to add a new user later, LOL."
    echo "################################################"

    # if choose 2:
elif test $x -eq 2; then
    echo "Please input an new username:"
    read u
    echo "Please input the password:"
    read p

    ipsecConf=
    strongswanConf=
    ipsecSecrets=
    ipsecD=
    isInApt="$(apt-cache search strongswan | wc -l)"
    isInApt=0
    if test $isInApt -gt 0; then
	ipsecConf=/etc/ipsec.conf
        strongswanConf=/etc/strongswan.conf
        ipsecSecrets=/etc/ipsec.secrets
	ipsecD=/etc/ipsec.d
    else
        ipsecConf=/usr/local/etc/ipsec.conf
        strongswanConf=/usr/local/etc/strongswan.conf
        ipsecSecrets=/usr/local/etc/ipsec.secrets
	ipsecD=/usr/local/etc/ipsec.d
    fi


    # Add an new account
    echo "$u %any : EAP \"$p\"" >> $ipsecSecrets

    echo
    echo "##############"
    echo "Success!"
    echo "##############"

else
    echo "Error."
    exit
fi
