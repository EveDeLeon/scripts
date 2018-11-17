#!/bin/bash

# COLORS
Reset='\033[0m'
Re='\033[0;31m'
Gr='\033[0;32m'
Bl='\033[0;36m'

# PATH TO FILE VARIABLE
PTFILE="/etc/php/7.2/apache2/"
# PTFILE="/etc/php/7.2/fpm/" # IF YOU'RE USING NGINX INSTEAD OF APACHE

# SED SUBSTITUTION FUNCTION
substitution (){
	# FIRST THE FUNCTION LOOK FOR A COINCIDENCE FOR THE SUBSTITUTION ON THE CONFIG FILE, 
	# IF IT DOESN'T FIND ONE, THE FUNCTION ADD THE CONFIGURATION TO THE END OF THE FILE
        if ! (egrep -q \;\?\s\?$1 $PTFILE/php.ini); then
                echo -e "$2" &>> $PTFILE/php.ini
                echo -e "$Gr \n The $1 line has been added. $Reset" && sleep 1
	# IF IT FINDS A COINCIDENCE INSTEAD OF ADDING IT, THE FUNCTION CHANGE THE ACTUAL
	# CONFIGURATION FOR THE NEW ONE
        else
                sed -i -e "$3 s@#\?\s\?$1\s\?.*@$2@g" $PTFILE/php.ini
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

#INSTALLING PHP

echo -e "$Bl \n Installing php ver. 7.2 $Reset"

apt update
apt install php7.2

# CHECK IF CONFIG FILE EXISTS ON /etc/php/7.2/apache2/php.ini PATH
if [[ ! -f /etc/php/7.2/apache2/php.ini ]]; then
        echo -e "$Re File not found! $Reset"
        exit
fi

# BACKUP OF FILE php.ini FILE
d=$(date +"%Y%m%d")
echo -e "$Bl \n Creating backup file" && sleep 1
cp $PTFILE/php.ini $PTFILE/"php.ini.bak.$d"
echo -e "$Gr \n Created backup file php.ini.bak.$d $Reset" && sleep 1

#RESTRICT PHP INFORMATION LEAKAGE

message "expose_php"
substitution "expose_php" "expose_php = Off"

#LOG ALL PHP ERRORS

message "display_errors"
substitution "display_errors\s=" "display_errors = Off"

message "log_errors"
substitution "log_errors\s=" "log_errors = On"

awk '/log_errors = On/ { print; print "\terror_log = /var/log/custom/php_scripts_error.log"; next }1' $PTFILE/php.ini > $PTFILE/php.ini.tmp && mv $PTFILE/php.ini.tmp $PTFILE/php.ini

#DISALLOW UPLOADING FILES

message "file_uploads"
substitution "file_uploads" "file_uploads = Off" "/max/!"

#TURN OFF REMOTE CODE EXECUTION

message "allow_url_fopen"
substitution "allow_url_fopen" "allow_url_fopen = Off"

message "allow_url_include"
substitution "allow_url_include" "allow_url_include = Off"

#CONTROL POST SIZE

message "post_max_size"
substitution "post_max_size" "post_max_size = 1K"

#RESOURCE CONTROL (DoS CONTROL)

message "max_execution_time"
substitution "max_execution_time" "max_execution_time = 30"

message "max_input_time"
substitution "max_input_time\s=" "max_input_time = 30"

message "memory_limit"
substitution "memory_limit" "memory_limit = 40M"

#DISABLING DANGEROUS PHP FUNCTIONS

message "disable_functions"
substitution "disable_functions" "disable_functions =exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source"

#PHP FASTCGI / CGI - cgi.force_redirect DIRECTIVE

message "cgi.force"
substitution "cgi.force_redirection\s=\s1" "cgi.force_redirect = On"

#LIMIT PHP ACCESS TO FILE SYSTEM

message "open_basedir"
substitution "open_basedir\s=" "open_basedir = /var/www/html"

#SESSION PATH

message "session.save_path"
substitution 'session.save_path\s=\s"/var' 'session.save_path = "/var/lib/php/session"'

message "upload_tmp_dir"
substitution "upload_tmp_dir\s=" 'upload_tmp_dir = "/var/lib/php/session"'
