class perforce_sdp::client (
  $version = $perforce_sdp::params::p4_version_short
) inherits perforce_sdp::params {  
  
  include perforce_sdp::base
  
  file { 'p4':
    path     => "${p4_dir}/common/bin/p4",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4",
    mode     => "0700",
    owner    => $osuser,
    group    => $osgroup,
    #notify   => Exec['create_p4_links'],
  }
  
  exec { 'create_p4_links':
    command     => "${p4_dir}/common/bin/create_links.sh p4",
    cwd         => "${p4_dir}/common/bin",
    refreshonly => true,
    user        => $osuser,
    subscribe   => File['p4'],
  }  
  
}
