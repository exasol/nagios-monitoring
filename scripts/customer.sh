#!/bin/bash

rm -rf /tmp/customer
ENV=$1
CHECKS=0
DEFS=0
echo -e "\n\n" >&2
git clone https://github.com/danielschlieder/customer.git /tmp/customer >/dev/null 2>&1
PENV="/tmp/customer/$ENV"
if [[ -e "$PENV" ]]; then
	echo -e "\n###############################################################################" >&2
	echo -e "\nFound checks supplied by the customer for environment $ENV" >&2
	echo -e "\n###############################################################################" >&2
	if [[ -e "$PENV/checks" ]]; then
		echo -e "\n-------------------------------------------------------" >&2
		echo -e "\nCopying checks" >&2
		echo -e "\n-------------------------------------------------------" >&2
		cp -arv $PENV/checks/* /usr/lib/nagios/plugins
		CHECKS=1
	fi 
	if [[ -e "$PENV/defs" ]]; then
		echo -e "\n-------------------------------------------------------" >&2
		echo -e "\nCopying check definition" >&2
		echo -e "\n-------------------------------------------------------" >&2
		mkdir -p /usr/share/icinga2/include/plugins-$ENV
		cp -arv $PENV/defs/* /usr/share/icinga2/include/plugins-$ENV
		echo -e "\n-------------------------------------------------------" >&2
		echo -e "\nEnabling new check definition" >&2
		echo -e "\n-------------------------------------------------------" >&2
		echo -e "include <plugins-$ENV>" >> /etc/icinga2/icinga2.conf
	else
		if [[ "$CHECKS" == "1" ]]; then
			echo -e "\n\nCustomer supplied checks without a definition! Please supply the definition in the /defs folder\n\n" >&2
			exit 1
		fi
	fi
	echo -e "\n###############################################################################" >&2
	echo -e "\nProcessed checks supplied by the customer for environment $ENV" >&2
	echo -e "\n###############################################################################" >&2
fi 
echo -e "\n\n" >&2
