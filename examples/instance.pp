include perforce::sdp_base
include perforce::client
include perforce::server
# include perforce::broker

perforce::instance {'1':
  server_id    => 'master',
  ensure       => 'running',
  p4port       => '1666',
}

# perforce::instance {'2':
#   ensure          => 'running',
#   p4brokerport    => '2667',
#   p4broker_target => 'localhost:1666',
# }

# perforce::instance {'2':
#   p4port => '2666',
# }
#
# perforce::instance {'3':
#   ensure => 'stopped',
#   p4port => '3666',
# }
