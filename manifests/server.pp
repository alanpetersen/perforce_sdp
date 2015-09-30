class perforce::server (
  $p4d_version          = $perforce::params::p4d_version,
  $source_location_base = $perforce::params::source_location_base,
  $dist_dir             = $perforce::params::dist_dir,
  $install_dir          = undef,
  $staging_base_path    = $perforce::params::staging_base_path,
) inherits perforce::params {

  $source_location = "${source_location_base}/r${p4_version_short}/${dist_dir_base}/p4d"

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  staging::file { 'p4d':
    source => $source_location,
  }

  if $install_dir == undef {
    if defined(Class['perforce::sdp_base']) {
      $actual_install_dir = "${perforce::sdp_base::p4_dir}/common/bin"
    } else {
      $actual_install_dir = $default_install_dir
    }
  } else {
    $actual_install_dir = $install_dir
  }

  file {'p4d':
    ensure  => file,
    path    => "${actual_install_dir}/p4d",
    mode    => '0755',
    source  => "file:///${staging_base_path}/perforce/p4d",
    require => Staging::File['p4d'],
  }

  # exec { 'create_p4d_links':
  #   command     => "${p4_dir}/common/bin/create_links.sh p4d",
  #   cwd         => "${p4_dir}/common/bin",
  #   refreshonly => true,
  #   user        => $osuser,
  #   subscribe   => File['p4d'],
  # }

}
