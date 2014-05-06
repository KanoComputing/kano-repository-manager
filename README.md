# Kano Repository Manager

**dr** (stands for debian repository) is a Debian repository management tool.
It will help you set up and maintain your own small package repository for any
Debian-based distribution. You can keep your sources in **git** and use the
**dr** tool to manage builds, versions, and releases. It works particularly
well in case your development is very fast and you ship new versions of
your packages often (even several times a day).

![Example of using dr](http://linuxwell.com/assets/images/posts/tco-example.png)

It is the tool we use to manage our software repository and the custom
packages for **Kano OS**. The application is written in **Ruby**, building
on top of many other tools (such as reprepro, debuild, debhelper, and others).

## Installation

You will need to install several dependencies in order to be able to use
**dr** properly. Running the following command should get you all you'll
need:

```bash
sudo apt-get install git tar gzip devscripts debhelper debootstrap \
                     qemu-user-static chroot ruby build-essential \
                     curl reprepro rngd-tools
```

Note that because **dr** uses tools such as **debootstrap**, **debhelper**,
and **debuild**, it's now limited for use on Debian-based distributions of
Linux only.

After you've got all the dependencies sorted, you can install **dr** with
the following command:

```bash
sudo gem install dr
```

## Usage

What follows is a rather basic and incomplete introduction to **dr**. For a more
comprehensive guide, please visit the [project
wiki](https://github.com/KanoComputing/kano-repository-manager/wiki) on GitHub.

### Setting up the repository

Before anything else, you need to initialise your repository. This can be
quite a complex task, but worry not, **dr** will guide you through the
whole process and set it up automatically. It will generate the GPG key pair
and also prepare an isolated build environment where the packages will be
built.

To make sure there is enough entropy available on the system when the GPG
pair is generated, make sure to run the following command before running
`dr init`:

```bash
sudo rngd -r /dev/urandom
```

After that, run
```bash
dr init <location-of-your-new-repo>
```

**dr** will ask you several questions and proceed to preparing the build
environment. The whole process can take up to 30 minutes to complete depending
on your internet connection.

![Creating a repo with dr](http://linuxwell.com/assets/images/posts/dr-init.png)

#### Configuration
As there can be several repositories present on a single system (you can run
`dr init` as many times as you like), you need to tell **dr** which one it
should use by default. Otherwise, we would have to type `--repo ~/example`
with every single command. There are two place where you set this up:

* either **system-wide** in the `/etc/dr.conf` file
* or **per-user** in the `~/.dr.conf`

Both files are simple **YAML** documents with the following format:

```yaml
default_repo: "example"

repositories:
  - name: "example"
    location: "/home/radek/example"
```

### Add a few packages

When your repo directory is up and running, the next step is to add a few
packages to it. Here, you have two options; you can either add a pre-built
deb files directly, or source packages hosted in git repositories.

To add a pre-build package run the following command:

```bash
dr add --deb path/to/the/package_1.0-35_all.deb
```

However, the full power of **dr** is not unleashed until you add a source
package, so that it can build and manage it for you. To add a source package,
point **dr** to the git repository in which you manage your project's sources.

```bash
dr add --git https://github.com/KanoComputing/kano-settings
```

![Adding a source package](http://linuxwell.com/assets/images/posts/dr-add.png)

**dr** is clever enough to determine all the information it needs about the
package automatically from the sources, so you don't need to do anything
else.

### Manage the packages



## License

Copyright (C) 2014 Kano Computing Ltd.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
