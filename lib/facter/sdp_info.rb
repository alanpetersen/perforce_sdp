require "open3"

vars = ["P4SERVER","P4PORT","SERVERID","P4HOME","P4LOG","P4JOURNAL","P4D_VERSION","P4ROOT","CHECKPOINTS","P4REPLICA"]

hash = {}

versionFile = '/p4/Version'
if File.exist?(versionFile)
	sdp_version = File.open(versionFile, &:readline).chomp()
  hash[:version] = sdp_version

  instances = {}
	Dir['/p4/common/config/p4_*.vars'].each do |file_name|
		next if File.directory? file_name
		instance = file_name.dup
		instance.gsub! '/p4/common/config/p4_', ''
		instance.gsub! '.vars', ''
		instance_vars = {}
		cmd = "(source /p4/common/bin/p4_vars " + instance + "; env)"
		lines = Array.new
		Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
			while line = stdout.gets
				line.chomp!
				var,value = line.split("=")
				if vars.include?(var)
					instance_vars[var] = value
				end
			end
		end
		instances[instance] = instance_vars
  end
  if !instances.empty?
    hash[:instances] = instances
  end
end

if !hash.empty?
  Facter.add(:sdp) do
    setcode do
      hash
    end
  end
end
