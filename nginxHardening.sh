#!/bin/bash

# COLORS
Reset='\033[0m'
Re='\033[0;31m'
Gr='\033[0;32m'
Bl='\033[0;36m'

# PATH TO FILE VARIABLE
PTFILE="/etc/nginx"

# SED SUBSTITUTION FUNCTION
substitution (){
	# FIRST THE FUNCTION LOOK FOR A COINCIDENCE FOR THE SUBSTITUTION ON THE CONFIG FILE, 
	# IF IT DOESN'T FIND ONE, THE FUNCTION ADD THE CONFIGURATION TO THE END OF THE FILE
        if ! (egrep -q \#\?\s\?$1 $PTFILE/nginx.conf); then
                echo -e "$2" &>> $PTFILE/nginx.conf
                echo -e "$Gr \n The $1 line has been added. $Reset" && sleep 1
	# IF IT FINDS A COINCIDENCE INSTEAD OF ADDING IT, THE FUNCTION CHANGE THE ACTUAL
	# CONFIGURATION FOR THE NEW ONE
        else
                sed -i -e "$3 s@#\?\s\?$1\s\?.*@$2@g" $PTFILE/nginx.conf
                echo -e "$Gr \n The $1 line has been updated. $Reset" && sleep 1
        fi
}

# FUNCTION FOR A SIMPLE MESSAGE
message (){
	echo -e "$Bl \n Adding $1 or updating.. $Reset" && sleep 1
}

# CHECK IF SCRIPT IS RUNNING AS ROOT
if [[ "$EUID" -ne 0 ]]; then
        echo -e "$Re Script must be run as user root $Reset"
        exit
fi

# INSTALLATION OF NGINX SERVICE

echo -e "$Bl \n Installing NGINX service $Reset" && sleep 1
apt -y update
apt -y install nginx nginx-extras

# CHECK IF CONFIG FILE EXISTS ON /etc/nginx/nginx.conf PATH
if [[ ! -f /etc/nginx/nginx.conf ]]; then
        echo -e "$Re File not found! $Reset"
        exit
fi

# BACKUP OF FILE nginx.conf FILE
d=$(date +"%Y%m%d")
echo -e "$Bl \n Creating backup file" && sleep 1
cp $PTFILE/nginx.conf $PTFILE/"nginx.conf.bak.$d"
echo -e "$Gr \n Created backup file nginx.conf.bak.$d $Reset" && sleep 1

# DISABLE WEAK CIPHER SUITES

echo -e "$Bl \n Disabling weak cipher suites" && sleep 1

CIPH='"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA HIGH !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS";'

awk '/ssl_prefer/ { print; print "\tssl_ciphers CIPHER"; next }1' $PTFILE/nginx.conf > $PTFILE/nginx.conf.tmp && mv $PTFILE/nginx.conf.tmp $PTFILE/nginx.conf

substitution "CIPHER" " $CIPH"

# SERVER TOKENS

message "server_tokens"
substitution "server_tokens" "server_tokens off;"

# DISABLE UNWANTED HTTP METHODS

echo -e "$Bl \n Disabling unwanted HTTP Methods" && sleep 1

touch /etc/nginx/conf.d/default.conf

tee -a /etc/nginx/conf.d/default.conf << END
server{
	if (\$request_method !~ ^(GET|HEAD|POST)$ )
	{
      		return 405;
	}
}
END

echo -e "$Gr \n HTTP methods successfuly disabled" && sleep 1

# CLICKJACKING ATTACK

echo -e "$Bl \n Adding prevention of clickJacking attack and X-XSS Protection" && sleep 1

awk '/sites-enabled/ { print; print ""; print "\t##"; print "\t# Custom conf"; print "\t##"; print ""; print "\tadd_header X-Frame-Options \"SAMEORIGIN\";"; print "add_header X-XSS-Protection \"1; mode=block\";";  next }1' $PTFILE/nginx.conf > $PTFILE/nginx.conf.bak && mv $PTFILE/nginx.conf.bak $PTFILE/nginx.conf

echo -e "$Gr \n Prevention of clickJacking and X-XSS Protection added successfuly" && sleep 1
