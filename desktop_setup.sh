#!/bin/bash

## Load a configuration file if exists
load_conf_file() {
	ready=0
	while [ $ready == 0 ]; do
		if [ -f $1 ]
			then
				print_log "Using $1"
				. $1
				ready=1;
			else
				read -p "File $1 not found. Do you wish to [R]etry, [C]ontinue or [Q]uit (r/c/q)?" answer
				if [ "$answer" == 'R' -o "$answer" == 'r' ]; then
					echo "Retrying"
					ready=0;
				fi
				if [ "$answer" == 'C' -o "$answer" == 'c' ]; then
					echo "Continue"
					ready=1;
				fi
				if [ "$answer" == 'Q' -o "$answer" == 'q' ]; then
					echo "Exiting setup.."
					exit 1;
				fi
		fi
	done
}


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

## Print log message
print_log() {
	echo -e "\n\n\t****** $1 ******"
}

## Loading configuration file
load_conf_file setup-env.conf

## Display variables to user for sanity check
echo -e "\t*************************************************"
echo -e "\t********** Ubuntu Desktop Setup Script **********"
echo -e "\t*************************************************"
echo -e "\tEnvironment Variables for the Setup:"
echo -e "\t\tSERVER_IP = $SERVER_IP"
echo -e "\t\tSUPER_USER = $SUPER_USER"
echo -e "\t\tSERVER_NAME = $SERVER_NAME"
echo -e "\t\tSERVER_DOMAIN = $SERVER_DOMAIN"
echo -e "\t\tSERVER_OTHER_NAMES = $SERVER_OTHER_NAMES"
echo -e "\t\tSSH_PORT = $SSH_PORT"
echo -e "\t\tMAILER_SMARTHOST = $MAILER_SMARTHOST"
echo -e "\t\tMAILER_PASSWORD = $MAILER_PASSWORD"
echo -e "\t\tSUPPORT_EMAIL = $SUPPORT_EMAIL"
echo -e "\t\tPACKAGES_FILE = $PACKAGES_FILE"
echo -e "\t\tPACKAGES_SCRIPT = $PACKAGES_SCRIPT"
echo -e "\t\tIPTABLES_SCRIPT = $IPTABLES_SCRIPT"
echo -e "\t*********************************************"
print_prompt


##
## System Setup
##

## Setup Repositories
print_log "Updating Repositories"
print_prompt

## External Repositories
# Sublime Text 2
add-apt-repository ppa:webupd8team/sublime-text-2

# UberWriter
add-apt-repository ppa:w-vollprecht/ppa

## Update system
print_log "Package update"
apt-get update
apt-get upgrade

## Install new packages
print_log "Installing new packages"
echo -n "apt-get install " > $PACKAGES_SCRIPT
sed '/^\#/d;/^$/d' $PACKAGES_FILE | tr '\n' ' ' >> $PACKAGES_SCRIPT
chmod 755 $PACKAGES_SCRIPT
sh $PACKAGES_SCRIPT
rm $PACKAGES_SCRIPT

# Capifony & Live Reload
gem install capifony railsless-deploy guard guard-livereload
gem install --version '~> 0.8.8' rb-inotify

# Dropbox
print_log "Install Dropbox"
print_prompt
cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86" | tar xzf -
~/.dropbox-dist/dropboxd

print_log "SuperUser Setup"
print_prompt
##
## SuperUser Setup
##

## User Management
print_log "User management"
usermod -a -G sudo $SUPER_USER
usermod -a -G adm $SUPER_USER
usermod -a -G www-data $SUPER_USER

## GRUB TIMEOUT
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$GRUB_TIMEOUT/" /etc/default/grub
# Load Windows by default (to help the non-geeks)
mv /etc/grub.d/30_os-prober /etc/grub.d/09_os-prober
update-grub

## Apache Config
sed -i "s#/var/www#/home/$SUPER_USER/Sites#" /etc/apache2/sites-available/default
ln -s /etc/apache2/mods-available/vhost_alias.load /etc/apache2/mods-enabled/
ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/
ln -s /etc/apache2/mods-available/expires.load /etc/apache2/mods-enabled/
ln -s /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled/
apachectl restart

## Mail Aliases
# echo "root: root,$SUPPORT_EMAIL" | tee -a /etc/aliases
# echo "$SUPER_USER: $SUPER_USER,$SUPER_USER@$SERVER_DOMAIN" | tee -a /etc/aliases
# newaliases

## Housekeeping
mkdir /home/$SUPER_USER/bin
chown -R $SUPER_USER:$SUPER_USER /home/$SUPER_USER/bin
# Groups
addgroup developers
usermod -a -G www-data $SUPER_USER
usermod -a -G developers $SUPER_USER
usermod -a -G developers www-data

