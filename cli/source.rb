require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
=begin
    BlackOps.source_remote( :w01a,
        op: :'mysaas.install.ubuntu_20_04.base',
        connect_as_root: true,
        logger: l
    )
=end
    BlackOps.source_remote( :w01a,
        op: :'mysaas.install.ubuntu_20_04.adspower',
        connect_as_root: true,
        logger: l
    )
rescue => e
    l.reset
    l.log(e.to_console.red)
end