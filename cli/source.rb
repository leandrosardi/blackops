require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    BlackOps.source( :master,
        op: :'install.ubuntu_20_04',
        connect_as_root: true,
        logger: l
    )
rescue => e
    l.reset
    l.log(e.to_console.red)
end