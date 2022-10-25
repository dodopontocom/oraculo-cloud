#!/usr/bin/env bash

export BASEDIR="$(cd $(dirname ${BASH_SOURCE[0]}) >/dev/null 2>&1 && pwd)"

oci session authenticate
terraform destroy --auto-approve
terraform apply --auto-approve

tfstate="${BASEDIR}/../mainnet/terraform.tfstate"
ext_ip=$(cat ${tfstate} | jq -r '.outputs.instance_pub_ip.value')
echo "${ext_ip}" > ${HOME}/external.ip

scp -o "StrictHostKeyChecking=no" ${HOME}/external.ip ubuntu@${ext_ip}:/home/ubuntu/