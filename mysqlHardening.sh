#!/bin/bash

# COLORS
Reset='\033[0m'
Re='\033[0;31m'
Gr='\033[0;32m'
Bl='\033[0;36m'

set -o errexit # abort on nonzero exitstatus
set -o nounset # abort on unbound variable

usage() {
cat << _EOF_

Usage: ${0} "ROOT PASSWORD"

 with "ROOT PASSWORD" the desired password for the database root user.

Use quotes if your password contains spaces or other special characters.
_EOF_
}

# PREDICATE THAT RETURNS EXIT STATUS 0 IF THE DATABASE ROOT PASSWORD
# IS SET, A NONZERO EXIT STATUS OTHERWISE.
rootpwset() {
 ! mysqladmin --user=root status > /dev/null 2>&1
}

# PREDICATE THAT RETURNS EXIT STATUS 0 IF THE MYSQL(1) COMMAND IS AVAILABLE,
# NONZERO EXIT STATUS OTHERWISE.
mysqlInstalled() {
 which mysql > /dev/null 2>&1
}

# COMMAND LINE PARSING

if [ "$#" -ne "1" ]; then
 echo "Expected 1 argument, got $#" >&2
 usage
 exit 2
fi

# VARIABLES
db_root_password="${1}"

# SCRIPT PROPER

if ! mysqlInstalled; then
 echo "The MySQL/MariaDB client mysql(1) is not installed."
 exit 1
fi

if rootpwset; then
 echo "Database root password already set"
 exit 0
fi

echo -e "$Bl \n adding password to user root.. \n Deleting anonymous users.. $Reset"
echo -e "$Bl \n Prevent remote connection from root.. \n Dropping database test $Reset"

mysql --user=root <<_EOF_
 UPDATE mysql.user SET authentication_string=PASSWORD('${db_root_password}') WHERE User='root';
 DELETE FROM mysql.user WHERE User='';
 DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
 DROP DATABASE IF EXISTS test;
 DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
 FLUSH PRIVILEGES;
_EOF_

echo -e "$Bl \n All done $Reset"
