class perforce_sdp::params {
  
  $osuser = 'perforce'
  $osgroup = 'perforce'
  $adminuser = 'p4admin'
  $adminpass = 'adminP@SS'
  $p4_dir = '/p4'
  $depotdata_dir = '/depotdata'
  $metadata_dir = '/metadata'
  $logs_dir = '/logs'
  $sslprefix = ''
  $p4_version = '2015.1'
  $p4d_version = '2015.1'
  $p4broker_version = '2015.1'
    
  $p4_version_short = regsubst($p4_version, '^20', '', 'G')
  $p4d_version_short = regsubst($p4d_version, '^20', '', 'G')
  $p4broker_version_short = regsubst($p4broker_version, '^20', '', 'G')
  
  if $::kernel == 'Linux' {
    if $::kernelmajversion == '2.6' {
      if $::os[architecture] == "x86_64" {
        $dist_dir = 'bin.linux26x86_64'
      } else {
        $dist_dir = 'bin.linux26x86'
      }
    }
  } elsif $::kernel == 'Windows' {
    
  } else {
    fail("Kernel OS ${::kernel} is not suppported")
  }
  
}