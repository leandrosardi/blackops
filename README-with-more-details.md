# BlackOps

[![GitHub Stars](https://img.shields.io/github/stars/leandrosardi/blackops?style=flat-square)](https://github.com/leandrosardi/blackops/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/leandrosardi/blackops?style=flat-square)](https://github.com/leandrosardi/blackops/network)
[![GitHub Issues](https://img.shields.io/github/issues/leandrosardi/blackops?style=flat-square)](https://github.com/leandrosardi/blackops/issues)
[![GitHub Tag](https://img.shields.io/github/v/tag/leandrosardi/blackops?style=flat-square)](https://github.com/leandrosardi/blackops/releases)
[![Last Commit](https://img.shields.io/github/last-commit/leandrosardi/blackops?style=flat-square)](https://github.com/leandrosardi/blackops/commits/main)
[![Repo Size](https://img.shields.io/github/repo-size/leandrosardi/blackops?style=flat-square)](https://github.com/leandrosardi/blackops)

![BlackOps Logo](./assets/blackops-logo-1.png)

The **BlackOps** tool makes it easy to perform your deployments from the comfort of your command line.

```
saas deploy --node=n01 --version=1.2
```

This is a more detailed version of [README](./README.md).

**Table of Contents**

1. [Getting Started](#1-getting-started)
2. [Remote Operations](#2-remote-operations)
3. [Configuration Files](#3-configuration-files)
4. [Environment Variable `$OPSLIB`](#4-environment-variable-opslib)
5. [Repositories](#5-repositories)
6. [Custom Parameters](#6-custom-parameters)
7. [Connecting](#7-connecting)
8. [Installing](#8-installing)
9. [Migrations](#9-migrations)
10. [Deploying](#10-deploying)
11. [Starting and Stopping Nodes](#11-starting-and-stopping-nodes)
12. [Configuration Templates](#12-configuration-templates)

## 1. Getting Started

Follow the steps below for running your first operation.

### 1.1. Install the `saas` command

BlackOps works on 

1. Ubuntu 20.04,
2. Ubuntu 22.04.

**Installing on Ubuntu 20.04**

```
wget https://github.com/leandrosardi/blackops/raw/refs/heads/main/bin/saas--ubuntu-20.04
sudo mv ./saas--ubuntu-20.04 /usr/bin/saas
sudo chmod 777 /usr/bin/saas
```

**Installing on Ubuntu 22.04**

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

saas source ./hostname.op --node=prod1 --root
```

The environment variable `$OPSLIB` can include a list of folders separated by `:`. 

E.g.:

```
export OPSLIB=~/:/home/leandro/code1:/home/leandro/code2

saas source ./hostname.op --node=prod1 --root
```

**Note:** If the file `BlackOpsFile` file is present into more than one path, then the `saas source` command will show an error message: `Configuration file is present in more than one path: <list of paths.>`.

## 5. Repositories

In your configuration file, you can define the folders where to find the `.op` files.

**BlackOpsFile**

```ruby
...
BlackOps.set(
    repositories: [
        '/home/leandro/ops',
        '/home/leandro/more-ops',
    ],
)
...
```

Any call to the `saas` command gets simplified, because you don't need to write the full path to the `.op` file.

```
saas source hostname --node=prod1 --root
```

**Note:** If the file `hostname.op` is present into more than one repository, then the `ops` command with show an error message: `Operation hostname.op is present in more than one repository: <list of repositories.>`.

## 6. Custom Parameters

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

## 7. Connecting

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

## 8. Installing

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

## 9. Migrations

The `saas migrations` command connects to a PostgreSQL database into a node and executes a series of SQL files.

```
saas migrations --node=prod1
```

You have to define the list of folders here to find such SQL files.

```ruby
BlackOps.add_node({
    :name => 'prod1',         
    ...
    :postgres_username => '<your postgres username>',
    :postgres_password => '<your postgres password>',
    :postgres_database => '<your postgres database>',
    ...
    :migration_folders => [
        '/home/blackstack/code1/master/sql',
        ...
    ],
})
```

**Notes:** 

- The list of folders are not referencing to paths in your local computer, but paths into the node.

- The list of migrations folders will be processed ony by one, in the same order they are listed. 

- The files into each folder will be processed one by one too, sorted by name.

- Each `.sql` file, will be executed sentence by sentence. Each sentence must to finish whith a semicolon (`;`).


## 10. Deploying

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

## 11. Starting and Stopping Nodes

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

## 12. Configuration Templates

Use templates to avoid code duplication in your configuration file.

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

## Disclaimer

BlackOps is provided “as is,” without warranty of any kind, express or implied. In no event shall the authors or contributors be liable for any claim, damages, or other liability arising from—whether in an action of contract, tort, or otherwise—your use of BlackOps or any operations performed with it. You assume full responsibility for verifying that any deployment or configuration change executed with BlackOps is safe and appropriate for your environment.

All third-party trademarks, service marks, and logos used in this README or in the tool itself remain the property of their respective owners, and no endorsement is implied. Use of BlackOps is at your own risk.

Logo has been taken from [here](https://www.flaticon.com/free-icon/command-line_9969711?related_id=9969486&origin=search).

