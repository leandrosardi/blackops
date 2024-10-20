**THIS PROJECT IS UNDER CONSTRUCTION**

# BlackOps

The **BlackOps** library makes it easy to manage your DevOps.

Once installed, BlackOps gives you a `ops` tool to perform your deployments and monitor your nodes from the comfort of your command line.

The `ops` command provides the following features: 

1. **Infrastructure as a Code** (IaaS),
2. **Continious Deployment** (CD),
3. **Logs Monitoring**, 
4. **Processes Monitoring**; and
5. **Infrastructure Monitoring**.

## 1. Getting Started

1. Install the `ops` command.

```
sudo apt-get update
sudo apt-get install blackops
```

2. Run an operation.

The code below will download and execute a `.ops` script that sets the hostname of your computer. 

```
wget https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op

ops source ./hostname.op --local --name=dev1
```

**Notes:**

Here are some other considerations about the `ops` command.

- If you are writing Ruby code, you can install the `blackops` gem. Such a gem allows you to perform all the same operations from Ruby code.

First, install the gem.

```
gem install blackops
```

Then, execute your ops from a Ruby script.

```ruby
require 'simple_cloud_logging'
require 'blackops'

l = BlackStack::LocalLogger.new('./example.log')

BlackOps.source_local(
        op: './hostname.op',
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

- The content of `hostname.op` looks like this:

**hostname.op**

```
# Description:
# - Very simple script that shows how to use an `.op` file to change the hostname of a node.
# - Run this op as root.
# 

# Change hostname
RUN hostnamectl set-hostname "$$name"
```

- The argument `--name` in the `ops` command is to replace the `$$name` variable into the `.ops` file.

- You can define any variable into your `.ops` file, and you can set its value into a command argument. 

E.g.: 

**set-rubylib.op**

```
RUN export RUBYLIB=$$rubylib
```

- All the variables defined into the `.ops` file must be present into the list of arguments of the `ops` command. Or, if you are using the `blackops` gem, all the variables must be present into the `parameters` hash.

## 2. Remote Operations

You can also run operations on a remote node through SSH.

You have to use the `--remote` and `--ssh` arguments instead of `--local`.

```
ops source ./hostname.op --remote --ssh=username:password@ip:port --name=prod1
```

If you are coding with Ruby, you can do a call to the `source_remote` method.

```ruby
require 'simple_cloud_logging'
require 'blackstack-nodes'
require 'blackops'

l = BlackStack::LocalLogger.new('./example.log')

n = BlackStack::Infrastructure::Node.new({
    :ip => '81.28.96.103',  
    :ssh_username => 'root',
    :ssh_port => 22,
    :ssh_password => '****',
})

