#!/bin/sh
set -e

# This script starts the JBDS application.  A single argument can
# be passed to set the desired screen size.  The argument must be in
# the form HORZxVERT where HORZ is a number >= 640 and VERT is a
# number >= 480.  Also, this script will enable any user to run
# JBDS if it is shutdown cleanly.

# default screen size
SCREEN_SIZE="1440x800"

# Generate passwd file based on current UID
function generate_passwd_file() {
  export USER_ID=$(id -u)
  export GROUP_ID=$(id -g)
  envsubst < /usr/local/share/passwd.template > /tmp/passwd
  export LD_PRELOAD=/usr/lib64/libnss_wrapper.so
  export NSS_WRAPPER_PASSWD=/tmp/passwd
  export NSS_WRAPPER_GROUP=/etc/group
}

# waits until desired window, with name in $1, is active
function wait_for_window {
    while [ "x`DISPLAY=:1 wmctrl -l | grep "$1"`" = "x" ]
    do
        sleep 2
    done
}

# leverage NSS wrapper to use our own passwd file
generate_passwd_file

# trap signals so we can close cleanly
RUNNING=true
trap "RUNNING=false" HUP INT QUIT KILL TERM

# set screen size based on arg if valid
if [ "$#" -gt 0 ]
then
  if [ "x`echo $1 | grep -E '^[0-9]+x[0-9]+$'`" != "x" ]
  then
    HORZ=`echo $1 | cut -dx -f1`
    VERT=`echo $1 | cut -dx -f2`

    if [ "$HORZ" -ge 640 -a "$VERT" -ge 480 ]
    then
      SCREEN_SIZE="${HORZ}x${VERT}"
    fi
  fi
fi

# create all needed directories
cd $HOME
mkdir -p workspace .vnc

# set vnc config if missing
cd .vnc
if [ ! -f passwd ]
then
  chmod 740 .
  echo 'VNCPASS' | vncpasswd -f > passwd
  chmod 600 passwd
  echo 'i3' > xstartup
  chmod a+x xstartup
fi

echo "Screen resolution set to $SCREEN_SIZE"

echo "Launching  Xvnc which launches window manager and app(s) ..."
cd ..
#vncserver :1 -name 'Desktop Name' -geometry $SCREEN_SIZE -depth 24
vncserver :1 -name 'Desktop Name' -geometry $SCREEN_SIZE -depth 24 -alwaysshared -SecurityTypes=VncAuth -fg 


echo "Loop to prevent container from exiting"
echo "CTRL-C to exit or run 'docker stop <container>'"
while $RUNNING
do
   sleep 2
done

echo "Closing 'cleanly' by killing Xvnc ..."
vncserver -kill :1

# remove user restricted files so they can be recreated
rm -f passwd .vnc

# set all permissions for root group
dummy=$(chgrp -R 0 ${HOME} && chmod -R g+rwX ${HOME} && :)
