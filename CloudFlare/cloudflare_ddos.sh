#!/bin/bash

API=""
EMAIL=""
ACCOUNT_ID=""

NginxSession=$(curl -s 127.0.0.1:50080/nginx_status | grep "Active connections:" | awk '{print $3}')
StatusProtectionFile=/tmp/ddos.txt

function CheckStatusProtection() {
     curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ACCOUNT_ID/settings" \
          -H "X-Auth-Email: $EMAIL" \
          -H "X-Auth-Key: $API" \
          -H "Content-Type: application/json" | jq '.result[42].value'
}

function EnableDdosProtection() {
     curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ACCOUNT_ID/settings/security_level" \
          -H "X-Auth-Email: $EMAIL" \
          -H "X-Auth-Key: $API" \
          -H "Content-Type: application/json" \
          --data '{"value":"under_attack"}'
}

function DisableDdosProtection() {
     curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ACCOUNT_ID/settings/security_level" \
          -H "X-Auth-Email: $EMAIL" \
          -H "X-Auth-Key: $API" \
          -H "Content-Type: application/json" \
          --data '{"value":"medium"}'
}

DdosProtectionFile=$(cat $StatusProtectionFile)
if [ $NginxSession -ge 550 ]; then
     if [ "$DdosProtectionFile" == "medium" ]; then
          EnableDdosProtection
          echo "under_attack" >$StatusProtectionFile
     fi
elif [ $NginxSession -lt 500 ]; then
     if [ "$DdosProtectionFile" == "under_attack" ]; then
          DisableDdosProtection
          echo "medium" >$StatusProtectionFile
     fi
fi
