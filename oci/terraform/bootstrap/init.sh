#!/usr/bin/env bash
set -e

COLD_PAY_ADDR=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/COLD_PAY_ADDR)
DARLENE1_TOKEN=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/DARLENE1_TOKEN)
TELEGRAM_ID=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/TELEGRAM_ID)
BOOTSTRAP_HASKELL_NONINTERACTIVE=true
CARDANO_NODE_TAG="1.35.3"
GHC_VERSION="8.10.7"
CABAL_VERSION="3.6.2.0"
NODE_HOME="${HOME}/cardano-node"
CARDANO_NODE_SOCKET_PATH="${NODE_HOME}/db/socket"
NODE_CONFIG="preprod"
mkdir ${HOME}/git
mkdir ${NODE_HOME}

cd ${NODE_HOME}
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/config.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/topology.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/byron-genesis.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/shelley-genesis.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/alonzo-genesis.json

cd -

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Hello from ${HOSTNAME}"

sudo apt-get upgrade
sudo apt-get update -y
sudo apt-get install -y bison net-tools unzip \
  flex python3-pip tcptraceroute git jq bc make automake rsync htop \
  build-essential pkg-config libffi-dev libgmp-dev \
  libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev \
  make g++ wget libncursesw5 libtool autoconf \
  libncurses-dev libtinfo5 numactl llvm-12 libnuma-dev

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="apt done"

nwmagic="$(cat ${NODE_HOME}/shelley-genesis.json | jq -r .networkMagic)"
nwmagic_arg="testnet-magic ${nwmagic}"

### 001 setup
cd ${HOME}/git
git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

sudo ln -s /usr/local/lib/libsodium.so.23.3.0 /usr/lib/libsodium.so.23

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - install libsodium done"

# ref.: https://gist.github.com/reqlez/a9291d25c477a5aa6f411db78a95fa31
curl -sS -o prereqs.sh https://raw.githubusercontent.com/cardano-community/guild-operators/alpha/scripts/cnode-helper-scripts/prereqs.sh
chmod +x prereqs.sh
./prereqs.sh -b alpha

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - install secp done"

cd ${HOME}
curl --proto '=https' --tlsv1.2 -sSf -o ghcup.sh https://get-ghcup.haskell.org
chmod +x ghcup.sh
./ghcup.sh

source ${HOME}/.ghcup/env
source ${HOME}/.bashrc

ghcup upgrade
ghcup install cabal ${CABAL_VERSION}
ghcup set cabal ${CABAL_VERSION}

ghcup install ghc ${GHC_VERSION}
ghcup set ghc ${GHC_VERSION}

echo PATH="$HOME/.local/bin:$PATH" >> ${HOME}/.bashrc
LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

echo export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" >> ${HOME}/.bashrc
echo export NODE_HOME=${NODE_HOME} >> $HOME/.bashrc

echo export NODE_CONFIG=${NODE_CONFIG} >> ${HOME}/.bashrc
source ${HOME}/.bashrc

cabal update
cabal --version
ghc --version

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ghcup,cabal setup done"

cd ${HOME}/git
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node
git fetch --all --recurse-submodules --tags
git checkout tags/${CARDANO_NODE_TAG}

cabal configure -O0 -w ghc-${GHC_VERSION}

echo -e "package cardano-crypto-praos\n flags: -external-libsodium-vrf" > cabal.project.local
sed -i $HOME/.cabal/config -e "s/overwrite-policy:/overwrite-policy: always/g"

cabal build cardano-node
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - cardano-node done"
sleep 10
cabal build cardano-cli
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - cardano-cli done"
sleep 10

sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-cli") /usr/local/bin/cardano-cli
sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-node") /usr/local/bin/cardano-node

#leave TraceMempool as it is in BP and false in relay
sed -i config.json -e "s/TraceBlockFetchDecisions\": false/TraceBlockFetchDecisions\": true/g"
if [[ $(echo ${HOSTNAME} | grep -E "\-1") ]]; then
  sed -i config.json -e "s/TraceMempool\": true/TraceMempool\": false/g"
fi

echo export CARDANO_NODE_SOCKET_PATH="${CARDANO_NODE_SOCKET_PATH}" >> ${HOME}/.bashrc
export CARDANO_NODE_SOCKET_PATH="${CARDANO_NODE_SOCKET_PATH}"
source ${HOME}/.bashrc

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - Almost there"
message=$(uptime -p)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"

chown -R ubuntu:ubuntu ${HOME}/cardano-node
sudo chown -R ubuntu:ubuntu ${HOME}

### 002 - Run
#cardano-cli query tip --testnet-magic 1
cat > ${NODE_HOME}/startNode.sh << EOF
#!/bin/bash

DIRECTORY=${NODE_HOME}

PORT=3000
HOSTADDR=0.0.0.0
TOPOLOGY=\${DIRECTORY}/topology.json
DB_PATH=\${DIRECTORY}/db
SOCKET_PATH=\${DIRECTORY}/db/socket
CONFIG=\${DIRECTORY}/config.json
/usr/local/bin/cardano-node run --topology \${TOPOLOGY} --database-path \${DB_PATH} --socket-path \${SOCKET_PATH} --host-addr \${HOSTADDR} --port \${PORT} --config \${CONFIG}
EOF

cat > ${NODE_HOME}/cardano-node.service << EOF 
# The Cardano node service (part of systemd)
# file: /etc/systemd/system/cardano-node.service

[Unit]
Description     = Cardano node service
Wants           = network-online.target
After           = network-online.target 

[Service]
User            = ubuntu
Type            = simple
WorkingDirectory= ${NODE_HOME}
ExecStart       = /bin/bash -c '${NODE_HOME}/startNode.sh'
KillSignal=SIGINT
RestartKillSignal=SIGINT
TimeoutStopSec=2
LimitNOFILE=32768
Restart=always
RestartSec=5
SyslogIdentifier=cardano-node

[Install]
WantedBy	= multi-user.target
EOF

sudo mv ${NODE_HOME}/cardano-node.service /etc/systemd/system/cardano-node.service
sudo chmod 644 /etc/systemd/system/cardano-node.service
sudo chmod +x ${NODE_HOME}/startNode.sh
sudo systemctl daemon-reload
sudo systemctl enable cardano-node
sudo systemctl reload-or-restart cardano-node
sudo systemctl start cardano-node

sleep 120

ps -ef | grep cardano-node | grep -v grep >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    message="${HOSTNAME} - Node is running on systemd now..."
    curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${message}"
fi

##############################################################################
############# Watch blockchain syncronization #############
##############################################################################
message=$(uptime -p)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"
while [[ $(cardano-cli query tip --testnet-magic 1 | grep -i sync | awk '{ print $2 }' | cut -d'.' -f1 | cut -c 2-) -lt 100 ]]; do
    message="${HOSTNAME} - sync progress: "
    message+=$(cardano-cli query tip --testnet-magic 1 | grep -i sync | awk '{ print $2 }' | cut -d'.' -f1 | cut -c 2-)
    curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"
    sleep 1200
done
message=$(uptime -p)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"

### 003 - part III
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="part III starts"
cardano-cli query protocol-parameters --${nwmagic_arg} --out-file ${NODE_HOME}/protocol.json


