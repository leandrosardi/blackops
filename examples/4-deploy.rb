require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    BlackStack::Deployment.source( :slave,
        bash_script_filename: './master.blackstack',
        params: [
            GIT_USERNAME,
            GIT_PASSWORD,
        ], 
        logger: l
    )
rescue => e
    l.error(e)
end