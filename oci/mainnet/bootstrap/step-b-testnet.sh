#!/usr/bin/env bash
set -e

step-b-testnet

#Critical Key Security Reminder: The only stake pool keys and certs that are required to run a stake pool are
#those required by the block producer. Namely, the following three files.
###
### On block producer node
###
#KES=${NODE_HOME}/keys/kes.skey
#VRF=${NODE_HOME}/keys/vrf.skey
#CERT=${NODE_HOME}/keys/node-op.cert

[[ -d ${NODE_HOME}/keys ]] || mkdir -p ${NODE_HOME}/keys
[[ -d ${NODE_HOME}/cold ]] || mkdir -p ${NODE_HOME}/cold
KEYS="${NODE_HOME}/keys"
COLD="${NODE_HOME}/cold"

# building the payment and stake adresses
if [[ "$(cardano-cli query tip --testnet-magic 1 | jq -r '.syncProgress' | cut -d'.' -f1)" -eq "100" ]]; then
  cardano-cli query protocol-parameters \
    --testnet-magic 1 \
    --out-file ${NODE_HOME}/params.json

  cardano-cli address key-gen \
    --verification-key-file ${COLD}/payment.vkey \
    --signing-key-file ${COLD}/payment.skey

  cardano-cli stake-address key-gen \
    --verification-key-file ${COLD}/stake.vkey \
    --signing-key-file ${COLD}/stake.skey

  cardano-cli stake-address build \
    --stake-verification-key-file ${COLD}/stake.vkey \
    --out-file ${KEYS}/stake.addr \
    --testnet-magic 1

  cardano-cli address build \
    --payment-verification-key-file ${COLD}/payment.vkey \
    --stake-verification-key-file ${COLD}/stake.vkey \
    --out-file ${KEYS}/paymentwithstake.addr \
    --testnet-magic 1

  cardano-cli query utxo \
    --address $(cat ${KEYS}/paymentwithstake.addr) \
    --testnet-magic 1
  else
    echo "blockchain not synced"
fi

# Registering Stake Address
cardano-cli stake-address registration-certificate \
    --stake-verification-key-file ${COLD}/stake.vkey \
    --out-file ${COLD}/stake.cert

currentSlot=$(cardano-cli query tip --testnet-magic 1 | jq -r '.slot')
echo Current Slot: $currentSlot

cardano-cli query utxo \
    --address $(cat ${KEYS}/paymentwithstake.addr) \
    --testnet-magic 1 > fullUtxo.out

tail -n +3 fullUtxo.out | sort -k3 -nr > balance.out

cat balance.out

tx_in=""
total_balance=0
while read -r utxo; do
    in_addr=$(awk '{ print $1 }' <<< "${utxo}")
    idx=$(awk '{ print $2 }' <<< "${utxo}")
    utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
    total_balance=$((${total_balance}+${utxo_balance}))
    echo TxHash: ${in_addr}#${idx}
    echo ADA: ${utxo_balance}
    tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
done < balance.out
txcnt=$(cat balance.out | wc -l)
echo Total ADA balance: ${total_balance}
echo Number of UTXOs: ${txcnt}

#Registering a stake address requires a deposit of 2000000 lovelace
stakeAddressDeposit=$(cat ${NODE_HOME}/params.json | jq -r '.stakeAddressDeposit')
echo stakeAddressDeposit : $stakeAddressDeposit

#### fund the adress before continuing
exit -1

cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${KEYS}/paymentwithstake.addr)+0 \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee 0 \
    --out-file ${KEYS}/tx.tmp \
    --certificate ${COLD}/stake.cert

fee=$(cardano-cli transaction calculate-min-fee \
    --tx-body-file ${KEYS}/tx.tmp \
    --tx-in-count ${txcnt} \
    --tx-out-count 1 \
    --testnet-magic 1 \
    --witness-count 2 \
    --byron-witness-count 0 \
    --protocol-params-file ${NODE_HOME}/params.json | awk '{ print $1 }')
echo fee: $fee

txOut=$((${total_balance}-${stakeAddressDeposit}-${fee}))
echo Change Output: ${txOut}

cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${KEYS}/paymentwithstake.addr)+${txOut} \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee ${fee} \
    --certificate-file ${COLD}/stake.cert \
    --out-file ${KEYS}/tx.raw

cardano-cli transaction sign \
    --tx-body-file ${KEYS}/tx.raw \
    --signing-key-file ${COLD}/payment.skey \
    --signing-key-file ${COLD}/stake.skey \
    --testnet-magic 1 \
    --out-file ${KEYS}/tx.signed

