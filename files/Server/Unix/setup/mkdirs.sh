#!/bin/bash
#------------------------------------------------------------------------------
# Copyright (c) Perforce Software, Inc., 2007-2014. All rights reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1  Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2.  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE
# SOFTWARE, INC. BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
# THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
#------------------------------------------------------------------------------
#
# Change the first three variables below to match the volume names on the machine
# you are configuring the SDP on. 
# Set the remaining variables appropriately. The meaning of each should be obvious.
#
# In the SDP variable below, the sdp directory needs to contain the contents of:
# //guest/perforce_software/sdp/main/...
#
# Run this script as root, and pass in the instance number you are configuring.
# If you do not have root access, then some commands will be skipped, and you will
# need to have the defined $P4DIR directory already existing (created
# by the root user and the ownership changed to the OS user that you are planning
# to run Perforce under). The Metadata, Depotdata and Logs volumes will also need
# to be owned by the OS user as well in order for the script to work. You can then
# run this script as the OS user for Perforce and everything should work fine.
#
# This script creates an init script in the $P4DIR/$SDP_INSTANCE/bin directory. You can use
# it from there if you are configuring a cluster, or you can link it in /etc/init.d
# if you are setting up a stand alone machine.
#
# After running this script, you also need to set up the crontab based on files
# in $P4DIR/common/etc/cron.d.  For convenience, crontab files are copied to 
# $P4DIR/p4.crontab and $P4DIR/p4.crontab.replica.
#
# Now, put the license file in place and launch the server with the init script.
#
# Then run $P4DIR/common/bin/p4master_run <instance> $P4DIR/common/bin/live_checkpoint.sh
# and then run both the daily_backup.sh and weekly_backup.sh to make sure everything is
# working before setting up the crontab.
#
# Also run $P4DIR/common/bin/p4master_run <instance> $P4DIR/common/bin/p4review.py <instance>
# to make sure the review script is working properly.
#
# UPGRADING SDP
# Specify the -test parameter to the script.
# In this case the script will NOT make the various directories under $P4DIR, but will instead
# create /tmp/p4 directory structure with the various files processed via templates etc.
# You can then manually compare this directory structure with your existing $P4DIR structure
# and manually copy the various files into it.
#

set -u

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
   echo "Usage: $0 <instance> [-test]"
   exit 1
fi

# Verify instance value
SDP_INSTANCE=$1
if [[ "$SDP_INSTANCE" = "-test" ]]; then
    echo "Error: An instance argument is required."
    exit 1
fi

