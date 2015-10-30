require 'spec_helper_acceptance'

describe 'perforce::server :', :unless => UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do

  context 'default parameters' do
    it 'should be compile successfully and be idempotent' do
      pp = "class { '::perforce::server': }"

      # Apply twice to ensure no errors the second time.
      apply_manifest(pp, :catch_failures => true)
      expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
    end

    describe command('p4d -V') do
      its(:exit_status) { should eq 0 }
    end
  end

  context 'sdp install with defaults' do
    pp = <<-EOF
    class {'::perforce::sdp_base':}
    class {'::perforce::client':}
    class {'::perforce::server':}
EOF

    apply_manifest(pp, :catch_failures => true)

  end

end
