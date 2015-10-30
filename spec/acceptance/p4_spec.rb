require 'spec_helper_acceptance'

describe 'perforce::client :', :unless => UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do

  context 'default parameters' do
    it 'should be compile successfully and be idempotent' do
      pp = "class { '::perforce::client': }"

      # Apply twice to ensure no errors the second time.
      apply_manifest(pp, :catch_failures => true)
      expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
    end

    describe command('p4 -V') do
      its(:exit_status) { should eq 0 }
    end
  end

end
