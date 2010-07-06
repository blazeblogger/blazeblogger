# makefile for the bash completion support for BlazeBlogger
# Copyright (C) 2009, 2010 Jaromir Hradilek

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
#
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
#
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

# General settings; feel free to modify according to your situation:
SHELL   = /bin/sh
INSTALL = /usr/bin/install -c

# Installation directory;  feel free to modify according  to your taste and
# current situation:
prefix  = /etc/bash_completion.d

# Make rules; please, do not edit these unless you really know what you are
# doing:
.PHONY: all install uninstall

all:
	@echo "Type \`make install' to perform the installation."

install:
	$(INSTALL) -d $(prefix)
	$(INSTALL) -m 644 blazeblogger $(prefix)/blazeblogger

uninstall:
	rm -f $(prefix)/blazeblogger

