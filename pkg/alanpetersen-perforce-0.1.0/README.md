# perforce

#### Table of Contents
1. [Module Description - What the module does and why it is useful](#module-description)
1. [Setup - The basics of getting started with Perforce](#setup)

## Module Description

The Perforce module installs, configures, and manages the various Perforce components.



This is the perforce module. It provides the ability to manage Perforce client
and server components, within an SDP (Server Deployment Package) environment.

## Setup

### Getting Started with Perforce

#### Perforce Client (p4)

If you want the Perforce command-line client (p4) installed with the default options you can run

`include '::perforce::client'`

If you need to customize options, such as the p4 version to install or the install location, you can pass in the attributes:

~~~
class { '::perforce::client':
  p4_version    => '2015.1',
  install_dir   => '/usr/local/bin',
}
~~~

When installing in an SDP (Server Deployment Package) environment, ensure that the perforce::sdp_base class is declared. If declared, then the client software will be installed in the /p4/common/bin directory and the associated version and symbolic links will be created. When installing in an SDP environment, do not specify the install_dir attribute, as the install location should be controlled by the SDP installation.

~~~
include ::perforce::sdp_base
include ::perforce::client
~~~