# Note that if the following is set to 1 then a trial run is done, into /tmp/p4
TEST=0
if [[ $# -gt 1 ]] && [[ "$2" = "-test" ]]; then
		TEST=1
fi

##############################################################################################
# CONFIGURATION VARIABLES:
#
# Do not prefix these paths with a /
MD=metadata
DD=depotdata
LG=logs

# If you are sharing the depotdata volume with a replica, change this value to TRUE
SHAREDDATA=FALSE

OSUSER=perforce
OSGROUP=perforce
SDP=/$DD/sdp

# CASEINSENSITIVE settings:
# 0 -- Server will run with case sensitivity default of the underlying platform (Unix is case sensitive).
# 1 -- Server will run in C1 mode, forcing case-insensitive mode on normally case-sensitive platforms
CASEINSENSITIVE=1

# Admin user's account name.
ADMINUSER=p4admin

# Admin user's password
P4ADMINPASS=adminpass

# Admin user's email
ADMINEMAIL=admin@company.com

# Set port numbers and values below.
# SSL_PREFIX should be blank to not use SSL, otherwise ssl:
SSL_PREFIX=ssl:
P4_PORT=1666
# Brokers can basically be replaced with command triggers now.
P4BROKER_PORT=1667
P4WEB_PORT=80
P4FTP_PORT=21

# Set MASTERINSTANCE to the first instance in your installation.
# This is used for linking the license and ssl dir to the other instances to avoid duplication.
MASTERINSTANCE=1

# If you are using a purely numeric server port and want to use the default 
# increasing port number for each instance, you can uncomment the lines below:
#P4_PORT=${SDP_INSTANCE}666
#P4BROKER_PORT=${SDP_INSTANCE}667
#P4WEB_PORT=808${SDP_INSTANCE}
#P4FTP_PORT=202${SDP_INSTANCE}

# DNS Name or IP address of master or edge server
P4DNSNAME=DNS_name_of_master_server

# Service user's account name.
SVCUSER=service

# Replication service user's password
P4SERVICEPASS=servicepass

# Master server.id name
# This would also be the name of an Edge server
# if you are configuring an Edge SDP install.
MASTERNAME=master

# Replica TRUE or FALSE setting
# This should be FALSE for commit and edge servers since they both run like a master server.
REPLICA_TF=FALSE

# Name used in configure settings for the replica name.
# Also used for the name of Edge replicas as well, not
# an Edge server. An Edge server is run like a normal
# master server, so it is named in the master variable.
REPLICANAME=replica1

# Mail Host Address
MAILHOST=mail.company.com

# Email address for p4review complaints for each instance
# look something like P4Review_1666@company.com.  Set
# the COMPLAINFROM_PREFIX (e.g. "P4Review") and
# COMPLAINFROM_DOMAIN (e.g. "company.com)" here.  Instance
# specific values are substituted below.
COMPLAINFROM_DOMAIN=company.com
COMPLAINFROM="${SSL_PREFIX}${P4DNSNAME}:${P4_PORT}_P4Review\@${COMPLAINFROM_DOMAIN}"


# END CONFIGURATION VARIABLES
##############################################################################################

SDP_VERSION="Rev. SDP/Unix/UNKNOWN"
[[ -r $SDP/Version ]] && SDP_VERSION="$(cat $SDP/Version)"

P4DIR=/p4

export AWK=awk
export ID=id
export MAIL=mail

OS=`uname`
if [[ "${OS}" = "SunOS" ]] ; then
  export AWK=/usr/xpg4/bin/awk
  export ID=/usr/xpg4/bin/id
  export MAIL=mailx
elif [[ "${OS}" = "AIX" ]] ; then
  export AWK=awk
  export ID=id
  export MAIL=mail
fi

if [[ `$ID -u` -eq 0 ]]; then
   echo "Verified: Running as root."
elif [[ `whoami` == $OSUSER ]]; then
   echo -e "\nWarning:  Not running as root; chown commands will be skipped and basic directories should exist.\n"
else
   echo -e "\nError: $0 must be run as as root or $OSUSER.\n"
   exit 1
fi

if [[ $TEST -eq 1 ]]; then
  DD=tmp
  MD=tmp
  LG=tmp
  P4DIR=/tmp/p4
  echo -e "\n*********  -test specified - will install to $DD/p4  *********\n"
fi

SDP_COMMON=$SDP/Server/Unix/p4/common

[[ -f $SDP_COMMON/bin/p4 ]] || { echo "No p4 in $SDP_COMMON/bin" ; exit 1 ;}
[[ -f $SDP_COMMON/bin/p4d ]] || { echo "No p4d in $SDP_COMMON/bin" ; exit 1 ;}

chmod 755 $SDP_COMMON/bin/p4
chmod 700 $SDP_COMMON/bin/p4d
[[ -f $SDP_COMMON/bin/p4broker ]] && chmod 700 $SDP_COMMON/bin/p4broker
[[ -f $SDP_COMMON/bin/p4web ]] && chmod 700 $SDP_COMMON/bin/p4web
[[ -f $SDP_COMMON/bin/p4p ]] && chmod 700 $SDP_COMMON/bin/p4p

# Make sure you update the p4 and p4d versions in the sdp/Server/Unix/p4/common/bin directory when making
# new instances at a later date.
P4RELNUM=`$SDP_COMMON/bin/p4 -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4DRELNUM=`$SDP_COMMON/bin/p4d -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4BLDNUM=`$SDP_COMMON/bin/p4 -V | grep -i Rev. | $AWK -F / '{print $4}' | $AWK '{print $1}'`
P4DBLDNUM=`$SDP_COMMON/bin/p4d -V | grep -i Rev. | $AWK -F / '{print $4}' | $AWK '{print $1}'`

[[ -d $P4DIR ]] || mkdir $P4DIR

[[ -d /$DD/p4 ]] || mkdir /$DD/p4
[[ -d /$MD/p4 ]] || mkdir /$MD/p4
[[ -d /$LG/p4 ]] || mkdir /$LG/p4

mkdir -p /$DD/p4/$SDP_INSTANCE/bin
mkdir -p /$DD/p4/$SDP_INSTANCE/tmp
mkdir -p /$DD/p4/$SDP_INSTANCE/depots
mkdir -p /$DD/p4/$SDP_INSTANCE/checkpoints
mkdir -p /$LG/p4/$SDP_INSTANCE/checkpoints.rep

[[ -d $P4DIR/ssl ]] || mkdir -p $P4DIR/ssl
[[ -d /$DD/p4/common/bin ]] || mkdir -p /$DD/p4/common/bin
[[ -d /$DD/p4/common/config ]] || mkdir -p /$DD/p4/common/config

mkdir -p /$MD/p4/$SDP_INSTANCE/root/save
mkdir -p /$MD/p4/$SDP_INSTANCE/offline_db
mkdir -p /$LG/p4/$SDP_INSTANCE/logs

cd /$DD/p4/$SDP_INSTANCE

if [[ $TEST -eq 0 ]]; then
    [[ -L root ]] || ln -s /$MD/p4/$SDP_INSTANCE/root
    [[ -L offline_db ]] || ln -s /$MD/p4/$SDP_INSTANCE/offline_db
    if [[ ! -d logs ]]; then
        [[ -L logs ]] || ln -s /$LG/p4/$SDP_INSTANCE/logs
    fi
    if [[ ! -d checkpoints.rep ]]; then
        [[ -L checkpoints.rep ]] || ln -s /$LG/p4/$SDP_INSTANCE/checkpoints.rep
    fi
    cd $P4DIR
    [[ -L $SDP_INSTANCE ]] || ln -s /$DD/p4/$SDP_INSTANCE
    [[ -L sdp ]] || ln -s $SDP $P4DIR/sdp
    [[ -L common ]] || ln -s /$DD/p4/common
fi

if [[ "$REPLICA_TF" == "FALSE" ]]; then
    SERVERID=$MASTERNAME
else
    SERVERID=$REPLICANAME
fi
echo $SERVERID > /p4/$SDP_INSTANCE/root/server.id

[[ -f /$DD/p4/common/bin/p4_$P4RELNUM.$P4BLDNUM ]] || cp $SDP_COMMON/bin/p4 /$DD/p4/common/bin/p4_$P4RELNUM.$P4BLDNUM
[[ -f /$DD/p4/common/bin/p4d_$P4DRELNUM.$P4DBLDNUM ]] || cp $SDP_COMMON/bin/p4d /$DD/p4/common/bin/p4d_$P4DRELNUM.$P4DBLDNUM

if [[ ! -f /$DD/p4/common/bin/p4_vars ]]; then
  cp -R $SDP_COMMON/bin/* /$DD/p4/common/bin

  if [[ ! -d /$DD/p4/common/lib ]]; then
    cp -pr $SDP_COMMON/lib /$DD/p4/common/.
  fi

  echo $P4ADMINPASS > /$DD/p4/common/bin/adminpass
  echo $P4SERVICEPASS > /$DD/p4/common/bin/servicepass

  cd /$DD/p4/common/bin
  ln -s p4_$P4RELNUM.$P4BLDNUM p4_${P4RELNUM}_bin
  ln -s p4d_$P4DRELNUM.$P4DBLDNUM p4d_${P4DRELNUM}_bin
  ln -s p4_${P4RELNUM}_bin p4_bin

  sed -e "s/REPL_MAILTO/${ADMINEMAIL}/g" \
     	-e "s/REPL_MAILFROM/${ADMINEMAIL}/g" \
     	-e "s/REPL_ADMINUSER/${ADMINUSER}/g" \
     	-e "s/REPL_SVCUSER/${SVCUSER}/g"  \
     	-e "s:REPL_SDPVERSION:${SDP_VERSION}:g" \
     	-e "s:REPL_SHAREDDATA:${SHAREDDATA}:g" \
     	-e "s/REPL_OSUSER/${OSUSER}/g" $SDP_COMMON/config/p4_vars.template > p4_vars
fi

cd /$DD/p4/common/bin

ln -s p4d_${P4DRELNUM}_bin p4d_${SDP_INSTANCE}_bin

# Create broker links if broker exists
if [[ -f $SDP_COMMON/bin/p4broker ]]; then 
  P4BRELNUM=`$SDP_COMMON/bin/p4broker -V | grep -i Rev. | $AWK -F / '{print $3}'`
  P4BBLDNUM=`$SDP_COMMON/bin/p4broker -V | grep -i Rev. | $AWK -F / '{print $4}' | $AWK '{print $1}'`
  [[ -f /$DD/p4/common/bin/p4broker_$P4BRELNUM.$P4BBLDNUM ]] || cp $SDP_COMMON/bin/p4broker /$DD/p4/common/bin/p4broker_$P4BRELNUM.$P4BBLDNUM
  [[ -L p4broker_${P4BRELNUM}_bin ]] && unlink p4broker_${P4BRELNUM}_bin 
  ln -s p4broker_$P4BRELNUM.$P4BBLDNUM p4broker_${P4BRELNUM}_bin 
  [[ -L p4broker_${SDP_INSTANCE}_bin ]] && unlink p4broker_${SDP_INSTANCE}_bin 
  ln -s p4broker_${P4BRELNUM}_bin p4broker_${SDP_INSTANCE}_bin
  cd $P4DIR/$SDP_INSTANCE/bin
  [[ -L p4broker_${SDP_INSTANCE} ]] || ln -s $P4DIR/common/bin/p4broker_${SDP_INSTANCE}_bin p4broker_${SDP_INSTANCE}
  sed "s/REPL_SDP_INSTANCE/${SDP_INSTANCE}/g" $SDP_COMMON/etc/init.d/p4broker_instance_init.template > p4broker_${SDP_INSTANCE}_init
  chmod +x p4broker_${SDP_INSTANCE}_init
fi

# Create P4Web links if P4Web exists
cd /$DD/p4/common/bin
if [[ -x $SDP_COMMON/bin/p4web ]]; then 
  P4WEBRELNUM=`$SDP_COMMON/bin/p4web -V | grep -i Rev. | $AWK -F / '{print $3}'`
  P4WEBBLDNUM=`$SDP_COMMON/bin/p4web -V | grep -i Rev. | $AWK -F / '{print $4}' | $AWK '{print $1}'`
  [[ -f /$DD/p4/common/bin/p4web_$P4WEBRELNUM.$P4WEBBLDNUM ]] || cp $SDP_COMMON/bin/p4web /$DD/p4/common/bin/p4web_$P4WEBRELNUM.$P4WEBBLDNUM
  [[ -L p4web_${P4WEBRELNUM}_bin ]] && unlink p4web_${P4WEBRELNUM}_bin 
  ln -s p4web_$P4WEBRELNUM.$P4WEBBLDNUM p4web_${P4WEBRELNUM}_bin 
  [[ -L p4web_${SDP_INSTANCE}_bin ]] && unlink p4web_${SDP_INSTANCE}_bin 
  ln -s p4web_${P4WEBRELNUM}_bin p4web_${SDP_INSTANCE}_bin
  cd $P4DIR/$SDP_INSTANCE/bin
  [[ -L p4web_${SDP_INSTANCE} ]] || ln -s $P4DIR/common/bin/p4web_${SDP_INSTANCE}_bin p4web_${SDP_INSTANCE}
  sed "s/REPL_SDP_INSTANCE/${SDP_INSTANCE}/g" $SDP_COMMON/etc/init.d/p4web_instance_init.template > p4web_${SDP_INSTANCE}_init
  chmod +x p4web_${SDP_INSTANCE}_init
fi

# Create p4p links if p4p exists
cd /$DD/p4/common/bin
if [[ -x $SDP_COMMON/bin/p4p ]]; then 
  P4PRELNUM=`$SDP_COMMON/bin/p4p -V | grep -i Rev. | $AWK -F / '{print $3}'`
  P4PBLDNUM=`$SDP_COMMON/bin/p4p -V | grep -i Rev. | $AWK -F / '{print $4}' | $AWK '{print $1}'`
  [[ -f /$DD/p4/common/bin/p4p_$P4PRELNUM.$P4PBLDNUM ]] || cp $SDP_COMMON/bin/p4p /$DD/p4/common/bin/p4p_$P4PRELNUM.$P4PBLDNUM
  [[ -L p4p_${P4PRELNUM}_bin ]] && unlink p4p_${P4PRELNUM}_bin 
  ln -s p4p_$P4PRELNUM.$P4PBLDNUM p4p_${P4PRELNUM}_bin 
  [[ -L p4p_${SDP_INSTANCE}_bin ]] && unlink p4p_${SDP_INSTANCE}_bin 
  ln -s p4p_${P4PRELNUM}_bin p4p_${SDP_INSTANCE}_bin
  cd $P4DIR/$SDP_INSTANCE/bin
  [[ -L p4p_${SDP_INSTANCE} ]] || ln -s $P4DIR/common/bin/p4p_${SDP_INSTANCE}_bin p4p_${SDP_INSTANCE}
  sed "s/REPL_SDP_INSTANCE/${SDP_INSTANCE}/g" $SDP_COMMON/etc/init.d/p4p_instance_init.template | sed "s/REPL_DNSNAME/${P4DNSNAME}/g" > p4p_${SDP_INSTANCE}_init
  chmod +x p4p_${SDP_INSTANCE}_init
  mkdir -p /$DD/p4/$SDP_INSTANCE/cache
fi

cd $P4DIR/$SDP_INSTANCE/bin
ln -s $P4DIR/common/bin/p4_bin p4_$SDP_INSTANCE

sed "s/REPL_SDP_INSTANCE/${SDP_INSTANCE}/g" $SDP_COMMON/etc/init.d/p4d_instance_init.template > p4d_${SDP_INSTANCE}_init
chmod +x p4d_${SDP_INSTANCE}_init

# Moved the less commonly used, but always created init scripts to an init directory.
mkdir init
cd init

sed "s/REPL_SDP_INSTANCE/${SDP_INSTANCE}/g" $SDP_COMMON/etc/init.d/p4dtg_instance_init.template > p4dtg_${SDP_INSTANCE}_init
chmod +x p4dtg_${SDP_INSTANCE}_init

sed "s/REPL_SDP_INSTANCE/${SDP_INSTANCE}/g" $SDP_COMMON/etc/init.d/p4ftpd_instance_init.template > p4ftpd_${SDP_INSTANCE}_init
chmod +x p4ftpd_${SDP_INSTANCE}_init

cd ..

if [ $CASEINSENSITIVE -eq 0 ]; then
  ln -s $P4DIR/common/bin/p4d_${SDP_INSTANCE}_bin p4d_$SDP_INSTANCE
else
  echo '#!/bin/bash' > p4d_$SDP_INSTANCE
  echo P4D=/p4/common/bin/p4d_${SDP_INSTANCE}_bin >> p4d_$SDP_INSTANCE
  echo 'exec $P4D -C1 "$@"' >> p4d_$SDP_INSTANCE
  chmod +x p4d_$SDP_INSTANCE
fi

cd $P4DIR/common/config
sed "s/MASTER_NAME/${MASTERNAME}/g" $SDP_COMMON/config/instance_vars.template |\
  sed "s/REPL_REPNAME/${REPLICANAME}/g" |\
  sed "s/REPL_SSLPREFIX/${SSL_PREFIX}/g" |\
  sed "s/REPL_P4PORT/${P4_PORT}/g" |\
  sed "s/REPL_P4BROKERPORT/${P4BROKER_PORT}/g" |\
  sed "s/REPL_P4WEBPORT/${P4WEB_PORT}/g" |\
  sed "s/REPL_P4FTPPORT/${P4FTP_PORT}/g" |\
  sed "s/REPL_DNSNAME/${P4DNSNAME}/g" > p4_${SDP_INSTANCE}.vars
chmod +x p4_${SDP_INSTANCE}.vars

sed "s/REPL_ADMINISTRATOR/${ADMINEMAIL}/g" $SDP_COMMON/config/p4review.cfg.template |\
  sed "s/REPL_COMPLAINFROM/${COMPLAINFROM}/g" |\
  sed "s/REPL_MAILHOST/${MAILHOST}/g" |\
  sed "s/REPL_DNSNAME/${P4DNSNAME}/g" > p4_${SDP_INSTANCE}.p4review.cfg

cd $P4DIR
if [[ ! -f ${P4DIR}/p4.crontab ]]; then 
  sed -e "s/REPL_MAILTO/${ADMINEMAIL}/g" \
      -e "s/REPL_MAILFROM/${ADMINEMAIL}/g" $SDP_COMMON/etc/cron.d/crontab.template > p4.crontab 
else
  echo "You need to duplicate the instance section in ${P4DIR}/p4.crontab and update the instance number to ${SDP_INSTANCE} and update ${OSUSER}'s crontab."
fi

if [[ ! -f ${P4DIR}/p4.crontab.replica ]]; then 
  sed -e "s/REPL_MAILTO/${ADMINEMAIL}/g"  \
      -e "s/REPL_MAILFROM/${ADMINEMAIL}/g" $SDP_COMMON/etc/cron.d/crontab.replica.template > p4.crontab.replica
else
  echo "You need to duplicate the instance section in ${P4DIR}/p4.crontab.replica and update the instance number to ${SDP_INSTANCE} and update ${OSUSER}'s crontab."
fi

cd $P4DIR/${SDP_INSTANCE}/bin

if [[ `$ID -u` -eq 0 ]]; then
   if [[ $TEST -eq 0 ]]; then
      chown $OSUSER:$OSGROUP /$DD
      chown $OSUSER:$OSGROUP /$LG
      chown $OSUSER:$OSGROUP /$MD
   fi
   chown $OSUSER:$OSGROUP /$DD/p4
   chown $OSUSER:$OSGROUP /$LG/p4
   chown $OSUSER:$OSGROUP /$MD/p4
  
   chown -h $OSUSER:$OSGROUP $P4DIR
   chown -h $OSUSER:$OSGROUP $P4DIR/$SDP_INSTANCE
   chown -h $OSUSER:$OSGROUP $P4DIR/common
   [[ $TEST -eq 0 ]] && chown -h $OSUSER:$OSGROUP $P4DIR/sdp
   chown $OSUSER:$OSGROUP $P4DIR/*

   chown -Rh $OSUSER:$OSGROUP $P4DIR/common
   [[ $TEST -eq 0 ]] && chown -Rh $OSUSER:$OSGROUP $P4DIR/sdp
   chown -Rh $OSUSER:$OSGROUP /$DD/p4/common
   chown -Rh $OSUSER:$OSGROUP /$DD/p4/$SDP_INSTANCE
   chown -Rh $OSUSER:$OSGROUP /$MD/p4/$SDP_INSTANCE
   chown -Rh $OSUSER:$OSGROUP /$LG/p4/$SDP_INSTANCE
else
   echo "Not running as root, so chown commands were skipped."
fi

chmod 700 /$MD/p4
chmod 700 /$DD/p4
chmod 700 /$LG/p4

chmod -R 700 /$MD/p4/$SDP_INSTANCE
chmod -R 700 /$DD/p4/$SDP_INSTANCE
chmod -R 700 /$DD/p4/common
chmod -R 700 /$LG/p4/$SDP_INSTANCE

if [[ $SDP_INSTANCE != $MASTERINSTANCE ]]; then
  if [[ -f $P4DIR/$MASTERINSTANCE/root/license ]]; then
    ln -s $P4DIR/$MASTERINSTANCE/root/license $P4DIR/$SDP_INSTANCE/root/license
    chown -h $OSUSER:$OSGROUP $P4DIR/$SDP_INSTANCE/root/license
  fi
fi

chmod 755 $P4DIR/${SDP_INSTANCE}/bin/*_init
chmod 755 $P4DIR/${SDP_INSTANCE}/bin/init/*_init
chmod 600 /$DD/p4/common/bin/adminpass
chmod 600 /$DD/p4/common/bin/servicepass
chmod 600 /$DD/p4/common/bin/*.cfg
chmod 600 /$DD/p4/common/bin/*.html
chmod 700 $P4DIR/ssl
if [[ -e $P4DIR/ssl/* ]]; then
    chmod 600 $P4DIR/ssl/*
fi

echo "It is recommended that the ${OSUSER}'s umask be changed to 0026 to block world access to Perforce files."
echo "Add umask 0026 to ${OSUSER}'s .bash_profile to make this change."
if [[ "$REPLICA_TF" == "TRUE" ]]; then
  echo "Be sure to set the configurable: ${REPLICANAME}#journalPrefix=/p4/${SDP_INSTANCE}/checkpoints.rep/p4_${SDP_INSTANCE}"
  echo "Also, replication should be done using depot-standby in the server spec and journalcopy along with pull -L"
fi

if [[ $TEST -eq 1 ]]; then
  echo ""
  echo "This was done in TEST mode - please run the following command to see any changes should be"
  echo "applied to your live environment (manually):"
  echo ""
  echo "  diff -r /p4/$SDP_INSTANCE/bin $P4DIR/$SDP_INSTANCE/bin"
  echo "  diff -r /p4/common $P4DIR/common"
  echo ""
  echo "If ugprading an older SDP version then be careful to ensure files in /p4/common/config are correct"
  echo "and update that /p4/common/bin/p4_vars is appropriate."
  echo ""
fi

exit 0
