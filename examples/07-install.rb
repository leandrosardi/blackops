require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    BlackOps.install( :master,
        op: 'install.ubuntu_20_04',
        logger: l
    )    
rescue => e
    l.reset
    l.log(e.to_console.red)
end