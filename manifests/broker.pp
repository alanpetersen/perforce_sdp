class perforce::broker (
  $osuser               = $perforce::params::osuser,
  $osgroup              = $perforce::params::osgroup,
  $adminuser            = $perforce::params::adminuser,
  $adminpass            = $perforce::params::adminpass,
  $p4_dir               = $perforce::params::p4_dir,
  $depotdata_dir        = $perforce::params::depotdata_dir,
  $metadata_dir         = $perforce::params::metadata_dir,
  $logs_dir             = $perforce::params::logs_dir,
  $sslprefix            = $perforce::params::sslprefix,
  $p4_version           = $perforce::params::p4_version,
  $p4d_version          = $perforce::params::p4d_version,
  $p4broker_version     = $perforce::params::p4broker_version,
  $source_location_base = $perforce::params::source_location_base,
) inherits perforce::params {

  include perforce_sdp::base

  file { 'p4broker':
    path     => "${p4_dir}/common/bin/p4broker",
    checksum => 'md5lite',
    source   => "puppet:///modules/perforce_sdp/${version}/${dist_dir}/p4broker",
    mode     => '0700',
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
