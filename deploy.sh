#!/bin/bash
set -e

# Create a new project
oc new-project guacamole

# If the project has a default limitrange delete it
oc delete limitrange --all

# Build a version of guacamole that runs unprivileged
oc new-build --name guacamole-unprivileged https://github.com/rlucente-se-jboss/guacamole-client-wrapper
while ! oc get pod guacamole-unprivileged-1-build | grep Running ; do sleep 2 ;done
oc logs -f guacamole-unprivileged-1-build 

# Create a mysql instance backed by a pvc. Set readiness probe and wait for it to deploy
oc new-app mysql MYSQL_USER=guacamole MYSQL_PASSWORD=guacamole MYSQL_DATABASE=guacamole
oc set volume dc/mysql --add --name=mysql-volume-1 -t pvc --claim-name=mysql-claim --claim-size=1G --overwrite
oc set probe dc/mysql --readiness --open-tcp=3306
oc rollout status dc/mysql -w
MYSQLPOD=$(oc get pods  | grep Running | grep -v deploy | awk '{print $1}')

# Run mysql once to obtain the mysql db init script
oc run guacamole -it --wait --image=$(oc get is guacamole-unprivileged -o=go-template='{{ .status.dockerImageRepository}}') --restart=Never --command -- /opt/guacamole/bin/initdb.sh --mysql > initdb.sql
oc delete pod guacamole

# Run the init script in mysql pod
oc rsh $MYSQLPOD mysql -h 127.0.0.1 -P 3306 -u guacamole -pguacamole guacamole < initdb.sql

# Create the guacamole pod with the guacamole continaer built above and the guacd container. Set probes on both containers
oc new-app guacamole-unprivileged+guacamole/guacd --name=guacamole -e GUACAMOLE_HOME=/home/guacamole/.guacamole -e GUACD_HOSTNAME=127.0.0.1 -e GUACD_PORT=4822 -e  MYSQL_HOSTNAME=mysql.guacamole.svc.cluster.local -e MYSQL_PORT=3306 -e MYSQL_DATABASE=guacamole -e MYSQL_USER=guacamole -e MYSQL_PASSWORD=guacamole
oc set probe -c guacamole dc/guacamole --readiness --open-tcp=8080
oc set probe -c guacamole-1 dc/guacamole --readiness --open-tcp=4822
oc rollout status dc/guacamole -w

# Create both http and https endpoints
oc expose service guacamole --port=8080 --path=/guacamole
oc create route edge guac-secure --service=guacamole --path=/guacamole --port=8080

# Build and deploy our guac demo app from its Dockerfile
oc new-build --name=guac-app --strategy=docker --binary
oc start-build guac-app --from-dir=guac-app --follow --wait
oc adm policy add-role-to-user view system:serviceaccount:guacamole:default
oc new-app --image-stream=guac-app

# Capture the route for making API calls
export ROUTE=$(oc get route guacamole --template={{.spec.host}})

# Retrieve admin user authentication token
export TOKEN=$(curl -X POST -H "Content-Type: application/x-www-form-urlencoded" http://$ROUTE'/guacamole/api/tokens?username=guacadmin&password=guacadmin'  | jq -r .authToken)

# Create openshift user
curl -X POST -H "Content-Type: application/json" -d '{"username":"openshift","password":"openshift","attributes":{"disabled":"","expired":"","access-window-start":"","access-window-end":"","valid-from":"","valid-until":"","timezone":null}}' http://${ROUTE}/guacamole/api/session/data/mysql/users'?token='$TOKEN

# Grant permissions to openshift user to create connections and change their own password
curl -X PATCH -H "Content-Type: application/json" -d '[{"op":"add","path":"/userPermissions/openshift","value":"UPDATE"},{"op":"add","path":"/systemPermissions","value":"CREATE_CONNECTION"}]' http://${ROUTE}/guacamole/api/session/data/mysql/users/openshift/permissions'?token='$TOKEN

# Retrieve openshift user token
export TOKEN=$(curl -X POST -H "Content-Type: application/x-www-form-urlencoded" http://$ROUTE'/guacamole/api/tokens?username=openshift&password=openshift'  | jq -r .authToken)

# Create a connection to the vnc server running in our guac-app pod as the openshift user
curl -X POST -H "Content-Type: application/json" -d '{"parentIdentifier":"ROOT","name":"guac-app","protocol":"vnc","parameters":{"port":"5901","read-only":"","swap-red-blue":"","cursor":"","color-depth":"","clipboard-encoding":"","dest-port":"","recording-exclude-output":"","recording-exclude-mouse":"","recording-include-keys":"","create-recording-path":"","enable-sftp":"","sftp-port":"","sftp-server-alive-interval":"","enable-audio":"","hostname":"guac-app.guacamole.svc.cluster.local","password":"VNCPASS"},"attributes":{"max-connections":"","max-connections-per-user":"","weight":"","failover-only":"","guacd-port":"","guacd-encryption":"","guacd-hostname":""}}' http://${ROUTE}'/guacamole/api/session/data/mysql/connections?token='$TOKEN

# Print the login url and credentials
echo Log in to https://$(oc get route guac-secure -o jsonpath='{.spec.host}')/guacamole with creds openshift / openshift 
