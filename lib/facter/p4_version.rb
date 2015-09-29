# Fact: p4_version
#
# Purpose: get Perforce client version
#
# Resolution:
#   Tests for presence of p4, returns N/A if not present
#   returns revision information from output of "p4 -V"
#
# Caveats:
#   p4 must be found on the standard path
#
# Notes:
#   None

Facter.add(:p4_version) do
  version='N/A'
  if Facter::Util::Resolution.which('p4')
    Facter::Util::Resolution.exec('p4 -V 2>&1').lines.each do |line|
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
