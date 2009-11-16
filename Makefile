# makefile for BlazeBlogger, a CMS without boundaries
# Copyright (C) 2009 Jaromir Hradilek

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
SRCS   := src/blaze-add.pl src/blaze-config.pl src/blaze-edit.pl \
          src/blaze-init.pl src/blaze-list.pl src/blaze-log.pl \
          src/blaze-make.pl src/blaze-remove.pl
DOCS   := pod/blaze-submit.pod pod/blazeblogger.pod pod/blazeintro.pod \
          pod/blazetheme.pod
MAN1   := src/blaze-add.1 src/blaze-config.1 src/blaze-edit.1 \
          src/blaze-init.1 src/blaze-list.1 src/blaze-log.1 \
          src/blaze-make.1 src/blaze-remove.1 pod/blaze-submit.1
MAN7   := pod/blazeblogger.7 pod/blazeintro.7 pod/blazetheme.7

# Installation directories; feel free to modify according to your taste and
# current situation:
prefix  = /usr/local
bindir  = $(prefix)/bin
mandir  = $(prefix)/share/man
man1dir = $(mandir)/man1
man7dir = $(mandir)/man7

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
	$(INSTALL) -m 755 utils/blaze.sh $(bindir)/blaze
	$(INSTALL) -m 755 utils/blaze-submit.sh $(bindir)/blaze-submit
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
	$(INSTALL) -m 644 pod/blaze-submit.1 $(man1dir)
	$(INSTALL) -d $(man7dir)
	$(INSTALL) -m 644 pod/blazeintro.7 $(man7dir)
	$(INSTALL) -m 644 pod/blazetheme.7 $(man7dir)
	$(INSTALL) -m 644 pod/blazeblogger.7 $(man7dir)

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
	-rm -f $(bindir)/blaze-submit
	@echo "Removing man pages..."
	-rm -f $(man1dir)/blaze-add.1
	-rm -f $(man1dir)/blaze-log.1
	-rm -f $(man1dir)/blaze-edit.1
	-rm -f $(man1dir)/blaze-init.1
	-rm -f $(man1dir)/blaze-list.1
	-rm -f $(man1dir)/blaze-make.1
	-rm -f $(man1dir)/blaze-config.1
	-rm -f $(man1dir)/blaze-remove.1
	-rm -f $(man1dir)/blaze-submit.1
	-rm -f $(man7dir)/blazeintro.7
	-rm -f $(man7dir)/blazetheme.7
	-rm -f $(man7dir)/blazeblogger.7
	@echo "Removing empty directories..."
	-rmdir $(bindir) $(man1dir) $(man7dir) $(mandir)

%.1: %.pl
	$(POD2MAN) --section=1 --release="Version $(VERSION)" $^ $@

%.1: %.pod
	$(POD2MAN) --section=1 --release="Version $(VERSION)" $^ $@

%.7: %.pod
	$(POD2MAN) --section=7 --release="Version $(VERSION)" $^ $@

