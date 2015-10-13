
perforce_sdp::instance {'1':
	p4port => '1666',
  serverId => 'master',
}

include perforce_sdp::server
include perforce_sdp::client
include perforce_sdp::broker

