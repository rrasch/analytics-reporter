#!/bin/bash

set -e

SCRIPT_HOME=$HOME/work/analytics-reporter

umask 022

cd $SCRIPT_HOME
git pull

source "$HOME/.rvm/scripts/rvm"

./storage-reporter.rb

sleep 5

./analytics-reporter.rb

# unset rvm environment
{ type -t __rvm_unload >/dev/null; } && __rvm_unload

# unset other ruby vars
unset GEM_HOME
unset GEM_PATH
unset RUBY_VERSION

sleep 5

source "$HOME/venv/analytics/bin/activate"

./analytics-by-location-v4.py

deactivate
