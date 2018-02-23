#!/bin/bash
set -e

mkdir -p /etc/portage/repos.conf

cat << EOF > /etc/portage/repos.conf/pmr2-overlay.conf
[pmr2-overlay]
location = /usr/local/portage/pmr2-overlay
sync-type = git
sync-uri = https://github.com/PMR2/portage.git
priority = 50
auto-sync = Yes
EOF

cat << EOF > /etc/portage/package.use/pmr2
# required by dev-db/virtuoso-server-6.1.6::pmr2-overlay
# required by dev-db/virtuoso-server::pmr2-overlay (argument)
sys-libs/zlib minizip
EOF

emerge --sync pmr2-overlay
emerge --noreplace net-misc/omniORB dev-util/cmake dev-db/unixODBC \
    dev-python/cffi media-libs/openjpeg media-libs/libjpeg-turbo \
    dev-python/virtualenv \
    dev-db/virtuoso-odbc::pmr2-overlay \
    dev-db/virtuoso-server::pmr2-overlay

eselect python set python2.7

if ! id -u $ZOPE_USER > /dev/null 2>&1; then
    useradd -m -k /etc/skel $ZOPE_USER
fi

mkdir -p "${PMR_HOME}"
chown zope:zope "${PMR_HOME}"
cd "${PMR_HOME}"
su zope -c "git clone https://github.com/PMR2/pmr2.buildout"
cd pmr2.buildout
su zope -c "python bootstrap.py"
su zope -c "bin/buildout -c buildout-git.cfg"

# TODO set up init scripts
# TODO rc-update add pmr2.zeoserver default
# TODO rc-update add pmr2.instance default

# TODO set up apache
# TODO set up, import owl files to virtuoso
