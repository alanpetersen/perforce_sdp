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
> * Other Product Support -- later I want to expand this to Proxy (p4p), P4Web, etc. support but
> initially I am focussed on p4, p4d, and p4broker

This is the perforce module. It provides the ability to manage Perforce client
and server components, within an SDP (Server Deployment Package) environment.

## Setup

### Getting Started with Perforce

#### Common attributes

The client, server and broker classes support the following common attributes:

| attribute            | description |
| -------------------- | ----------- |
| source_location_base | Base location for the source. Defaults to the standard Perforce distribution site: `ftp://ftp.perforce.com/perforce`. This can be hosted locally, using the following protocols: `http(s)`, `puppet`, `ftp`, or `local` (used for network mounts) |
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

If you need to customize options, such as the p4d version to manage or the install location, you can pass in the attributes:

~~~
class { '::perforce::server':
  p4d_version   => '2015.1',
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

If you want the Perforce broker service (p4broker) managed with the default options you can declare

`include '::perforce::broker'`

If you need to customize options, such as the p4broker version to manage or the install location, you can pass in the attributes:

~~~
class { '::perforce::broker':
  p4broker_version => '2015.1',
  install_dir      => '/usr/local/bin',
}
~~~

When installing in an SDP (Server Deployment Package) environment, ensure that the `perforce::sdp_base` class is declared. If declared, then the software will be installed in the /p4/common/bin directory and the associated version and symbolic links will be created. When installing in an SDP environment, do not specify the install_dir attribute, as the install location should be controlled by the SDP installation.

The SDP requires that a Perforce client also be present, so typically the `perforce::client` class should also be declared

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

The Perforce SDP provides a sample implementation of best practices, such as performing offline checkpoints, rotating logs and journals routinely, and doing a database sanity/safety check before starting the server. It is open source and available at [https://swarm.workshop.perforce.com/projects/perforce-software-sdp](https://swarm.workshop.perforce.com/projects/perforce-software-sdp)

#### SDP Commmon Files

##### Usage

The `perforce::sdp_base` class manages the base SDP installation. To declare this class and accept the default attribute values, you can use

`include '::perforce::sdp_base'`

If you need to customize options, such as the OS user to manage or the install location, you can pass in the attributes:

~~~
class { '::perforce::sdp_base':
  osuser => 'perforce',
  osgroup => 'perforce',
  p4_dir => '/p4',
}
~~~


##### Attributes

The following attributes can be used to configure how the SDP base installation is managed.

| attribute  | description |
| ---------- | ----------- |
| osuser            | Operating system user that will own the SDP directories and executables. This is managed within the class. Defaults to `perforce`. |
| osgroup           | Operating system group that will own the SDP directories and executables. This is managed within the class. Defaults to `perforce`. |
| adminuser         | Perforce admin user. Defaults to `p4admin`. This user will not be created in the Perforce server instance. |
| adminpass         | Password for the Perforce admin user. The value will be written to the adminpass file. Defaults to `undef`. |
| mail_to           | Email address to which administrative messages (e.g. daily backup script output) will be sent. Defaults to `p4admins`. |
| mail_from         | Email address used as the 'from' address in outgoing email messages. Defaults to `p4admin`. |
| p4_dir            | The base SDP directory. Defaults to `/p4` on Linux systems. |
| depotdata_dir     | The mountpoint for the Perforce depot data. This mountpoint must already exist (i.e. is managed outside the `perforce::sdp` class.). This defaults to `/depotdata` on Linux. |
| metadata_dir      | The mountpoint for the Perforce metadata. This mountpoint must already exist (i.e. is managed outside the `perforce::sdp` class.). This defaults to `/metadata` on Linux. |
| logs_dir          | The mountpoint for the Perforce and SDP log files. This mountpoint must already exist (i.e. is managed outside the `perforce::sdp` class.). This defaults to `/logs` on Linux. |
| sslprefix         | The default ssl prefix to use (e.g. `ssl:`). This defaults to `undef`. |
| sdp_version       | The SDP version to manage. This defaults to `Rev. SDP/MultiArch/2015.1/15810 (2015/09/21).` |
| staging_base_path | The location where the binaries will be staged on the local node's filesystem. This defaults to `/var/staging/perforce`. |



#### Managing Instances

##### Usage

Instances can only be managed within the context of an existing `perforce::sdp_base` installation. Managed instances can be server, broker, or both.

The `perforce::instance` defined type requires that

For example, to create a p4d instance called '1' with the server_id 'master', declare the following:

~~~
include ::perforce::sdp_base
include ::perforce::client
include ::perforce::server

::perforce::instance {'1':
  server_id    => 'master',
  ensure       => 'running',
  p4port       => '1666',
}
~~~

##### Attributes

###### common attributes
| attribute  | description |
| ---------- | ----------- |
| ensure     | The run setting for the managed services. Should be `running` or `stopped`. Default is `running`. |

###### p4d attributes
| attribute      | description |
| -------------- | ----------- |
| p4port         | If set, then a p4d instance is managed on the node. Default is `undef`. |
| server_id      | The server_id of the instance. A server_id file with the value of this attribute will be created in the root directory of the instance. Default is `$title` |
| is_master      | Flag to indicate whether this is a master or replica. Default is `true`. |
| master_dns     | The DNS name of the master server. This is needed if the instance is a replica. Default is `undef`. |
| ssl            | A boolean indicating whether or not ssl is required for the instance. Default is `false`. |
| case_sensitive | A boolean indicating whether or not the instance will run in case sensitive mode. Default is `false`. |
| p4d_version    | The version of p4d to use. Should be in the format *yyyy.n* (e.g. 2015.1). Default is `undef`. |

###### p4broker attributes
| attribute        | description |
| ---------------- | ----------- |
| p4brokerport     | If set, then a p4broker instance is managed on the node. Default is `undef`. |
| p4broker_version | The version of p4broker to use. Should be in the format *yyyy.n* (e.g. 2015.1). Default is `undef`. |
| p4broker_target  | The P4PORT of the instance with which the broker will communicate. Default is `undef`. |






.
