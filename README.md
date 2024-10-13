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

The `ops list` command will merge the nodes defined in your confiuration file with the list of instances in your Contabo account.

