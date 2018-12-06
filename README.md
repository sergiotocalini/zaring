# zaring
Zabbix Agent - Java Springboot

# Dependencies
## Projects
* [Stuffs](https://github.com/sergiotocalini/stuffs/tree/master/springboot)

## Packages
* ksh
* sudo

__**Debian/Ubuntu**__

```
#~ sudo apt install ksh sudo
#~
```

__**Red Hat**__
```
#~ sudo yum install ksh sudo
#~
```

# Deploy
Please the script requires to have already installed the springboot init.d script. Follow the README for the other [project](https://github.com/sergiotocalini/stuffs/tree/master/springboot).

## Zabbix
Zabbix user has to have sudo privileges.

```
#~ cat /etc/sudoers.d/user_zabbix
# Allow the user zabbix to execute any command without password
zabbix	ALL=(ALL:ALL) NOPASSWD:ALL
```

Then you can run the deploy_zabbix script

```
#~ git clone https://github.com/sergiotocalini/zaring.git
#~ sudo ./zaring/deploy_zabbix.sh
#~ sudo systemctl restart zabbix-agent
```

*Note: the installation has to be executed on the zabbix agent host and you have to import the template on the zabbix web. The default installation directory is /etc/zabbix/scripts/agentd/zaring/*
