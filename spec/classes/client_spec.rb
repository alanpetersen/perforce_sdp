require "spec_helper"

describe 'perforce::client' do

  describe 'testing with unsupported OS' do
    let(:facts) do
      { :kernel => 'foo'}
    end
    it { is_expected.not_to compile.and_raise_error(/not supported/)  }
  end

  context 'testing with supported OS and default parameters' do
    let(:facts) do
      { :kernel => 'Linux'}
    end
    it { is_expected.to compile.with_all_deps  }
    it { is_expected.to contain_class('staging') }
    it { is_expected.to contain_class('perforce::client') }
    it { should contain_file('p4').with_path('/usr/local/bin/p4') }
  end

end
