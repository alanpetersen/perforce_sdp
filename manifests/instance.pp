define perforce_sdp::instance (
  $instanceName = $title,
  $p4port = 1666,
  $serverId,
) {
  include perforce_sdp::base
  
  File {
    owner => $perforce_sdp::base::osuser,
    group => $perforce_sdp::base::osgroup,
    mode  => '0600',
  }
  
  $p4_dir = $perforce_sdp::base::p4_dir
  $depotdata_dir = $perforce_sdp::base::depotdata_dir
  $metadata_dir = $perforce_sdp::base::metadata_dir
  $logs_dir = $perforce_sdp::base::logs_dir
  
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

  file { "${p4_dir}/${instanceName}/offline_db":
    ensure => 'symlink',
    target => "${metadata_dir}/p4/${instanceName}/offline_db",
  }

}