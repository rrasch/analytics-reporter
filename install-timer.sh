#!/bin/bash

set -eu

SYSTEMD_DIR=$HOME/.config/systemd/user

SYSTEMCTL="systemctl --user --no-pager"

APP_HOME=$(dirname -- "$(readlink -f -- "$0")")

export SYSTEMD_PAGER=""

umask 022

set +e
$SYSTEMCTL stop analytics.timer 2>/dev/null
$SYSTEMCTL disable analytics.service analytics.timer 2>/dev/null
set -e

install -m 0644 -D -t $SYSTEMD_DIR $APP_HOME/analytics.{timer,service}

perl -pi -e "s,<APP_HOME>,$APP_HOME," $SYSTEMD_DIR/analytics.service
perl -pi -e "s,<LOGDIR>,$HOME," $SYSTEMD_DIR/analytics.service

systemd-analyze verify $SYSTEMD_DIR/analytics.*

$SYSTEMCTL daemon-reload

$SYSTEMCTL enable analytics.service analytics.timer
$SYSTEMCTL start analytics.timer 
$SYSTEMCTL --full status analytics.timer

loginctl enable-linger
