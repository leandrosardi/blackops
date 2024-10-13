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

- The parameter `--name` in the `ops` command is to replace the `$$name` variable into the `.ops` file.

- You can define any variable into your `.ops` file, and you can set its value into a command parameter. 
E.g.: 

**set-rubylib.op**

```
RUN export RUBYLIB=$$rubylib
```

## 2. Remote Operations

You can also run operations on a remote node through SSH.

You have to use the `--remote` and `--ssh` parameters instead of `--local`.

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





