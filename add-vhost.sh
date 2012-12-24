#!/bin/bash

# A simple Apache VirtualHost configuration builder
# by Jay Williams <jay@myd3.com>
# Tested on Linux Mint 14

## Print prompt and do not proceed unless user enters Y or N.
print_prompt() {
	ready=0
	while [ $ready == 0 ]; do
		read -p "Do you wish to proceed (y/n)? " answer
		if [ "$answer" == 'Y' -o "$answer" == 'y' ]; then
			ready=1
		fi
		if [ "$answer" == 'N' -o "$answer" == 'n' ]; then
			echo "Exiting setup.."
			exit 1;
		fi
	done
}

if [ ! "$1" ]; then
    echo "Error: No ServerName Specified"
    exit 2
fi

if [ ! -d "$2" ]; then
    echo "Error: No DocumentRoot Specified"
    exit 3
fi

DOMAIN=$1
ROOT=`realpath $2`

echo -e "\n\n\t****** Site Information ******"
echo "Please verify that the information below is correct before proceding."
echo
echo -e "ServerName:    (www.)$DOMAIN"
echo -e "DocumentRoot:  $ROOT"
print_prompt

echo 'Creating VirtualHost...'
echo -e "<VirtualHost *:80>
    ServerName  www.$DOMAIN
    ServerAlias $DOMAIN
    DocumentRoot $ROOT
</VirtualHost>" \
    > "/etc/apache2/sites-available/$DOMAIN"

ln -s "/etc/apache2/sites-available/$DOMAIN" "/etc/apache2/sites-enabled/"

echo 'Adding Hosts Entry...'
echo -e "127.0.0.1       $DOMAIN\n127.0.0.1   www.$DOMAIN" >> /etc/hosts

echo 'Restarting Apache...'
apachectl restart

echo '...DONE!'