BlackOps.source_remote(
        node: n,
        op: './hostname.op',
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

## 3. Configuration Files

You can define nodes into a **configuration file**.

Such a configuration file is written with Ruby syntax.

The `ops` command has a Ruby interpreted enbedded, so you don't need to have Ruby installed in your computer.

**config.rb**

```ruby
BlackOps.add_node({
    :name => 'prod1',         
    :ip => '55.55.55.55',
    :ssh_username => 'blackstack',
    :ssh_port => 22,
    :ssh_password => 'blackops-password',
    :ssh_root_password => 'root-password',
})
```

Then you can run the `ops` command refrencing to 

1. such a configuration file;

2. the node defined in such a configuration file;

and

3. the `--connect-as-root` flag to use `root` user for this operation.

```
ops source ./hostname.ops --remote --config=./config.rb --node=prod1 --connect-as-root --name=prod1 
```

You can do the same from Ruby code:

```ruby
require 'simple_cloud_logging'
require 'blackstack-nodes'
require 'blackops'

l = BlackStack::LocalLogger.new('./example.log')

require_relative './config'

BlackOps.source(
        'prod1', # name of node defined in `config.rb`
        op: './hostname.op',
        parameters: => {
            'name' => 'dev1',
        },
        connect_as_root: true,
        logger: l
)
```

Note, if the `--connect-as-root` flag is disabled, then BlackOps will access the node with the `blackstack` user.

## 4. Environment Variable `$OPSLIB`

Additionally, you can define an environment variable `$OPSLIB`, and the `ops` command will look for `config.rb`.

This way, you don't need to write the `--config` argument every time you call the `ops` command.

```
export OPSLIB=~/

ops source ./hostname.ops --remote --node=prod1 --name=prod1
```

The environment variable `$OPSLIB` may include a list of folders separater by `:`. 

E.g.:

```
export OPSLIB=~/:/home/leandro/code1:/home/leandro/code2

ops source ./hostname.ops --remote --node=prod1 --name=prod1
```

## 5. Remote `.op` Files

You can refer to `.op` files stored in your local computer or hosted in the web.

E.g.:

```
ops source https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op --remote --node=prod1 --name=prod1
```

## 6. Repositories

In your configuration file, you can define the locations where to find the `.op` files.

Such locations must be either:

1. folders in your local computer, or
2. URLs in the web.

**config.rb**

```ruby
...
BlackOps.set(
    repositories: [
        # private operations defined in my local computer.
        '/home/leandro/code1/blackops/ops',
        # public operations defined in blackops repository.
        'https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops',
    ],
)
...
```

Any call to the `ops` command gets simplified:

```
ops source hostname.op --remote --node=prod1 --name=prod1
```

**Notes:**

There are some considerations about the repositories.

- If the file `hostname.op` is present into more than one repository, then the `ops` command with show an error message: `Operation hostname.op is present in more than one repository: <list of repositories.>`.

## 7. Custom Parameters

The argument `--name` is not really necessary in the command below, 

```
ops source hostname.op --remote --node=prod1 --name=prod1
```

because it is already defined in the hash descriptor of the node (`:name`).

**config.rb**

```ruby
...
BlackOps.add_node({
    :name => 'prod1', # <=====
    :ip => '55.55.55.55',
    :ssh_username => 'blackstack',
    :ssh_port => 22,
    :ssh_password => 'blackops-password',
    :ssh_root_password => 'root-password',
})
...
```

You can define any custom parameter into the hash descriptor of your node. 

E.g.: You can define the value for the `--rubylib` argument,

```ruby
...
BlackOps.add_node({
    :name => 'prod1', 
    :rubylib => '/home/blackstack/code', # <=====
    :ip => '55.55.55.55',
    :ssh_username => 'blackstack',
    :ssh_port => 22,
    :ssh_password => 'blackops-password',
    :ssh_root_password => 'root-password',
})
...
```

so the execution of the operation `set-rubylib.op` gets simplified even more:

```
ops source set-rubylib.op --remote --node=prod1
```

## 8. Connecting

You can access any node via SSH using the credentials defined in `config.rb`.

```
ops ssh prod1
```

## 9. Monitoring

Your can list your nodes and monitor the usage of CPU, RAM and disk space.

```
ops list
```

![blackops list of nodes](/assets/list01.png)

The `ops list` command will:

1. show all the nodes defined in your configuration file;

2. connect the nodes one by one via SSH and bring **RAM usage**, **CPU usage**, **disk usage** and **custom alerts** (custom alerts will be introduced further).

**Notes:**

- Once connected to a node, the values shown in the row of the node will be aupdated every 5 seconds by default.

![blackops list of nodes](/assets/list02.png)

- You an define a custom number of seconds to update each row:

```
ops list --interval 15
```

- The SSH connection to a node may fail.

![blackops list of nodes](/assets/list03.png)

- By default; the usage of RAM, CPU or disk must be under 50% or it will be shown in red.

![blackops list of nodes](/assets/list04.png)

- You can define custom thresholds for RAM, CPU and disk usage.

```
ops list --cpu-threshold 75 --ram-threshold 80 --disk-threshold 40 
```

- You can define the thresholds of each node in your configuration file.

```ruby
...
BlackOps.add_node({
    :name => 'prod1',
    :ip => '55.55.55.55',
    :cpu_threshold => 75, # <=====
    :ram_threshold => 80, # <=====
    :disk_threshold => 40, # <=====
    ...
})
...
```

- The number of alerts must be 0, or it will be shown in red. This treshold is always `0` and cannot be modified.

![blackops list of nodes](/assets/list05.png)

- You can use wildcard to choose the list of nodes you want to see.

```
ops list worker*
```

- If you press `CTRL+C`, the SSH connections will be closed one by one.

## 10. Infrastructure Managing

You can connect BlackOps with [Contabo](https://contabo.com) using our [Contabo Client library](https://github.com/leandrosardi/contabo-client).

**config.rb**

```ruby
...
BlackOps.set(
    contabo: ContaboClient.new(
        client_id: 'INT-11833581',
        client_secret: '******',
        api_user: 'leandro@massprospecting.com',
        api_password: '********'
    ),
)
...
```

The `ops list` command will **merge** the nodes defined in your confiuration file with the list of instances in your Contabo account.

Such a merging is performed using the public IPv4 addess of **Contabo instances** and **nodes** defined in the configuration file.

```
ops list
```

![blackops infrastructure management](/assets/contabo01.png)

**NoteS:**

- The rows with no value in the **Contabo ID** column are nodes defined into the configuration file, but not existing in the list of Contabo instances.

E.g.: in the picture above, the no `slave01`.

- The rows with `unknown` in the **status** column are Contabo instances that are not defined in your configuration file.

The `unknown` situation happens when you have a software that creates instances on Contabo dynamically, using [Contabo Client's `create` feature](https://github.com/leandrosardi/contabo-client?tab=readme-ov-file#creating-an-instance). 

E.g.: You developed a scalable SAAS that create a dedicated instance on Contabo for each user signed up.

To avoid the `unknown` situation, your software should store instances created dynamically into its database, and add them to BlackOps dynamically too. The next section is about this ([Adding Nodes Dynamically](#11-adding-nodes-dynamically)).

## 11. Adding Nodes Dynamically

Define the hash descriptor of a node into a `.json` file.

**new_nodes.json**

```ruby
[
    {
        :name => 'worker06',
        :ip => '195.179.229.21',
        ...
    }, {
        :name => 'worker07',
        :ip => '195.179.229.22',
        ...
    },
]
```

Then run the `ops add` command.

```
ops add ./new_nodes.json
```

If you place your `.json` files into any folder specified into the `$OPSLIB`, then you don't need to write the full path of such a `.json` file in the command call.

```
ops add new_nodes.json
```

### `list` overwriting

If you are coding on Ruby, you can use the `blackops` gem, and define your own `list` command.

**my-list.rb**

```ruby
require 'blackops'
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
})
require 'blackops-list' # <=== This line invoques the `ops list` command, including the command line arguments processing.
```

And then you call it.

```
ops my-list worker*
```

The `my-list.rb` file most be located in one of the folders listed into the environment variable `$OPSLIB`.

This feature is important when you develop a software that create/delete instances of servers dynamically and sotre them into a databases instead of a configuration file.

E.g.: You are coding a SaaS where a new VPS is created for for every new user of your platform.

## 12. Processes Watching

When you define a node, you can specify what are the processes that will be running there.

**config.rb**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :procs => [
        '/home/blackstack/code1/master/ipn.rb',
        '/home/blackstack/code1/master/dispatch.rb',
        '/home/blackstack/code1/master/allocate.rb',
    ]
})
```

Then, call the `proc` command to list watch if they are running or not.

```
ops proc
```

_picture pending_

You can also use wildcards with specify the nodes you want to watch:

```
ops proc worker*
```

**Notes:**

- The `proc` command simply connect the nodes via SSH and performa a `grep` command to find the processes you specified.

- If one processes listed into the `procs` array is not found when running the `grep`, then such a process is shown as `offline` in the list.

- If one

### `proc` overwriting

**my-proc.rb**

```ruby
require 'blackops'
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
})
require 'blackops-proc' # <=== This line invoques the `ops list` command, including the command line arguments processing.
```

```
ops my-proc
```

## 13. Logs Watching

When you define a node, you can specify what are the log files that you may want to watch.

**config.rb**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :logfiles => [
        '/home/blackstack/code1/master/ipn.log',
        '/home/blackstack/code1/master/dispatch.log',
        '/home/blackstack/code1/master/allocate.log',
    ]
})
```

You can also define a pattern of log files using wildcards.

**config.rb**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :logfiles => [
        '/home/blackstack/code1/master/*.log',
    ]
})
```

You can run a kinda `ls` of all the files into a node that matches with the list of files defined in its hash descriptor.

```
ops logfiles worker*
```

![BlackOps Logfiles Watching](/assets/logfiles01.png)

You can define a list of keywords into log files that can be indicating that an error is happening.

**config.rb**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :logfiles => [
        '/home/blackstack/code1/master/*.log',
    ],
    :logkeywords => [
        'error', 'failure', 'failed',
    ] 
})
```

