#!/bin/bash

# COLORS
Reset='\033[0m'
Re='\033[0;31m'
Gr='\033[0;32m'
Bl='\033[0;36m'

# PATH TO FILE VARIABLE
PTFILE="/etc/apache2/"

# SED SUBSTITUTION FUNCTION
substitution (){
	# FIRST THE FUNCTION LOOK FOR A COINCIDENCE FOR THE SUBSTITUTION ON THE CONFIG FILE, 
	# IF IT DOESN'T FIND ONE, THE FUNCTION ADD THE CONFIGURATION TO THE END OF THE FILE
        if ! (egrep -q ^#\?\s\?$1 $PTFILE/apache2.conf); then
                echo -e "$2" &>> $PTFILE/apache2.conf
                echo -e "$Gr \n The $1 line has been added. $Reset" && sleep 1
	# IF IT FINDS A COINCIDENCE INSTEAD OF ADDING IT, THE FUNCTION CHANGE THE ACTUAL
	# CONFIGURATION FOR THE NEW ONE
        else
                sed -i -e "$3 s@^#\?\s\?$1\s\?.*@$2@g" $PTFILE/apache2.conf
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

# INSTALLING APACHE2

echo -e "$Bl \n Installing apache2 service" && sleep 1
apt -y update
apt -y install apache2

# CHECK IF CONFIG FILE EXISTS ON /etc/apache2/apache2.conf PATH
if [[ ! -f /etc/apache2/apache2.conf ]]; then
        echo -e "$Re File not found! $Reset"
        exit
fi

# BACKUP OF FILE apache2.conf FILE
d=$(date +"%Y%m%d")
echo -e "$Bl \n Creating backup file" && sleep 1
cp $PTFILE/apache2.conf $PTFILE/"apache2.conf.bak.$d"
echo -e "$Gr \n Created backup file apache2.conf.bak.$d $Reset" && sleep 1

# REMOVE SERVER VERSION BANNER
message "Server Tokens"
# SERVER TOKENS WILL CHANGE HEADER TO PRODUCTION ONLY, I.E. APACHE
substitution "ServerTokens" "ServerTokens Prod"

message "Server Signature"
# SERVER SIGNATURE WILL REMOVE THE VERSION INFORMATION FROM THE PAGE GENERATED BY APACHE WEB SERVER
substitution "ServerSignature" "ServerSignature Off"

# DISABLE DIRECTORY BROWSER LISTING
message "Browser Listing"
# DISABLE DIRECTORY LISTING IN A BROWSER
sed -i 's,'$(awk '/<Directory \/var\/www\//{getline; print  $2}' $PTFILE/apache2.conf)',-Indexes -Includes,' $PTFILE/apache2.conf
sed -i 's,'$(awk '/<Directory \/var\/www\//{getline; print  $4}' $PTFILE/apache2.conf)',+FollowSymLinks,' $PTFILE/apache2.conf

# ETAG
message "ETag"
# PREVENTS VULNERAVILITIES THROUGH ETAG HEADER
substitution "FileETag" "FileETag None"

# RUN APACHE FROM NON-PRIVILEGED ACCOUNT
groupadd apache
useradd -G apache apache
chown -R apache:apache /var/www

message "User"
substitution "User " "User apache"

message "Group"
substitution "Group " "Group apache"

# DISABLE TRACE HTTP REQUEST

message "TraceEnable"
substitution "TraceEnable" "TraceEnable Off"

# SET COOKIE WITH HTTPONLY AND SECURE FLAG

a2enmod	headers

message "Header edit"
substitution "Header\sedit" "Header edit Set-Cookie ^(.*)$ \$1;HttpOnly;Secure"

# CLICKJACKING ATTACK

message "Header always"
substitution "Header\salways" "Header always append X-Frame-Options SAMEORIGIN"

# X-XSS PROTECTION

message "Header set"
substitution "Header\sset" 'Header set X-XSS-Protection "1; mode=block"'

# DISABLE HTTP 1.0 PROTOCOL

a2enmod rewrite

tee -a $PTFILE/apache2.conf << END
RewriteEngine On
RewriteCond %{THE_REQUEST} !HTTP/1.1$
RewriteRule .* - [F]
END

# TIMEOUT VALUE CONFIGURATION

message "Timeout"
substitution "Timeout" "Timeout 60" "/The/!"
