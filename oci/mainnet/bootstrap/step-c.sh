#!/usr/bin/env bash
set -e

#step-c

echo "0" > ${HOME}/currentRewardValue.txt

cat > ${HOME}/sendRewardBalanceAlert.sh << EOF
#!/usr/bin/env bash

file_check=\$(cat /home/ubuntu/currentRewardValue.txt)
DARLENE1_TOKEN=\$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/DARLENE1_TOKEN)
TELEGRAM_ID=\$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/TELEGRAM_ID)
message="!!! Reward Alert !!! Balance updated ---> "
reward_check=\$(cardano-cli query stake-address-info --address \$(cat \${NODE_HOME}/keys/stake.addr) --testnet-magic 1 | jq -r ".[0].rewardAccountBalance")

if [[ \${file_check} -ne \${reward_check} ]]; then
        message+="\${reward_check} Ada"
        echo "\${reward_check}" > /home/ubuntu/currentRewardValue.txt
        curl -s -X POST https://api.telegram.org/bot\${DARLENE1_TOKEN}/sendMessage -d chat_id=\${TELEGRAM_ID} -d text="\${message}"
else
        message="Balance update ---> \${file_check} Ada"
        curl -s -X POST https://api.telegram.org/bot\${DARLENE1_TOKEN}/sendMessage -d chat_id=\${TELEGRAM_ID} -d text="\${message}"
fi
EOF

chmod +x ${HOME}/sendRewardBalanceAlert.sh

cat > ${HOME}/simpleTx.sh << EOF
#!/usr/bin/env bash

currentSlot=""
magic="--mainnet"
currentSlot=\$(cardano-cli query tip \${magic} | jq -r .block)

echo currentSlot: \$currentSlot

amountToSend="\${1}"
echo amountToSend: \${amountToSend}
destinationAddress="\$(cat \${NODE_HOME}/keys/paymentwithstake.addr)"
echo destinationAddress: \${destinationAddress}
fromAddr="\$(cat \${NODE_HOME}/keys/payment.addr)"

cardano-cli query utxo --address \${fromAddr} \${magic} > fullUtxo.out
tail -n +3 fullUtxo.out | sort -k3 -nr > balance.out
cat balance.out

tx_in=""
total_balance=0
while read -r utxo; do
    in_addr=\$(awk '{ print \$1 }' <<< "\${utxo}")
    idx=\$(awk '{ print \$2 }' <<< "\${utxo}")
    utxo_balance=\$(awk '{ print \$3 }' <<< "\${utxo}")
    total_balance=\$((\${total_balance}+\${utxo_balance}))
    echo TxHash: \${in_addr}#\${idx}
    echo ADA: \${utxo_balance}
    tx_in="\${tx_in} --tx-in \${in_addr}#\${idx}"
done < balance.out

txcnt=\$(cat balance.out | wc -l)
echo Total ADA balance: \${total_balance}
echo Number of UTXOs: \${txcnt}

cardano-cli transaction build-raw \
    \${tx_in} \
    --tx-out \${fromAddr}+0 \
    --tx-out \${destinationAddress}+0 \
    --invalid-hereafter 99999999 \
    --fee 0 \
    --out-file tx.tmp

echo txcnt: \${txcnt}

cardano-cli query protocol-parameters \${magic} --out-file params.json
fee=\$(cardano-cli transaction calculate-min-fee \
    --tx-body-file tx.tmp \
    --tx-in-count \${txcnt} \
    --tx-out-count 2 \
    \${magic} \
    --witness-count 1 \
    --byron-witness-count 0 \
    --protocol-params-file params.json | awk '{ print \$1 }')
echo fee: \$fee

txOut=\$((\${total_balance}-\${fee}-\${amountToSend}))
echo Change Output: \${txOut}

echo tx_in: \$tx_in
cardano-cli transaction build-raw \
    \${tx_in} \
    --tx-out \${fromAddr}+\${txOut} \
    --tx-out \${destinationAddress}+\${amountToSend} \
    --invalid-hereafter 99999999 \
    --fee \${fee} \
    --out-file tx.raw

cardano-cli transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file \${NODE_HOME}/keys/payment.skey \
    \${magic} \
    --out-file tx.signed

cardano-cli transaction submit --tx-file tx.signed \${magic}
EOF

sudo chmod +x ${HOME}/simpleTx.sh

cat > ${HOME}/isLeader.sh << EOF
#!/usr/bin/env bash

#DARLENE1_TOKEN=\$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/DARLENE1_TOKEN)
#TELEGRAM_ID=\$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/TELEGRAM_ID)
#curl -s -X POST https://api.telegram.org/bot\${DARLENE1_TOKEN}/sendMessage -d chat_id=\${TELEGRAM_ID} -d text="\${message}"

#cardano-cli query leadership-schedule --testnet-magic 1 --genesis \${NODE_HOME}/shelley-genesis.json --stake-pool-id \$(cat \${NODE_HOME}/stakepoolid.txt) --vrf-signing-key-file \${NODE_HOME}/cold/vrf.skey --current
#cardano-cli query leadership-schedule --testnet-magic 1 --genesis \${NODE_HOME}/shelley-genesis.json --stake-pool-id \$(cat \${NODE_HOME}/stakepoolid.txt) --vrf-signing-key-file \${NODE_HOME}/cold/vrf.skey --next
EOF

sudo chmod +x ${HOME}/isLeader.sh

cat > ${HOME}/clean.sh << EOF
#!/usr/bin/env bash

CLEAN="\${HOME}/s"
CCLEAN="\${HOME}/ss"

KES=\${NODE_HOME}/keys/kes.skey
VRF=\${NODE_HOME}/keys/vrf.skey
CERT=\${NODE_HOME}/keys/node-op.cert
_KES=\${NODE_HOME}/cold/kes.skey
_VRF=\${NODE_HOME}/cold/vrf.skey
_CERT=\${NODE_HOME}/cold/node-op.cert

[[ -d \${CLEAN} ]] || mkdir -p \${CLEAN}
[[ -d \${CCLEAN} ]] || mkdir -p \${CCLEAN}

ls \${KES} && mv -f \${KES} \${NODE_HOME}
ls \${VRF} && mv -f \${VRF} \${NODE_HOME}
ls \${CERT} && mv -f \${CERT} \${NODE_HOME}

ls \${_KES} && mv -f \${_KES} \${NODE_HOME}
ls \${_VRF} && mv -f \${_VRF} \${NODE_HOME}
ls \${_CERT} && mv -f \${_CERT} \${NODE_HOME}

#backup
mv \${NODE_HOME}/keys/* \${CLEAN}
mv \${NODE_HOME}/cold/* \${CCLEAN}

cp \${NODE_HOME}/kes.skey \${CCLEAN}
cp \${NODE_HOME}/vrf.skey \${CCLEAN}
cp \${NODE_HOME}/node-op.cert \${CCLEAN}
EOF

sudo chmod +x ${HOME}/clean.sh