![BlackOps Logfiles Watching](/assets/logfiles02.png)

You can list the lines with **error keywords** into logfiles.

```
ops logkeywords worker06 --filename=*dispatch.log 
```

The `logkeywords` command simply connect the node via SSH and perform a `cat <logfilename> | grep "keyword"` command.

**Notes:**

- If the 

## 14. Custom Alerts

_pending_

## 15. Email Notifications

You can define an SMTP relay and a list of email address to notify when any value in the table above goes red.

```ruby
...
BlackOps.set({
    :alerts => {
        :smtp_ip => '...', 
        :smtp_port => '...', 
        :smtp_username => '...', 
        :smtp_password => '...', 
        :smtp_sending_name => 'BlackOps',
        :smtp_sending_email => 'blackops@massprospecting.com',
        :receivers => [
            'leandro@massprospecting.com',
            ...
            'cto@massprospecting.com',
        ]
    }
    ...
})
...
```

**Notes:**

- You can run the `ops list` command in background, keep it monitoring 24/7, and get notified when an error happens.

```
ops list --background
```

- When CPU or RAM usage run over their threshold, no email will be delivered. This is because CPU and RAM usage may be very flutuating.

- An email notification will be delivered when the disk usage raises over its threshold at a first time after has been under it.

- An email notifications will be delivered when the number of alerts raises over `0` at a first time after has been `0`.

- Log error keywords

- Processes not running

- Any email notification includes the name and public IP of the node, the value of CPU usage, RAM usage, disk usage and alerts, and the threshold of each one.


