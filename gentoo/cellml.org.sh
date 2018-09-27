#!/bin/sh
# XXX this script assumes vboxtools has been used to "activate" a
# VirtualBox control environment.

set -e
# XXX these MUST be read from some configuration file

# BACKUP_* flags are origin restoration endpoints
# export BACKUP_HOST=
# export BACKUP_USER=
# export BACKUP_ZEO_PATH=

# export DIST_SERVER=https://dist.physiomeproject.org/

# XXX CELLML_HOME should be configured
# export CELLML_HOME=
# export CELLML_ZEO_KEY=
# export CELLML_ZEO_BACKUP=
# export CELLML_USER=

# export HOST_FQDN="cellml.org"

export BUILDOUT_NAME="cellml.site"
export SITE_ROOT="cellml"
export ZOPE_INSTANCE_PORT=13080

# XXX TODO upstream should implement some shell that sets this up
alias SSH_CMD="ssh -oStrictHostKeyChecking=no -oBatchMode=Yes -i \"${VBOX_PRIVKEY}\" root@${VBOX_IP}"

export BUILDOUT_ROOT="${CELLML_HOME}/${BUILDOUT_NAME}"

restore_cellml_backup () {
    # XXX consider `exec ssh-agent $SCRIPT` to ensure ssh-agent dies
    eval "$(ssh-agent -s)"
    # restore from backup
    # XXX figure out how to better add the keyscan results.
    SSH_CMD <<- EOF
	mkdir -p "${CELLML_ZEO_BACKUP}"
	ssh-keyscan "${BACKUP_HOST}" >> ~/.ssh/known_hosts 2>/dev/null
	EOF

    ssh-add "${CELLML_ZEO_KEY}"
    SSH_CMD -A <<- EOF
	rsync -av ${BACKUP_USER}@${BACKUP_HOST}:"${BACKUP_ZEO_PATH}" \
	    "${CELLML_ZEO_BACKUP}"
	EOF
    ssh-add -d "${CELLML_ZEO_KEY}"

    SSH_CMD <<- EOF
        /etc/init.d/cellml.instance stop
        /etc/init.d/cellml.zeoserver stop
	chown -R ${CELLML_USER}:${CELLML_USER} ${CELLML_ZEO_BACKUP}
	cd "${CELLML_HOME}/cellml.site"
	su ${CELLML_USER} -c \
	    "bin/repozo -R -r \"${CELLML_ZEO_BACKUP}\"/backup -o var/filestorage/Data.fs"
	su ${CELLML_USER} -c \
	    "cp -r \"${CELLML_ZEO_BACKUP}\"/blobstorage var/"
	EOF
    ssh-agent -k
}

if [ $# = 0 ]; then
    # enable all local commands/shortcuts
    CELLML_ORG=server/cellml.org.sh
    SETUP_PRODUCTION=server/install_production_services.sh
    RESTORE_BACKUP=1
fi

while [[ $# > 0 ]]; do
    opt="$1"
    case "${opt}" in
        --install-cellml)
            CELLML_ORG=server/cellml.org.sh
            shift
            ;;
        --install-production)
            SETUP_PRODUCTION=server/install_production_services.sh
            shift
            ;;
        --restore-backup)
            RESTORE_BACKUP=1
            shift
            ;;
        *)
            die "unknown option '${opt}'"
            ;;
    esac
done

# prepare local ssh-agent and outbound connection
SSH_CMD /etc/init.d/net.eth1 start

# install CELLML
if [ ! -z "${CELLML_ORG}" ]; then
    envsubst \$CELLML_USER,\$CELLML_HOME < "${CELLML_ORG}" | SSH_CMD
fi

# install and setup for production
if [ ! -z "${SETUP_PRODUCTION}" ]; then
    envsubst \${BUILDOUT_NAME},\$HOST_FQDN,\$BUILDOUT_ROOT,\$ZOPE_INSTANCE_PORT,\$SITE_ROOT < "${SETUP_PRODUCTION}" | SSH_CMD
fi

# restore backup
if [ ! -z "${RESTORE_BACKUP}" ]; then
    if [ -z "${CELLML_ZEO_KEY}" ]; then
        echo "skipping backup restore; CELLML_ZEO_KEY undefined"
    else
        restore_cellml_backup
    fi
fi

# XXX make this cleanup run regardless.
SSH_CMD /etc/init.d/net.eth1 stop
