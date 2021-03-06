#!/bin/bash
#

#Initialisation de la variables designant l'interface reseau
export IF_RESEAU="wlan0"

#On efface toutes les regles existantes
sudo iptables -F

#On supprime d'eventuelles regles personnelles
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t nat -P PREROUTING ACCEPT
sudo iptables -t nat -P POSTROUTING ACCEPT
sudo iptables -t nat -P OUTPUT ACCEPT
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -t mangle -P PREROUTING ACCEPT
sudo iptables -t mangle -P OUTPUT ACCEPT

#Mise en place des regles par defaut (on refuse tout par default)
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP

#On accepte les connexions sur la boucle locale (sur lo == 127.0.0.1 modifié si sa change)
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

#On accepte les connexions depuis le LAN (192.168.0 & 192.168.1 modifié si sa change)
sudo iptables -A INPUT -s 192.168.0.0/24 -j ACCEPT
sudo iptables -A OUTPUT -d 192.168.0.0/24 -j ACCEPT
sudo iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A OUTPUT -d 192.168.1.0/24 -j ACCEPT

#On refuse certaines requetes 
sudo iptables -N SCANS
sudo iptables -A SCANS -p tcp --tcp-flags FIN,URG,PSH FIN,URG,PSH -j DROP
sudo iptables -A SCANS -p tcp --tcp-flags ALL ALL -j DROP
sudo iptables -A SCANS -p tcp --tcp-flags ALL NONE -j DROP
sudo iptables -A SCANS -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
sudo iptables -A INPUT -p udp --dport 33434:33523 -j DROP
sudo iptables -A OUTPUT -p tcp --dport telnet -j DROP

#Rejet des paquets bizarres ou mal formés
sudo iptables -A INPUT -m state --state INVALID -j DROP
sudo iptables -A FORWARD -m state --state INVALID -j DROP



#On autorise les connexion sur les port pour odoo
sudo iptables -A INPUT -p tcp -m tcp --sport 8069 -j ACCEPT
sudo iptables -A OUTPUT -p tcp -m tcp --dport 8069 -j ACCEPT

#On autorise les connexion sur les port pour le serveur mail
#sudo iptables -A INPUT -p tcp -m tcp --sport 8070 -j ACCEPT
#sudo iptables -A OUTPUT -p tcp -m tcp --dport 8070 -j ACCEPT

#On autorise les connexion sur les port pour nextclood
#sudo iptables -A INPUT -p tcp -m tcp --sport 8071 -j ACCEPT
#sudo iptables -A OUTPUT -p tcp -m tcp --dport 8071 -j ACCEPT

#On autorise les connexion sur les port pour ClamAV
#sudo iptables -A INPUT -p tcp -m tcp --sport 8072 -j ACCEPT
#sudo iptables -A OUTPUT -p tcp -m tcp --dport 8072 -j ACCEPT





#Flood TCP&UDP
#sudo iptables -A INPUT -i $IF_RESEAU -p tcp --syn -m limit --limit 3/s -j ACCEPT
#sudo iptables -A INPUT -i $IF_RESEAU -p udp -m limit --limit 10/s -j ACCEPT
#sudo iptables -A INPUT -i $IF_RESEAU -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
#sudo iptables -A INPUT -i $IF_RESEAU -p icmp --icmp-type echo-reply -m limit --limit 1/s -j ACCEPT

#Transfert IP et Masquerad
#echo 1 > /proc/sys/net/ipv4/ip_forward
#echo 0 > /proc/sys/net/ipv4/ip_forward

# Si 3 connexions SSH en 1 minute -> drop
sudo iptables -I INPUT -p tcp --dport 2222 -i $IF_RESEAU -m state --state NEW -m recent --set
sudo iptables -I INPUT -p tcp --dport 2222 -i $IF_RESEAU -m state --state NEW -m recent --update --seconds 60 --hitcount 3 -j DROP

