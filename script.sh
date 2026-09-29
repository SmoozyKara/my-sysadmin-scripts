#!/bin/bash
LOGFILE="/var/log/syslog"
[ ! -f "$LOGFILE" ] && LOGFILE="/var/log/auth.log"
grep -aEi "error|fail" "$LOGFILE" > report.txt
