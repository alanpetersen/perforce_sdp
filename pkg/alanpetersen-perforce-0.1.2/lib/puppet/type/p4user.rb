Puppet::Type.newtype(:p4user) do
  @doc = "Creates and manages Perforce users. This type is designed to be used with a Perforce Server Deployment Package (SDP) installation."

  newparam(:name, :namevar => true) do
    desc "user's id"
  end

  newparam(:email) do
    desc "user's email address"
  end

  newparam(:fullName) do
    desc "user's full name"
  end

  newparam(:password) do
    desc "user's password"
  end
  
  newparam(:instance) do
    desc "Perforce SDP instance"
  end
  
  newproperty(:ensure, :parent => Puppet::Property::Ensure) do
    newvalue(:present, :event => :user_created) do
      provider.create
    end
    
    newvalue(:absent, :event => :user_removed) do
      provider.delete
    end
    
  end
  
end