# Ecriture de la politique de log
# Ici on affiche [IPTABLES DROP] dans /var/log/message a chaque paquet rejette par iptables
sudo iptables -N LOG_DROP
sudo iptables -A LOG_DROP -j LOG --log-level 1 --log-prefix '[IPTABLES DROP]:'
sudo iptables -A LOG_DROP -j DROP

# On met en place les logs en entree, sortie et routage selon la politique LOG_DROP ecrit avant
sudo iptables -A FORWARD -j LOG_DROP
sudo iptables -A INPUT -j LOG_DROP
sudo iptables -A OUTPUT -j LOG_DROP

# Nous vidons les chaines predefinies :
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F

# Nous supprimons les regles des chaines personnelles :
sudo iptables -X 
sudo iptables -t nat -X
sudo iptables -t mangle -X

# Nous les faisons pointer par déut sur DROP
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT DROP
sudo iptables -P FORWARD DROP

#Autorise les rénses
#iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# On autorise le ping
sudo iptables -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p icmp -m limit --limit 5/s -j ACCEPT

#(Facultatif : autoriser l'accés au serveur sdepuis l'extérieur)
sudo iptables -A INPUT -p TCP --dport ssh -i eth0 -j ACCEPT
sudo iptables -A INPUT -p TCP --dport http -i eth0 -j ACCEPT
sudo iptables -A INPUT -p TCP --dport 64738 -i eth0 -j ACCEPT
sudo iptables -A INPUT -p UDP --dport 64738 -i eth0 -j ACCEPT

#anti scan
sudo iptables -A INPUT -i eth0 -p tcp --tcp-flags FIN,URG,PSH FIN,URG,PSH -j DROP
sudo iptables -A INPUT -i eth0 -p tcp --tcp-flags ALL ALL -j DROP
sudo iptables -A INPUT -i eth0 -p tcp --tcp-flags ALL NONE -j DROP
sudo iptables -A INPUT -i eth0 -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
sudo iptables -A INPUT -i eth0 -p tcp --tcp-flags SYN,ACK,FIN,RST RST -j DROP

#S'assure les NOUVELLES connexions TCP entrantes sont des paquets SYN
sudo iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

#Packets with incoming fragments
sudo iptables -A INPUT -f -j DROP

#incoming malformed XMAS packets
sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

#Incoming malformed NULL packets
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

#serveur DNS
#iptables -A INPUT --protocol udp --source-port 53 -j ACCEPT
#iptables -A OUTPUT --protocol udp --destination-port 53 -j ACCEPT

#Sortie web
sudo iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

#Autoriser sortie FTP
#iptables -A OUTPUT -p tcp --dport 21 -j ACCEPT
#iptables -A OUTPUT -p tcp --dport 20 -j ACCEPT

#Permettre le trafic entrant et sortant pour le port SSH, cad le port 22
sudo iptables -t filter -A INPUT -p tcp --dport 22 -j LOGACCEPT #-i eth0
sudo iptables -t filter -A OUTPUT -p tcp --dport 22 -j ACCEPT
echo "ssh ok"

#Permettre le trafic entrant pour un éventuel serveur openVpn, cad le port 1194
#iptables -t filter -A INPUT -p udp --dport 1194 -j LOGACCEPT
#echo "OpenVpn ok"

#Pour éventuellement autoriser les ping en entrée, dé-commentez ces lignes
#iptables -t filter -A INPUT -p icmp -j LOGACCEPT

#Autoriser le ping en sortie
sudo iptables -t filter -A OUTPUT -p icmp -j ACCEPT
echo "ping en sortie ok"

#Autoriser les requètes DNS en sortie
sudo iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
echo "dns ok"

#Pour éventuellement autoriser les requêtes DNS en entrée, dé-commentez ces lignes
#iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
#iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT

#Autoriser les requêtes NTP en sortie pour pouvoir se synchroniser ai niveau temps
#iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT
#echo "ntp ok"

#Autoriser tout le trafic en entrée depuis le réseau local qui commencera ici par une ip en 192.168
#iptables -t filter -A INPUT -s 192.168.0.0/16 -j ACCEPT
#echo "reseau local ok"

