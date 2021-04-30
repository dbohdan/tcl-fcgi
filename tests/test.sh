#! /bin/sh

set -e

# Variables.

fastcgi_port=9005
nginx_port=8085
temp_dir=/tmp/fcgi-test-nginx

if command -v nginx > /dev/null; then
    nginx=nginx
elif [ -e /usr/sbin/nginx ]; then
    nginx=/usr/sbin/nginx
else
    echo "error: can't find nginx"
    exit 1
fi

# Setup.

cd "$(dirname "$0")/.."

sed -i "
    s|listen .*|listen $nginx_port;|
    s|fastcgi_pass .*|fastcgi_pass 127.0.0.1:$fastcgi_port;|
" tests/nginx.conf

rm -rf "$temp_dir"
mkdir -m 0700 "$temp_dir"
mkdir "$temp_dir/proxy"

# Start the FastCGI example and Nginx.

TCLLIBDIR="$(pwd)/tcl-src"
export TCLLIBDIR
tclsh example/echo-tcl.tcl -port "$fastcgi_port" &
tclsh_pid="$!"

"$nginx" -c "$(pwd)/tests/nginx.conf" &
nginx_pid="$!"

# Clean up on exit.

trap '
    kill "$nginx_pid" "$tclsh_pid" || true
    sleep 1
    rm -rf "$temp_dir"
' EXIT INT TERM

# Wait and test.

sleep 2

curl --fail --silent "http://127.0.0.1:$nginx_port/?hello=world" \
| awk '/QUERY_STRING/ { print $0; exit !match($0, /hello=world/) }'
