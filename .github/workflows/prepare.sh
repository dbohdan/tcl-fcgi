#! /bin/sh
set -eu

if [ "$(uname)" = Linux ]; then
    apt-get install -y nginx tcl tcllib
fi

if [ "$(uname)" = Darwin ]; then
    brew install nginx tcl-tk
fi


if [ "$(uname)" = FreeBSD ]; then
    pkg install -y nginx tcl86 tcllib
    ln -s /usr/local/bin/tclsh8.6 /usr/local/bin/tclsh
fi

if [ "$(uname)" = NetBSD ]; then
    pkgin -y install nginx tcl tcllib
fi

if [ "$(uname)" = OpenBSD ]; then
    pkg_add -I nginx tcl%8.6 tcllib
    ln -s /usr/local/bin/tclsh8.6 /usr/local/bin/tclsh
fi
