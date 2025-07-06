# BlackOps

![BlackOps Logo](./assets/blackops-logo-1.png)

The **BlackOps** tool makes it easy to manage your DevOps.

BlackOps gives you a command series to perform your deployments.

E.g.:

```
saas deploy --node=n01 --version=1.2
```

For a more detailed documentation, refere to [README with more details](./README-with-more-details.md).

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

### Install the `saas` command

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

### Run an operation.

The code below will download and execute a very simple `.op` script that sets the hostname of your computer. 

```
wget https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops/hostname.op
saas source ./hostname.op --local --name=dev1
```

## 2. Remote Operations

You can run operations on a remote node through SSH.

Use the `--ssh` arguments instead of `--local`.

```
saas source ./hostname.op --ssh=username:password@ip:port --name=prod1
```

## 3. Configuration Files

You can define nodes into a **configuration file** called **BlackOpsFile**.

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

## 4. Environment Variable `$OPSLIB`

You can store one or more paths to the **BlackOpsFile** into the environment variable `$OPSLIB`. 

```
export OPSLIB=~/:/home/leandro/code1:/home/leandro/code2
saas source ./hostname.op --node=prod1 --root
```

## 5. Repositories

You can define the folders where to find the `.op` files in your configuration file.

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

Now you don't need to write the full path to the `.op` file.

```
saas source hostname --node=prod1 --root
```

## 6. Custom Parameters

You can define any custom parameter into the hash descriptor of your node. 

**BlackOpsFile**

```ruby
...
BlackOps.add_node({
    :name => 'prod1', 
    :rubylib => '/home/blackstack/code', # <=====
    ...
})
...
```

The execution of any operation gets simplified.

```
saas source set-rubylib --node=prod1
```

## 7. Connecting

**BlackOpsFile**

```ruby
...
BlackOps.add_node({
    :name => 'prod1', 
    ...
    :ip => '55.55.55.55',
    :ssh_username => 'blackstack',
    :ssh_port => 22,
    :ssh_password => 'blackops-password',
    :ssh_root_password => 'root-password',
})
...
```

Run the `saas ssh` command to easily connect your node.

```
saas ssh prod1
```

Add the `--root` argument to connect as the root user.

```
saas ssh prod1 --root
```

## 8. Installing

**BlackOpsFile**

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

Run all the operations defined for installation:

```
saas install --node=worker* --root
```

## 9. Migrations

**BlackOpsFile**

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

Connect to a PostgreSQL database into a node and executes the series of SQL files.

```
saas migrations --node=prod1
```

## 10. Deploying

**BlackOpsFile**

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

Run all the operations defined for deployment of a new version:

```
saas deploy --node=worker*
```

## 11. Starting and Stopping Nodes

**BlackOpsFile**

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

Run all the operations defined for starting your nodes:

```
saas start --node=worker* --root
```

Run all the operations defined for stopping your nodes:

```
saas stop --node=worker* --root
```

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

