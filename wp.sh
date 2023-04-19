#!/bin/bash

# Script to install multiple Wordpress instances into single web server.
# 
# TODO: If using bitnami lamp stack, disable pagespeed module because can confuse students when js/css files are cached.
# https://docs.bitnami.com/bch/apps/wordpress/administration/use-pagespeed/
#
# REQUIREMENTS 
# 
# LAMP environment installed. Script is tested with Bitnami LAMP stack.
# https://bitnami.com/stack/lamp
# 
# Script will contain one Bitnami specific step. The last line, 'set_directory_permissions'
# is optional and work only in Bitnami environment.
#
# EXAMPLE OF USAGE
#
# Run script in working directory that will hold the public wordpress sites.
# htdocs or www -folder for example.
#
# > wp.sh -f mycsvfile.csv
#
# mycsvfile should have following content without header columns. Script will
# read all rows and create multiple sites.
#
# username,password 
#
# Given information is used to create all credentials for website and database.
#
# IMPORTANT
#
# When script connect to database, it use mysql command. It will use current session
# user. You should create my.cnf file in to home directory and set mysql credentials
# that have rights to create new users and databases.
#
# my.cnf content:
#
# [client]
# user=dbuser
# password=dbpass
#
# MOTIVATION
# 
# Script was made for set up multiple Wordpress instances for students. It should be easy
# to configurate any needs. You only need single web server and then environments is
# ready for teaching Wordpress. The script is not for production usage.
# 
# AUTHOR
#
# Turo Nylund (turo.nylund@outlook.com) 
#

# =======================
# Define global variables
# =======================

CURRENT_DIR=$(pwd)
MACHINE_PUBLIC_IP=$(curl https://api.ipify.org)
# ======================
# Define functions
# ======================

print_message() {
	echo "$1"	
}

create_database_with_user() {
    # $1 is user to create
    # $2 is password for user
    # $3 is database name
    SQL_COMMAND="CREATE DATABASE ${3} /*!40100 COLLATE \"utf8_general_ci\" */;"
    SQL_COMMAND+="CREATE USER '${1}'@'%' IDENTIFIED BY '${2}';"
    SQL_COMMAND+="GRANT USAGE ON *.* TO '${1}'@'%';"
    SQL_COMMAND+="GRANT SELECT, EXECUTE, SHOW VIEW, ALTER, ALTER ROUTINE, CREATE, CREATE ROUTINE, CREATE TEMPORARY TABLES, CREATE VIEW, DELETE, DROP, EVENT, INDEX, INSERT, REFERENCES, TRIGGER, UPDATE  ON ${3}.* TO '${1}'@'%';"
    SQL_COMMAND+="FLUSH PRIVILEGES;"

    # Uncomment if you want to debug SQL command.
    # print_message "$SQL_COMMAND"

    mysql --execute="$SQL_COMMAND"
}

set_directory_permissions() {
	# Optional but needed for bitnami lamp stack
	# to set right folder and file permissions.
	sudo chown -R bitnami:daemon /opt/bitnami/apache2/htdocs
	sudo chmod -R g+w /opt/bitnami/apache2/htdocs
}

wordpress_modify_configs() {
	site=$1
        dbuser=$2 
        dbpass=$3 
        dbname=$4

	#create wp config
	cp ./$site/wp-config-sample.php ./$site/wp-config.php

	# will define FS_METHOD type.
	# FS_METHOD This setting forces the filesystem (or connection) method.
	# direct means that plugins can be installed without ftp connection 
	sed -i -e "/DB_COLLATE/a\define(\'FS_METHOD\', \'direct\');" ./$site/wp-config.php 
}

install_wordpress_site() {
    # $1 argument ins the csv file that contain wordpress
    # sites information.
    sites_in_file=$1

	# Read site information from csv file.
	# csv -file should have following columns.
	# username, password
	while IFS=, read -r username password 
	do
        print_message "Row data: $username|$password"
        if [ -z "$username" ]
        then
            print_message "Skip empty row"
            continue
        fi

        dbuser="db_user_$username"
        dbname="db_name_$username"
        site="$username"

        create_database_with_user $dbuser $password $dbname
        print_message "Database \"$dbname\" created"

        wp-cli core download --path="$site"
        wp-cli config create --path="$site" --dbname="$dbname" --dbuser="$dbuser" --dbhost="127.0.0.1" --dbpass="$password"
        wp-cli core install --path="$site" --url="http://$MACHINE_PUBLIC_IP/$site" --title="My Wordpress site" --admin_user="$username" --admin_email="$username@mailinator.com" --admin_password="$password" --skip-email
        
        print_message "Wordpress installation for $username completed. Site url is http://$MACHINE_PUBLIC_IP/$site"

        sudo ./add_user.sh -u $site
	done < $sites_in_file
}

# ======================
# Main application start.
# ======================

# Read arguments and check mandatory input
while getopts ":f:" opt; do
    case $opt in
    f) csvfile="$OPTARG"
    ;;
    \?) print_message "Invalid option -$OPTARG" >&2
    ;;
    esac
done

if [ -z "$csvfile" ]
then
    print_message "CSV file not found."
    exit
fi

if ! command -v wp-cli &> /dev/null
then
    print_message "wp-cli command not found. Check that the tool is installed and can be executed using command wp-cli."
    print_message "INFO: Trying to install WP-CLI tool now. Read more https://wp-cli.org/"
    wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp-cli
    sudo chmod +x /usr/local/bin/wp-cli
fi

print_message "A robot is now installing WordPress sites for you."

#download_wordpress_and_unzip
install_wordpress_site $csvfile

print_message "Script finished"

# Optional but needed for bitnami lamp stack
# to set right folder and file permissions.
set_directory_permissions