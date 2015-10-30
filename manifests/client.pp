# perforce::client class
#   - used to manage the p4 binary
class perforce::client (
  $p4_version           = $perforce::params::p4_version,
  $p4_executable        = $perforce::params::p4_executable,
  $source_location_base = $perforce::params::source_location_base,
  $dist_dir             = $perforce::params::dist_dir,
  $install_dir          = undef,
  $staging_base_path    = $perforce::params::staging_base_path,
  $refresh_staged_file  = $perforce::params::refresh_staged_file,
  $default_install_dir  = $perforce::params::default_install_dir,
  $default_os_user      = $perforce::params::default_os_user,
  $default_os_group     = $perforce::params::default_os_group,
  $default_file_mode    = $perforce::params::default_file_mode,
) inherits perforce::params {

  $p4_version_short = regsubst($p4_version, '^20', '', 'G')
  $source_location  = "${source_location_base}/r${p4_version_short}/${dist_dir}/${p4_executable}"

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  $staged_file_location = "${staging_base_path}/${module_name}/${p4_executable}"

  if $refresh_staged_file {
    file {'clear_staged_p4':
      ensure => 'absent',
      path   => $staged_file_location,
    }
  }

  staging::file { $p4_executable:
    source => $source_location,
  }

  if $install_dir == undef {
    if defined(Class['perforce::sdp_base']) {
      $actual_install_dir = "${perforce::sdp_base::p4_dir}/common/bin"
      $p4_owner = $perforce::sdp_base::osuser
      $p4_group = $perforce::sdp_base::osgroup
      exec { 'create_p4_links':
        command     => "${perforce::params::p4_dir}/common/bin/create_links.sh p4",
        cwd         => "${perforce::params::p4_dir}/common/bin",
        refreshonly => true,
        user        => $p4_owner,
        group       => $p4_group,
        subscribe   => File['p4'],
      }
    } else {
      $actual_install_dir = $default_install_dir
      $p4_owner = $default_os_user
      $p4_group = $default_os_group
    }
  } else {
    $actual_install_dir = $install_dir
    $p4_owner = $default_os_user
    $p4_group = $default_os_group
  }

  if !defined(File[$actual_install_dir]) {
    notice("### managing dir: ${actual_install_dir}")
    file { $actual_install_dir:
      ensure => 'directory',
      owner  => $p4_owner,
      group  => $p4_group,
      mode   => '0777',
      before => File['p4'],
    }
  }

  file {'p4':
    ensure  => file,
    path    => "${actual_install_dir}/${p4_executable}",
    mode    => '0755',
    owner   => $p4_owner,
    group   => $p4_group,
    source  => "file:///${staged_file_location}",
    require => Staging::File[$p4_executable],
  }

}
