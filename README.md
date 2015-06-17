# Kano Repository Manager

[![Join the chat at https://gitter.im/KanoComputing/kano-repository-manager](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/KanoComputing/kano-repository-manager?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Gem Version](https://badge.fury.io/rb/dr.svg)](http://badge.fury.io/rb/dr)

**dr** (stands for debian repository) is a Debian repository management tool.
It will help you set up and maintain your own small package repository for any
Debian-based distribution. You can keep your sources in **git** and use the
**dr** tool to manage builds, versions, and releases. It works particularly
well in case your development is very fast and you ship new versions of
your packages often (even several times a day).

The following diagram illustrates how `dr` works. It takes source packages
that are managed in git repositories, builds them and serves them in
different suites. For more information, please see this
[project's wiki](https://github.com/KanoComputing/kano-package-system/wiki).

<p align="center">
  <img src="http://i.imgur.com/pe8A9kd.png"
       alt="How dr operates">
</p>

It is the tool we use to manage our software repository and the custom
packages for **Kano OS**. The application is written in **Ruby**, building
on top of many other tools (such as reprepro, debuild, debhelper, and others).

Here is like it looks like in the terminal:

![Example of using dr](http://linuxwell.com/assets/images/posts/tco-example.png)
