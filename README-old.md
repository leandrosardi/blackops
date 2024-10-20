**THIS PROJECT IS UNDER CONSTRUCTION**

# BlackOps

The **BlackOps** library makes it easy to manage CD operations of your software projects.

The `ops` command is great for managing: 

1. **Infrastructure as a Code** (IaaS),
2. **Continious Deployment** (CD),
3. **Logs Monitoring**, 
4. **Processes Monitoring**; and
5. **Infrastructure Monitoring**.

---

BlackOps is a framework for building automated deployment scripts. Although BlackOps itself is written in Ruby, it can easily be used to deploy projects of any language or framework, be it Rails, Java, or PHP.

Once installed, BlackOps gives you a `ops` tool to perform your deployments from the comfort of your command line.

---

**Outline:**

1. [The `ops` Command](#1-the-ops-command)
2. [Define Nodes](#2-define-nodes)
3. [Create Nodes](#3-create-nodes)
4. [Release Node](#4-release-node)
5. [Install](#5-install)
6. [Deploy](#6-deploy)
7. [Stop](#7-stop)
8. [Start](#8-start)
9. [Restart](#9-restart)
10. [Push Secrets](#10-push-secrets)
11. [Pull Secrets](#11-pull-secrets)
12. [Connect via SSH](#12-connect-via-ssh)
13. [Reboot](#13-reboot)
14. [Procs](#14-procs)
15. [Log](#15-log)
16. [Stat](#16-stat)
17. [Proxies](#17-proxies)
18. [Web](#18-web)
19. [SSL](#19-ssl)
20. [Alerts](#20-alerts)
21. [Custom Installation Snippets](#21-custom-installation-snippets)
22. [Custom Deployment Snippets](#22-custom-deployment-snippets)
23. [Custom Alerts Snippets](#23-custom-alerts-snippets)
24. [Distributed Monitoring](#24-distributed-monitoring)

## 1. The `ops` Command

The `ops` command simply receives the name of a Ruby **script** that you want to execute.

```
ops <ruby script filename>
```

The `ops` command will look for such a script into the folder specified in the environment variable `$SAASLIB`. 

If the script your call receives parameters, then you can add them.

```
ops <ruby script filename> <list of command line parameters>
```

E.g.: The command below with shown the installed version My.SaaS. 
It requires that a script `version.rb` exists into the folder specified at `$SAASLIB`.

```
ops version
```

Here is the list of scripts you can execute:

| script  | example                                       | description                                                                                                                                          |
|---------|-----------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| create  | `ops create node=master`                     | Create a new instance of a cloud server into a hosting provider like Contabo.                                                                        |
| release | `ops release node=master`                    | Release the nodes to be created again.                                                                                                               |
| install | `ops install nodes=master,slave01`           | install standard environment into an Ubuntu 20.04 server.                                                                                            |
| deploy  | `ops deploy nodes=master,slave01,worker01`   | Deploy the latest version of my.saas and the configured extensions, including source code, gems, sql migrations and updating SSL certifications too. |
| stop    | `ops stop nodes=master,s01,w0101 procs=*`    | Stop a specific process or all processes running into one or more nodes.                                                                             |
| start   | `ops start nodes=master,s01,w0101  procs=*`  | Start a specific list of processes into one or more nodes.                                                                                           |
| restart | `ops restart nodes=master,s01,w0101 procs=*` | Restart a specific list of process into one or more nodes.                                                                                           |
| push    | `ops push secrets=master`                    | Submit the secret files to your secret repository.                                                                                                   |
| pull    | `ops pull secrets=master`                    | Download the secret files from your secret repository.                                                                                               |
| ssh     | `ops ssh node=s01`                           | Open a SSH connection to a specific node.                                                                                                            |
| reboot  | `ops reboot nodes=master,slave01`            | Reboot a node.                                                                                                                                       |
| procs   | `ops procs nodes=master,s01,w0101`           | Watch list of processes defined for each node, and show which ones are running and which ones are not.                                               |
| log     | `ops log nodes=master,s01,w0101`             | Watch one log of the ones defined for those nodes, and watch it.                                                                                     |
| stat    | `ops stat nodes=master,s01,w0101`            | Watch the usage of CPU, memory, and disk space of each node if your infrastructure.                                                                  |
| assign  | `ops assign`                             | Assign each nodes (including monitoring nodes) to one monitoring node        |

**Logging**

Every script write into its own logfile.

The same outout you see in your terminal is saved into a log file.

Logfiles are located in the path you defined into a new environment variable: `$SAASLOG`.

**Silent Mode**

Any command you run, it can be ran in `silent` mode by simply redirecting `STDOUT` and `STDERR`, and running in backend.

E.g.:

```
ops procs nodes=.* > /dev/null 2>&1 &
```

Running a command in silent mode allows you to launch it into a server and monitor your infrastructure 24/7 and receive an email alert as soon as an alert is raised.

## 2. Define Nodes

You can add a node to your infrastructure as follows:

```ruby
BlackOps.add_node({
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    #
    # Mandatory.
    #
    # Allowed values: string with a valid hostname.
    #
    :name => 'master', 

    # If true, this node is belonging your development environment.
    # If true, ignore this node when deploying.
    #
    # Optional. Default: false.
    #
    # Allowed values: boolean.
    # 
    :dev => false, 

    # Public Internet IP address of the node.
    # If `nil`, that means that no instance of a cloud server has been created yet for this node.
    #
    # Optional. Default: `nil`.
    #
    # Allowed values: string with a valid IP address.
    # 
    :ip => nil,

    # Who is providing this node.
    # Allowed values: [:contabo].
    #
    # Optional. Default: :contabo.
    #
    # Allowed values: symbol with one of the following values [:contabo].
    # 
    :provider => :contabo,

    # What service is this.
    # If :provider is :contabo, allowed values are ['CLOUD VPS 1', 'CLOUD VPS 3', 'CLOUD VPS 6']
    #
    # Mandatory.
    #
    # Allowed values: string with one of the following values ['CLOUD VPS 1', 'CLOUD VPS 3', 'CLOUD VPS 6'].
    # 
    :service => :V45, # CLOUD VPS 1

    # Reference to another node where is hosted the database to work with.
    #
    # Mandatory.
    #
    # Allowed values: string with a valid PostgreSQL database name,
    # 
    :db => 'dev2',

    # SSH credentials.
    # Root password is required to install the environment at the first time.
    #
    # Mandatory. The 4 keys below are mandatory. 
    #
    # Allowed values: 
    # - ssh_username: string with a valid Linus user name,
    # - ssh_port: integer with a valid port number
    # - ssh_password: string with a valid Linux password.
    # - ssh_root_password: string with a valid Linux password.
    # 
    :ssh_username => 'blackstack',
    :ssh_port => 22,
    :ssh_password => '<write SSH password here>',
    :ssh_root_password => '<write SSH password here>',

    # Parameters to connect to the github repositories.
    #
    # Instead of GitHub password, you have to provide an access token.
    # How to get a GitHub access token: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app 
    #
    # Mandatory. The 4 keys below are mandatory. 
    #
    # Allowed values: 
    # - git_repository: string that a can concatenate to 'https://github.com/' and get a valid URL of a GitHub repository.
    # - git_branch: integer with a valid GitHub branch name.
    # - git_username: string with a valid GitHub username.
    # - git_password: string with a valid GitHub password.
    # 
    :git_repository => 'leandrosardi/my.saas',
    :git_branch => 'main', 
    :git_username => 'leandrosardi',
    :git_password => '<your github access token>',
    
    # Folder into where you want to clone the repository defined in `git_repository`.
    #
    # Mandatory.
    #
    # Allowed values: string with a valid Linux full path to a folder. Relative paths are not allowed.
    #
    :code_folder => '/home/blackstack/code1/master',

    # List of processes to start
    #
    # Optional. Default: [].
    #
    # Allowed values: (TODO: pendng)
    #
    :procs => {
        # list of commands to run when starting a node.
        :start => [
            {
                # the command you are executing must be located into `code_folder`.
                :command => 'app.rb port=3000',
                # where to redirect any output in the starting of this command.
                # note that the command may log into another file once it started.
                :stdout => '/home/blackstack/code1/master/app.log',
                :stderr => '/home/blackstack/code1/master',
                # value to assign to the environment variable `$RUBYLIB`
                :rubylib => '/home/blackstack/code1/master',
            }, {
                ...
            }
        ],
        # list of commands to kill when stopping a node.
        :stop => [
            'app.rb port=3000',
            'adspower',
            ...
        ],
    },

    # List of logfiles allowed to watch or monitor.
    #
    # Optional. Default: [].
    #
    # Allowed values: (TODO: pendng)
    #
    :logs => [
        '/home/blackstack/code1/master/app.log',
        ... 
    ],

    # List of websites published on this node.
    # This is used for monitoring.
    #
    # Optional. Default: [].
    #
    # Allowed values: (TODO: pendng)
    #
    :webs => [
        {
            # descriptive name of this website.
            :name => 'ruby-sinatra',
            # port this website is listening.
            :port => 3000,
            # protocol used. Allowed values are [:http, :https].
            :protocol => :http,
        }, {
            # descriptive name of this website.
            :name => 'nginx',
            # port this website is listening.
            :port => 443,
            # protocol used. Allowed values are [:http, :https].
            :protocol => :https,
        }
    ],
})
```

When you call `BlackOps.add_node` to add a node to your infrastructure, a new instance of the class `BlackStack::Infrastructure::Node` will be created and added to the arraw `@nodes` of the module `BlackOps`.

For more information about the `BlackStack::Infrastructure::Node` class, refer to our [BlackStack Nodes](https://github.com/leandrosardi/blackstack-nodes) library.

Note that if the hash descriptor passed to the `add_node` method has not the right format, of if there are missed parameters, or if there are unknown parameters; then such a method will raise an exception `Node hash descriptor mailformed.`

## 3. Create Nodes

You can create a new instance of a cloud server for any of the nodes you have defined.

- You can do that by Ruby code:


```ruby
BlackOps.create :master
```

- Or you can do it with the CLI:

```
ops create nodes=master
```

- If the node has been already created, the command will raise an exception.

```
ops create nodes=master
Error: Command already created.
```

- You can also request the creation all nodes using regular expressions.

```
ops create nodes=*
```

- You can also request the creation some nodes by listing them separated by commas.

```
ops create nodes=master,slave01
```

- You can do both: listing many nodes, and using regular expressions in some elements of the list.

```
ops create nodes=master,slave.*
```

## 4. Release Node

If you have manually deleted the instance of a node from your hosting provider, you can update that your database.

The `release` script simply assign `nil` value to the field `ip`.

- You can do that by Ruby code:


```ruby
BlackOps.release :master
```

- Or you can do it with the CLI:

```
ops create nodes=master,slave.*
```

## 5. Install

Install the my.saas envoronment into one node, by running the script `install.20.04.sh`.

- You can do that by Ruby code:


```ruby
BlackOps.install :master
```

- Or you can do it with the CLI:

```
ops install nodes=master,slave.*
```

## 6. Deploy

This command will:

- pull the latest version of source code of my.saas from the branch specified in `git_branch`,

- pull the latest version of source code of each [extension](/docu/16.extensibility.md) specified in the `config.rb`, 

- run `bundler update`,

- execute all sql migrations in the folder `sql`,

- install SSL certification.

You can automatically perform all the operations above.

- You can do that by Ruby code:


```ruby
BlackOps.deploy :master
```

- Or you can do it with the CLI:

```
ops deploy nodes=master,slave.*
```

## 7. Stop

Stop a specific process or all processes running into one or more nodes.

_complete the rest of documentation__

## 8. Start

Start a specific list of processes into one or more nodes.

_complete the rest of documentation__

## 9. Restart

Restart a specific list of process into one or more nodes.

_complete the rest of documentation__

## 10. Push Secrets

Submit the secret files `config.rb` from your local environment to your secret repository.

First thing first, you have to define what are your secrets.

E.g.:

```ruby
BlackOps.set_secrets({
    # define your secret repository.
    :git_repository => 'leandrosardi/my.secrets',
    :git_branch => 'main', 
    :git_username => 'leandrosardi',
    # Instead of GitHub password, you have to provide an access token.
    # How to get a GitHub access token: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app 
    :git_password => '<your github access token>',

    # define your secret files.
    :secrets => [
        {
            # this is where you place the source code for the master node.
            #
            # representative name of this secret.
            :name => :master,
            # path in my local environment where this secret is placed.
            :path => 'home/leandro/code1/master/config.rb',
        }, {
            # this is where you place the source code for any slave node.
            #
            # representative name of this secret.
            :name => :slave,
            # path in my local environment where this secret is placed.
            :path => 'home/leandro/code1/slave/config.rb',
        }
    ]
})
```

Then,

- You can do that by Ruby code:


```ruby
BlackOps.push :master
```

- Or you can do it with the CLI:

```
ops push secrets=master,slave
```

Note that if the hash descriptor passed to the `set_secrets` method has not the right format, of if there are missed parameters, or if there are unknown parameters; then such a method will raise an exception `Secret hash descriptor mailformed.`

## 11. Pull Secrets

Download the secret files from your secret repository to your local environment.

_complete the rest of documentation__

## 12. Connect via SSH

Open a SSH connection to a specific node.

_complete the rest of documentation__

## 13. Reboot

Reboot nodes.

_complete the rest of documentation__

## 14. Procs

Show list of processes defined for each node, and show which ones are running and which ones are not.

- You can do that by Ruby code and get a hash descriptor of the **state** of each process defined for a node.

The **state** of a process indicates if such a process is running or not:


```ruby
BlackOps.procs :master
# => [{ :proc => 'app.rb port=3000', running => true }]
```

- Or you can do it with the CLI, and watch a table that will update every 5 seconds by default:

```
ops push nodes=master

| proc             | running |
|------------------|---------|
| app.rb port=3000 | yes     |
```

- You can specify the interval to update the table:

```
ops procs secrets=master interval=10
```

- You can also specify the processes you want to watch using regular expression:

```
ops procs secrets=master procs=app
```

- Obviously, you can specify a list of many nodes and many processes to watch:

```
ops procs secrets=master,slave.* procs=app,import,timeline
```

## 15. Log

Watch one log of the ones defined for a nodes, and watch it.

_complete the rest of documentation__

## 16. Stat

Watch the usage of CPU, memory, and disk space of each node if your infrastructure.

_complete the rest of documentation__

## 17. Proxies

Show list of proxies defined for each node, and show which ones are running and which ones are not.

For using this feature, you have to define the proxies configured on a node.

```ruby
BlackOps.add_node({
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    # Mandatory.
    :name => 'proxy-server-01', 

    ...

    # List of proxies installed.
    # Optional. Default: nil.
    :proxies => {
        # define username and password for all proxies.
        :default_username => 'proxy-user-01',
        :default_password => '<password for all proxies here>',
        # list of proxies.
        # Mandatory.
        :ports => [
            # you can define a specific port with specific credentials.
            { :numbers => 3000, :username => 'custom-user', :password => '<custom password>' },
            # you can define an array of ports that use default credentials.
            # note that you are converting a rnage into an array.
            { :numbers => [3001..3250].to_a },
        ]
    }
})
```

_complete the rest of documentation__

## 18. Web

Watch list of websites defined for each node, and if they are runnng or not.

_complete the rest of documentation__

## 19. SSL

Watch list of SSL certificates defined for each node, and they are working or not with no expiration.

_complete the rest of documentation__

## 20. Alerts

When you define a node, you can setup the following alerts:

- if CPU usage is over a threshold,
- if memory usage is over a threshold,
- if disk usage is under a threshold,
- if a log file contains certain strings or string patterns,
- if a process is not running,
- if a proxy is not working,
- if a website is not running; and
- if a SSL is not working.

```ruby
BlackOps.add_node({
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    # Mandatory.
    :name => 'proxy-server-01', 

    ...

    # Alerts configuration.
    # Optional. Default: nil.
    :alerts => [
        # List of users to be warned.
        # Mandatory.
        :users => [
            { :name => 'Leandro Sardi', :email => 'leandro@massprospecting.com' },
        ],
        # If nil, ignore CPU usage.
        # Optional. Default: nil.
        :cpu_max_usage => 0.5, # 50%
        # If nil, ignore memory usage.
        # Optional. Default: nil.
        :mem_max_usage => 0.75, # 75%
        # If nil, ignore disk usage.
        # Optional. Default: nil.
        :dks_max_usage => 0.85, # 85%
        # If false, ignore if processes are running or not.
        # Optional. Default: true.
        :procs => true,
        # If false, ignore if proxies are working or not.
        # Optional. Default: true.
        :proxies => true,
        # If false, ignore if websutes are running or not.
        # Optional. Default: true.
        :webs => true,
        # If false, ignore if SSL certificates are working or not.
        # This alert will be applicate for those webs with `:https` protocol only.
        # Optional. Default: true.
        :certs => true,
        # List of patterns to watch on each log file.
        # If nil, ignore the logs watching.
        # Optional. Default: nil.
        :logs => {
            # patterns to use of it has not been defined on any node
            :default_patterns => [ /error/i, /out of/i ],
            # list of files to monitor.
            # mandatory.
            :files => [
                # monitor this file, using array of custom patterns to detect errors.
                {
                    :filename => '/home/blackstack/code1/master/app.log'
                    :patterns => [/404/, /500/]
                # monitor this file, using one custom pattern to detect errors.
                }, {
                    :filename => '/home/blackstack/code1/master/import.log'
                    :patterns => /CSV wrong/i
                # monitor these other files, using default patterns.
                }, {
                    :filename => '/home/blackstack/code1/master/dispatcher.log'
                # monitor all those files that match with a pattern.
                }, {
                    :filename => /\/home\/blackstack\/code1\/master\/worker\.log/
                }
            ]
        }
    ]
})
```

_complete the rest of documentation__

## 21. Custom Installation Snippets

By default, the `install` script execute our [standard environment installation](https://github.com/leandrosardi/environment).

In some cases, you may want to run with other environment. E.g.: When we are running a proxies server.

```ruby
BlackOps.add_node({
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    # Mandatory.
    :name => 'proxy-server-01', 

    ...

    # Custom Snippet for Environment Installation.
    :install => Proc.new do |node, logger, *args|
        # ...
    end

})
```

_complete the rest of documentation__

## 22. Custom Deployment Snippets

By default, the `deploy` script will:

- pull the latest version of source code of my.saas from the branch specified in `git_branch`,

- pull the latest version of source code of each [extension](/docu/16.extensibility.md) specified in the `config.rb`, 

- run `bundler update`,

- execute all sql migrations in the folder `sql`; and

- install SSL certification.

In some cases, you may want to run a custom deployment. E.g.: When you are running [worker nodes](/docu/00.reference-architectures.md#master-slave-worker-architecture); who don't need to install my.saas, but they need to run custom processing scripts instead.

```ruby
BlackOps.add_node({
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    # Mandatory.
    :name => 'proxy-server-01', 

    ...

    # Custom Snippet for Deployment.
    :deploy => Proc.new do |node, logger, *args|
        # ...
    end

})
```

_complete the rest of documentation__

## 23. Custom Alerts Snippets

You can define a custom function that returns a string with an alert description; or returns `nil` that there is not an alert.

Use **custom alerts** to raise custom alerts that are specific to the business.

E.g.: Failed payments processing.

```ruby
BlackOps.add_node({
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    # Mandatory.
    :name => 'proxy-server-01', 

    ...

    :alerts => [
        # List of users to be warned.
        # Mandatory.
        :users => [
            { :name => 'Leandro Sardi', :email => 'leandro@massprospecting.com' },
        ],

        ...

        # Array of Custom Alert Snippets.
        # Optional. Default: [].
        # 
        :snippets => [
            {
                # descriptive name of the custom alert
                :name => 'Failed payment processing',

                # function that returns `nil` if there is no an alert to warn the users.
                # otherwise, it returns a string with a description of the problem to warn the users.
                :func => Proc.new do |node, logger, *args|
                    # ...
                end,
            },
        ],    
    ]
})
```

_complete the rest of documentation__

## 24. Distributed Monitoring

As long as your infrastructure grows, you cannot monitor all nodes with one stand-alone process.

E.g.: The command

```
ops procs nodes=.* interval=30 > /dev/null 2>&1 &
```

should run every 30 seconds. But if your list of nodes is too long, every run may take more than 30 seconds.

To distribute the monitoring of nodes altrough processes, and even altrough many servers, you have to 

1. define nodes that will be used for monitoring,

```ruby
BlackOps.add_nodes([{
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    # Mandatory.
    :name => 'monitor-01', 
    
    ...

}, {
    # Unique name to identify a host (a.k.a.: node).
    # It is equal to the hostname of the node.
    # Mandatory.
    :name => 'monitor-02', 
    
    ...

}, {

    ...

}])
```

2. define what are the nodes used for monitoring,

```ruby
BlackOps.set_monitoring({
    # max number of processes allowed in a node.
    :default_max_procs => 150,
    # list of nodes used for monitoring.
    :nodes => [
        # assign a node for monitoring, using the default number of `max_procs`.
        { :name => 'monitor-01' },
        # assign a node for monitoring, with a custom number of `max_procs`.
        { :name => 'monitor-02', :max_procs => 250 },
    ]
})
```

and 

3. run the `assign` script:

```ruby
ops assign
```

The `assign` script will 

- assign one monitoring node to each node; and

- add the necessary processes (`:procs`) and log files (`:logs`) for the monitoring of such a node.

Note that for each node that you are monitoring, you launch:

- one single `procs` process,
- one single `web` process,
- one single `ssl` process,
- one single `stat` process,
- one single `proxies` process,
- one `log` process for each log file in the node.

