define perforce::instance (
  $instanceName = $title,
  $serverId = $::fqdn,
  $p4port = 1666,
  $case_sensitive = false,
  $p4d_version = undef
) {

  if(!defined(Class['perforce::sdp_base'])) {
    fail('Usage: must declare perforce::sdp_base class before using this resource.')
  }

  if(!defined(Class['perforce::server'])) {
    fail('Usage: must declare perforce::server class before using this resource.')
  }

  $osuser = $perforce::sdp_base::osuser
  $osgroup = $perforce::sdp_base::osuser
  $p4_dir = $perforce::sdp_base::p4_dir
  $depotdata_dir = $perforce::sdp_base::depotdata_dir
  $metadata_dir = $perforce::sdp_base::metadata_dir
  $logs_dir = $perforce::sdp_base::logs_dir
  $sslprefix = $perforce::sdp_base::sslprefix

  if $p4d_version == undef {
    $p4d_instance_version = $perforce::sdp_base::p4d_version
  } else {
    $p4d_instance_version = $p4d_version
  }

  File {
    owner => $osuser,
    group => $osgroup,
    mode  => '0600',
  }

  file { ["${depotdata_dir}/p4",
          "${depotdata_dir}/p4/${instanceName}",
          "${depotdata_dir}/p4/${instanceName}/bin",
          "${depotdata_dir}/p4/${instanceName}/checkpoints",
          "${depotdata_dir}/p4/${instanceName}/depots",
          "${depotdata_dir}/p4/${instanceName}/ssl",
          "${depotdata_dir}/p4/${instanceName}/tmp"]:
    ensure => 'directory',
  }

  file { ["${metadata_dir}/p4",
          "${metadata_dir}/p4/${instanceName}",
          "${metadata_dir}/p4/${instanceName}/root",
          "${metadata_dir}/p4/${instanceName}/offline_db",]:
    ensure => 'directory',
  }

  file { ["${logs_dir}/p4",
          "${logs_dir}/p4/${instanceName}",
          "${logs_dir}/p4/${instanceName}/logs"]:
    ensure => 'directory',
  }

  file { "${p4_dir}/${instanceName}":
    ensure => 'symlink',
    target => "${depotdata_dir}/p4/${instanceName}",
  }

  file { "${p4_dir}/${instanceName}/logs":
    ensure => 'symlink',
    target => "${logs_dir}/p4/${instanceName}/logs",
  }

  file { "${p4_dir}/${instanceName}/root":
    ensure => 'symlink',
    target => "${metadata_dir}/p4/${instanceName}/root",
  }

  file { "${p4_dir}/${instanceName}/root/server.id":
    ensure  => file,
    content => "${serverId}\n",
  }

  file { "${p4_dir}/${instanceName}/offline_db":
    ensure => 'symlink',
    target => "${metadata_dir}/p4/${instanceName}/offline_db",
  }

  file { "/etc/init.d/p4d_${instanceName}":
    content => template('perforce/p4d_instance_init.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }

  file { "${p4_dir}/common/config/p4_${instanceName}.vars":
    ensure  => 'file',
    mode    => '0700',
    content => template('perforce/instance_vars.erb'),
  }

  file { "${p4_dir}/${instanceName}/bin/p4_${instanceName}":
    ensure => 'link',
    target => "${p4_dir}/common/bin/p4_${p4d_instance_version}_bin",
  }

  file { "${p4_dir}/common/bin/p4d_${instanceName}_bin":
    ensure => 'link',
    target => "${p4_dir}/common/bin/p4d_${p4d_instance_version}_bin",
  }

  file { "${p4_dir}/${instanceName}/bin/p4d_${instanceName}":
    ensure  => 'file',
    content => template('perforce/instance_script.erb'),
    mode    => '0700',
  }

  service {"p4d_${instanceName}":
    ensure  => 'running',
    enable  => true,
    pattern => "p4d_${instanceName}_bin",
    require => File["/etc/init.d/p4d_${instanceName}"],
  }

  file { "${p4_dir}/${instanceName}/bin/p4d_${instanceName}_init":
    content => template('perforce/p4d_instance_init.erb'),
    mode    => '0700',
  }


}
