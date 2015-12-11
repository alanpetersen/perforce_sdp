# perforce::broker class
#   - used to manage the p4broker binary
class perforce::broker (
  $p4broker_version     = $perforce::params::p4broker_version,
  $source_location_base = $perforce::params::source_location_base,
  $dist_dir             = $perforce::params::dist_dir,
  $install_dir          = undef,
  $staging_base_path    = $perforce::params::staging_base_path,
  $refresh_staged_file  = $perforce::params::refresh_staged_file,
) inherits perforce::params {

  $p4broker_version_short = regsubst($p4broker_version, '^20', '', 'G')
  $source_location        = "${source_location_base}/r${p4broker_version_short}/${dist_dir}/p4broker"

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  $staged_file_location = "${staging_base_path}/${module_name}/p4broker"

  if $refresh_staged_file {
    file {'clear_staged_p4broker':
      ensure => 'absent',
      path   => $staged_file_location,
    }
  }

  staging::file { 'p4broker':
    source => $source_location,
  }

  if $install_dir == undef {
    if defined(Class['perforce::sdp_base']) {
      $actual_install_dir = "${perforce::sdp_base::p4_dir}/common/bin"
      $p4broker_owner = $perforce::sdp_base::osuser
      $p4broker_group = $perforce::sdp_base::osgroup
      exec { 'create_p4broker_links':
        command     => "${perforce::params::p4_dir}/common/bin/create_links.sh p4broker",
        cwd         => "${perforce::params::p4_dir}/common/bin",
        refreshonly => true,
        user        => $p4broker_owner,
        group       => $p4broker_group,
        subscribe   => File['p4broker'],
      }
    } else {
      $actual_install_dir = $perforce::params::default_install_dir
      $p4broker_owner = 'root'
      $p4broker_group = 'root'
    }
  } else {
    $actual_install_dir = $install_dir
    $p4broker_owner = 'root'
    $p4broker_group = 'root'
  }

  file {'p4broker':
    ensure  => file,
    path    => "${actual_install_dir}/p4broker",
    mode    => '0700',
    owner   => $p4broker_owner,
    group   => $p4broker_group,
    source  => "file:///${staged_file_location}",
    require => Staging::File['p4broker'],
  }

}
