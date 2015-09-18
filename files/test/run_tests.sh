#!/bin/bash
# Run the vagrant tests

oses=""
halt_vagrant=0

# Allow the specific platform to be specified via parameter
if [ ,"$1" = ,"ubuntu" ] ; then
	oses="ubuntu"
elif [ ,"$1" = ,"centos" ] ; then
	oses="centos"
else
	oses="ubuntu centos"
	if [ ,"$1" = ,"-halt" ]; then
		halt_vagrant=1
	fi
fi

all_test_output=./sdp/alltests.out
if [ -f $all_test_output ] ; then
	rm $all_test_output
fi

# Make sure that p4 binaries are present and correct
origdir=`pwd`
cd ./sdp/Server/Unix/p4/common/bin
if [ ! -f p4 ]; then
	wget -nv ftp.perforce.com/perforce/r15.1/bin.linux26x86_64/p4
fi
if [ ! -f p4d ]; then
	wget -nv ftp.perforce.com/perforce/r15.1/bin.linux26x86_64/p4d
fi
cd $origdir

echo Running SDP tests
tests_failed=0
for os in $oses
do
	machine=$os-sdpmaster
	vagrant up $machine > /tmp/sdp-vagrant.out
	echo $os>> $all_test_output
	test_output="test-$os.out"
	vagrant ssh $machine -c "sudo /p4/reset_sdp.sh" -- -n -T
	vagrant ssh $machine -c "sudo -u perforce date > /tmp/$test_output" -- -n -T
	vagrant ssh $machine -c "uname -a >> /tmp/$test_output" -- -n -T
	# Avoid Jenkins immediately failing job without letting us cat the output
	set +e
	if [ ,"$os" = ,"ubuntu" ] ; then
		vagrant ssh $machine -c "sudo -H -u perforce python3 /p4/test_SDP.py >> /tmp/$test_output 2>&1" -- -n -T
		tests_failed=$?
	else
		vagrant ssh $machine -c "sudo -i -u perforce /usr/local/bin/python3.3 /p4/test_SDP.py >> /tmp/$test_output 2>&1" -- -t -t
		tests_failed=$?
	fi
	vagrant ssh $machine -c "sudo cp /tmp/$test_output /sdp" -- -t -t
	cat ./sdp/$test_output>> $all_test_output
	if [ $halt_vagrant -ne 0 ]; then
		vagrant halt $machine
	fi
	set -e
	if [ $tests_failed -ne 0 ]; then
		break
	fi 
done
cat $all_test_output
exit $tests_failed
