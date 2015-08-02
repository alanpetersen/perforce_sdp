#!/bin/bash

EXE=$1

if [ "$EXE" = "" ]; then
    echo "executable must be specified"
    exit 1
fi

common_dir=/p4/common/bin

if [ -d $common_dir ]; then
  cd $common_dir
else
  echo $common_dir does not exist.
  exit 1
fi

[ -f ${common_dir}/${EXE} ] || { echo "No ${EXE} in ${common_dir}" ; exit 1 ;}

REV=$(${common_dir}/${EXE} -V|grep Rev.|cut -d' ' -f2)
RELNUM=$(echo ${REV}|cut -d'/' -f3)
BLDNUM=$(echo ${REV}|cut -d'/' -f4)

[ -f ${EXE}_${RELNUM}.${BLDNUM} ] || cp ${EXE} ${EXE}_${RELNUM}.${BLDNUM}
[ -f ${EXE}_${RELNUM}_bin ] && unlink ${EXE}_${RELNUM}_bin
ln -s ${EXE}_${RELNUM}.${BLDNUM} ${EXE}_${RELNUM}_bin

exit 0

AWK=awk
ID=id

OS=`/bin/uname`
if [ "${OS}" = "SunOS" ] ; then
  AWK=/usr/xpg4/bin/awk
  ID=/usr/xpg4/bin/id
elif [ "${OS}" = "AIX" ] ; then
  AWK=awk
  ID=id
fi

export AWK
export ID


[ -f $common_dir/p4 ] || { echo "No p4 in $common_dir" ; exit 1 ;}
[ -f $common_dir/p4d ] || { echo "No p4d in $common_dir" ; exit 1 ;}

chmod 755 $common_dir/p4
chmod 700 $common_dir/p4d
[[ -f $common_dir/p4broker ]] && chmod 755 $common_dir/p4broker

P4RELNUM=`./p4 -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4DRELNUM=`./p4d -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4BLDNUM=`./p4 -V | grep -i Rev. | $AWK -F / '{print $4}' | awk '{print $1}'`
P4DBLDNUM=`./p4d -V | grep -i Rev. | $AWK -F / '{print $4}' | awk '{print $1}'`

[ -f p4_$P4RELNUM.$P4BLDNUM ] || cp p4 p4_$P4RELNUM.$P4BLDNUM
[ -f p4d_$P4DRELNUM.$P4DBLDNUM ] || cp p4d p4d_$P4DRELNUM.$P4DBLDNUM
[ -f p4_${P4RELNUM}_bin ] && unlink p4_${P4RELNUM}_bin
ln -s p4_$P4RELNUM.$P4BLDNUM p4_${P4RELNUM}_bin
[ -f p4d_${P4DRELNUM}_bin ] && unlink p4d_${P4DRELNUM}_bin
ln -s p4d_$P4DRELNUM.$P4DBLDNUM p4d_${P4DRELNUM}_bin
[ -f p4_bin ] && unlink p4_bin
ln -s p4_${P4RELNUM}_bin p4_bin

