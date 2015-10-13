class perforce::server (
  $p4d_version          = $perforce::params::p4d_version,
  $source_location_base = $perforce::params::source_location_base,
  $dist_dir             = $perforce::params::dist_dir,
  $install_dir          = undef,
  $staging_base_path    = $perforce::params::staging_base_path,
  $refresh_staged_file  = $perforce::params::refresh_staged_file,
) inherits perforce::params {

  $p4d_version_short = regsubst($p4d_version, '^20', '', 'G')
  $source_location   = "${source_location_base}/r${p4server_version_short}/${dist_dir_base}/p4d"

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  $staged_file_location = "${staging_base_path}/${module_name}/p4d"

  if $refresh_staged_file {
    file {'clear_staged_p4d':
      ensure => 'absent',
      path   => $staged_file_location,
    }
  }

  staging::file { 'p4d':
    source => $source_location,
  }

  if $install_dir == undef {
    if defined(Class['perforce::sdp_base']) {
      $actual_install_dir = "${perforce::sdp_base::p4_dir}/common/bin"
      $p4d_owner = $perforce::sdp_base::osuser
      $p4d_group = $perforce::sdp_base::osgroup
      exec { 'create_p4d_links':
        command     => "${perforce::sdp_base::p4_dir}/common/bin/create_links.sh p4d",
        cwd         => "${perforce::sdp_base::p4_dir}/common/bin",
        refreshonly => true,
        user        => $p4d_owner,
        group       => $p4_group,
        subscribe   => File['p4d'],
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

  file {'p4d':
    ensure  => file,
    path    => "${actual_install_dir}/p4d",
    mode    => '0700',
    owner   => $p4d_owner,
    group   => $p4d_group,
    source  => "file:///${staged_file_location}",
    require => Staging::File['p4d'],
  }

}
