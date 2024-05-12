#! /bin/sh
set -eu

if [ "$(uname)" = NetBSD ]; then
    PATH=/usr/pkg/sbin:$PATH
fi

if [ "$(uname)" = OpenBSD ]; then
    PATH=/usr/local/sbin:$PATH
fi

make test
