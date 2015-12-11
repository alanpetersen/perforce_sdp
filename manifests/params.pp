# perforce::params class
#   - provides default and calculated values for various variables
class perforce::params {
  $adminuser              = 'p4admin'
  $adminpass              = undef
  $mail_to                = 'p4admins'
  $mail_from              = 'p4admin'
  $ssl_prefix             = undef
  $sdp_version            = 'Rev. SDP/MultiArch/2015.1/15810 (2015/09/21).'
  $p4_version             = '2015.1'
  $p4d_version            = '2015.1'
  $p4broker_version       = '2015.1'
  $source_location_base   = 'ftp://ftp.perforce.com/perforce'

  $refresh_staged_file    = false

  $p4_version_short       = regsubst($p4_version, '^20', '', 'G')
  $p4d_version_short      = regsubst($p4d_version, '^20', '', 'G')
  $p4broker_version_short = regsubst($p4broker_version, '^20', '', 'G')

  $parts                  = split($sdp_version, ' ')
  $sdp_rev_field          = regsubst($parts[1], 'SDP/MultiArch/', '', 'G')
  $sdp_version_short      = regsubst($sdp_rev_field, '/', '.', 'G')

  case $::kernel {
    'Linux': {
      if $::kernelmajversion == '2.6' {
        if $::architecture == 'x86_64' {
          $dist_dir = 'bin.linux26x86_64'
        } else {
          $dist_dir = 'bin.linux26x86'
        }
      }
      $osuser              = 'perforce'
      $osuser_password     = undef
      $osgroup             = 'perforce'
      $sdp_type            = 'Unix'
      $p4_dir              = '/p4'
      $depotdata_dir       = '/depotdata'
      $metadata_dir        = '/metadata'
      $logs_dir            = '/logs'
      $default_install_dir = '/usr/local/bin'
      $default_os_user     = 'root'
      $default_os_group    = 'root'
      $sdp_distro          = "sdp.Unix.${sdp_version_short}.tgz"
      $staging_base_path   = '/var/staging'
      $p4_executable       = 'p4'
      $p4d_executable      = 'p4d'
      $p4broker_executable = 'p4broker'
      $default_file_mode   = '0755'
    }
    'Windows': {
      $osuser              = 'Perforce'
      $osuser_password     = 'p@ssw0rd'
      $osgroup             = 'Perforce_Group'
      $sdp_type            = 'Windows'
      $p4_dir              = 'c:/p4'
      $depotdata_dir       = 'c:/depotdata'
      $metadata_dir        = 'c:/metadata'
      $logs_dir            = 'c:/logs'
      $default_install_dir = 'c:/Perforce'
      $default_os_user     = 'Administrator'
      $default_os_group    = 'Administrators'
      $sdp_distro          = "sdp.Windows.${sdp_version_short}.zip"
      $staging_base_path   = 'c:/staging'
      $p4_executable       = 'p4.exe'
      $p4d_executable      = 'p4d.exe'
      $p4broker_executable = 'p4broker.exe'
      $default_file_mode   = '0666'
      if $::os[architecture] == 'x64' {
        $dist_dir = 'bin.ntx64'
      } else  {
        $dist_dir = 'bin.ntx86'
      }
    }
    default: {
      fail("Kernel OS ${::kernel} is not suppported")
    }
  }

}
