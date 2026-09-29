#!/bin/bash
LOGFILE="/var/log/syslog"
[ ! -f "$LOGFILE" ] && LOGFILE="/var/log/auth.log"

if [ ! -f "$LOGFILE" ]; then
    echo "Ошибка: лог-файл $LOGFILE не найден" >&2
    exit 1
fi

grep -aEi "error|fail" "$LOGFILE" > report.txt
echo "Готово: report.txt содержит $(wc -l < report.txt) строк"
