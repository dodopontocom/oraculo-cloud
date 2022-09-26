#!/usr/bin/env bash

export COLD_PAY_ADDR=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/COLD_PAY_ADDR)

DARLENE1_TOKEN=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/attributes/DARLENE1_TOKEN)
TELEGRAM_ID=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/attributes/TELEGRAM_ID)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Hello from ${HOSTNAME}"

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y git jq bc make automake rsync htop \
    build-essential pkg-config libffi-dev libgmp-dev \
    libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev \
    make g++ wget libncursesw5 libtool autoconf libncurses-dev libtinfo5

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - apt upgrade done"