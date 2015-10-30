# Class: perforce_sdp
#
# This module manages perforce_sdp
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class perforce (
  $osuser           = $perforce_sdp::params::osuser,
  $osgroup          = $perforce_sdp::params::osgroup,
  $adminuser        = $perforce_sdp::params::adminuser,
  $adminpass        = $perforce_sdp::params::adminpass,
  $p4_dir           = $perforce_sdp::params::p4_dir,
  $depotdata_dir    = $perforce_sdp::params::depotdata_dir,
  $metadata_dir     = $perforce_sdp::params::metadata_dir,
  $logs_dir         = $perforce_sdp::params::logs_dir,
  $sslprefix        = $perforce_sdp::params::sslprefix,
  $p4_version       = $perforce_sdp::params::p4_version,
  $p4d_version      = $perforce_sdp::params::p4d_version,
  $p4broker_version = $perforce_sdp::params::p4broker_version,
  $source_base      = $perforce_sdp::params::source_base,
) inherits perforce::params {
}
