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
NODE_CONFIG="mainnet"
nwmagic_arg="mainnet"
#NODE_CONFIG="testnet"
#nwmagic_arg="testnet-magic 1"

mkdir ${HOME}/git
mkdir ${NODE_HOME}

wget -P ${NODE_HOME} -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/config.json
#wget -P ${NODE_HOME} -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/topology.json
#for mainnet topology (p2p enabled)
#wget -P ${NODE_HOME} -N https://book.world.dev.cardano.org/environments/mixed/topology.json
wget -P ${NODE_HOME} -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/byron-genesis.json
wget -P ${NODE_HOME} -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/shelley-genesis.json
wget -P ${NODE_HOME} -N https://book.world.dev.cardano.org/environments/${NODE_CONFIG}/alonzo-genesis.json

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Hello from ${HOSTNAME}"

sudo apt-get upgrade
sudo apt-get update -y
sudo apt-get install -y bison net-tools unzip \
  flex python3-pip tcptraceroute git jq bc make automake rsync htop \
  build-essential pkg-config libffi-dev libgmp-dev \
  libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev \
  make g++ wget libncursesw5 libtool autoconf \
  libncurses-dev libtinfo5 numactl llvm-12 libnuma-dev \
  libpam-google-authenticator fail2ban chrony

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="apt done"

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
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
echo export NODE_HOME=${NODE_HOME} >> ${HOME}/.bashrc
export NODE_HOME=${NODE_HOME}

echo export NODE_CONFIG=${NODE_CONFIG} >> ${HOME}/.bashrc
export NODE_CONFIG=${NODE_CONFIG}
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
sed -i ${HOME}/.cabal/config -e "s/overwrite-policy:/overwrite-policy: always/g"

cabal build cardano-node
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - cardano-node done"
sleep 10
cabal build cardano-cli
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - cardano-cli done"
sleep 10

sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-cli") /usr/local/bin/cardano-cli
sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-node") /usr/local/bin/cardano-node

cd ${HOME}

#leave TraceMempool as it is in BP and false in relay
sed -i ${NODE_HOME}/config.json -e "s/TraceBlockFetchDecisions\": false/TraceBlockFetchDecisions\": true/g"
if [[ $(echo ${HOSTNAME} | grep -E "\-1") ]]; then
  sed -i ${NODE_HOME}/config.json -e "s/TraceMempool\": true/TraceMempool\": false/g"
fi

#Enable P2P
cat ${NODE_HOME}/config.json | jq -r '. |= . + {"EnableP2P": true}' > ${NODE_HOME}/_config.json 
mv ${NODE_HOME}/_config.json ${NODE_HOME}/config.json

echo export CARDANO_NODE_SOCKET_PATH="${CARDANO_NODE_SOCKET_PATH}" >> ${HOME}/.bashrc
export CARDANO_NODE_SOCKET_PATH="${CARDANO_NODE_SOCKET_PATH}"
source ${HOME}/.bashrc

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - Almost there"
message=$(uptime -p)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"

chown -R ubuntu:ubuntu ${HOME}/cardano-node
sudo chown -R ubuntu:ubuntu ${HOME}

curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Getting DB snapshot"
cd ${NODE_HOME}
mkdir db
wget -r -np -nH -R "index.html*" -e robots=off https://${NODE_CONFIG}.adamantium.online/db/
cd -
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Snapshot done"

### 002 - Run
cat > ${NODE_HOME}/startNode.sh << EOF
#!/bin/bash

DIRECTORY=${NODE_HOME}

PORT=3000
HOSTADDR=0.0.0.0
TOPOLOGY=\${DIRECTORY}/topology.json
DB_PATH=\${DIRECTORY}/db
SOCKET_PATH=\${DIRECTORY}/db/socket
CONFIG=\${DIRECTORY}/config.json
/usr/local/bin/cardano-node run +RTS -N -A16m -qg -qb -RTS --topology \${TOPOLOGY} --database-path \${DB_PATH} --socket-path \${SOCKET_PATH} --host-addr \${HOSTADDR} --port \${PORT} --config \${CONFIG}
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

#install z-ram
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Getting z-ram"
sudo apt install -y linux-modules-extra-$(uname -r) zram-config

cat > ${HOME}/init-zram-swapping << EOF 
#!/bin/sh

modprobe zram

# Calculate memory to use for zram (1/2 of ram)
totalmem=`LC_ALL=C free | grep -e "^Mem:" | sed -e 's/^Mem: *//' -e 's/  *.*//'`
echo lz4 > /sys/block/zram0/comp_algorithm
mem=\$((totalmem / 2 * 1024 * 3))

# initialize the devices
echo \$mem > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 150 /dev/zram0
EOF

sudo cp ${HOME}/init-zram-swapping /usr/bin/init-zram-swapping
sudo /usr/bin/init-zram-swapping
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Z-ram done"

message=$(cat ${HOME}/external.ip)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="External ip: ${message}"

#Crocny
cat > ${HOME}/chrony.conf << EOF
pool time.google.com       iburst minpoll 1 maxpoll 2 maxsources 3
pool ntp.ubuntu.com        iburst minpoll 1 maxpoll 2 maxsources 3
pool us.pool.ntp.org     iburst minpoll 1 maxpoll 2 maxsources 3

# This directive specify the location of the file containing ID/key pairs for
# NTP authentication.
keyfile /etc/chrony/chrony.keys

# This directive specify the file into which chronyd will store the rate
# information.
driftfile /var/lib/chrony/chrony.drift

# Uncomment the following line to turn logging on.
#log tracking measurements statistics

# Log files location.
logdir /var/log/chrony

# Stop bad estimates upsetting machine clock.
maxupdateskew 5.0

# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can’t be used along with the 'rtcfile' directive.
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than
# one second, but only in the first three clock updates.
makestep 0.1 -1
EOF

sudo mv ${HOME}/chrony.conf /etc/chrony/chrony.conf
sudo systemctl restart chronyd.service
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="Crony done"

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
while [[ $(cardano-cli query tip --${nwmagic_arg} | grep -i sync | awk '{ print $2 }' | cut -d'.' -f1 | cut -c 2-) -lt 100 ]]; do
    message="${HOSTNAME} - sync progress: "
    message+=$(cardano-cli query tip --${nwmagic_arg} | grep -i sync | awk '{ print $2 }' | cut -d'.' -f1 | cut -c 2-)
    curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${message}"
    sleep 1200
done
message=$(uptime -p)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"

### 003 - part III
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="part III starts - continue in the server!!!"

wget https://raw.githubusercontent.com/dodopontocom/oraculo-cloud/wip/oci/mainnet/bootstrap/step-b.sh
wget https://raw.githubusercontent.com/dodopontocom/oraculo-cloud/wip/oci/mainnet/bootstrap/step-c.sh
chmod +x ./step-b.sh
chmod +x ./step-c.sh

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get autoremove
sudo apt-get autoclean

sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow -f noninteractive unattended-upgrades

message=$(uptime -p)
curl -s -X POST https://api.telegram.org/bot${DARLENE1_TOKEN}/sendMessage -d chat_id=${TELEGRAM_ID} -d text="${HOSTNAME} - ${message}"