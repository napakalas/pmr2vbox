#!/bin/sh
# XXX this script assumes vboxtools has been used to "activate" a
# VirtualBox control environment.

set -e
# XXX these MUST be read from some configuration file
# export BACKUP_HOST=
# export BACKUP_USER=
# export BACKUP_DATA_PATH=
# export BACKUP_ZEO_PATH=
# export DIST_SERVER=
# export JARS_SERVER=
# export NEO4J_VERSION=neo4j-community-3.0.1
# export TOMCAT_VERSION=8.5
# # TODO figure out usage of TOMCAT_SUFFIX and whether it is applicable
# # without complicating things.
# export TOMCAT_USER=tomcat
# # XXX PMR_HOME should be configured
# # XXX should also apply a step to attach a separate drive
# export PMR_HOME=
# export MORRE_HOME=
# export PMR_DATA_KEY=
# export PMR_ZEO_KEY=
# export PMR_DATA_ROOT=
# export PMR_ZEO_BACKUP=
# export ZOPE_USER=zope
# export MORRE_USER=zope


# XXX TODO upstream should implement some shell that sets this up
alias SSH_CMD="ssh -oStrictHostKeyChecking=no -oBatchMode=Yes -i \"${VBOX_PRIVKEY}\" root@${VBOX_IP}"


restore_pmr2_backup () {
    # XXX consider `exec ssh-agent $SCRIPT` to ensure ssh-agent dies
    eval "$(ssh-agent -s)"
    # restore from backup
    # XXX figure out how to better add the keyscan results.
    SSH_CMD <<- EOF
	mkdir -p "${PMR_DATA_ROOT}"
	mkdir -p "${PMR_ZEO_BACKUP}"
	ssh-keyscan "${BACKUP_HOST}" >> ~/.ssh/known_hosts 2>/dev/null
	EOF

    ssh-add "${PMR_DATA_KEY}"
    SSH_CMD -A <<- EOF
	rsync -av ${BACKUP_USER}@${BACKUP_HOST}:"${BACKUP_DATA_PATH}" \
	    "${PMR_DATA_ROOT}"
	EOF
    ssh-add -d "${PMR_DATA_KEY}"

    ssh-add "${PMR_ZEO_KEY}"
    SSH_CMD -A <<- EOF
	rsync -av ${BACKUP_USER}@${BACKUP_HOST}:"${BACKUP_ZEO_PATH}" \
	    "${PMR_ZEO_BACKUP}"
	EOF
    ssh-add -d "${PMR_ZEO_KEY}"

    SSH_CMD <<- EOF
	chown -R ${ZOPE_USER}:${ZOPE_USER} $PMR_DATA_ROOT
	chown -R ${ZOPE_USER}:${ZOPE_USER} $PMR_ZEO_BACKUP
	cd "${PMR_HOME}/pmr2.buildout"
	su ${ZOPE_USER} -c \
	    "bin/repozo -R -r \"${PMR_ZEO_BACKUP}\" -o var/filestorage/Data.fs"
	EOF
    ssh-agent -k

    # TODO use low level zopepy python code to trigger re-indexing
    # of external resources (i.e. morre and virtuoso)
}


if [ $# = 0 ]; then
    # enable all local commands/shortcuts
    INSTALL_PMR2=server/install_pmr2.sh
    INSTALL_MORRE=server/install_morre.sh
    INSTALL_BIVES=server/install_bives.sh
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

# install Bives
if [ ! -z "${RESTORE_BACKUP}" ]; then
    restore_pmr2_backup
fi


# XXX make this cleanup run regardless.
SSH_CMD /etc/init.d/net.eth1 stop
