class perforce_sdp::client (
  $version = $perforce_sdp::params::p4_version
) inherits perforce_sdp::params {  
  
  include perforce_sdp::base
  
  file { 'p4':
    path     => "${p4_dir}/common/bin/p4",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4",
    mode     => "0700",
    notify   => Exec['fix_links.sh'],
  }
}