##
## System Configuration
##

# Font Cache
print_log "Font Cache"
fc-cache -fv

## Machine Locale Details
print_log "Setup Timezone"
dpkg-reconfigure tzdata
print_log "Setup Locales"
locale-gen $SERVER_LOCALE
update-locale LANG=$SERVER_LOCALE
dpkg-reconfigure locales
print_log "Selecting Default Worldlist"
select-default-wordlist

## Alternatives
print_log "Updating alernatives"
#ln -sf /bin/bash /bin/sh
update-alternatives --config editor
update-alternatives --config x-www-browser

## Hostname
# print_log "HostName configuration"
# #echo "$SERVER_NAME.$SERVER_DOMAIN" | tee /etc/hostname
# echo "$SERVER_NAME" | tee /etc/hostname
# hostname -F /etc/hostname

## DNS Name Servers
# print_log "DNS Configuration"
# echo "nameserver 8.8.8.8" | tail -a /etc/resolvconf/resolv.conf.d/tail
# echo "nameserver 8.8.4.4" | tail -a /etc/resolvconf/resolv.conf.d/tail
# service networking restart

## SSH Configuration
print_log "SSH Configuration"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.default
sed -i "s/Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i -e 's/^PermitRootLogin yes/PermitRootLogin no/' -e 's/^PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/^UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
echo "" | tee -a /etc/ssh/sshd_config
echo "# Permit only specific users" | tee -a /etc/ssh/sshd_config
echo "AllowUsers $SUPER_USER" | tee -a /etc/ssh/sshd_config
service ssh restart

## Email Configuration using Exim
# print_log "Exim configuration"
# cp /etc/exim4/update-exim4.conf.conf /etc/exim4/update-exim4.conf.conf.default
# sed -i -e "s/^dc_eximconfig_configtype='.*'/dc_eximconfig_configtype='smarthost'/" \
    # -e "s/^dc_other_hostnames='.*'/dc_other_hostnames=''/" \
    # -e "s/^dc_smarthost='.*'/dc_smarthost='$MAILER_SMARTHOST'/" \
    # -e "s/^dc_readhost=='.*'/dc_readhost=='$SERVER_NAME.$SERVER_DOMAIN'/" \
    # -e "s/^dc_hide_mailname='.*'/dc_hide_mailname='false'/"  /etc/exim4/update-exim4.conf.conf
# echo "$SERVER_NAME.$SERVER_DOMAIN" | tee /etc/mailname
# echo "*:$MAILER_EMAIL:$MAILER_PASSWORD" | tee -a /etc/exim4/passwd.client
# unset MAILER_PASSWORD
# update-exim4.conf
# service exim4 restart
# Sending Test Email
# echo "Hello World! From $USER on $(hostname) sent to $SUPER_USER" | mail -s "Hello World from $(hostname)" $SUPER_USER

## Secure MySQL
print_log "Securing MySQL"
mysql_secure_installation

## iptables
# curl https://raw.github.com/alghanmi/vps_setup/master/scripts/iptables-setup.sh | sed -e s/^SERVER_IP=.*/SERVER_IP=\"$SERVER_IP\"/ -e s/^SSH_PORT=.*/SSH_PORT=\"$SSH_PORT\"/ - > /home/$SUPER_USER/bin/iptables-setup.sh
# chmod 755 /home/$SUPER_USER/bin/iptables-setup.sh
# sh /home/$SUPER_USER/bin/iptables-setup.sh

## User Configuration Files
##
print_log "User specific configuration"
print_prompt

# Local & work directories
# mkdir -p /home/$SUPER_USER/work/lib
mkdir -p /home/$SUPER_USER/.ssh
mkdir -p /home/$SUPER_USER/bin
mkdir -p /home/$SUPER_USER/Sites
mkdir -p /home/$SUPER_USER/Projects

# Create a local SSH config file for hosts
touch /home/$SUPER_USER/.ssh/authorized_keys
chmod 600 /home/$SUPER_USER/.ssh/authorized_keys
chmod 700 /home/$SUPER_USER/.ssh

# Fix Ownership
chown $SUPER_USER:$SUPER_USER /home/$SUPER_USER/.bashrc
chown -R $SUPER_USER:$SUPER_USER /home/$SUPER_USER/.ssh
chown -R $SUPER_USER:$SUPER_USER /home/$SUPER_USER/bin
# chown -R www-data:www-data /home/www

##
## Desktop Preferences
##
print_log "Desktop Preferences"
print_prompt
