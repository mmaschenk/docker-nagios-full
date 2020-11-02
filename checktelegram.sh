#!/bin/sh

if [ -z "$BOT_ADMIN_NOTIFY" ] || [ -z "$BOT_TOKEN" ] || [ -z "$BOT_GROUP_NOTIFY" ] ; then
  cat << CONFIG_WRONG
Your configuration is in error.

Either the variable "BOT_TOKEN", "BOT_GROUP_NOTIFY" or "BOT_ADMIN_NOTIFY" has 
not been set to a value. These variables are necessary to have telegram-
notifications working.

Nagios will startup, but telegram notifications will not work in your system.
CONFIG_WRONG
else
  echo "Telegram config check passed"
fi
