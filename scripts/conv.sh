#!/bin/bash

ENV=$1
if [[ $ENV -eq "default" ]]; then 
	cp -a /tmp/yaml2mon/testing/default.yaml /etc/icinga2/conf.d/ENV.yaml
else
	git clone https://github.com/danielschlieder/environments /tmp/envs 
	ENV=/tmp/envs/$ENV.yaml 
	if [[ -e "$ENV" ]]; then 
		cp "$ENV" /etc/icinga2/conf.d/ENV.yaml
	else
		echo "Given Environment $1 not found (as $ENV)"
		exit 1
	fi 

fi