cardano-cli transaction submit \
    --tx-file ${KEYS}/tx.signed \
    --testnet-magic 1

# Block producer keys
cardano-cli node key-gen-KES \
    --verification-key-file ${KEYS}/kes.vkey \
    --signing-key-file ${KEYS}/kes.skey

cardano-cli node key-gen \
    --cold-verification-key-file ${COLD}/node.vkey \
    --cold-signing-key-file ${COLD}/node.skey \
    --operational-certificate-issue-counter ${COLD}/node-op.counter

slotsPerKESPeriod=$(cat ${NODE_HOME}/shelley-genesis.json | jq -r '.slotsPerKESPeriod')
echo slotsPerKESPeriod: ${slotsPerKESPeriod}

slotNo=$(cardano-cli query tip --testnet-magic 1 | jq -r '.slot')
echo slotNo: ${slotNo}

kesPeriod=$((${slotNo} / ${slotsPerKESPeriod}))
echo kesPeriod: ${kesPeriod}
startKesPeriod=${kesPeriod}
echo startKesPeriod: ${startKesPeriod}

cardano-cli node issue-op-cert \
    --kes-verification-key-file ${KEYS}/kes.vkey \
    --cold-signing-key-file ${COLD}/node.skey \
    --operational-certificate-issue-counter ${COLD}/node-op.counter \
    --kes-period ${startKesPeriod} \
    --out-file ${COLD}/node-op.cert

cardano-cli node key-gen-VRF \
    --verification-key-file ${KEYS}/vrf.vkey \
    --signing-key-file ${KEYS}/vrf.skey

chmod 400 ${KEYS}/vrf.skey
cp ${COLD}/node-op.cert ${KEYS}/node-op.cert
cp ${KEYS}/vrf.skey ${COLD}/vrf.skey
cp ${KEYS}/vrf.vkey ${COLD}/vrf.vkey

sudo systemctl stop cardano-node

#for i in $(ls ${NODE_HOME}/keys/kes.skey ${NODE_HOME}/keys/vrf.skey ${NODE_HOME}/keys/node-op.cert); do cp ${i} ${NODE_HOME}; done
# then copy rest to off line device

cat > ${NODE_HOME}/_startNode.sh << EOF
#!/bin/bash

DIRECTORY=${NODE_HOME}

PORT=3000
HOSTADDR=0.0.0.0
TOPOLOGY=\${DIRECTORY}/topology.json
DB_PATH=\${DIRECTORY}/db
SOCKET_PATH=\${DIRECTORY}/db/socket
CONFIG=\${DIRECTORY}/config.json

#KES=\${DIRECTORY}/kes.skey
#VRF=\${DIRECTORY}/vrf.skey
#CERT=\${DIRECTORY}/node-op.cert

/usr/local/bin/cardano-node run +RTS -N -A16m -qg -qb -RTS --topology \${TOPOLOGY} --database-path \${DB_PATH} --socket-path \${SOCKET_PATH} --host-addr \${HOSTADDR} --port \${PORT} --config \${CONFIG} --shelley-kes-key \${KES} --shelley-vrf-key \${VRF} --shelley-operational-certificate \${CERT}
EOF

mv ${NODE_HOME}/startNode.sh ${NODE_HOME}/startNode.sh_bkp
mv ${NODE_HOME}/_startNode.sh ${NODE_HOME}/startNode.sh

cat > ${NODE_HOME}/_topology.json << EOF
{
  "LocalRoots": {
    "groups": [
      {
        "localRoots": {
          "accessPoints": [],
          "advertise": false
        },
        "valency": 1
      }
    ]
  },
  "PublicRoots": [
    {
      "publicRoots": {
        "accessPoints": [
          {
            "address": "preprod-node.world.dev.cardano.org",
            "port": 30000
          }
        ],
        "advertise": false
      }
    }
  ],
  "useLedgerAfterSlot": 4642000
}
EOF

sudo systemctl start cardano-node

#wait 3 minutes
sleep 180

# Registering Stake Pool
cat > ${NODE_HOME}/poolMetaData.json << EOF
{
"name": "Yet Another Cool Pool",
"description": "A Cardano Ecosystem Believer",
"ticker": "YACP",
"homepage": "https://github.com/dodopontocom/yacp"
}
EOF

