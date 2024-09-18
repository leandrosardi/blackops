require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    BlackStack::Deployment.install( :master,
        bash_script_filename: './environment.ubuntu-20-04.blackstack',
        logger: l
    )
rescue => e
    l.error(e)
end