require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    BlackOps.source( :master,
        op: :hostname,
        connect_as_root: true,
        logger: l
    )
rescue => e
    l.log(e.to_console.red)
end