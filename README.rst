PMR2 VirtualBox Image generator
===============================

Instead of just providing documentation on how to buidl the whole thing,
it would be useful to also have a working script that will build the
whole thing.  Following was the original documentation done for Gentoo.


PMR2 base system build instructions for Gentoo
----------------------------------------------

Start the process by either following the base_image build instructions
or start from a clone of it.

The following instructions assumes the usage of the root user account.


System level prerequisites
~~~~~~~~~~~~~~~~~~~~~~~~~~

As the man portage tree no longer has the ebuilds for virutoso, and that
it is easier just to have this available as a system level dependency,
create a portage repository configuration with the following contents at
``/etc/portage/repos.conf/pmr2-overlay.conf``:

.. code:: ini

    [pmr2-overlay]
    location = /usr/local/portage/pmr2-overlay
    sync-type = git
    sync-uri = https://github.com/PMR2/portage.git
    priority = 50
    auto-sync = Yes

Emerge sync the repo (ensure that dev-vcs/git was already installed) and
then

.. code::

    # emerge --sync pmr2-overlay

There are various system level dependencies required for the full build
to succeed.

Plone uses the 'Pillow' image library, following are required

    media-libs/libjpeg-turbo
        the minimum required package.
    media-libs/openjpeg
        extra package for the jpeg2k support, which also depends on
        other image libraries that Pillow can use (e.g. png)

For pygit2

    dev-python/cffi
        the bindings to libgit2 require this

For virtuoso

    dev-db/virtuoso-server::pmr2-overlay
        the base server.
    dev-db/virtuoso-odbc::pmr2-overlay
        the virtuoso unix odbc driver
    dev-db/unixODBC
        provides the actual implementation for the unix odbc.

For CellML API

    dev-util/cmake
        cmake is the build system
    net-misc/omniORB
        needed to turn the .idl interface files into .hxx c++ header
        files.

For build environment isolation

    dev-python/virtualenv
        for setting up a python virtualenv.

Install the various system level dependencies as specified above so that
the buildout command will work for PMR.

.. code::

    # emerge --ask net-misc/omniORB dev-util/cmake dev-db/unixODBC \
        dev-python/cffi media-libs/openjpeg media-libs/libjpeg-turbo \
        dev-python/virtualenv \
        dev-db/virtuoso-odbc::pmr2-overlay \
        dev-db/virtuoso-server::pmr2-overlay

Also ensure that python2 is activated for the duration of the build.
This is to ensure that the various naive build scripts that make use of
system Python with Python 2 syntax.

.. code::

    # eselect python set python2.7


Installation of the PMR2 application stack.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Need to have zope user added and switch to that for the application
stack.

.. code::

    # useradd -m -k /etc/skel zope
    # su - zope
    $ cd ~

Continue with the build process as the zope user.

Clone the repository and build it normally.  As Mercurial support is no
longer needed on production, consider using the buildout-git.cfg

.. code::

    $ git clone https://github.com/PMR2/pmr2.buildout
    $ cd pmr2.buildout
    $ python bootstrap.py
    $ bin/buildout -c buildout-git.cfg
