#!/usr/bin/env bash
# This bootstraps a new Ubuntu-precise server with requirements for SDP testing
# These are:
# - various SDP filesystems
# - perforce account
# - Python 3.3
# - P4Python

cd /tmp

sudo apt-get update

# We need mail for the various SDP scripts
sudo debconf-set-selections <<< "postfix postfix/mailname string `hostname`"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"
sudo apt-get install -y postfix
sudo apt-get install -y mailutils

# build-essential required to compile and build Python
sudo apt-get install -y build-essential

# Python 3.3 required - there is apt-get package for Python 3.2 but that is a dodgy release with bugs for P4Python etc.
echo "Downloading Python"
wget -q http://www.python.org/ftp/python/3.3.6/Python-3.3.5.tar.xz
tar xJf ./Python-3.3.6.tar.xz
cd ./Python-3.3.6
./configure
make && sudo make install

# Build P4Python
cd /tmp
mkdir p4python
cd p4python
echo "Downloading P4API and P4Python"
wget -q ftp://ftp.perforce.com/perforce/r15.1/bin.linux26x86_64/p4api.tgz
tar xzf p4api.tgz
wget -q ftp://ftp.perforce.com/perforce/r15.1/bin.tools/p4python.tgz
tar xzf p4python.tgz
P4PYTHON_PATH=`find /tmp/p4python/ -name "p4python-*"`
cd $P4PYTHON_PATH
API_PATH=`find /tmp/p4python/ -name "p4api-*" -type d`
mv setup.cfg setup.cfg.bak
echo [p4python_config] > setup.cfg
echo p4_api=$API_PATH>> setup.cfg
sudo /usr/local/bin/python3 setup.py install
