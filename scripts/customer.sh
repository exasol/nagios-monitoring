#!/bin/bash

rm -rf /tmp/customer
ENV=$1

git clone https://github.com/danielschlieder/customer /tmp/customer >/dev/null 2>&1
PENV="/tmp/customer/$ENV/"
if [[ -e "$PENV" ]]; then
	if [[ -e "$PENV/checks" ]]; then
		cp "$PENV/checks/*" /usr/lib/nagios/plugins
	fi 
	if [[ -e "$PENV/defs" ]]; then
		mkdir -p /usr/share/icinga2/include/plugins-$ENV
		cp "$PENV/defs/*" /usr/share/icinga2/include/plugins-$ENV
	fi
	echo "include <plugins-$ENV>" >> /etc/icinga2/icinga2.conf
fi 
