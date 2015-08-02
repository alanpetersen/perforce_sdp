# Fact: p4d_version
#
# Purpose: get Perforce server version
#
# Resolution:
#   Tests for presence of p4d, returns N/A if not present
#   returns revision information from output of "p4d -V"
#
# Caveats:
#   none
#
# Notes:
#   None

Facter.add(:p4d_version) do
  version='N/A'
  if Facter::Util::Resolution.which('p4d')
    Facter::Util::Resolution.exec('p4d -V 2>&1').lines.each do |line|
      if(line.start_with?("Rev."))
        parts = line.sub(/Rev\. /,'').split('/')
        major = parts[2]
        build = parts[3].split(' ')[0]
        version = major + "." + build
      end
    end
  end
  setcode do
    version
  end
end