#!/usr/bin/env bash
set -e

DARLENE1_TOKEN=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/DARLENE1_TOKEN)
TELEGRAM_ID=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/TELEGRAM_ID)

### content


###

##############################################################################
############# Watch blockchain syncronization #############
##############################################################################
#message=$(uptime -p)
#curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"
#while [[ $(ls) ]]; do
#    message="${HOSTNAME} - sync progress: "
#    message+=$(ls)
#    curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"
#    sleep 1200
#done
message=$(uptime -p)
message+=$(cat /home/ubuntu/hi.txt)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"