PMR2 VirtualBox Image generator
===============================

Instead of just providing documentation on how to buidl the whole thing,
it would be useful to also have a working script that will build the
whole thing.  Following was the original documentation done for Gentoo.

Do note that this relies on
`vboxtools <https://github.com/metatoaster/vboxtools>`_.  Documentation
on how these scripts actually work (and how to make them work) to come.
In brief, follow the instructions on creating a base Gentoo system, and
then call ``activatevm`` to spawn a new bash session.  Before executing
``gentoo/script.sh``, ensure that all relevant variables are filled with
a defined value.

Roughly speaking, the whole build process may be achieved by doing:

.. code-block:: console

    git clone https://github.com/metatoaster/vboxtools.git
    git clone https://github.com/PMR2/pmr2vbox.git
    vboxtools/bin/createvm-gentoo -U -n pmr_demo
    # go make a snack while the base system builds
    # optionally once that is done, vboxtools/bin/exportvm a copy of it
    vboxtools/bin/activatevm pmr_demo
    pmr2vbox/gentoo/script.sh

Once all that is done, it should result in a VirtualBox instance that
contain an instance with a base set of models.
