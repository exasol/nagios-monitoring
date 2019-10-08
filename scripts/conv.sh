#!/bin/bash

rm -rf /tmp/envs
ENV=$1

#if [[ "$ENV" == "default" ]]; then
#	cp -a /tmp/yaml2mon/testing/default.yaml /etc/icinga2/conf.d/ENV.yaml
#else
	git clone https://github.com/danielschlieder/environments /tmp/envs >/dev/null 2>&1
	ENV="/tmp/envs/$ENV.yaml"
	if [[ -e "$ENV" ]]; then
		cp "$ENV" /etc/icinga2/conf.d/ENV.yaml
		cp -a "$ENV" /etc/icinga2/conf.d/ENV.yaml
		rm -rf /tmp/envs
	else
		echo -e "\nGiven Environment $1 not found (as $ENV)\n"
		exit 1
	fi 

#fi
