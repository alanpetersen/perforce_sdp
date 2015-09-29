class perforce::server (
  $osuser               = perforce::params::osuser,
  $osgroup              = perforce::params::osgroup,
  $adminuser            = perforce::params::adminuser,
  $adminpass            = perforce::params::adminpass,
  $p4_dir               = perforce::params::p4_dir,
  $depotdata_dir        = perforce::params::depotdata_dir,
  $metadata_dir         = perforce::params::metadata_dir,
  $logs_dir             = perforce::params::logs_dir,
  $sslprefix            = perforce::params::sslprefix,
  $p4_version           = perforce::params::p4_version,
  $p4d_version          = perforce::params::p4d_version,
  $p4broker_version     = perforce::params::p4broker_version,
  $source_location_base = perforce::params::source_location_base,
inherits perforce::params {

  include perforce_sdp::base

  file { 'p4d':
    path     => "${p4_dir}/common/bin/p4d",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4d",
    mode     => '0700',
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
