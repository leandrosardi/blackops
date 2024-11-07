require_relative '../lib/blackops.rb'
require_relative '../BlackOpsFile'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    #BlackOps.nodes.map { |n| n[:name] }.each { |name|
name='master'
        l.logs "#{name.blue}... "
        BlackOps.deploy( name.to_sym,
            logger: l
        )
        l.done
    #}
rescue => e
    l.reset
    l.log(e.to_console.red)
end