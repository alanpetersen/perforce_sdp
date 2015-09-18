#!/usr/bin/env bash
# This bootstraps a new Ubuntu-precise server with requirements for SDP testing
# Assumes that Python3.3 and P4Python are already installed
# (see bootstrap-ubuntu/centos.sh for details)
# This script sets up:
# - SDP filesystems
# - perforce account


echo "Making sdp directories"
sudo mkdir /depotdata
sudo mkdir /metadata
sudo mkdir /logs
echo "Creating perforce user"
sudo groupadd perforce
sudo useradd -d /p4 -s /bin/bash -m perforce -g perforce

echo "Allowing user 'perforce' sudo privileges"
echo 'perforce ALL=(ALL) NOPASSWD:ALL'>/tmp/perforce
sudo chmod 0440 /tmp/perforce
sudo chown root:root /tmp/perforce
sudo mv /tmp/perforce /etc/sudoers.d
echo perforce:Password | sudo chpasswd

# Setup a few things to make life easier as the Perforce user
BASH_PROF=/tmp/.bash_profile
echo 'export PATH=/sdp/Server/Unix/p4/common/bin:$PATH'> $BASH_PROF
echo 'export P4CONFIG=.p4config'>> $BASH_PROF
echo 'export P4P4PORT=1666'>> $BASH_PROF
sudo chown perforce:perforce $BASH_PROF
sudo mv $BASH_PROF /p4

RESET_SDP=/tmp/reset_sdp.sh
echo '#!/bin/bash'> $RESET_SDP
echo 'sudo cp -R /sdp /depotdata'>> $RESET_SDP
echo 'sudo chown -R perforce:perforce /depotdata/sdp'>> $RESET_SDP
sudo chmod +x $RESET_SDP
sudo chown perforce:perforce $RESET_SDP
sudo mv $RESET_SDP /p4
sudo /p4/reset_sdp.sh

sudo ln -s /sdp/Server/test/test_SDP.py /p4/test_SDP.py
sudo chown perforce:perforce /p4/test_SDP.py
