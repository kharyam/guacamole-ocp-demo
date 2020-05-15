#!/bin/bash
set -e

# Create a new project
oc new-project guacamole
oc label namespace/guacamole kiali.io/member-of=guacamole-smcp

# If the project has a default limitrange delete it
oc delete limitrange --all

# Build a version of guacamole that runs unprivileged
oc new-build --name guacamole-unprivileged https://github.com/rlucente-se-jboss/guacamole-client-wrapper
while ! oc get pod guacamole-unprivileged-1-build | grep Running ; do sleep 2 ;done
oc logs -f guacamole-unprivileged-1-build 

oc create -f mysql-deployment.yml
oc set volume deployment/mysql --add --name=mysql-volume-1 -t pvc --claim-name=mysql-claim --claim-size=1G --overwrite --mount-path=/var/lib/mysql/data
oc create -f mysql-svc.yml
oc rollout status deployment/mysql -w

MYSQLPOD=$(oc get pods  | grep Running | grep -v deploy | awk '{print $1}')

# Run mysql once to obtain the mysql db init script
oc run guacamole -it --wait --image=$(oc get is guacamole-unprivileged -o=go-template='{{ .status.dockerImageRepository}}') --restart=Never --command -- /opt/guacamole/bin/initdb.sh --mysql > initdb.sql
oc delete pod guacamole

# Run the init script in mysql pod
oc rsh $MYSQLPOD mysql -h 127.0.0.1 -P 3306 -u guacamole -pguacamole guacamole < initdb.sql

oc create -f guacamole-deployment.yml
oc create -f guacamole-svc.yml
oc rollout status deployment/guacamole -w

# Create both http and https endpoints
oc expose service guacamole --port=8080 --path=/guacamole
oc create route edge guac-secure --service=guacamole --path=/guacamole --port=8080

# Build and deploy our guac demo app from its Dockerfile
oc new-build --name=guac-app --strategy=docker --binary
oc start-build guac-app --from-dir=guac-app --follow --wait
oc adm policy add-role-to-user view system:serviceaccount:guacamole:default
oc create -f guac-app-deployment.yml
oc create -f guac-app-svc.yml
oc rollout status deployment/guac-app -w

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


# Cleanup
oc get pods | grep Completed | awk '{print $1}' | xargs oc delete pod

# Print the login url and credentials
echo Log in to https://$(oc get route guac-secure -o jsonpath='{.spec.host}')/guacamole with creds openshift / openshift 
