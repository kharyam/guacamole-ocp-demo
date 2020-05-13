# Guacamole on OCP Demo

This demo will deploy guacamole containerized on OpenShift along with a containerized i3 window manager running xcalc and firefox side-by-side. The demo can be deployed using the deploy.sh script. Log into an OpenShift cluster (tested on 4.4) and execute this script on a linux command line.

This is based off of Rich Lucente's [blog](https://www.openshift.com/blog/put-ide-container-guacamole) and [git repository](https://github.com/rlucente-se-jboss/jbds-via-html5/blob/master/resources/start.sh).

## Limitations / TODOs
The VNC connection would frequently crash if tls was enabled (which it is by default). Disabled tls for the purposes of this demo. Another technique such as mTLS via istio can be used to mitigate this.

Currently the application pod is running fedora.
