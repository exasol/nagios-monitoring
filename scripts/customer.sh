#!/bin/bash

rm -rf /tmp/customer
ENV=$1

git clone https://github.com/danielschlieder/customer /tmp/customer >/dev/null 2>&1
ENV="/tmp/customer/$ENV/"
if [[ -e "$ENV" ]]; then
	if [[ -e "$ENV/checks" ]]; then
		cp "$ENV/checks/*" /usr/lib/nagios/plugins
	fi 
	if [[ -e "$ENV/defs" ]]; then
		cp "$ENV/defs/*" /usr/share/icinga2/include
	fi
	echo "include <plugins-$1>" >> /etc/icinga2/icinga2.conf
fi 
