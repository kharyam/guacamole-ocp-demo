# ISTIO mTLS Demo

1. [Install service mesh](https://docs.openshift.com/container-platform/4.4/service_mesh/service_mesh_install/installing-ossm.html)


2. Deploy the Guacamole Demo

3. Deploy SMCP

```
oc new-project guacamole-smcp
oc create -f smcp.yml
oc create -f smmr.yml

# https route
oc create route edge gateway-secure --service=istio-ingressgateway --port=8080
```

4. Wait for SMCP to deploy all pods
```
watch oc get pods -n guacamole-smcp
```

5. Create istio objects

```
oc create -f gateway.yml -n guacamole
oc create -f guacamole-dr.yml -n guacamole
oc create -f guac-app-dr.yml -n guacamole
oc create -f mysql-dr.yml -n guacamole
oc create -f virtualservice.yml -n guacamole
```

6. Delete routes and pods to force injection
```
oc delete route --all -n guacamole
oc delete pod --all -n guacamole
```
