#!/bin/bash

VERSION="1.0"
TAUTH_CONF_ROOT="/etc/tauth"
TAUTH_CONF=$TAUTH_CONF_ROOT/"tauth_config"
TAUTH_ROOT="/usr/local/tauth"

#Colors for display
NOCOLOR='\033[0m'
red() { CRED='\033[0;31m'; echo -e ${CRED}$1${NOCOLOR}; }
blue() { CBLUE='\033[0;34m'; echo -e ${CBLUE}$1${NOCOLOR}; }
green() { CGREEN='\033[0;32m'; echo -e ${CGREEN}$1${NOCOLOR}; }




check_ssh() {
#find SSH config file
if [[ -f /etc/ssh/sshd_config ]]; then
	SSH_CONF="/etc/ssh/sshd_config"
	#green "SSH config file found at "$SSH_CONF
	
else
	red "No SSH config found in /etc/ssh/sshd_config"
	read -p "Enter location of SSH config file: " loc
	if [[ -f $loc ]]; then
		SSH_CONF=$loc
		green "SSH config file found at "$SSH_CONF
	else
		red "No SSH config found in "$loc
		red "Exiting...."
	fi
fi
}


check_root() {
#check root
if [ $(whoami) != "root" ]; then
	red "restart as root!"
	red "Exiting...."
	exit
fi
}

load_settings() {
if [[ -f $TAUTH_CONF ]]; then
	EMAIL_User=$(cat $TAUTH_CONF | grep EmailUser | awk '{print $2}')
	EMAIL_Pass=$(cat $TAUTH_CONF | grep EmailPass | awk '{print $2}')
	EMAIL_Serv=$(cat $TAUTH_CONF | grep EmailServer | awk '{print $2}')
	EMAIL_Only=$(cat $TAUTH_CONF | grep EmailOnly | awk '{print $2}')
    EMAIL_Only=${EMAIL_Only,,}
	SSH_CONF=$(cat $TAUTH_CONF | grep SshConfig | awk '{print $2}')
#	if [ $SSH_CONF == "" | $EMAIL_Only == "" ]; then
#		red "Configuration file errors!"
#		red "SshConfig missing or EmailOnly missing"
#	#green "Configuration file loaded"
#	fi
else
	red "No configuration file found! Restart Program!"
	exit
fi
}



code=$(head /dev/urandom | tr -dc 0-9 | head -c5)

sel() {
while true; do
    read -e -p "Choose SMS or EMAIL: " -i "sms" method
    case $method in
        "EMAIL" | "email" | "e") 
		send "email"
		break;;
        "sms" | "SMS" | "s" )
		if [ "$EMAIL_Only" = "yes" ]; then
			red "No SMS service! Sending email..."
			send "email"
		else
			send "sms"
		fi
		break;;
        * ) echo "Please choose SMS or EMAIL";;
    esac
done
}

get_info() {
#Gets the hostname from the connection
SIP=$(echo $SSH_CONNECTION | awk '{print $1}')
SHOST=$(nslookup $SIP | grep 'name =' | awk '{print $4}')
SFIN="$SHOST [$SIP]"
}

log() {
#log a command with status of $1
echo "$1"$'\t'"$(date +"%m-%d-%y_%H:%M:%S")"$'\t'"$(whoami)"$'\t'"$SIP"$'\t'"$SHOST" >> /var/log/tauth/tauth.log
}

#send mode[sms|email]
send() {

if [ $1 == "email" ]; then
	echo -e "Subject: TAUTH code\n\nCode: $code\nFrom: $SFIN" > /tmp/mail.txt
	curl -sS --url "$EMAIL_Serv" --ssl-reqd --mail-from "$EMAIL_User" --mail-rcpt "$EMAIL" --upload-file /tmp/mail.txt --user "$EMAIL_User:$EMAIL_Pass" --insecure
	green "Email sent to $(whoami)"
	rm /tmp/mail.txt
elif [ $1 == "sms" ]; then
	message="message=$code"
	sent=$(curl -s http://textbelt.com/text -d number=$PHONE -d $message)
	green "Code sent..."
	success=$(echo $sent | cut -d" " -f3)
	if [ $success == "true" ]; then 
		green "Success! Please wait up to 1 minute for code to arrive..."
	else
		red "Sending code failed!! Restart to try Email"
		exit
	fi
else
	red "No email to text service!"
	exit
fi

}

main_login() {
read -e -p "Enter Code: " pass
case $pass in
    $code ) 
	green "Accepted Code!"
    log "LOGIN"
	/bin/bash
	blue "Thank you for using t-auth"
	exit
    ;;
    * )
	red "Incorrect! Removing from server..."
    log "FAILED"
    ;;
esac
}

load_user() {
#check if the user has tauth files
#if not, directly login
USER=$(whoami)
USER_CONF="/home/$USER/.tauth/user_config"
USER_DIR="/home/$USER/.tauth"
if [[ -f $USER_CONF ]]; then
	EMAIL=$(cat $USER_CONF | grep Email | awk '{print $2}')
	PHONE=$(cat $USER_CONF | grep Phone | awk '{print $2}')
else
	tauth_login $code
fi
}

tauth_login() {
if [ $1 == $code ]; then
	/bin/bash
	blue "Thank you for using t-auth"	
	exit
else
	red "Incorrect! Removing from server..."
fi
}

blue "Server secured with TAUTH"
load_settings
load_user
get_info

blue "Please login with authentication code"
#Select message version and send code
if [ "$EMAIL_Only" != "yes" ]; then
	sel
else
	send "email"
fi
#read users input
main_login

