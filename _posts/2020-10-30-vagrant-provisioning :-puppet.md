---
main_title: "Vagrant Provisioning : Puppet"
title: "Vagrant Provisioning : Puppet"
layout: post
---

<img src="/assets/img/vagrant_puppet/main.jpg"/>

* hello
{:toc}

## Prerequisites

- <a target="_blank" href="https://www.vagrantup.com/">Vagrant</a>
- <a target="_blank" href="https://www.virtualbox.org/">Virtualbox</a>
- <a target="_blank" href="https://curl.haxx.se/">Curl</a>
- <a target="_blank" href="https://www.gnu.org/software/bash/">Bash</a>

## Staging Area

```
mkdir -p ~/vag_puppet_env/{module,manifests}
```
```
cd ~/vag_puppet_env
```
```
mkdir -p module/test_module/{files,manifests,templates}
```
```
touch Vagrantfile start.sh manifests/default.pp \
 module/test_module/manifests/init.pp
```

## Vagrantfile

Edit the Vagrantfile with the below content which pulls ubuntu vm-box.

```
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-16.04"
  config.vm.network "forwarded_port", guest: 80, host: 8084
  config.vm.provision "shell", path: "./start.sh"
  config.vm.provision "puppet" do |puppet|
    puppet.module_path = "./module"
  end
end
```

## Starting Puppet Agent

```bash
#!/bin/sh
command -v puppet > /dev/null && { exit 0; }

ID=$(cat /etc/os-release | awk -F= '/^ID=/{print $2}' | tr -d '"')

case "${ID}" in
  debian|ubuntu)
    wget https://apt.puppetlabs.com/puppet4-release-$(lsb_release -cs).deb
    dpkg -i puppet4-release-$(lsb_release -cs).deb
    apt-get -qq update
    apt-get install -y puppet-agent
    apt-get install -y unzip
    ;;
  *)
    exit 1
    ;;
esac
```

## Manifest

./manifests/default.pp

```
node default {
  include test_module
}
```

## Testing

To start provisioning
```
vagrant up
```

Check the changes in the box
```
vagrant ssh
```

### Contact Me
{% for mentor in site.data.people.me %}
 <div class="mentor-detail" style="display:flex; ">
<img style="margin-left:0px; margin-right:10px; border-radius: 100%; object-fit: cover;" src="{{mentor.link}}" height="{{mentor.ht}}" width="{{mentor.wt}}" />
 <a style="text-decoration:none;" >{{mentor.name}} <br> {{mentor.pos}}</a>
    </div>
{% endfor %}
- Feel free to send me a mail at <a href="mailto:indrarahul2018@gmail.com">indrarahul2018@gmail.com</a>