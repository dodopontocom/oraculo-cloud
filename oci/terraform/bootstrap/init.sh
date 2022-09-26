#!/usr/bin/env bash

export COLD_PAY_ADDR=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/COLD_PAY_ADDR)