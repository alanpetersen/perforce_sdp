require 'spec_helper_acceptance'

describe 'perforce::server:', :unless => UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do

  context 'testing with default parameters' do

    it 'should be compile successfully and be idempotent' do
      # clean up existing files -- both staged and installed
      shell('rm -rf /var/staging/perforce')
      shell('rm -f /usr/local/bin/p4d')

      pp = "class { '::perforce::server': }"
      # Apply twice to ensure no errors the second time.
      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    describe command('/usr/local/bin/p4d -V') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match /Perforce - The Fast Software Configuration Management System/ }
    end

  end

  context 'testing with specific version' do

    it 'should be compile successfully and be idempotent' do
      # clean up existing files -- both staged and installed
      shell('rm -rf /var/staging/perforce')
      shell('rm -f /usr/local/bin/p4d')

      pp = <<-EOF
        class {'::perforce::server':
          p4d_version => '2012.2',
        }
      EOF
      apply_manifest(pp, :catch_failures => true)
    end

    describe command('/usr/local/bin/p4d -V') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match /2012\.2/ }
    end

  end

end
