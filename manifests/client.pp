class perforce::client (
  $p4_version           = $perforce::params::p4_version,
  $source_location_base = $perforce::params::source_location_base,
  $dist_dir             = $perforce::params::dist_dir,
  $install_dir          = undef,
  $staging_base_path    = $perforce::params::staging_base_path,
  $refresh_staged_file  = $perforce::params::refresh_staged_file,
) inherits perforce::params {

  $p4_version_short = regsubst($p4_version, '^20', '', 'G')
  $source_location  = "${source_location_base}/r${p4_version_short}/${dist_dir_base}/p4"

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  $staged_file_location = "${staging_base_path}/${module_name}/p4"

  if $refresh_staged_file {
    file {'clear_staged_p4':
      ensure => 'absent',
      path   => $staged_file_location,
  #    before => Staging::File['p4'],
    }
    # exec { 'delete_staged_p4':
    #   command => "/bin/rm ${staging_base_path}/perforce/p4",
    #   before => Staging::File['p4'],
    # }
  }

  staging::file { 'p4':
    source => $source_location,
  }

  if $install_dir == undef {
    if defined(Class['perforce::sdp_base']) {
      $actual_install_dir = "${perforce::sdp_base::p4_dir}/common/bin"
      $p4_owner = $perforce::sdp_base::osuser
      $p4_group = $perforce::sdp_base::osgroup
      exec { 'create_p4_links':
        command     => "${p4_dir}/common/bin/create_links.sh p4",
        cwd         => "${p4_dir}/common/bin",
        refreshonly => true,
        user        => $p4_owner,
        group       => $p4_group,
        subscribe   => File['p4'],
      }
    } else {
      $actual_install_dir = $default_install_dir
      $p4_owner = 'root'
      $p4_group = 'root'
    }
  } else {
    $actual_install_dir = $install_dir
    $p4_owner = 'root'
    $p4_group = 'root'
  }

  file {'p4':
    ensure  => file,
    path    => "${actual_install_dir}/p4",
    mode    => '0700',
    owner   => $p4_owner,
    group   => $p4_group,
    source  => "file:///$staged_file_location",
    require => Staging::File['p4'],
  }

}
