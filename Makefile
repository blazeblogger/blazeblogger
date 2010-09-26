# makefile for BlazeBlogger, a CMS without boundaries
# Copyright (C) 2009-2010 Jaromir Hradilek

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
POD2MAN = /usr/bin/pod2man
SRCS    = src/blaze-add.pl src/blaze-config.pl src/blaze-edit.pl \
          src/blaze-init.pl src/blaze-list.pl src/blaze-log.pl \
          src/blaze-make.pl src/blaze-remove.pl
DOCS    = pod/blazeblogger.pod pod/blazeintro.pod pod/blazetheme.pod
MAN1    = src/blaze-add.1 src/blaze-config.1 src/blaze-edit.1 \
          src/blaze-init.1 src/blaze-list.1 src/blaze-log.1 \
          src/blaze-make.1 src/blaze-remove.1
MAN7    = pod/blazeblogger.7 pod/blazeintro.7 pod/blazetheme.7

# Installation directories; feel free to modify according to your taste and
# current situation:
prefix  = /usr/local
bindir  = $(prefix)/bin
datadir = $(prefix)/share/blazeblogger
mandir  = $(prefix)/share/man
man1dir = $(mandir)/man1
man7dir = $(mandir)/man7
langdir = $(datadir)/lang

# Additional information:
VERSION = 1.0.0

# Make rules;  please do not edit these unless you really know what you are
# doing:
.PHONY: all clean install uninstall

all: $(MAN1) $(MAN7)

clean:
	-rm -f $(MAN1) $(MAN7)

install: $(MAN1) $(MAN7)
	@echo "Copying scripts..."
	$(INSTALL) -d $(bindir)
	$(INSTALL) -m 755 src/blaze-add.pl $(bindir)/blaze-add
	$(INSTALL) -m 755 src/blaze-log.pl $(bindir)/blaze-log
	$(INSTALL) -m 755 src/blaze-edit.pl $(bindir)/blaze-edit
	$(INSTALL) -m 755 src/blaze-init.pl $(bindir)/blaze-init
	$(INSTALL) -m 755 src/blaze-list.pl $(bindir)/blaze-list
	$(INSTALL) -m 755 src/blaze-make.pl $(bindir)/blaze-make
	$(INSTALL) -m 755 src/blaze-config.pl $(bindir)/blaze-config
	$(INSTALL) -m 755 src/blaze-remove.pl $(bindir)/blaze-remove
	@echo "Copying utilities..."
	$(INSTALL) -m 755 unix/blaze.sh $(bindir)/blaze
	@echo "Copying man pages..."
	$(INSTALL) -d $(man1dir)
	$(INSTALL) -m 644 src/blaze-add.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-log.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-edit.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-init.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-list.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-make.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-config.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-remove.1 $(man1dir)
	$(INSTALL) -d $(man7dir)
	$(INSTALL) -m 644 pod/blazeintro.7 $(man7dir)
	$(INSTALL) -m 644 pod/blazetheme.7 $(man7dir)
	$(INSTALL) -m 644 pod/blazeblogger.7 $(man7dir)
	@echo "Copying language files..."
	$(INSTALL) -d $(langdir)
	$(INSTALL) -m 644 lang/cs_CZ $(langdir)
	$(INSTALL) -m 644 lang/de_DE $(langdir)
	$(INSTALL) -m 644 lang/en_GB $(langdir)
	$(INSTALL) -m 644 lang/en_US $(langdir)
	$(INSTALL) -m 644 lang/es_ES $(langdir)
	$(INSTALL) -m 644 lang/eu_ES $(langdir)
	$(INSTALL) -m 644 lang/fr_FR $(langdir)
	$(INSTALL) -m 644 lang/ja_JP $(langdir)
	$(INSTALL) -m 644 lang/pt_BR $(langdir)
	$(INSTALL) -m 644 lang/ru_RU $(langdir)
	$(INSTALL) -m 644 lang/uk_UK $(langdir)

uninstall:
	@echo "Removing scripts..."
	-rm -f $(bindir)/blaze-add
	-rm -f $(bindir)/blaze-log
	-rm -f $(bindir)/blaze-edit
	-rm -f $(bindir)/blaze-init
	-rm -f $(bindir)/blaze-list
	-rm -f $(bindir)/blaze-make
	-rm -f $(bindir)/blaze-config
	-rm -f $(bindir)/blaze-remove
	@echo "Removing utilities..."
	-rm -f $(bindir)/blaze
	@echo "Removing man pages..."
	-rm -f $(man1dir)/blaze-add.1
	-rm -f $(man1dir)/blaze-log.1
	-rm -f $(man1dir)/blaze-edit.1
	-rm -f $(man1dir)/blaze-init.1
	-rm -f $(man1dir)/blaze-list.1
	-rm -f $(man1dir)/blaze-make.1
	-rm -f $(man1dir)/blaze-config.1
	-rm -f $(man1dir)/blaze-remove.1
	-rm -f $(man7dir)/blazeintro.7
	-rm -f $(man7dir)/blazetheme.7
	-rm -f $(man7dir)/blazeblogger.7
	@echo "Removing language files..."
	-rm -f $(langdir)/cs_CZ
	-rm -f $(langdir)/de_DE
	-rm -f $(langdir)/en_GB
	-rm -f $(langdir)/en_US
	-rm -f $(langdir)/es_ES
	-rm -f $(langdir)/eu_ES
	-rm -f $(langdir)/fr_FR
	-rm -f $(langdir)/ja_JP
	-rm -f $(langdir)/pt_BR
	-rm -f $(langdir)/ru_RU
	-rm -f $(langdir)/uk_UK
	@echo "Removing empty directories..."
	-rmdir $(bindir) $(man1dir) $(man7dir) $(mandir) $(langdir) \
               $(datadir)

%.1: %.pl
	$(POD2MAN) --section=1 --release="Version $(VERSION)" $^ $@

%.7: %.pod
	$(POD2MAN) --section=7 --release="Version $(VERSION)" $^ $@

