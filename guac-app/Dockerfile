FROM fedora:latest

ENV HOME /home/guac-app

# Add the needed packages for JBDS
RUN    dnf -y update \
    && dnf -y install \
           gettext \
           nss_wrapper \
           i3 \
           tigervnc-server \
           wmctrl \
           origin-clients \
           xcalc \
           firefox \
    && dnf -y clean all

# Create installation directory and set the openbox window manager
# configuration for all users
#RUN echo 'export DISPLAY=:1' >> /etc/xdg/openbox/environment \
#    && echo "xcalc &" \
#             >> /etc/xdg/openbox/autostart

ADD resources/start.sh /usr/local/bin/

# This file is used to create a temporary passwd file for use by
# the NSS wrapper so that the openbox window manager can launch
# correctly.  OCP will use a non-deterministic user id, so we have
# to provide a valid passwd entry for that UID for openbox
ADD resources/passwd.template /usr/local/share/


# Create the home directory and set permissions
RUN  mkdir -p ${HOME}/.config/i3 \
    && chmod a+rwX ${HOME} \
    && chmod a+rx /usr/local/bin/start.sh \
    && chmod a+r /usr/local/share/passwd.template

ADD resources/i3-config $HOME/.config/i3/config

EXPOSE 5901

USER 1000

CMD /usr/local/bin/start.sh

# No volume support yet, so everything in /home/jbdsuser is ephemeral.
# Eventually this can be a mounted persistent volume so each user can
# have a persistent maven repository, workspace, etc.
