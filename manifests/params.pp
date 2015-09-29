class perforce::params {
  $osuser                 = 'perforce'
  $osgroup                = 'perforce'
  $adminuser              = 'p4admin'
  $adminpass              = undef
  $p4_dir                 = '/p4'
  $depotdata_dir          = '/depotdata'
  $metadata_dir           = '/metadata'
  $logs_dir               = '/logs'
  $sslprefix              = ''
  $sdp_version            = 'latest'
  $p4_version             = '2015.1'
  $p4d_version            = '2015.1'
  $p4broker_version       = '2015.1'
  $source_location_base   = 'ftp://ftp.perforce.com/perforce'

  $p4_version_short       = regsubst($p4_version, '^20', '', 'G')
  $p4d_version_short      = regsubst($p4d_version, '^20', '', 'G')
  $p4broker_version_short = regsubst($p4broker_version, '^20', '', 'G')

  case $::kernel {
    'Linux': {
      if $::kernelmajversion == '2.6' {
        if $::os[architecture] == 'x86_64' {
          $dist_dir_base = 'bin.linux26x86_64'
        } else {
          $dist_dir_base = 'bin.linux26x86'
        }
      }
      $sdp_type            = 'Unix'
      $default_install_dir = '/usr/local/bin'
      $sdp_distro          = "sdp.Unix.${sdp_version}.tgz"
      $staging_base_path   = '/var/staging'
    }
    'Windows': {
      $sdp_type            = 'Windows'
      $default_install_dir = 'c:/Program Files/Perforce'
      $sdp_distro          = "sdp.Windows.${sdp_version}.zip"
      $staging_base_path   = 'c:/staging'
    }
    default: {
      fail("Kernel OS ${::kernel} is not suppported")
    }
  }

}
