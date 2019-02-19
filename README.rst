PMR2 VirtualBox Image generator (OSX, MacOS Mojave 10.14.3)
===========================================================

    Instead of just providing documentation on how to build the whole thing,
    it would be useful to also have a working script that will build the
    whole thing.  Following was the original documentation done for Gentoo.

    Do note that this relies on
    `vboxtools <https://github.com/metatoaster/vboxtools>`_.  Documentation
    on how these scripts actually work (and how to make them work) to come.
    In brief, follow the instructions on creating a base Gentoo system, and
    then call ``activatevm`` to spawn a new bash session.  Before executing
    ``gentoo/script.sh``, ensure that all relevant variables are filled with
    a defined value.

In order to implement the VirtualBox Image in MacOS, there are two conditions 
to be considered:

- MacOS is built based on Unix which is similar to Linux but they 
  still have a number of differences
- Bash version in MacOS is 3.2.x which does not support some commands 
  in the cloned scripts

Therefore, before continuing to the next process, it is necessary to prepare
the MacOS environment:

- MacOS usually is not equipped with wget so firstly is installing wget

.. code-block:: console

    $ ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    $ brew install wget --with-libressl

- Since MacOS is based on Unix,therefore, it's sed command behaves slightly different
  to Linux. As an alternative, we can install gsed which operates as same as sed in Linux

.. code-block:: console

    $ brew install gnu-sed --with-default-names
 
- The date command in MacOS is also has different behaviour so it is replaced by gdate.
  gdate is included in coreutils
  
.. code-block:: console

    $ brew install coreutils
    
- Installing Bash version > 4.0

.. code-block:: console

    $ ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null 2> /dev/null
    $ brew install bash
    
- Configure the terminal to the new bash

.. code-block:: console

    $ sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
    $ chsh -s /usr/local/bin/bash

Roughly speaking, the whole build process may be achieved by doing:

.. code-block:: console

    $ git clone https://github.com/metatoaster/vboxtools.git
    Cloning into 'vboxtools'...
    ...
    $ git clone https://github.com/PMR2/pmr2vbox.git
    Cloning into 'pmr2vbox'...
    ...
    $ # the create-gentoo command defaults to checking for the correct
    $ # signature of the downloaded images; the following commands will
    $ # acquire the right signatures; please verify this against the
    $ # Gentoo installation handbook linked in the documentation on the
    $ # landing page of the vboxtools repository

This point is describing the modification conducted to the original scripts. 
Otherwise, you may continue to the next command directly.

- File: vboxtools/bin/createvm-gentoo

    - Replace: #!/bin/bash, with: #!/usr/bin/env bash
      without replacement the script is pointing to the old bash

- File: vboxtools/lib/gentoo

    - Replace: #!/bin/bash, with: #!/usr/bin/env bash
    - Replace: date=$(date -u +%Y%m%d --date="$day day ago")
      with: date=$(gdate -u +%Y%m%d --date="$day day ago")

- File: vboxtools/lib/utils

    - Replace all sed command with gsed
    - Replace the body of set_vm_mac_ip () with:
      
      .. code-block:: console
      
          name="$1"
          net="$2"
          VBOX_MAC=$(
              VBoxManage showvminfo "${name}" | grep "${net}" | \
              gsed -r 's/.*MAC: ([0-9A-F]*).*/\1/' | gsed -r 's/(.{2})/:\1/g' | \
              cut -b 2- | sed 's/0\([0-9A-Za-z]\)/\1/g'
          )
          info "mac is $VBOX_MAC"
          VBOX_IP=$(
              arp -an | grep -i ${VBOX_MAC} | cut -d'(' -f2 | cut -d')' -f1
          )
          if [ -z $VBOX_IP ]; then
              warn "failed to derive IP"
              return 1
          fi
          info "ip is $VBOX_IP"
          export VBOX_MAC=$VBOX_MAC
          export VBOX_IP=$VBOX_IP

.. code-block:: console

    $ gpg --keyserver hkp://keys.gnupg.net --recv-keys 0xBB572E0E2D182910
    gpg: requesting key 0xBB572E0E2D182910 from hkp server ...
    ...
    $ gpg --keyserver hkp://keys.gnupg.net --recv-keys 0xDB6B8C1F96D8BF6D
    gpg: requesting key 0xDB6B8C1F96D8BF6D from hkp server ...
    ...
    $ # create the vm; this process will take a while, a snack and/or
    $ # drink is suggested.
    $ vboxtools/bin/createvm-gentoo -U -n pmr_demo
    2018-10-04 16:00:00 URL:http://distfiles.gentoo.org/...
    ...
    gpg: Signature made Thu 04 Oct 2018 13:51:26 NZDT
    gpg:                using RSA key E1D6ABB63BFCFB4BA02FDF1CEC590EEAC9189250
    gpg: Good signature from "Gentoo ebuild repository signing key ...
    ...
    completing installation, removing installation script
    Waiting for VM "pmr_demo" to power on...
    VM "pmr_demo" has been successfully started.
    Once the VM is fully booted, connect to it with the following command:
        vboxtools/bin/connectvm "pmr_demo"
    ...
    $ # installation completed, but instead of connecting to the VM once
    $ # it fully boots up, it may be activated using:
    $ vboxtools/bin/activatevm pmr_demo
    spawning new shell (ctrl-d to exit)
    $ # the shell should actually be prefixed with the name of the VM
    $ # the prompt should appear as `(pmr_demo) $`
    $ pmr2vbox/gentoo/script.sh
     * Bringing up interface eth1
     *   dhcp ...
    ...

Once all that is done, it should result in a VirtualBox instance that
contain an instance with a base set of models.  The instance may be
opened with a web browser; one possible method is:

.. code-block:: console

    $ xdg-open http://${VBOX_IP}:8280/pmr

Alternatively, replace ``xdg-open`` with ``echo`` and then copy/paste
the URL to the address bar of a web browser.
