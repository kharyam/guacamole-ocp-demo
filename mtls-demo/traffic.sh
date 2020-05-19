#!/bin/bash

export ROUTE=$(oc get route gateway-secure -n guacamole-smcp --template={{.spec.host}})

while true
do
	curl -kX POST -H "Content-Type: application/x-www-form-urlencoded" \
		https://$ROUTE'/guacamole/api/tokens?username=openshift&password=openshift'
sleep 2 
done
