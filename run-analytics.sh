#!/bin/bash

set -e

SCRIPT_HOME=$HOME/work/analytics-reporter

umask 022

. /etc/os-release

if [ "$ID" = "ubuntu" ]; then
    export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
    export SSL_CERT_DIR="/etc/ssl/certs"
fi

cd $SCRIPT_HOME
git pull

if [ -f "$HOME/.rvm/scripts/rvm" ]; then
	source "$HOME/.rvm/scripts/rvm"
fi

./storage-reporter.rb "$@"

sleep 5

./analytics-reporter.rb "$@"

# unset rvm environment
{ type -t __rvm_unload >/dev/null; } && __rvm_unload

# unset other ruby vars
unset GEM_HOME
unset GEM_PATH
unset RUBY_VERSION

sleep 5

source "$HOME/venv/analytics/bin/activate"

./analytics-by-location-v4.py "$@"

deactivate
