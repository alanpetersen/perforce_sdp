# perforce

#### Table of Contents
1. [Module Description - What the module does and why it is useful](#module-description)
1. [Setup - The basics of getting started with Perforce](#setup)
  * [Common Attributes - ](#common-attributes)
  * [Perforce Client (p4) - command-line client used to interact with a Perforce service](#perforce-client)
  * [Perforce Server (p4d) - the main Perforce service](#perforce-server)
  * [Perforce Broker (p4broker) - the Perforce broker component](#perforce-broker)
1. [Server Deployment Package - managing the SDP with Puppet](#server-deployment-package)
  * [Managing Instances - managing service (p4d and p4broker) instances](#managing-instances)

## Module Description

The Perforce module installs, configures, and manages the various Perforce components.

> NOTE: This module is currently under development. I thought I'd release it to the forge as it's
> progressed pretty well, but there are still several things that are being modified.
>
> Specifically:
> * Documentation -- docs are a work in progress (aren't they always??)
> * Tests -- basic unit tests are in the `examples` directory, but rspec tests are still forthcoming
> * Windows Support -- still needs some work so right now it's not enabled

This is the perforce module. It provides the ability to manage Perforce client
and server components, within an SDP (Server Deployment Package) environment.

## Setup

### Getting Started with Perforce

#### Common attributes

The client, server and broker classes support the following common attributes:

| attribute            | description |
| -------------------- | ----------- |
| source_location_base | Base location for the source. Defaults to `ftp://ftp.perforce.com/perforce` |
| dist_dir_base        | Distribution directory base -- used as part of the source path (after the r*version_number* directory). This value is calculated based on the OS and architecture. |
| staging_base_path    | The location where the binaries will be staged on the local node's filesystem. This defaults to `/var/staging/perforce`. |
| install_dir          | The location where the binaries will be installed |
| refresh_staged_file  | a boolean indicating whether the staged file should be refreshed. Defaults to `false`. The implication of this is that new versions will not be downloaded as long as the staged file is present, so upgrades need to have this value (temporarily) set to `true`. This value could be left as `true` if the source_location_base is some local system. |

For example, on 64-bit Linux, the default location for the p4d binary would be
`ftp://ftp.perforce.com/perforce/r15.1/bin.linux26x86_64/p4d`

#### Perforce Client

##### Usage

If you want the Perforce command-line client (p4) managed with the default options you can declare

`include '::perforce::client'`

If you need to customize options, such as the p4 version to manage or the install location, you can pass in the attributes:

~~~
class { '::perforce::client':
  p4_version    => '2015.1',
  install_dir   => '/usr/local/bin',
}
~~~

When installing in an SDP (Server Deployment Package) environment, ensure that the `perforce::sdp_base` class is declared. If declared, then the client software will be installed in the /p4/common/bin directory and the associated version and symbolic links will be created. When installing in an SDP environment, do not specify the install_dir attribute, as the install location should be controlled by the SDP installation.

~~~
include ::perforce::sdp_base
include ::perforce::client
~~~

##### Attributes

In addition to the common attributes, the following attributes are available with the `perforce::client` class:

| attribute  | description |
| ---------- | ----------- |
| p4_version | The version of the p4 client to manage. Defaults to `2015.1`. |


#### Perforce Server

> NOTE: This class is used to manage the p4d binaries on the node, but it does not manage an instance.
> Instances can be managed using the defined type `perforce::instance`, but this type does require
> that the SDP is also being managed.

##### Usage

If you want the Perforce service (p4d) managed with the default options you can declare

`include '::perforce::server'`

If you need to customize options, such as the p4 version to manage or the install location, you can pass in the attributes:

~~~
class { '::perforce::client':
  p4_version    => '2015.1',
  install_dir   => '/usr/local/bin',
}
~~~

When installing in an SDP (Server Deployment Package) environment, ensure that the `perforce::sdp_base` class is declared. If declared, then the software will be installed in the /p4/common/bin directory and the associated version and symbolic links will be created. When installing in an SDP environment, do not specify the install_dir attribute, as the install location should be controlled by the SDP installation.

The SDP requires that a Perforce client also be present, so typically the `perforce::client` class should also be declared

~~~
include ::perforce::sdp_base
include ::perforce::client
include ::perforce::server
~~~

##### Attributes

In addition to the common attributes, the following attributes are available with the `perforce::server` class:

| attribute  | description |
| ---------- | ----------- |
| p4d_version | The version of the p4 client to manage. Defaults to `2015.1`. |


#### Perforce Broker

> NOTE: This class is used to manage the p4broker binaries on the node, but it does not manage an instance.
> Instances can be managed using the defined type `perforce::instance`, but this type does require
> that the SDP is also being managed.

##### Usage

~~~
include ::perforce::sdp_base
include ::perforce::client
include ::perforce::broker
~~~

##### Attributes

In addition to the common attributes, the following attributes are available with the `perforce::broker` class:

| attribute  | description |
| ---------- | ----------- |
| p4broker_version | The version of the p4 client to manage. Defaults to `2015.1`. |


### Server Deployment Package

#### Managing Instances
