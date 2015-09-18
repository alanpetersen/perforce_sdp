define perforce_sdp::instance (
  $instanceName = $title,
  $serverId = $::fqdn,
  $p4port = 1666,
  $caseSensitive = false,
) {
  include perforce_sdp::base
  
  $osuser = $perforce_sdp::base::osuser
  $osgroup = $perforce_sdp::base::osuser
  $p4_dir = $perforce_sdp::base::p4_dir
  $depotdata_dir = $perforce_sdp::base::depotdata_dir
  $metadata_dir = $perforce_sdp::base::metadata_dir
  $logs_dir = $perforce_sdp::base::logs_dir
  $sslprefix = $perforce_sdp::base::sslprefix
  $p4_version = $perforce_sdp::base::p4_version
  $p4d_version = $perforce_sdp::base::p4d_version
  $p4broker_version = $perforce_sdp::base::p4broker_version
  
  $p4_version_short = $perforce_sdp::base::p4_version_short
  $p4d_version_short = $perforce_sdp::base::p4d_version_short
  $p4broker_version_short = $perforce_sdp::base::p4broker_version_short
  
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
    ensure => file,
    content => "$serverId\n",
  }

  file { "${p4_dir}/${instanceName}/offline_db":
    ensure => 'symlink',
    target => "${metadata_dir}/p4/${instanceName}/offline_db",
  }

  file { "/etc/init.d/p4d_${instanceName}":
    content => template('perforce_sdp/p4d_instance_init.erb'),
    owner => 'root',
    group => 'root',
    mode => '0755',
  }
  
  file { "${p4_dir}/common/config/p4_${instanceName}.vars":
    ensure => 'file',
    mode => '0700',
    content => template('perforce_sdp/instance_vars.erb'),
  }
  
  file { "${p4_dir}/${instanceName}/bin/p4_${instanceName}":
    ensure => 'link',
    target => "${p4_dir}/common/bin/p4_${p4_version}_bin",
  }

  file { "${p4_dir}/common/bin/p4d_${instanceName}_bin":
    ensure => 'link',
    target => "${p4_dir}/common/bin/p4d_${p4_version}_bin",
  }
  
  if $caseSensitive {

    file { "${p4_dir}/${instanceName}/bin/p4d_${instanceName}":
      ensure => 'link',
      target => "${p4_dir}/common/bin/",
    }
    
  } else {
  
    file { "${p4_dir}/${instanceName}/bin/p4d_${instanceName}":
      ensure => 'file',
      content => template('perforce_sdp/case_insensitive_script.erb'),
      mode => '0700',
    }
 
  }
  
  service {"p4d_${instanceName}":
    ensure => 'running',
    enable => true,
    pattern => "p4d_${instanceName}_bin",
    require => File["/etc/init.d/p4d_${instanceName}"],
  }
  
  file { "${p4_dir}/${instanceName}/bin/p4d_${instanceName}_init":
    content => template('perforce_sdp/p4d_instance_init.erb'),
    mode => '0700',
  }
  
  
}