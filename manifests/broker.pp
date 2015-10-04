class perforce::broker (
  $p4broker_version     = $perforce::params::p4broker_version,
  $source_location_base = $perforce::params::source_location_base,
  $dist_dir             = $perforce::params::dist_dir,
  $install_dir          = undef,
  $staging_base_path    = $perforce::params::staging_base_path,
) inherits perforce::params {

  $source_location = "${source_location_base}/r${p4_version_short}/${dist_dir_base}/p4broker"

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  staging::file { 'p4broker':
    source => $source_location,
  }

  if $install_dir == undef {
    if defined(Class['perforce::sdp_base']) {
      $actual_install_dir = "${perforce::sdp_base::p4_dir}/common/bin"
      $p4d_owner = $perforce::sdp_base::osuser
      $p4d_group = $perforce::sdp_base::osgroup
      exec { 'create_p4broker_links':
        command     => "${p4_dir}/common/bin/create_links.sh p4broker",
        cwd         => "${p4_dir}/common/bin",
        refreshonly => true,
        user        => $p4d_owner,
        group       => $p4_group,
        subscribe   => File['p4broker'],
      }
    } else {
      $actual_install_dir = $default_install_dir
      $p4d_owner = 'root'
      $p4d_group = 'root'
    }
  } else {
    $actual_install_dir = $install_dir
    $p4d_owner = 'root'
    $p4d_group = 'root'
  }

  file {'p4broker':
    ensure  => file,
    path    => "${actual_install_dir}/p4broker",
    mode    => '0700',
    owner   => $p4d_owner,
    group   => $p4d_group,
    source  => "file:///${staging_base_path}/perforce/p4broker",
    require => Staging::File['p4broker'],
  }

}
