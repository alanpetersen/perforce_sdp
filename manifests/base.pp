class perforce_sdp::base (
   $depotdata_dir = $perforce_sdp::params::depotdata_dir,
   $sslprefix = $perforce_sdp::params::sslprefix,
) inherits perforce_sdp::params {
  
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
  
  file { [$p4_dir, $depotdata_dir, $metadata_dir, $logs_dir]:
    ensure => 'directory',
  }
  
  file { "${depotdata_dir}/common":
    mode => '0700',
    source => 'puppet:///modules/perforce_sdp/Server/Unix/p4/common',
    recurse => true,
  }

  file { "${p4_dir}/common":
    ensure => 'symlink',
    target => "${depotdata_dir}/common",
  }

  file { "${p4_dir}/common/config":
    ensure => 'directory',
  }
  
  file { "${p4_dir}/common/bin/p4_vars":
    mode => '0700',
    content => template('perforce_sdp/p4_vars.erb')
  }

  if $adminpass {
    file { "${p4_dir}/common/bin/adminpass":
      mode => '0400',
      content => $adminpass,
    }
  }
  
}