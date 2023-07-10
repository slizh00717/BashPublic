#!/bin/bash

HOST=$1
DATE_TODAY=$(date)

INFO_SSL=$(echo | openssl s_client -servername $HOST -connect $HOST:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
ENED_SSL=$(echo $INFO_SSL | grep "notAfter=" | sed 's/notAfter\=//')

ENED_SSL=${ENED_SSL#*=}
MONTH_ENDING=$(echo $ENED_SSL | awk {'print $1'})
DATE_ENDING=$(echo $ENED_SSL | awk {'print $2'})

check_month=$(date --date '+7 day' | awk {'print $3'})
check_date=$(date --date '+7 day' | awk {'print $2'})

if [ "$MONTH_ENDING" != "$check_month" ]; then
    echo "Месяц не совпадает"
fi
if [ $DATE_ENDING -eq $check_date ]; then
    echo "Дата совпадает"
fi

echo $MONTH_ENDING
echo $check_month
echo $DATE_ENDING
echo $check_date
