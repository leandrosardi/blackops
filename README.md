# BlackOps

The **BlackOps** library makes it easy to manage your DevOps.

BlackOps gives you an script series to perform your deployments and monitor your nodes from the comfort of your command line.

BlackOps provides the following features: 

1. **Continious Deployment**,
2. **Logs Monitoring**, 
3. **Processes Monitoring**; and
4. **Infrastructure Monitoring**.

**Note:** BlackOps has been tested on the following stack:

- Ubuntu 20.04,
- Ruby 3.1.2; and
- Bundler 2.3.7.

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
10. [Deploying](#10-deploying)
11. [Starting and Stopping Nodes](#11-starting-and-stopping-nodes)
12. [Configuration Templates](#12-configuration-templates)
13. [Monitoring](#13-monitoring)
14. [Infrastructure Managing](#14-infrastructure-managing)
15. [Custom Alerts](#15-custom-alerts)
16. [Processes Watching](#16-processes-watching)
17. [Logs Watching](#17-logs-watching)
18. [Further Work](#18-further-work)

## 1. Getting Started

1. Clone the project.

```
mkdir -p ~/code1
cd ~/code1
git clone https://github.com/leandrosardi/blackops
```

2. Install gems.

```
cd ~/code1/blackops
bundler update
```

3. Run an operation.

The code below will download and execute a `.ops` script that sets the hostname of your computer. 

```
cd ~/code1/blackops/cli

wget https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op

ruby source.rb ./hostname.op --local --name=dev1
```

**Notes:**

Here are some other considerations about the `source.rb` script:

- You can write `./hostname` instead of `./hostname.op`.

The `source` command will look for the `./hostname` file. And if `./hostname` doesn't exists, then the `source` command will try with `./hostname.op`

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

- The argument `--name` in the `source.rb` script is to replace the `$$name` variable into the `.ops` file.

- You can define any variable into your `.ops` file, and you can set its value into a command argument. 

E.g.: 

**set-rubylib.op**

```
RUN export RUBYLIB=$$rubylib
```

- All the variables defined into the `.ops` file must be present into the list of arguments of the `source.rb` script.

## 2. Remote Operations

You can also run operations on a remote node through SSH.

Use the `--ssh` arguments instead of `--local`.

```
ruby source.rb ./hostname.op --ssh=username:password@ip:port --name=prod1
```

## 3. Configuration Files

You can define nodes into a **configuration file**.

Such a configuration file is written with Ruby syntax.

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

Then you can run the `source.rb` command referencing to 

1. such a configuration file;

2. the node defined in such a configuration file;

and

3. the `--root` flag to use `root` user for this operation.

```
ruby source.rb ./hostname.ops --config=./BlackOpsFile --node=prod1 --root --name=prod1 
```

**Note:** 

- In the example above, if the `--root` flag is disabled, then BlackOps will access the node with the `blackstack` user. Otherwise, it will access with the `root` user.

## 4. Environment Variable `$OPSLIB`

Additionally, you can store one or more paths into the environment variable `$OPSLIB`. 

The `source.rb` script will look for `BlackOpsFile` there.

Using `$OPSLIB` you don't need to write the `--config` argument every time you call the `ops source` command.

E.g.:

```
export OPSLIB=~/

ruby source.rb hostname --node=prod1 --name=prod1
```

The environment variable `$OPSLIB` can include a list of folders separated by `:`. 

E.g.:

```
export OPSLIB=~/:/home/leandro/code1:/home/leandro/code2

ruby source,rb hostname --node=prod1 --name=prod1
```

**Notes:**

There are some considerations about the `$OPSLIB` variable:

- If the file `BlackOpsFile` file is present into more than one path, then the `source.rb` script will show an error message: `Configuration file is present in more than one path: <list of paths.>`.

## 5. Remote `.op` Files

You can refer to `.op` files hosted in the web.

E.g.:

```
ruby source.rb https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op --node=prod1 --name=prod1
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

Any call to the `ops` command gets simplified, because you don't need to write the full path to the `.ops` file.

```
ops source hostname.op --node=prod1 --name=prod1
```

**Notes:**

There are some considerations about the repositories.

- If the file `hostname.op` is present into more than one repository, then the `ops` command with show an error message: `Operation hostname.op is present in more than one repository: <list of repositories.>`.

## 7. Custom Parameters

The argument `--name` is not really necessary in the command line, 

```
ops source hostname.op --node=prod1 --name=prod1
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

So the execution of any operation gets simplified even more.

E.g.:

The `--rubylib` argument in the command line is not longer needed:

```
ops source set-rubylib.op --node=prod1
```

## 8. Connecting

You can access any node via SSH using the `ops ssh` command and the credentials defined in `BlackOpsFile`.

The goal of the `ops ssh` command is that you can access any node easily, writing short commands.

```
ops ssh prod1
```

**Notes:**

- You can also require to connect as `root`.

E.g.:

```
ops ssh prod1 --root
```

- You can do the same from Ruby code.

E.g.:

```ruby
BlackOps.ssh( :prod1,
    connect_as_root: true,
    logger: l
)
```

## 9. Installing

The `ops install` executes one or more `.op` scripts, like the `ops source` does.

E.g.:

```
ops install worker*
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

- You can also require to connect as `root`.

E.g.:

```
ops install worker* --root
```

- You can do the same from Ruby code.

E.g.:

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.install_remote(
    node: n,
    connect_as_root: true,
    logger: l
)
```

- Internally, the `BlackOps.install_remote` method calls `BlackOps.source_remote`.

- The `ops install` command supports all the same arguments than `ops source`, except the `op` argument:

    1. `--local`.
    2. `--foo=xx` where `foo` is a paremeter to be replaced in the `.op` file.
    3. `--root`
    4. `--config`
    5. `--ssh`

- The `BlackOps.install_remote` method also supports all the same parameters than `BlackStack.source_remote`, except the `op` parameter:

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.install_remote(
        node: n,
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

- There is a `BlackOps.install_local` method too.

```ruby
BlackOps.install_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

- When running `ops install` in your local computer, use the `--local` argument, and don't forget the `--install_ops` argument too.

```
ops install --local \
    --install_ops "mysaas.install.ubuntu_20_04.base,mysaas.install.ubuntu_20_04.postgresql,mysaas.install.ubuntu_20_04.nginx,mysaas.install.ubuntu_20_04.adspower" \
```

```ruby
BlackOps.install_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
            ...
            'install_ops' => [ # <===
                'mysaas.install.ubuntu_20_04.base',
                'mysaas.install.ubuntu_20_04.postgresql',
                'mysaas.install.ubuntu_20_04.nginx',
                'mysaas.install.ubuntu_20_04.adspower',
            ],
        },
        logger: l   
)
```

**Pre-Built Install Operations:**

There are some pre-built install operations that you can use:

- [Install base required packages on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.base.op).
- [Install PostgreSQL on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.postgresql.op).
- [Install Nginx on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.nginx.op).
- [Install AdsPower on Ubuntu 20.04](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mysaas.install.ubuntu_20_04.adspower.op).

## 10. Deploying

The `ops deploy` executes one or more `.op` scripts (like the `ops source` does), and it also connects a **PostgreSQL database** for running SQL migrations.

E.g.:

```
ops deploy worker*
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
ops deploy worker* --root
```

- You can do the same from Ruby code.

E.g.:

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.deploy_remote( 
    node: n,
    connect_as_root: true,
    logger: l
)
```

- To execute migrations, your node must to define both: the **connection parameters** and the **migration folders**:

**BlackOpsFile**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :migrations => {
        # db connection parameters 
        'postgres_port' => 5432, # <===
        'postgres_database' => 'blackstack',
        'postgres_username' => 'blackstack',
        'postgres_password' => 'MyFooPassword123', 
        ...
        # migration folders
        'migration_folders' => [ # <===
            '/home/leandro/code1/sql',
            '/home/leandro/code2/sql',
        ],
    },
    ...
    # deployment operations
    :deploy_ops => [ 
        'mass.slave.deploy',
        'mass.sdk.deploy',
    ]
})
```

- When running migrations, BlackOps will execute every `.sql` file into the migration folders. 

BlackOps will iterate the folders in the same order they are listed.

At each folder, BlackOps will execute the `.sql` scripts sorted by their filenames.

For each `.sql` file, BlackOps will execute sentence by sentence. Where each sentence finishes whith a semicolon (`;`).

- You can execute a deployment from Ruby code too:

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.deploy_remote(
    node: n,
    logger: l
)
```

- Internally, the `BlackOps.deploy_remote` method calls `BlackOps.source_remote`.

- The `ops deploy` command supports all the same arguments than `ops source`, except the `op` argument:

    1. `--local`.
    2. `--foo=xx` where `foo` is a paremeter to be replaced in the `.op` file.
    3. `--root`
    4. `--config`
    5. `--ssh`

- The `BlackOps.deploy_remote` method also supports all the same parameters than `BlackStack.source_remote`, except the `op` parameter:

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.deploy_remote(
        node: n,
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

- There is a `BlackOps.deploy_local` method too.

```ruby
BlackOps.deploy_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

- When running `ops deploy` in your local computer, don't forget to define the `--local` argument, the **list of operations**, the **connection parameters** and **migration folders** into your command line:

```
ops deploy --local \
    --deploy_ops "./hostname.op,./rubylib.op" \
    --postgres_port 5432
    --postgres_database blackstack \
    --postgres_username blackstack \
    --postgres_password MyFooPassword123 \
    --migration_folders="/home/leandro/code1/sql,/home/leandro/code2.sql" \
```

and you can do the same from Ruby code:

```ruby
BlackOps.deploy_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
            ...
            'deploy_ops' => [ # <===
                'mass.slave.deploy',
                'mass.sdk.deploy',
            ],
            ...
            # db connection parameters 
            'postgres_port' => 5432, # <===
            'postgres_database' => 'blackstack',
            'postgres_username' => 'blackstack',
            'postgres_password' => 'MyFooPassword123',
            ...
            # migration folders
            'migration_folders' => [ # <===
                '/home/leandro/code1/sql',
            ],
        },
        logger: l   
)
```

- The parameters below are not mandatory, but if one of them is defined, all the others must be defined too:

    1. `postgres_port`,
    2. `postgres_database`,
    3. `postgres_username`,
    4. `postgres_password`,
    5. `migration_folders`.

Otherwise, `BlackOps.deploy` will raise an exception:

**Pre-Built Deploy Operations:**

There are some pre-built deploy operations that you can use:

- [Deploy source code of master node of MassProspsecting](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.master.deploy.op).
- [Deploy source code of slave node of MassProspsecting](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.slave.deploy.op).
- [Deploy source code of MassProspsecting SDK](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.sdk.deploy.op).

## 11. Starting and Stopping Nodes

You can define a list of operations for:

1. starting (running) your software, and
2. stopping your software 

in any node.

E.g.:

```
ops start worker*
```

and 

```
ops stop worker*
```

Both `ops start` and `ops stop` execute one or more `.op` scripts, like the `ops source` does.

**Notes:**

- The commands above will run operations for all the nodes defined in your `BlackOpsFile` with name matching `worker*`.

- The list of `.op` scripts to execute are defined in the keys `start_ops` and `stop_ops` of the node descriptor.

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

- You can also require to connect as `root`.

E.g.:

```
ops start worker* --root
```

or

```
ops stop worker* --root
```

- You can do the same from Ruby code.

E.g.:

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.start_remote(
    node: n,
    connect_as_root: true,
    logger: l
)
```

or

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.stop_remote(
    node: n,
    connect_as_root: true,
    logger: l
)
```

- Internally, the `BlackOps.start_remote` and `BlackOps.stop_remote` methods call `BlackOps.source_remote`.

- The `ops start` and `ops stop` commands support all the same arguments than `ops source`, except the `op` argument:

    1. `--local`.
    2. `--foo=xx` where `foo` is a paremeter to be replaced in the `.op` file.
    3. `--root`
    4. `--config`
    5. `--ssh`

- The `BlackOps.start_remote` and `BlackOps.stop_remote` methods also support all the same parameters than `BlackStack.source_remote`, except the `op` parameter:

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.start_remote(
        node: n,
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

or

```ruby
# Get hash descriptor of the node.
h = BlackOps.get_node(:worker06)
# Create instance of node.
n = BlackStack::Infrastructure::Node.new(h)

BlackOps.stop_remote(
        node: n,
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

- There are `BlackOps.start_local` and `BlackOps.stop_local` methods too.

```ruby
BlackOps.start_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

and

```ruby
BlackOps.stop_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
        },
        logger: l   
)
```

- When running `ops start` or `ops stop` in your local computer, use the `--local` argument, and don't forget the `--start_ops` or `--stop_ops` arguments too.

```
ops start --local \
    --start_ops "./start.worker.op"
```

or

```
ops stop --local \
    --stop_ops "./start.worker.op"
```

and you can do the same from Ruby code:

```ruby
BlackOps.start_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
            ...
            'start_ops' => [ # <===
                'mass.worker.start',
            ],
        },
        logger: l   
)
```

or

```ruby
BlackOps.stop_local(
        #op: './hostname.op', <== Ignore. Operations are defined in the hash descriptor of the node.
        parameters: => {
            'name' => 'dev1',
            ...
            'stop_ops' => [ # <===
                'mass.worker.stop',
            ],
        },
        logger: l   
)
```

**Pre-Built Start/Stop Operations:**

There are some pre-built operations for starting or stopping your software:

- [Start processes on MassProspecting Master Node](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.master.start.op).
- [Stop processes on MassProspecting Master Node](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.master.stop.op).
- Start processes on MassProspecting Slave Nodes.
- Stop processes on MassProspecting Slave Nodes.
- [Start processes on MassProspecting Worker Nodes](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.worker.start.op).
- [Stop processes on MassProspecting Worker Nodes](https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/mass.worker.start.op)

## 12. Configuration Templates

_pending_

## 13. Monitoring

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

- You can define a custom number of seconds to update each row:

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
ops list worker*
```

- If you press `CTRL+C`, the `ops list` command will terminate.

## 14. Infrastructure Managing

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

The `ops list` command will **merge** the nodes defined in your configuration file with the list of instances in your Contabo account.

Such a merging is performed using the public IPv4 addess of **Contabo instances** and **nodes** defined in the configuration file.

```
ops list
```

![blackops infrastructure management](/assets/contabo01.png)

**Notes:**

- The rows with no value in the **Contabo ID** column are nodes defined into the configuration file, but not existing in the list of Contabo instances.

E.g.: in the picture above, the no `slave01`.

- The rows with `unknown` in the **status** column are Contabo instances that are not defined in your configuration file.

The `unknown` situation happens when you have a software that creates instances on Contabo dynamically, using [Contabo Client's `create` feature](https://github.com/leandrosardi/contabo-client?tab=readme-ov-file#creating-an-instance).

E.g.: You developed a scalable SAAS that creates a dedicated instance on Contabo for each user signed up.

To avoid the `unknown` situation, your software should store instances created dynamically into its database, and add them to BlackOps dynamically too, by editing your `BlackOpsFile`

## 15. Custom Alerts

You can write code snipets of monitoring of your nodes:

**BlackOpsFile**

```ruby
BlackOps.add_node({
    :name => 's01',
    :ip => '195.179.229.20',
    ...
    :alerts => { # <=== 

        # this function calls the REST-API of a MassProspecting Slave Node, 
        # and returns true if there are one or more `job` record with failed status  
        #
        # Arguments:
        # - node: Instance of a node object.
        # - ssh: Already opened SSH connection with the node.
        :massprospecting_failed_jobs => Proc.new do |node, ssh, *args|
            # ...
            # source code to call the REST-API of the slave node
            # ...
        end,
        ...
    },
    ...
    # to call the REST-API of the slave node, you will need an API key for sure.
    :api_key => 'foo-api-key',
})
```

Using the `ops alerts` command, you can get a report of the alerts raised by each node.

```
ops alerts s*
```

## 16. Processes Watching

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

Then, call the `proc` command to watch 

1. if they are running or not,
2. the RAM consumed by each one of the processes; and 
3. the CPU consumed by each one of the processes.

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

## 17. Logs Watching

When you define a node, you can specify what are the log files that you may want to watch.

E.g.:

**BlackOpsFile**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :logs => [
        '/home/blackstack/code1/master/ipn.log',
        '/home/blackstack/code1/master/dispatch.log',
        '/home/blackstack/code1/master/allocate.log',
    ]
})
```

Then, you can run the `ops logs` command that is a kinda `ls` of all the files into a node that matches with the list of files defined in its hash descriptor.

```
ops logs worker*
```

![BlackOps Logfiles Watching](/assets/logfiles01.png)

**Notes:**

- In the list of logfiles shown by the command `ops logs`, you can choose one of then and start watching it online.

This feature simply does a `tail -f` of such a logfile.

_picture pending_

- You can also define a pattern of log files using wildcards.

E.g.:

**BlackOpsFile**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :logs => [
        '/home/blackstack/code1/master/*.log',
    ]
})
```

- You can define a list of keywords into log files that can be indicating that an error happened.

E.g.:

**BlackOpsFile**

```ruby
BlackOps.add_node({
    :name => 'worker06',
    :ip => '195.179.229.21',
    ...
    :logs => [
        '/home/blackstack/code1/master/*.log',
    ],
    :keywords => [
        'error', 'failure', 'failed',
    ] 
})
```

![BlackOps Logfiles Watching](/assets/logfiles02.png)

- You can run the command `ops keywords` for listing the lines with **error keywords** into some logfiles, into some nodes.

E.g.:

```
ops keywords worker* --filename=*dispatch.log 
```

- The `keywords` command simply connect the node via SSH and perform a `cat <logfilename> | grep "keyword"` command.

## 18. Further Work

### Email Notifications

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

### Scalability

- Scalable Monitoring
- Scalable Processes Watching
- Scalable Log Watching
- Scalable Deployment

### Directives

E.g.:

**mysaas.ubuntu_20_04.full.op**

```ruby
# This directive validates you are connecting the node as root.
#!root
```

### Requires

E.g.:

**mysaas.ubuntu_20_04.full.op**

```ruby
# This requires execute another op at this point.
require mysaas.ubuntu_20_04.base.op
```
