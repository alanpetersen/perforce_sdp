class perforce::sdp_base (
  $osuser               = $perforce::params::osuser,
  $osgroup              = $perforce::params::osgroup,
  $adminuser            = $perforce::params::adminuser,
  $adminpass            = $perforce::params::adminpass,
  $mail_to              = $perforce::params::mail_to,
  $mail_from            = $perforce::params::mail_from,
  $p4_dir               = $perforce::params::p4_dir,
  $depotdata_dir        = $perforce::params::depotdata_dir,
  $metadata_dir         = $perforce::params::metadata_dir,
  $logs_dir             = $perforce::params::logs_dir,
  $sslprefix            = $perforce::params::sslprefix,
  $sdp_version          = $perforce::params::sdp_version,
  $staging_base_path    = $perforce::params::staging_base_path,
) inherits perforce::params {

  File {
    ensure => 'file',
    owner  => $osuser,
    group  => $osgroup,
    mode   => '0600',
  }

  group { $osgroup:
    ensure => 'present'
  }

  user { $osuser:
    ensure => 'present',
    gid    => $osgroup,
    home   => $p4_dir,
  }

  $p4_dir_expanded = splitpath($p4_dir)
  file { $p4_dir_expanded:
    ensure => 'directory',
  }

  $depotdata_dir_expanded = splitpath("$depotdata_dir/p4")
  file { $depotdata_dir_expanded:
    ensure => 'directory',
  }

  $metadata_dir_expanded = splitpath("$metadata_dir/p4")
  file { $metadata_dir_expanded:
    ensure => 'directory',
  }

  $logs_dir_expanded = splitpath("$logs_dir/p4")
  file { $logs_dir_expanded:
    ensure => 'directory',
  }

  if(!defined(Class['staging'])) {
    class { 'staging':
      path  => $staging_base_path,
    }
  }

  staging::file { $sdp_distro:
    source => "puppet:///modules/perforce/${sdp_distro}"
  }

  staging::extract { $sdp_distro:
    target  => $depotdata_dir,
    creates => "${depotdata_dir}/sdp",
    require => Staging::File[$sdp_distro],
  }

  file { "${p4_dir}/Version":
    source  => "file:///${depotdata_dir}/sdp/Version",
    require => Staging::Extract[$sdp_distro],
  }

  file { "${depotdata_dir}/common":
    mode    => '0700',
    source  => "file:///${depotdata_dir}/sdp/Server/${sdp_type}/p4/common",
    recurse => true,
    require => Staging::Extract[$sdp_distro],
  }

  file { "${depotdata_dir}/common/bin/create_links.sh":
    mode    => '0700',
    source  => 'puppet:///modules/perforce/create_links.sh',
    require => Staging::Extract[$sdp_distro],
  }

  file { "${depotdata_dir}/common/bin/p4d_base":
    mode    => '0700',
    source  => 'puppet:///modules/perforce/p4d_base',
    require => Staging::Extract[$sdp_distro],
  }

  file { "${p4_dir}/common":
    ensure => 'symlink',
    target => "${depotdata_dir}/common",
  }

  file { "${p4_dir}/sdp":
    ensure => 'symlink',
    target => "${depotdata_dir}/sdp",
  }

  file { "${p4_dir}/ssl":
    ensure => 'directory',
  }

  file { "${p4_dir}/common/config":
    ensure => 'directory',
  }

  file { "${p4_dir}/common/bin/p4_vars":
    mode    => '0700',
    content => template('perforce/p4_vars.erb')
  }

  if $adminpass {
    file { "${p4_dir}/common/bin/adminpass":
      mode    => '0400',
      content => $adminpass,
    }
  }

}
