class perforce_sdp::server (
  $version = $perforce_sdp::params::p4d_version
) inherits perforce_sdp::params {
  
  include perforce_sdp::base
  
  file { 'p4d':
    path     => "${p4_dir}/common/bin/p4d",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4d",
    mode     => "0700",
    notify   => Exec['fix_links.sh'],
  }
  
}