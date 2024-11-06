require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    #BlackOps.nodes.map { |n| n[:name] }.each { |name|
name = 'w01b'
        l.logs "#{name.blue}... "
        BlackOps.start( name.to_sym,
            logger: l
        )
        l.done
    #}
rescue => e
    l.reset
    l.log(e.to_console.red)
end