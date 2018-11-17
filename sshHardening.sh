#!/bin/bash

# COLORS
Reset='\033[0m'
Re='\033[0;31m'
Gr='\033[0;32m'
Bl='\033[0;36m'

# PATH TO FILE VARIABLE
PTFILE="/etc/ssh"

# SED SUBSTITUTION FUNCTION
substitution (){
	# FIRST THE FUNCTION LOOK FOR A COINCIDENCE FOR THE SUBSTITUTION ON THE CONFIG FILE, 
	# IF IT DOESN'T FIND ONE, THE FUNCTION ADD THE CONFIGURATION TO THE END OF THE FILE
        if ! (egrep -q ^#\?\s\?$1 $PTFILE/sshd_config); then
                echo -e "$2" &>> $PTFILE/sshd_config
                echo -e "$Gr \n The $1 line has been added. $Reset" && sleep 1
	# IF IT FINDS A COINCIDENCE INSTEAD OF ADDING IT, THE FUNCTION CHANGE THE ACTUAL
	# CONFIGURATION FOR THE NEW ONE
        else
                sed -i -e "$3 s@^#\s\?$1\s\?.*@$2@g" $PTFILE/sshd_config
                echo -e "$Gr \n The $1 line has been updated. $Reset" && sleep 1
        fi
}

# FUNCTION FOR A SIMPLE MESSAGE
message (){
	echo -e "$Bl \n -------Adding $1 or updating------- $Reset" && sleep 1
}

# CHECK IF SCRIPT IS RUNNING AS ROOT
if [[ "$EUID" -ne 0 ]]; then
        echo -e "$Re Script must be run as user root $Reset"
        exit
fi

# CHECK IF CONFIG FILE EXISTS ON /etc/ssh/sshd_config PATH
if [[ ! -f /etc/ssh/sshd_config ]]; then
        echo -e "$Re File not found! $Reset"
        exit
fi

# BACKUP OF FILE sshd_config FILE
d=$(date +"%Y%m%d")
echo -e "$Bl \n Creating backup file" && sleep 1
cp $PTFILE/sshd_config $PTFILE/"sshd_config.bak.$d"
echo -e "$Gr \n Created backup file sshd_config.bak.$d $Reset" && sleep 1

# COMMENT EVERY LINE
echo -e "$Bl \n All lines will be commented,\n NOTE. A backup file has been\n created in the route :$PTFILE/sshd_config.bak.$d. $Reset" && sleep 1
sed -i -e "/#/! s/^/#/g" $PTFILE/sshd_config

# CHANGING PORT OF SSH
echo -e "$Bl \n Changing Port of SSH.. $Reset" && sleep 1
# THE NETSTAT COMMAND IS RUN FIRST TO KNOW IF THE PORT 30001 IS IN USE
netstat -plnt | grep -q :30001
if [ $? -eq 0 ]; then
	# IF THE PORT IS IN USE THE SCRIPT WILL EXIT WITH A MESSAGE OF PORT IN USE
        echo -e "$Re \n The port is being used. $Reset"
        exit
else
	# IF THE PORT IS NOT IN USE THE FUNCTION WILL PROCEED TO CHANGE IT FOR 30001
        sed -i -e 's/^#\s\?Port\s\?[0-9]\+/Port 30001/g' $PTFILE/sshd_config
        echo -e "$Gr \n The port has changed to 30001. $Reset" && sleep 1
fi

# IPTABLES RULES
# A RULE ACCEPTING CONNECTION TO PORT 30001 IS ADDED ON IPTABLES FIREWALL
echo -e "$Bl \n Adding rules to iptables.. $Reset" && sleep 1
iptables -A INPUT -p tcp --dport 30001 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -p tcp --sport 30001 -m conntrack --ctstate ESTABLISHED -j ACCEPT
echo -e "$Bl \n Rules added $Reset"

# KEY PAIRS GENERATION
# USER RUNNING SCRIPT VARIABLE
#USERRS= "sudo sh -c 'echo $SUDO_USER'"
echo | sudo -Hu $SUDO_USER ssh-keygen -t rsa -b 2048 -q -N ""
chmod 700 ~/.ssh
# THE SCRIPT LOOK FOR authorized_keys FILE IF IT DOESN'T FIND ONE, IT IS CREATED
if [[ ! -f /home/$SUDO_USER/.ssh/authorized_keys ]]; then
        sudo -Hu $SUDO_USER touch /home/$SUDO_USER/.ssh/authorized_keys
	echo -e "$Bl \n authorized_keys file created at /home/$SUDO_USER/.ssh/authorized_keys $Reset" && sleep 1
else
# IF IT FOUND A FILE IT WILL CREATE A BACKUP AND THEN PROCEED TO CLEAN IT
	cp /home/$SUDO_USER/.ssh/authorized_keys /home/$SUDO_USER/.ssh/authorized_keys.bak
	> /home/$SUDO_USER/.ssh/authorized_keys
	echo -e "$Bl \n Cleaned authorized_keys file $Reset" && sleep 1
	echo -e "$Bl \n A backup of the file has been created on /home/$SUDO_USER/.ssh/authorized_keys.bak $Reset" && sleep 1
fi
chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
echo -e "$Bl \n Public key has been added to authorized_keys $Reset" && sleep 1

# PROTOCOL
message "          Protocol          "

substitution "Protocol" "Protocol 2"

# PUBKEYAUTHENTICATION
message "    PubkeyAuthentication    "

substitution "PubkeyAuthentication" "PubkeyAuthentication yes"

# AUTHORIZEDKEYSFILE
message "     AuthorizedKeysFile     "

substitution "AuthorizedKeysFile" "AuthorizedKeysFile .ssh/authorized_keys"

# PASSWORDAUTHENTICATION
message "   PasswordAuthentication   "

substitution "PasswordAuthentication" "PasswordAuthentication no" "/PAM/!"

# USE OF PAM
message "            PAM             "

substitution "UsePAM" "UsePAM no"

# MAXSESSIONS
message "        MaxSessions         "

substitution "MaxSessions" "MaxSessions 2"

# X11FORWARDING
message "       X11Forwarding        "

substitution "X11Forwarding" "X11Forwarding no"

# PERMITROOTLOGIN
message "      PermitRootLogin       "

substitution "PermitRootLogin" "PermitRootLogin no"

# ALLOWTCPFORWARDING
message "     AllowTcpForwarding     "

substitution "AllowTcpForwarding" "AllowTcpForwarding no"

# CLIENTALIVE INTERVAL & COUNTMAX
message "ClientAliveInterval/CountMax"

substitution "ClientAliveInterval" "ClientAliveInterval 2"

substitution "ClientAliveCountMax" "ClientAliveCountMax 2"

# COMPRESSION"
message "        Compression         "

substitution "Compression" "Compression no"

# LOGLEVEL
message "          LogLevel          "

substitution "LogLevel" "LogLevel VERBOSE"

# ALLOWAGENTFORWARDING
message "    AllowAgentForwarding    "

substitution "AllowAgentForwarding" "AllowAgentForwarding no"

# MAXAUTHTRIES
message "        MaxAuthTries        "

substitution "MaxAuthTries" "MaxAuthTries 2"

# TCPKEEPALIVE
message "        TCPKeepAlive        "

substitution "TCPKeepAlive" "TCPKeepAlive no"

# ALLOW USERS
#message "List of allowed users"

#substitution "AllowUsers" "AllowUsers "

# FAIL2BAN CONFIGURATION

apt update

echo -e "$Bl \n Installing Fail2ban $Reset" && sleep 1
ls /etc/init.d/ | grep -q fail2ban
if [ $? -eq 0 ]; then
        echo -e "fail2ban is already installed"
else
        apt install -y fail2ban
fi

# ONCE INSTALLED IT IS CREATED A COPY OF THE CONFIGURATION FILE
JAILLPATH="/etc/fail2ban/jail.local"
echo -e "$Bl \n Creating jail.local file $Reset" && sleep 1
if [[ ! -f /etc/fail2ban/jail.local ]]; then
	touch $JAILLPATH
#	cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
else
	echo "$Re \n There's already a local file on /etc/fail2ban/ path, creating backup $Reset"
	cp $JAILLPATH $JAILLPATH.bak

fi

echo -e "$Bl \n enabling ssh on fail2ban $Reset" && sleep 1
#sed -i -e '/^\[sshd\]/a \\nenabled = true' /etc/fail2ban/jail.local
#sed -i -e 's/^port\s\+=\s\+ssh/port = 30001/g' /etc/fail2ban/jail.local
#echo -e "[sshd]" &>> /etc/fail2ban/jail.local

tee -a $JAILLPATH << END
[sshd]
enabled = true
banaction = iptables-multiport
maxretry = 3
findtime = 43200
bantime = 86400
END

echo -e "$Bl \n restarting fail2ban $Reset" && sleep 1
/etc/init.d/fail2ban restart

# HOSTKEY PREFERENCE

message "HostKey"

substitution "HostKey /etc/ssh/ssh_host_ed25519_key" "HostKey /etc/ssh/ssh_host_ed25519_key"
substitution "HostKey /etc/ssh/ssh_host_rsa_key" "HostKey /etc/ssh/ssh_host_rsa_key"

# CIPHERS AND ALGHORITMS

message "Ciphers and alghorithms"

substitution "KexAlgorithms" "KexAlgorithms curve25519-sha256@libssh.org"
substitution "Ciphers" "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
substitution "MACs" "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com"

# REGENERATE MODULI

#echo -e "$Bl \n Regenerating MODULI \n This can take a few minutes.. $Reset" && sleep 1

#ssh-keygen -G moduli-2048.candidates -b 2048
#ssh-keygen -T moduli-2048 -f moduli-2048.candidates
#cp moduli-2048 /etc/ssh/moduli
#rm moduli-2048
