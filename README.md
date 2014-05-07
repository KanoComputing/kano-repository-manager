# Kano Repository Manager

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
  <img src="http://linuxwell.com/assets/images/posts/dr-basic.png"
       alt="How dr operates">
</p>

It is the tool we use to manage our software repository and the custom
packages for **Kano OS**. The application is written in **Ruby**, building
on top of many other tools (such as reprepro, debuild, debhelper, and others).

Here is like it looks like in the terminal:

![Example of using dr](http://linuxwell.com/assets/images/posts/tco-example.png)

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