cardano-cli stake-pool metadata-hash --pool-metadata-file ${NODE_HOME}/poolMetaData.json > ${NODE_HOME}/poolMetaDataHash.txt
cardano-cli stake-pool metadata-hash --pool-metadata-file <(curl -s -L https://raw.githubusercontent.com/dodopontocom/yacp/develop/poolMetaData.json)
cat ${NODE_HOME}/poolMetaDataHash.txt

minPoolCost=$(cat ${NODE_HOME}/params.json | jq -r .minPoolCost)
echo minPoolCost: ${minPoolCost}

cardano-cli stake-pool registration-certificate \
    --cold-verification-key-file ${COLD}/node.vkey \
    --vrf-verification-key-file ${COLD}/vrf.vkey \
    --pool-pledge 900000000 \
    --pool-cost 340000000 \
    --pool-margin 0.009 \
    --pool-reward-account-verification-key-file ${COLD}/stake.vkey \
    --pool-owner-stake-verification-key-file ${COLD}/stake.vkey \
    --testnet-magic 1 \
    --pool-relay-ipv4 193.123.121.74 \
    --pool-relay-port 6000 \
    --metadata-url https://bit.ly/3eDFAx6 \
    --metadata-hash $(cat ${NODE_HOME}/poolMetaDataHash.txt) \
    --out-file ${COLD}/pool.cert

cp ${COLD}/pool.cert ${KEYS}/pool.cert

cardano-cli stake-address delegation-certificate \
    --stake-verification-key-file ${COLD}/stake.vkey \
    --cold-verification-key-file ${COLD}/node.vkey \
    --out-file ${COLD}/deleg.cert

cp ${COLD}/deleg.cert ${KEYS}/deleg.cert

currentSlot=$(cardano-cli query tip --testnet-magic 1 | jq -r '.slot')
echo Current Slot: $currentSlot

cardano-cli query utxo \
    --address $(cat ${KEYS}/paymentwithstake.addr) \
    --testnet-magic 1 > fullUtxo.out

tail -n +3 fullUtxo.out | sort -k3 -nr > balance.out

cat balance.out

tx_in=""
total_balance=0
while read -r utxo; do
    in_addr=$(awk '{ print $1 }' <<< "${utxo}")
    idx=$(awk '{ print $2 }' <<< "${utxo}")
    utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
    total_balance=$((${total_balance}+${utxo_balance}))
    echo TxHash: ${in_addr}#${idx}
    echo ADA: ${utxo_balance}
    tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
done < balance.out
txcnt=$(cat balance.out | wc -l)
echo Total ADA balance: ${total_balance}
echo Number of UTXOs: ${txcnt}

# deposit for a stake pool is currently 500000000 Lovelace
stakePoolDeposit=$(cat ${NODE_HOME}/params.json | jq -r '.stakePoolDeposit')
echo stakePoolDeposit: $stakePoolDeposit

cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${KEYS}/paymentwithstake.addr)+$(( ${total_balance} - ${stakePoolDeposit}))  \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee 0 \
    --certificate-file ${COLD}/pool.cert \
    --certificate-file ${COLD}/deleg.cert \
    --out-file ${KEYS}/tx.tmp

fee=$(cardano-cli transaction calculate-min-fee \
    --tx-body-file ${KEYS}/tx.tmp \
    --tx-in-count ${txcnt} \
    --tx-out-count 1 \
    --testnet-magic 1 \
    --witness-count 3 \
    --byron-witness-count 0 \
    --protocol-params-file ${NODE_HOME}/params.json | awk '{ print $1 }')
echo fee: $fee

txOut=$((${total_balance}-${stakePoolDeposit}-${fee}))
echo txOut: ${txOut}

cardano-cli transaction build-raw \
    ${tx_in} \
    --tx-out $(cat ${KEYS}/paymentwithstake.addr)+${txOut} \
    --invalid-hereafter $(( ${currentSlot} + 10000)) \
    --fee ${fee} \
    --certificate-file ${COLD}/pool.cert \
    --certificate-file ${COLD}/deleg.cert \
    --out-file ${KEYS}/tx.raw

cp ${KEYS}/tx.raw ${COLD}/tx.raw

cardano-cli transaction sign \
    --tx-body-file ${COLD}/tx.raw \
    --signing-key-file ${COLD}/payment.skey \
    --signing-key-file ${COLD}/node.skey \
    --signing-key-file ${COLD}/stake.skey \
    --testnet-magic 1 \
    --out-file ${COLD}/tx.signed

cp ${COLD}/tx.signed ${KEYS}/tx.signed
cardano-cli transaction submit \
    --tx-file ${KEYS}/tx.signed \
    --testnet-magic 1