# On accepte la sortie de certains protocoles
#sudo iptables -A OUTPUT -o $IF_RESEAU -p UDP --dport 123 -j ACCEPT		# Port 123  (Time ntp udp)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 123 -j ACCEPT		# Port 123  (Time ntp tcp)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p UDP --dport domain -j ACCEPT		# Port 53   (DNS)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport domain -j ACCEPT		# Port 53   (DNS)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport http -j ACCEPT		# Port 80   (Http)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport https -j ACCEPT		# Port 443  (Https)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport pop3 -j ACCEPT		# Port 110  (Pop3)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 993 -j ACCEPT		# Port 993  (auth.SSL)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 995 -j ACCEPT		# Port 995  (auth.SSL)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport smtp -j ACCEPT		# Port 25   (Smtp)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport ftp-data -j ACCEPT	# Port 20   (Ftp Data)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport ftp -j ACCEPT		# Port 21   (Ftp)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 2222 -j ACCEPT		# Port #2222   (Ssh)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 10000 -j ACCEPT		# Port 10000   (webmin)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 445 -j ACCEPT        	# Port 445  (Samba)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 139 -j ACCEPT        	# Port 139  (Samba)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p UDP --dport 137:138 -j ACCEPT    	# Port 137 a 138 (Samba)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport nntp -j ACCEPT		# Port 119  (News groups)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 1863 -j ACCEPT		# Port 1863 (Msn messenger)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 5222 -j ACCEPT		# Port 1863 (Msn Pidgin)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 6881:6889 -j ACCEPT	# Port 6881 a 6889 (Bittorrent)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 4662:4662 -j ACCEPT	# Port 4662 a 4662 (Amule&Azureus)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p UDP --dport 4672:4672 -j ACCEPT	# Port 4662 a 4662 (Amule&Azureus)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p UDP --dport 5000 -j ACCEPT		# Port 4662 a 4662 (Amule)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 46021:46021 -j ACCEPT	# Port 46021 (Azureus)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 8000 -j ACCEPT		# Port 8000&9000 (Amarok)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 9000 -j ACCEPT		# Port 8000&9000 (Amarok)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p TCP --dport 32100:32101 -j ACCEPT	# Port 32100&32101 (VLC)
#sudo iptables -A OUTPUT -o $IF_RESEAU -p UDP --dport 32100:32101 -j ACCEPT	# Port 32100&32101 (VLC)

#On autorise les connexions deja etablies ou relatives à  une autre connexion a sortir
sudo iptables -A OUTPUT -o $IF_RESEAU --match state --state ESTABLISHED,RELATED -j ACCEPT

#On autorise les connexions deja etablies a entrer
sudo iptables -A INPUT  -i $IF_RESEAU --match state --state ESTABLISHED,RELATED -j ACCEPT

#On autorise le serveur a faire des ping sur des IP exterieur
sudo iptables -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

#On interdit les pings 
#sudo iptables -A INPUT -p icmp -j DROP

#On peut aller plus finement en gérant le type de réponse icmp.
#iptables -A INPUT -i $IF_RESEAU -p icmp --icmp-type destination-unreachable -j DROP
#iptables -A INPUT -i $IF_RESEAU -p icmp --icmp-type echo-reply -j DROP
#iptables -A INPUT -i $IF_RESEAU -p icmp --icmp-type echo-request -j DROP
#iptables -A INPUT -i $IF_RESEAU -p icmp --icmp-type time-exceeded -j DROP
#iptables -A INPUT -i $IF_RESEAU -p icmp --icmp-type source-quench -j DROP


#iptables -t filter -A OUTPUT -p udp --dport 161 -j ACCEPT
#iptables -t filter -A INPUT -p udp --dport 161 -j ACCEPT

#Regles de secu
#iptables -A INPUT -p all -j DROP
#iptables -A OUTPUT -p all -j DROP
#iptables -A FORWARD -p all -j DROP

###///////////////////////////###
#on quitte le script
exit
