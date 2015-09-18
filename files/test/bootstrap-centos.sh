#!/usr/bin/env bash
# This bootstraps a new CentOS server with requirements for SDP testing
# These are:
# - Python 3.3
# - P4Python

cd /tmp

sudo yum update -y

# Tools required to compile and build Python
sudo yum groupinstall -y "Development tools"
sudo yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel

echo /usr/local/lib>> sudo /etc/ld.so.conf

# Python 3.3 required
echo "Downloading Python"
wget -q http://www.python.org/ftp/python/3.3.6/Python-3.3.6.tar.xz
tar xJf ./Python-3.3.6.tar.xz
cd ./Python-3.3.6
./configure --prefix=/usr/local --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
make && sudo make altinstall

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
sudo /usr/local/bin/python3.3 setup.py install
