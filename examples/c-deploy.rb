require_relative '../lib/blackops.rb'
load '/home/leandro/code1/blackops/BlackOpsFile'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    BlackOps.deploy( :master,
        logger: l
    )    
rescue => e
    l.reset
    l.log(e.to_console.red)
end