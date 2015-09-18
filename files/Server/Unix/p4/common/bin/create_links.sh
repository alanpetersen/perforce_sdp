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

echo "common_dir=${common_dir}" >> /tmp/create_links.log
echo "EXE=${EXE}" >> /tmp/create_links.log

[ -f ${common_dir}/${EXE} ] || { echo "No ${EXE} in ${common_dir}" ; exit 1 ;}

REV=$(${common_dir}/${EXE} -V|grep Rev.|cut -d' ' -f2)
RELNUM=$(echo ${REV}|cut -d'/' -f3)
BLDNUM=$(echo ${REV}|cut -d'/' -f4)

echo "REV=${REV}" >> /tmp/create_links.log
echo "RELNUM=${RELNUM}" >> /tmp/create_links.log
echo "BLDNUM=${BLDNUM}" >> /tmp/create_links.log

[ -f ${EXE}_${RELNUM}.${BLDNUM} ] || cp ${EXE} ${EXE}_${RELNUM}.${BLDNUM}
[ -f ${EXE}_${RELNUM}_bin ] && unlink ${EXE}_${RELNUM}_bin
ln -s ${EXE}_${RELNUM}.${BLDNUM} ${EXE}_${RELNUM}_bin

echo "created ${EXE}_${RELNUM}_bin link" >> /tmp/create_links.log

exit 0
