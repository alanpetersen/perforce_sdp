class perforce::sdp_dirs (
  $osuser,
  $osgroup,
  $p4_dir,
  $depotdata_dir,
  $metadata_dir = nil,
  $logs_dir = nil,
) {
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

  $depotdata_dir_expanded = splitpath($depotdata_dir)
  file { $depotdata_dir_expanded:
    ensure => 'directory',
  }

  staging::file { 'sample.tar.gz':
    source => 'puppet:///modules/perforce/sample.tar.gz'
  }

  staging::extract { 'sample.tar.gz':
    target  => '/tmp/staging',
    creates => '/tmp/staging/sample',
    require => Staging::File['sample.tar.gz'],
  }
}
