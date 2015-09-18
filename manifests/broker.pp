class perforce_sdp::broker (
  $version = $perforce_sdp::params::p4broker_version_short
) inherits perforce_sdp::params {
  
  include perforce_sdp::base
  
  file { 'p4broker':
    path     => "${p4_dir}/common/bin/p4broker",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4broker",
    mode     => "0700",
    owner    => $osuser,
    group    => $osgroup,
    #notify   => Exec['create_p4broker_links'],
  }

  exec { 'create_p4broker_links':
    command     => "${p4_dir}/common/bin/create_links.sh p4broker",
    cwd         => "${p4_dir}/common/bin",
    refreshonly => true,
    user        => $osuser,
    subscribe   => File['p4broker'],
  }  
  
}