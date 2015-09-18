Welcome
=======
This is a test harness for the Perforce Unix SDP (Server Deployment Package). 
One quick 'vagrant up' will create a Ubuntu and a CentOS box where you can easily run the test harness.

Requirements
------------
To use this bundle you will need to download and install the following tools, both of which are free.

* VirtualBox (https://www.virtualbox.org/) 
* Vagrant (http://vagrantup.com)

The following vagrant plugins ("sudo vagrant plugin install<plugin name>"):

* vagrant-vbguest (installs latest VirtualBox Guest additions up to date - important for CentOS!)
* vagrant-hostmanager (optional - but very useful)
* vagrant-cachier (optional)

If you're not familiar with Vagrant, it is a command line based virtual machine management tool that makes it easy to create and provision virtual machines, all driven by a simple text file. If you haven't used it before be warned: simple VM management is addictive!

VirtualBox is an open source hypervisor made by Oracle. It runs on many platforms and is the default hypervisor for Vagrant. You do not need to know much of anything about Vagrant to use these tools. We'll explain the few commands you will likely need below.

Given that you are using a virtual machine you will need at least 512MB of RAM to run the environment. You will also need at least a gig of drive space to hold the VM image.

Usage
-----
1) Have a workspace which looks like (assuming name of myws.sdp):   

    View:
        //guest/perforce_software/sdp/main/... //myws.sdp/sdp/...
        //guest/perforce_software/sdp/main/test/* //myws.sdp/*

2) sync the workspace

3) From the command prompt run 'vagrant up' in the workspace root directory. The first time you run it will take a while!

The command 'vagrant up' tells Vagrant to look for the cleverly named 'Vagrantfile' and create the VM described within. Note you will need an internet connection during this process.

As you can see from the Vagrantfile it includes the sdp_test_config.json which defines the precise VMs, including IP Addresses to use etc.

Once Vagrant returns you will have a fully functional installation. See section on Workflow below for more details.

Vagrant Basics
--------------
You will need very few commands to be successful with Vagrant for this project. Here are the commands you will need.

* vagrant up - creates and provisions a new virtual machine if one does not currently exist
* vagrant destroy - halts and deletes the current virtual machine
* vagrant ssh - ssh's you into the VM so you can work on the machine
* vagrant halt - shuts down the virtual machine, but does not delete it

That's it! With those four commands you should be suitably dangerous to run tests.

One important part of using Vagrant is taking advantage of the shared folders it creates. With this project we automatically link most of the files that are in the directory along with the Vagrantfile to appropriate places within the VM. Things are shared to /sdp within the VM.

These shared folders allow you to use your favorite editors on your computer with the files that are being used by the VM. Without SSHing in you can edit files live inside the VM. This is one of the biggest advantages of using Vagrant; it lets you code with your preferred tools while still having the controlled environment your app needs.

This also means that if at any point you need a clean test environment a quick 'vagrant destroy' and 'vagrant up' will give you a fresh installation with all of your code changes intact. 'vagrant destroy' only deletes the contents of the VM, not the contents of your host machine.

Workflow for testing
--------------------

How to run:

1) Run 'vagrant ssh ubuntu-sdpmaster'  (or 'vagrant ssh centos-sdpmaster') from the workspace root directory you created to shell into the VM.
2) Run 'sudo su - perforce' to become user perforce (home directory is /p4)
3) ./reset_sdp.sh  (resets current directories)
4) python3 test_SDP.py  (This is a link to the real file under /sdp - on CentOS the command 

An alternative just to run all the tests is (from workspace root directory) and examine the output:

1) bash -x run_tests.sh

This could also be 'bash -x run_tests.sh ubuntu' (or centos) just to run tests on respective VM.
