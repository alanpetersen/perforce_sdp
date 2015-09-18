class perforce_sdp::server (
  $version = $perforce_sdp::params::p4d_version_short
) inherits perforce_sdp::params {
  
  include perforce_sdp::base
  
  file { 'p4d':
    path     => "${p4_dir}/common/bin/p4d",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4d",
    mode     => "0700",
    owner    => $osuser,
    group    => $osgroup,
  }
  
  exec { 'create_p4d_links':
    command     => "${p4_dir}/common/bin/create_links.sh p4d",
    cwd         => "${p4_dir}/common/bin",
    refreshonly => true,
    user        => $osuser,
    subscribe   => File['p4d'],
  }
  
}