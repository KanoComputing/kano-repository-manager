# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/jessie64"

  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "private_network", ip: "192.168.33.10"
  config.vm.network "public_network"

  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y \
        git \
        tar \
        gzip \
        devscripts \
        debhelper \
        debootstrap \
        qemu-user-static \
        ruby \
        rubygems \
        build-essential \
        curl \
        reprepro \
        rng-tools \
        dpkg-sig \
        ruby-dev \
        vim

    cd /vagrant && gem build dr.gemspec && gem install dr

  SHELL
end
