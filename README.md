**THIS PROJECT IS UNDER CONSTRUCTION**

# BlackOps

The **BlackOps** library makes it easy to manage CD operations of your software projects.

The `ops` provides the following features: 

1. **Infrastructure as a Code** (IaaS),
2. **Continious Deployment** (CD),
3. **Logs Monitoring**, 
4. **Processes Monitoring**; and
5. **Infrastructure Monitoring**.

Once installed, BlackOps gives you a `ops` tool to perform your deployments and monitor your nodes from the comfort of your command line.

## 1. Getting Started

1. Install the `ops` command.

```
sudo apt-get update
sudo apt-get install blackops
```

2. Run an installation script of your environment.

The following command executes bash command that set `dev1` as the hostname of your computer. 

```
wget https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op

ops source ./hostname.op --local --name=dev1
```

3. If you are writing Ruby code, you can additionally install the `blackops` gem. Such a gem allows you to perform all the same operations from Ruby code.

```
gem install blackops
```

**Notes:**

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

- All the variables defined into the `.ops` file must be present into the list of arguments of the `ops` command.

## 2. Remote Operations

You can also run operations on a remote node through SSH.

You have to use the `--remote` and `--ssh` arguments instead of `--local`.

```
ops source ./hostname.op --remote --ssh=username:password@ip:port --name=prod1
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

1. such a configuration file and 

2. the name of the node defined in such a configuration file.

```
ops source ./hostname.ops --remote --config=./config.rb --node=prod1 --name=prod1
```

## 4. Environment Variable `$OPSLIB`

Additionally, you can define an environment variable `$OPSLIB`, and the `ops` command will look for `config.rb`.

```
export OPSLIB=~/
ops source ./hostname.ops --remote --node=prod1 --name=prod1
```

The environment variable `$OPSLIB` may include a list of folders separater by `:`. E.g.:

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
        '/home/leandro/code1/blackops/ops',
        'https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops',
    ],
)
...
```

Any call to the `ops` command gets simplified:

```
ops source hostname.op --remote --node=prod1 --name=prod1
```

## 7. Custom Parameters

The argument `--name` is not really necessary in the command below, 

```
ops source hostname.op --remote --node=prod1 --name=prod1
```

becase it is already defined in the hash descriptior of the node (`:name`).

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

You can define any custom parameter into the hash descriptor of your node. E.g.:

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

Any call to the `ops` command gets simplified even more:

```
ops source set-rubylib.op --remote --node=prod1
```

## 8. Connecting

You manually access any node via SSH.

```
ops ssh --node=prod1
```

## 9. Monitoring

Your can list your nodes and monitor them.

```
ops list
```

![blackops list of nodes](/assets/list01.png)

The `ops list` command will:

1. show all the nodes defined in your configuration file;

2. connect the nodes one by one via SSH and bring **RAM usage**, **CPU usage**, **disk usage** and **custom alerts** that will be introduced further. 

**Notes:**

- Once connected to a node, the values of its row will be aupdated every 5 seconds by default.

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

The rows missing the Contabo ID (e.g.: `slave01`) are nodes defined into the configuration file, but not existing in the list of Contabo instances.

The `unknown` are Contabo instances that are not defined in your configuration file.

The `unknown` situation happens when you have a software that creates instances on Contabo dynamically, using [Contabo Client's `create` feature](https://github.com/leandrosardi/contabo-client?tab=readme-ov-file#creating-an-instance). 

**E.g.:** You developed a scalable SAAS that create a dedicated instance on Contabo for each user signed up.

To avoid the `unknown` situation, your software should store instances created dynamically into its database, and add then add them to BlackOps dynamically too.

## 11. Adding Nodes Dynamically

Define the hash descriptor of a node into a `.json` file.

Then run the `ops add` command.

```
ops add ./new_node.json
```

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

You can also define a patterm of log files using wildcards.

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

## 99. Email Notifications

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


