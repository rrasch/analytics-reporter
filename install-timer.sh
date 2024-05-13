#!/bin/bash

set -eu

SYSTEMD_DIR=$HOME/.config/systemd/user

SYSTEMCTL="systemctl --user --no-pager"

# APP_HOME=$HOME/work/analytics-reporter
APP_HOME=$(dirname -- "$(readlink -f -- "$0")")

install -m 0644 $APP_HOME/analytics.{timer,service} $SYSTEMD_DIR

perl -pi -e "s,<APP_HOME>,$APP_HOME," $SYSTEMD_DIR/analytics.service

set +e
$SYSTEMCTL stop analytics.timer
$SYSTEMCTL disable analytics.service analytics.timer
set -e

$SYSTEMCTL enable analytics.service analytics.timer
$SYSTEMCTL start analytics.timer 
$SYSTEMCTL list-timers
$SYSTEMCTL status 
