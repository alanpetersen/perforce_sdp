require 'pathname'

module Puppet::Parser::Functions
  newfunction(:splitpath, :type => :rvalue) do |args|
    if args.length == 1
      path = ''
      final = []
      arr = Pathname(args[0]).each_filename.to_a
      arr.each do |a|
      	path += '/' + a
      	final << path
      end
      return final
    elsif args.length > 1
      raise Puppet::ParseError, "only 1 path may be supplied"
    else
      raise Puppet::ParseError, "path argument required"
    end
  end
end
