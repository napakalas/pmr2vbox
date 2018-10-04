#!/bin/sh
# XXX this script assumes vboxtools has been used to "activate" a
# VirtualBox control environment.

set -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# XXX these MUST be read from some configuration file

# TODO should also apply optional step to attach a separate disk image

# BACKUP_* flags are origin restoration endpoints
export BACKUP_HOST=${BACKUP_HOST:-"dist.physiomeproject.org"}
export BACKUP_USER=${BACKUP_USER:-"pmrdemo"}

export DIST_SERVER=${DIST_SERVER:-"https://${BACKUP_HOST}"}
export JARS_SERVER=${JARS_SERVER:-"${DIST_SERVER}/jars"}
export NEO4J_VERSION=${NEO4J_VERSION-"neo4j-community-3.0.1"}
export TOMCAT_VERSION=${TOMCAT_VERSION:-"8.5"}

# TODO figure out usage of TOMCAT_SUFFIX and whether it is applicable
# without complicating things.
export TOMCAT_USER=${TOMCAT_USER:-"tomcat"}
export ZOPE_USER=${ZOPE_USER:-"zope"}
export MORRE_USER=${MORRE_USER:-"${ZOPE_USER}"}
export PMR_HOME=${PMR_HOME:-"/home/${ZOPE_USER}"}
export MORRE_HOME=${MORRE_HOME:-"/home/${MORRE_USER}"}
export BUILDOUT_NAME=${BUILDOUT_NAME:-"pmr2.buildout"}

export SITE_ROOT=${SITE_ROOT:-"pmr"}
export HOST_FQDN=${HOST_FQDN:-"pmr.example.com"}

export PMR_DATA_READ_KEY=${PMR_DATA_READ_KEY:-"${DIR}/pmrdemo_key"}
export PMR_DATA_ROOT=${PMR_DATA_ROOT:-"${PMR_HOME}/pmr2"}
export PMR_ZEO_BACKUP=${PMR_ZEO_BACKUP:-"${PMR_HOME}/backup"}

export ZOPE_INSTANCE_PORT=${ZOPE_INSTANCE_PORT:-"8280"}

chmod 600 "${DIR}/pmrdemo_key"

# XXX TODO upstream should implement some shell that sets this up
alias SSH_CMD="ssh -oStrictHostKeyChecking=no -oBatchMode=Yes -i \"${VBOX_PRIVKEY}\" root@${VBOX_IP}"

export BUILDOUT_ROOT="${PMR_HOME}/${BUILDOUT_NAME}"


restore_pmr2_backup () {
    # restore from backup
    SSH_CMD <<- EOF
	mkdir -p "${PMR_DATA_ROOT}"
	ssh-keyscan "${BACKUP_HOST}" >> ~/.ssh/known_hosts 2>/dev/null
	EOF

    # using a standalone ssh agent to forward the keypair into the
    # target machine without copying any actual secrets onto its
    # filesystem.
    eval "$(ssh-agent -s)"

    ssh-add "${PMR_DATA_READ_KEY}"
    SSH_CMD -A <<- EOF
	rsync -av ${BACKUP_USER}@${BACKUP_HOST}: "${PMR_DATA_ROOT}"
	EOF
    ssh-add -D

    # terminate the standalone ssh agent.
    ssh-agent -k

    # the zeo backup is kept as a backup subdir in the full data backup;
    # move that back up one level to keep separated from dvcs repos.

    SSH_CMD <<- EOF
	/etc/init.d/pmr2.instance stop
	/etc/init.d/pmr2.zeoserver stop
	chown -R ${ZOPE_USER}:${ZOPE_USER} $PMR_DATA_ROOT
	mv ${PMR_DATA_ROOT}/backup ${PMR_ZEO_BACKUP}
	cd "${BUILDOUT_ROOT}"
	su ${ZOPE_USER} -c \
	    "bin/repozo -R -r \"${PMR_ZEO_BACKUP}\" -o var/filestorage/Data.fs"
	EOF

    POSTINSTALL_REINDEX="server/postinstall_reindex.sh"

    envsubst \$ZOPE_USER,\$PMR_HOME < "${POSTINSTALL_REINDEX}" | SSH_CMD
}


if [ $# = 0 ]; then
    # enable all local commands/shortcuts
    INSTALL_PMR2=server/install_pmr2.sh
    INSTALL_MORRE=server/install_morre.sh
    INSTALL_BIVES=server/install_bives.sh
    SETUP_PRODUCTION=server/install_production_services.sh
    RESTORE_BACKUP=1
fi

while [[ $# > 0 ]]; do
    opt="$1"
    case "${opt}" in
        --install-pmr2)
            INSTALL_PMR2=server/install_pmr2.sh
            shift
            ;;
        --install-morre)
            INSTALL_MORRE=server/install_morre.sh
            shift
            ;;
        --install-bives)
            INSTALL_BIVES=server/install_bives.sh
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

# install PMR2
if [ ! -z "${INSTALL_PMR2}" ]; then
    envsubst \$DIST_SERVER,\$ZOPE_USER,\$PMR_HOME < "${INSTALL_PMR2}" | SSH_CMD
fi

# install Morre
if [ ! -z "${INSTALL_MORRE}" ]; then
    envsubst \$DIST_SERVER,\$JARS_SERVER,\$MORRE_USER,\$MORRE_HOME,\$NEO4J_VERSION < "${INSTALL_MORRE}" | SSH_CMD
fi

# install Bives
if [ ! -z "${INSTALL_BIVES}" ]; then
    envsubst \$DIST_SERVER,\$TOMCAT_VERSION,\$TOMCAT_USER < "${INSTALL_BIVES}" | SSH_CMD
fi

# install and setup for production
if [ ! -z "${SETUP_PRODUCTION}" ]; then
    envsubst \${BUILDOUT_NAME},\$HOST_FQDN,\$BUILDOUT_ROOT,\$ZOPE_INSTANCE_PORT,\$SITE_ROOT < "${SETUP_PRODUCTION}" | SSH_CMD
fi

# restore backup
if [ ! -z "${RESTORE_BACKUP}" ]; then
    if [ -z "${PMR_DATA_READ_KEY}" ]; then
        echo "skipping backup restore; PMR_DATA_READ_KEY undefined"
    else
        restore_pmr2_backup
    fi
fi


# XXX make this cleanup run regardless.
SSH_CMD /etc/init.d/net.eth1 stop
