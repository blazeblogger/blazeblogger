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

# General information:
NAME    = blazeblogger
VERSION = 1.1.2

# General settings:
SHELL   = /bin/sh
INSTALL = /usr/bin/install -c
POD2MAN = /usr/bin/pod2man
MAN1    = src/blaze-add.1 src/blaze-config.1 src/blaze-edit.1 \
          src/blaze-init.1 src/blaze-list.1 src/blaze-log.1 \
          src/blaze-make.1 src/blaze-remove.1
SRCS    = src/blaze-add.pl src/blaze-config.pl src/blaze-edit.pl \
          src/blaze-init.pl src/blaze-list.pl src/blaze-log.pl \
          src/blaze-make.pl src/blaze-remove.pl

# Installation directories:
config  = /etc
prefix  = /usr/local
bindir  = $(prefix)/bin
datadir = $(prefix)/share/$(NAME)
docsdir = $(prefix)/share/doc/$(NAME)-$(VERSION)
man1dir = $(prefix)/share/man/man1
compdir = $(config)/bash_completion.d

# Make rules;  please do not edit these unless you really know what you are
# doing:
.PHONY: all install_bin install_conf install_data install_docs \
        install_man install uninstall clean

all: $(MAN1)

install_bin:
	@echo "Copying executables..."
	$(INSTALL) -d $(bindir)
	$(INSTALL) -m 755 src/blaze-add.pl $(bindir)/blaze-add
	$(INSTALL) -m 755 src/blaze-log.pl $(bindir)/blaze-log
	$(INSTALL) -m 755 src/blaze-edit.pl $(bindir)/blaze-edit
	$(INSTALL) -m 755 src/blaze-init.pl $(bindir)/blaze-init
	$(INSTALL) -m 755 src/blaze-list.pl $(bindir)/blaze-list
	$(INSTALL) -m 755 src/blaze-make.pl $(bindir)/blaze-make
	$(INSTALL) -m 755 src/blaze-config.pl $(bindir)/blaze-config
	$(INSTALL) -m 755 src/blaze-remove.pl $(bindir)/blaze-remove
	$(INSTALL) -m 755 unix/blaze.sh $(bindir)/blaze

install_conf:
	@echo "Copying bash completion..."
	$(INSTALL) -d $(compdir)
	$(INSTALL) -m 644 unix/bash_completion $(compdir)/blazeblogger

install_data:
	@echo "Copying translations..."
	$(INSTALL) -d $(datadir)/lang
	$(INSTALL) -m 644 lang/cs_CZ $(datadir)/lang
	$(INSTALL) -m 644 lang/de_DE $(datadir)/lang
	$(INSTALL) -m 644 lang/en_GB $(datadir)/lang
	$(INSTALL) -m 644 lang/en_US $(datadir)/lang
	$(INSTALL) -m 644 lang/es_ES $(datadir)/lang
	$(INSTALL) -m 644 lang/eu_ES $(datadir)/lang
	$(INSTALL) -m 644 lang/fr_FR $(datadir)/lang
	$(INSTALL) -m 644 lang/ja_JP $(datadir)/lang
	$(INSTALL) -m 644 lang/pt_BR $(datadir)/lang
	$(INSTALL) -m 644 lang/ru_RU $(datadir)/lang
	$(INSTALL) -m 644 lang/uk_UK $(datadir)/lang

install_docs:
	@echo "Copying documentation..."
	$(INSTALL) -d $(docsdir)
	$(INSTALL) -m 644 FDL $(docsdir)
	$(INSTALL) -m 644 TODO $(docsdir)
	$(INSTALL) -m 644 README $(docsdir)
	$(INSTALL) -m 644 AUTHORS $(docsdir)
	$(INSTALL) -m 644 COPYING $(docsdir)
	$(INSTALL) -m 644 INSTALL $(docsdir)
	-$(INSTALL) -m 644 ChangeLog $(docsdir)

install_man: $(MAN1)
	@echo "Copying manual pages..."
	$(INSTALL) -d $(man1dir)
	$(INSTALL) -m 644 src/blaze-add.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-log.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-edit.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-init.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-list.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-make.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-config.1 $(man1dir)
	$(INSTALL) -m 644 src/blaze-remove.1 $(man1dir)
	$(INSTALL) -m 644 unix/man/man1/blaze.1 $(man1dir)

install: install_bin install_conf install_data install_docs install_man

uninstall:
	@echo "Removing executables..."
	-rm -f $(bindir)/blaze-add
	-rm -f $(bindir)/blaze-log
	-rm -f $(bindir)/blaze-edit
	-rm -f $(bindir)/blaze-init
	-rm -f $(bindir)/blaze-list
	-rm -f $(bindir)/blaze-make
	-rm -f $(bindir)/blaze-config
	-rm -f $(bindir)/blaze-remove
	-rm -f $(bindir)/blaze
	-rmdir $(bindir)
	@echo "Removing bash completion..."
	-rm -f $(compdir)/blazeblogger
	-rmdir $(compdir)
	@echo "Removing translations..."
	-rm -f $(datadir)/lang/cs_CZ
	-rm -f $(datadir)/lang/de_DE
	-rm -f $(datadir)/lang/en_GB
	-rm -f $(datadir)/lang/en_US
	-rm -f $(datadir)/lang/es_ES
	-rm -f $(datadir)/lang/eu_ES
	-rm -f $(datadir)/lang/fr_FR
	-rm -f $(datadir)/lang/ja_JP
	-rm -f $(datadir)/lang/pt_BR
	-rm -f $(datadir)/lang/ru_RU
	-rm -f $(datadir)/lang/uk_UK
	-rmdir $(datadir)/lang $(datadir)
	@echo "Removing documentation..."
	-rm -f $(docsdir)/FDL
	-rm -f $(docsdir)/TODO
	-rm -f $(docsdir)/README
	-rm -f $(docsdir)/AUTHORS
	-rm -f $(docsdir)/COPYING
	-rm -f $(docsdir)/INSTALL
	-rm -f $(docsdir)/ChangeLog
	-rmdir $(docsdir)
	@echo "Removing manual pages..."
	-rm -f $(man1dir)/blaze-add.1
	-rm -f $(man1dir)/blaze-log.1
	-rm -f $(man1dir)/blaze-edit.1
	-rm -f $(man1dir)/blaze-init.1
	-rm -f $(man1dir)/blaze-list.1
	-rm -f $(man1dir)/blaze-make.1
	-rm -f $(man1dir)/blaze-config.1
	-rm -f $(man1dir)/blaze-remove.1
	-rm -f $(man1dir)/blaze.1
	-rmdir $(man1dir)

clean:
	-rm -f $(MAN1)

%.1: %.pl
	$(POD2MAN) --section=1 --release="Version $(VERSION)" \
	                       --center="BlazeBlogger Documentation" $^ $@

