require_relative '../lib/blackops.rb'
load '/home/leandro/code1/secret/BlackOpsFile'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    #BlackOps.nodes.map { |n| n[:name] }.each { |name|
name = 'master'
        l.logs "#{name.blue}... "
        BlackOps.install( name.to_sym,
            logger: l
        )
        l.done
    #}
rescue => e
    l.reset
    l.log(e.to_console.red)
end