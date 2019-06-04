This branch is used to build the latest verison (as of bionic) of
network-manager as a snap meant to run on Ubuntu Core. This branch
is a fork of the bionic branch, which means by default patches are
not applied.

To build, you need an 18.04 system with snapcraft installed.

When snapcraft is run, the patches in debian/patches are applied
prior to the build stage.
