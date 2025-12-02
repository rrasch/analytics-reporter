#!/bin/bash

set -eu

SYSTEMD_DIR=$HOME/.config/systemd/user

SYSTEMCTL="systemctl --user --no-pager"

APP_HOME=$(dirname -- "$(readlink -f -- "$0")")

export SYSTEMD_PAGER=""

set +e
$SYSTEMCTL stop analytics.timer
$SYSTEMCTL disable analytics.service analytics.timer
set -e

install -m 0644 $APP_HOME/analytics.{timer,service} $SYSTEMD_DIR

perl -pi -e "s,<APP_HOME>,$APP_HOME," $SYSTEMD_DIR/analytics.service
perl -pi -e "s,<LOGDIR>,$HOME," $SYSTEMD_DIR/analytics.service

systemd-analyze verify $SYSTEMD_DIR/analytics.*

$SYSTEMCTL daemon-reload

$SYSTEMCTL enable analytics.service analytics.timer
$SYSTEMCTL start analytics.timer 
$SYSTEMCTL --full status analytics.timer

loginctl enable-linger
