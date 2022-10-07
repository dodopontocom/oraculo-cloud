#!/usr/bin/env bash

set -e

export COLD_PAY_ADDR=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/COLD_PAY_ADDR)

DARLENE1_TOKEN=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/DARLENE1_TOKEN)
TELEGRAM_ID=$(curl -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/TELEGRAM_ID)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Hello from ${HOSTNAME}"

sudo apt-get upgrade
sudo apt-get update
sudo apt-get install -y git jq bc make automake rsync htop \
    build-essential pkg-config libffi-dev libgmp-dev \
    libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev \
    make g++ wget libncursesw5 libtool autoconf libncurses-dev libtinfo5
sudo apt-get update -y
if [[ "$?" -ne "0" ]]; then
  curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - apt update failed"
fi
sudo apt-get install -y llvm libnuma-dev
if [[ "$?" -ne "0" ]]; then
  curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - apt numa and llvm failed"
fi

### 001 setup

export BOOTSTRAP_HASKELL_NONINTERACTIVE=true

CARDANO_NODE_TAG="1.35.3"
GHC_VERSION="8.10.7"
CABAL_VERSION="3.6.2.0"
NODE_HOME="${HOME}/cardano-node"

mkdir ~/git
cd ~/git
git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

sudo ln -s /usr/local/lib/libsodium.so.23.3.0 /usr/lib/libsodium.so.23

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - install libsodium done"

#https://github.com/input-output-hk/cardano-node/blob/master/doc/getting-started/install.md/
cd $HOME/git
git clone https://github.com/bitcoin-core/secp256k1
cd secp256k1
git checkout ac83be33
./autogen.sh
./configure --enable-module-schnorrsig --enable-experimental
make
sudo make install

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - install secp done"

cd $HOME
curl --proto '=https' --tlsv1.2 -sSf -o ghcup.sh https://get-ghcup.haskell.org
chmod +x ghcup.sh
./ghcup.sh

source $HOME/.ghcup/env

ghcup upgrade
ghcup install cabal ${CABAL_VERSION}
ghcup set cabal ${CABAL_VERSION}
###

ghcup install ghc ${GHC_VERSION}
ghcup set ghc ${GHC_VERSION}

echo PATH="$HOME/.local/bin:$PATH" >> $HOME/.bashrc
LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

echo export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" >> $HOME/.bashrc

echo export NODE_HOME=${HOME}/cardano-node >> $HOME/.bashrc
NODE_CONFIG=preprod

echo export NODE_CONFIG=preprod >> $HOME/.bashrc
source $HOME/.bashrc

cabal update
cabal --version
ghc --version

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ghcup,cabal setup done"

cd $HOME/git
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node
git fetch --all --recurse-submodules --tags
git checkout tags/${CARDANO_NODE_TAG}

cabal configure -O0 -w ghc-${GHC_VERSION}

echo -e "package cardano-crypto-praos\n flags: -external-libsodium-vrf" > cabal.project.local
sed -i $HOME/.cabal/config -e "s/overwrite-policy:/overwrite-policy: always/g"
#rm -rf $HOME/git/cardano-node/dist-newstyle/build/x86_64-linux/ghc-${GHC_VERSION}

cabal build cardano-node
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - cardano-node done"
sleep 10
cabal build cardano-cli
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - cardano-cli done"
sleep 10

sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-cli") /usr/local/bin/cardano-cli
sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-node") /usr/local/bin/cardano-node

/usr/local/bin/cardano-node --version
/usr/local/bin/cardano-cli --version

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - configure and build cardano cli node done"

mkdir $NODE_HOME
cd $NODE_HOME

wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/config.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/topology.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/byron-genesis.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/shelley-genesis.json
wget -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/alonzo-genesis.json

#leave TraceMempool as it is in BP and false in relay
sed -i config.json -e "s/TraceBlockFetchDecisions\": false/TraceBlockFetchDecisions\": true/g"
if [[ $(echo ${HOSTNAME} | grep relaynode) ]]; then
  sed -i config.json -e "s/TraceMempool\": true/TraceMempool\": false/g"
fi

CARDANO_NODE_SOCKET_PATH="${NODE_HOME}/db/socket"
echo export CARDANO_NODE_SOCKET_PATH="${NODE_HOME}/db/socket" >> ${HOME}/.bashrc
source ${HOME}/.bashrc

chown -R ubuntu:ubuntu ${HOME}/cardano-node
# sudo journalctl -u google-startup-scripts.service

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - Almost there"
message=$(uptime -p)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"

sudo chown -R ubuntu:ubuntu ${HOME}