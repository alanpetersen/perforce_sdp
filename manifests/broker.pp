class perforce_sdp::broker (
  $version = $perforce_sdp::params::p4broker_version
) inherits perforce_sdp::params {
  
  include perforce_sdp::base
  
  file { 'p4broker':
    path     => "${p4_dir}/common/bin/p4broker",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4broker",
    mode     => "0700",
    notify   => Exec['fix_links.sh'],
  }
  
}