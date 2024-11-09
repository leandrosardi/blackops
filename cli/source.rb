require_relative '../lib/blackops.rb'
load '/home/leandro/code1/secret/BlackOpsFile'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    [:w01b, :w01c, :w01d, :w01e, :w01f].each { |s|
        l.logs "#{s.to_s}... "
        BlackOps.source_remote( s.to_sym,
            op: :'mysaas.install.ubuntu_20_04.base',
            connect_as_root: true,
            logger: l
        )

        BlackOps.source_remote( s.to_sym,
            op: :'mysaas.install.ubuntu_20_04.adspower',
            connect_as_root: true,
            logger: l
        )
        l.done
    }
rescue => e
    l.reset
    l.log(e.to_console.red)
end