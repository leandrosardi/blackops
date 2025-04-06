# BlackOps

The **BlackOps** library makes it easy to manage your DevOps.

BlackOps gives you command series to perform your deployments and monitor your nodes from the comfort of your command line.

E.g.:

```
saas deploy --node=n01 --version=1.2
```

BlackOps provides the following features: 

1. **Continious Deployment**.
2. **Processes Monitoring**.
3. **Infrastructure Monitoring**.

**Note:** BlackOps has been tested on:

- Ubuntu 20.04,
- Ubuntu 22.04.

**Table of Contents**

1. [Getting Started](#1-getting-started)
2. [Remote Operations](#2-remote-operations)
3. [Configuration Files](#3-configuration-files)
4. [Environment Variable `$OPSLIB`](#4-environment-variable-opslib)
5. [Remote `.op` Files](#5-remote-op-files)
6. [Repositories](#6-repositories)
7. [Custom Parameters](#7-custom-parameters)
8. [Connecting](#8-connecting)
9. [Installing](#9-installing)
10. [Migrations](#10-migration)
11. [Deploying](#11-deploying)
12. [Starting and Stopping Nodes](#12-starting-and-stopping-nodes)
13. [Configuration Templates](#13-configuration-templates)
14. [Monitoring](#14-monitoring)
15. [Infrastructure Managing](#15-infrastructure-managing)
16. [Custom Alerts](#16-custom-alerts)
17. [Processes Watching](#17-processes-watching)
18. [Command `saas`](#18-command-saas)
19. [Releasing](#19-releasing)
20. [Further Work](#20-further-work)

## 1. Getting Started

Follow the steps below for running your first operation.

### 1.1. Download the `saas` command:

BlackOps works on 

1. Ubuntu 20.04,
2. Ubuntu 22.04.

**Ubuntu 20.04**

```
wget https://github.com/leandrosardi/blackops/raw/refs/heads/main/bin/saas--ubuntu-20.04
sudo mv ./saas--ubuntu-20.04 /usr/bin/saas
sudo chmod 777 /usr/bin/saas
```

**Ubuntu 22.04**

```
wget https://github.com/leandrosardi/blackops/raw/refs/heads/main/bin/saas--ubuntu-22.04
sudo mv ./saas--ubuntu-22.04 /usr/bin/saas
sudo chmod 777 /usr/bin/saas
```

### 1.2. Run an operation.

The code below will download and execute a very simple `.op` script that sets the hostname of your computer. 

```
wget https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op
saas source ./hostname.op --local --name=dev1
```

**Notes:**

Here are some other considerations about the `saas source` command:

- You can write `./hostname` instead of `./hostname.op`.

The `saas source` command will look for the `./hostname` file. And if `./hostname` doesn't exists, then the `source` command will try with `./hostname.op`

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

- The argument `--name` in the command line is to replace the `$$name` variable into the `.op` file.

- You can define any variable into your `.op` file, and you can set its value by command lines argument. 

E.g.: The operaton below requires you to define a `--rubylib` argument in your command line.

**set-rubylib.op**

```
RUN export RUBYLIB=$$rubylib
```

- All the variables defined into the `.op` file must be present into the list of arguments of the `saas source` command.

## 2. Remote Operations

You can also run operations on a remote node through SSH.

Use the `--ssh` arguments instead of `--local`.

```
saas source ./hostname.op --ssh=username:password@ip:port --name=prod1
```

## 3. Configuration Files

You can define nodes into a **configuration file**.

Such a configuration file is called **BlackOpsFile** and it is written with Ruby syntax.

**BlackOpsFile**

```ruby
BlackOps.add_node({
    :name => 'prod1',         
    :ip => '55.55.55.55',
    :ssh_username => 'blackstack',
    :ssh_port => 22,
    :ssh_password => 'blackstack-password',
    :ssh_root_password => 'root-password',
})
```

Then you can run the `saas source` command referencing to such a configuration file, and the node (`--node`) you want to work with.

```
saas source ./hostname.op --config=./BlackOpsFile --node=prod1 --root
```

**Note:** 

- The command line argument `--name` is no longer need if it is defined into the **BlackOpsFile**.

- In the command above, if the `--root` flag is not present, then BlackOps will access the node with the `blackstack` user.

## 4. Environment Variable `$OPSLIB`

Additionally, you can store one or more paths into the environment variable `$OPSLIB`. 

The `saas source` command will look for `BlackOpsFile` there.

Using `$OPSLIB` you don't need to write the `--config` argument every time you call the `saas source` command.

E.g.:

```
export OPSLIB=~/

saas source hostname --node=prod1 --root
```

The environment variable `$OPSLIB` can include a list of folders separated by `:`. 

E.g.:

```
export OPSLIB=~/:/home/leandro/code1:/home/leandro/code2

saas source hostname --node=prod1 --root
```

**Note:** If the file `BlackOpsFile` file is present into more than one path, then the `saas source` command will show an error message: `Configuration file is present in more than one path: <list of paths.>`.

## 5. Remote `.op` Files

You can refer to `.op` files hosted in the web.

E.g.:

```
saas source https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op --node=prod1 --root
```

## 6. Repositories

In your configuration file, you can define the locations where to find the `.op` files.

Such locations must be either:

1. folders in your local computer, or
2. URLs in the web.

**BlackOpsFile**

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

Any call to the `saas` command gets simplified, because you don't need to write the full path to the `.op` file.

```
saas source hostname --node=prod1 --name=prod1
```

**Note:** If the file `hostname.op` is present into more than one repository, then the `ops` command with show an error message: `Operation hostname.op is present in more than one repository: <list of repositories.>`.

## 7. Custom Parameters

The argument `--name` was not necessary in the command line below, 

```
saas source hostname --node=prod1 --root
```

because it is already defined in the hash descriptor of the node (`:name`).

**BlackOpsFile**

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

So the execution of any operation gets simplified.

E.g.:

The `--rubylib` argument in the command line is not longer needed:

```
saas source set-rubylib --node=prod1
```

## 8. Connecting

You can access any node via SSH using the `saas ssh` command and the credentials defined in `BlackOpsFile`.

The goal of the `saas ssh` command is that you can access any node easily, writing short commands.

```
saas ssh prod1
```

**Notes:**

- You can also require to connect as `root`.

E.g.:

```
saas ssh prod1 --root
```

## 9. Installing

The `saas install` command one or more `.op` scripts, like `saas source` does.

E.g.:

```
saas install --node=worker* --root
```

**Notes:**

- The command above will run installations for all the nodes defined in your `BlackOpsFile` with name matching `worker*`.

- The list of `.op` scripts to execute are defined in the key `install_ops` of the node descriptor.

E.g.:

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    # installation operations
    :install_ops => [ # <===
        'mysaas.install.ubuntu_20_04.base',
        'mysaas.install.ubuntu_20_04.postgresql',
        'mysaas.install.ubuntu_20_04.nginx',
        'mysaas.install.ubuntu_20_04.adspower',
    ]
})
```

- The `--root` argument may be not present, but in most cases you will require to connect as `root` to perform installations.

**Pre-Built Install Operations:**

There are some pre-built install operations that you can use.

**Ubuntu 20.04:**

- [Install base required packages on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.base.op).
- [Install PostgreSQL on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.postgresql.op).
- [Install Nginx on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.nginx.op).
- [Install AdsPower on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.adspower.op).

**Ubuntu 22.04:**

- [Install base required packages on Ubuntu 22.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_22_04.base.op).
- [Install PostgreSQL on Ubuntu 22.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_22_04.postgresql.op).
- [Install Nginx on Ubuntu 22.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_22_04.nginx.op).
- [Install AdsPower on Ubuntu 22.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_22_04.adspower.op).

## 10. Migrations

The `saas migrations` command connects to the database into a node and executes a series of SQL files.

```
saas migrations --node=prod1
```

You have to define the list of folders here to find such SQL files.

```ruby
BlackOps.add_node({
    :name => 'prod1',         
    ...
    :migration_folders => [
        '/home/blackstack/code1/master/sql',
        ...
    ],
})
```

**Notes:** 

- The list of folders are not referencing to paths in your local computer, but paths into the node.

- The ist of migrations folders will be processed ony by one, in the same order they are listed. 

- The files into each folder will be processed one by one too, sorted by name.

- Each `.sql` file, will be executed sentence by sentence. Each sentence must to finish whith a semicolon (`;`).


## 11. Deploying

The `saas deploy` is for updating source code, installing or updating libraries, and setup configuration files. 

The `saas deploy` command processes one or more `.op` scripts (like the `saas source` does).

E.g.:

```
saas deploy --node=worker*
```

**Notes:**

- The command above will run deployment for all the nodes defined in your `BlackOpsFile` with name matching `worker*`.

- The list of `.op` scripts to execute are defined in the key `deploy_ops` of the node descriptor.

E.g.:

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    # deployment operations
    :deploy_ops => [ # <===
        'mass.slave.deploy',
        'mass.sdk.deploy',
    ]
})
```

- You can also require to connect as `root`.

E.g.:

```
saas deploy --node=worker* --root
```

**Pre-Built Deploy Operations:**

There are some pre-built deploy operations that you can use:

- [Deploy source code of master node of MassProspsecting](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.master.deploy.op).
- [Deploy source code of slave node of MassProspsecting](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.slave.deploy.op).
- [Deploy source code of MassProspsecting SDK](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.sdk.deploy.op).

## 12. Starting and Stopping Nodes

You can define a list of operations for:

1. starting (running) your software, and
2. stopping your software 

in any node.

E.g.:

```
saas start --node=worker* --root
```

and 

```
saas stop --node=worker* --root
```

**Notes:**

- The `--root` argument will be required for sure if your operations start and stop services.

- The commands above will run operations for all the nodes defined in your `BlackOpsFile` with name matching `worker*`.

- The list of `.op` scripts to execute are defined in the keys `start_ops` and `stop_ops` of the node descriptor.

- Both `saas start` and `saas stop` execute one or more `.op` scripts, like the `saas source` does. You can define such operations in your configuration file.

E.g.:

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    # starting operations
    :start_ops => [ # <===
        'mass.worker.start',
    ],
    # stopping operations
    :stop_ops => [ # <===
        'mass.worker.stop',
    ],
})
```

**Pre-Built Start/Stop Operations:**

There are some pre-built operations for starting or stopping your software:

- [Start processes on MassProspecting Master Node](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.master.start.op).
- [Stop processes on MassProspecting Master Node](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.master.stop.op).
- Start processes on MassProspecting Slave Nodes.
- Stop processes on MassProspecting Slave Nodes.
- [Start processes on MassProspecting Worker Nodes](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.worker.start.op).
- [Stop processes on MassProspecting Worker Nodes](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.worker.start.op)

## 13. Configuration Templates

Use tempaltes to avoid code duplication in your configuration file.

**BlackOpsFile**

```ruby
# Re-usabeTemplates for Node-Descriptions
#
@t = {
    # SSH common parameters
    :ssh => {
        :ssh_username => 'blackstack',
        :ssh_port => 22,
    },
    # PostgreSQL commons parameters.
    :postgres => {
        :postgres_port => 5432,
        :postgres_username => 'blackstack',
    },
    # git credentials
    :git => {
        :git_username => 'leandrosardi',
        :git_password => GIT_PASSWORD,
    },
}

...

BlackOps.add_node({
    :name => 'worker01',
    :ip => '123.123.123.1',
    # it is recommended to manage one different SSH password for each node
    :ssh_password => 'foo-worker01-password123',
    :ssh_root_password => 'foo-worker01-root-password123',
}.merge(
    @t[:ssh],
    @t[:git],
))

BlackOps.add_node({
    :name => 'worker02',
    :ip => '123.123.123.2',
    # it is recommended to manage one different SSH password for each node
    :ssh_password => 'foo-worker02-password456',
    :ssh_root_password => 'foo-worker02-root-password456',
}.merge(
    @t[:ssh],
    @t[:git],
))

...

```

## 14. Monitoring

Your can list your nodes and monitor the usage of CPU, RAM and disk space.

```
ruby list.rb
```

![blackops list of nodes](/assets/list01.png)

The `list.rb` script will:

1. show all the nodes defined in your configuration file;

2. connect the nodes one by one via SSH and bring **RAM usage**, **CPU usage**, **disk usage** and **custom alerts** (custom alerts will be introduced further).

**Notes:**

- Once connected to a node, the values shown in the row of the node will be aupdated every 5 seconds by default.

![blackops list of nodes](/assets/list02.png)

- You can define a custom number of seconds to update each row:

```
ruby list.rb --interval=15
```

- The SSH connection to a node may fail.

![blackops list of nodes](/assets/list03.png)

- By default; the usage of RAM, CPU or disk must be under 50% or it will be shown in red.

![blackops list of nodes](/assets/list04.png)

- You can define the thresholds of each node in your configuration file, so you don't need write them in the command line:

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

- The number of **custom alerts** must be 0, or it will be shown in red. This treshold is always `0` and cannot be modified.

![blackops list of nodes](/assets/list05.png)

- You can use wildcard to choose the list of nodes you want to see.

```
ruby list.rb --node=worker*
```

- If you press `CTRL+C`, the `saas list` command will terminate.

## 15. Infrastructure Managing

You can connect BlackOps with [Contabo](https://contabo.com) using our [Contabo Client library](https://github.com/leandrosardi/contabo-client).

**BlackOpsFile**

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

The `list.rb` script will **merge** the nodes defined in your configuration file with the list of instances in your Contabo account.

Such a merging is performed using the public IPv4 addess of **Contabo instances** and **nodes** defined in the configuration file.

```
ruby list.rb
```

![blackops infrastructure management](/assets/contabo01.png)

**Notes:**

- The rows with no value in the **Contabo ID** column are nodes defined into the configuration file, but not existing in the list of Contabo instances.

E.g.: in the picture above, the no `slave01`.

- The rows with `unknown` in the **status** column are Contabo instances that are not defined in your configuration file.

The `unknown` situation happens when you have a software that creates instances on Contabo dynamically, using [Contabo Client's `create` feature](https://github.com/leandrosardi/contabo-client?tab=readme-ov-file#creating-an-instance).

E.g.: You developed a scalable SAAS that creates a dedicated instance on Contabo for each user signed up.

To avoid the `unknown` situation, your software should store instances created dynamically into its database, and add them to BlackOps dynamically too, by editing your `BlackOpsFile`

## 16. Custom Alerts

You can write code snipets of monitoring of your nodes:

**BlackOpsFile**

```ruby
BlackOps.add_node({
    :name => 's01',
    :ip => '195.179.229.20',
    ...
    :alerts => { # <=== 

        # this function calls the REST-API of a MassProspecting Slave Node, 
        # and returns true if there are no `job` records with failed status  
        #
        # Arguments:
        # - node: Instance of a node object.
        # 
        :massprospecting_failed_jobs => lambda do |node, *args|
            # ...
            # source code to call the REST-API of the slave node
            # ...
            return true
        end,
        ...
    },
    ...
    # to call the REST-API of the slave node, you will need an API key for sure.
    :api_key => 'foo-api-key',
})
```

Using the `alerts.rb` script, you can get a report of the alerts raised by each node.

```
ruby alerts.rb --node=worker*
```

## 17. Processes Watching

When you define a node, you can specify what are the processes that will be running there.

**BlackOpsFile**

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

Then, call the `proc.rb` script to watch 

1. if they are running or not,
2. the RAM consumed by each one of the processes; and 
3. the CPU consumed by each one of the processes.

```
ruby proc.rb
```

_picture pending_

You can also use wildcards with specify the nodes you want to watch:

```
ruby proc.rb --node=worker*
```

**Notes:**

- The `proc` command simply connect the nodes via SSH and performa a `grep` command to find the processes you specified.

- If one processes listed into the `procs` array is not found when running the `grep`, then such a process is shown as `offline` in the list.

## 18. Command `saas`

If you are working on a fresh OS with not Ruby installed, you can use the `saas` command.
The `saas` command is the same script series packed into an executable file.

**Step 1:** Install the `saas` command.

```
wget https://github.com/leandrosardi/blackops/raw/refs/heads/main/releases/saas-1.2-ubuntu-20.04

sudo mv saas-1.2-ubuntu-20.04 /usr/local/bin/saas

sudo chmod 777 /usr/local/bin/saas
```

If you have not Ubuntu 20.04 but another version, find all available versions [here](https://github.com/leandrosardi/blackops/tree/main/releases).


**Step 2:** Check if `saas` is working.

```
saas version
```

**Step 3:** Install your Ruby environment.

```
wget https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op

saas source ./hostname.op --local --name=dev1
```


## 19. Releasing

_pending_

## 20. Further Work

### a. Logs Watching and Alerts

Log watching & error keywords monitoring. 

https://github.com/leandrosardi/blackops/issues/48

### b. Email Notifications

You can define an SMTP relay and a list of email address to notify when any value in the table above goes red.

```ruby
...
BlackOps.set({
    :alerts => {
        'smtp_ip' => '...', 
        'smtp_port' => '...', 
        'smtp_username' => '...', 
        'smtp_password' => '...', 
        'smtp_sending_name' => 'BlackOps',
        'smtp_sending_email' => 'blackops@massprospecting.com',
        'receivers' => [
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

- You can run the `saas list` command in background, keep it monitoring 24/7, and get notified when an error happens.

```
saas list --background
```

- When CPU or RAM usage run over their threshold, no email will be delivered. This is because CPU and RAM usage may be very flutuating.

- An email notification will be delivered when the disk usage raises over its threshold at a first time after has been under it.

- An email notifications will be delivered when the number of alerts raises over `0` at a first time after has been `0`.

- Log error keywords

- Processes not running

- Any email notification includes the name and public IP of the node, the value of CPU usage, RAM usage, disk usage and alerts, and the threshold of each one.

### c. Scalability

- Scalable Monitoring
- Scalable Processes Watching
- Scalable Log Watching
- Scalable Deployment

### d. Directives

E.g.:

**mysaas.ubuntu_20_04.full.op**

```ruby
# This directive validates you are connecting the node as root.
#!root
```

### e. Requires

E.g.:

**mysaas.ubuntu_20_04.full.op**

```ruby
# This requires execute another op at this point.
require mysaas.ubuntu_20_04.base.op
```
