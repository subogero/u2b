define DESCR
Description: YouTube tool
 YouTube tool and Perl lib for search, stream extraction, download and playback
endef
export DESCR

SHELL := bash
REL := .release
all:
install: README.help
	# Copy u2b with help inserted
	perl -pe 'if (/^HELP/) { open R, "README.help"; print $$l while $$l=<R>; close R }' u2b >$(DESTDIR)/usr/bin/u2b
	chmod +x $(DESTDIR)/usr/bin/u2b
	# Copy the rest
	[ -d $(DESTDIR)/usr/lib/perl5/WWW ] || mkdir -p $(DESTDIR)/usr/lib/perl5/WWW
	cp U2B.pm $(DESTDIR)/usr/lib/perl5/WWW
	cp u2b.1 $(DESTDIR)/usr/share/man/man1/
uninstall:
	rm $(DESTDIR)/usr/bin/u2b
	rm $(DESTDIR)/usr/lib/perl5/WWW/U2B.pm
	rm $(DESTDIR)/usr/share/man/man1/u2b.1
u2b.1: README.man
	curl -F page=@README.man http://mantastic.herokuapp.com > u2b.1
.INTERMEDIATE: README.help README.man
README.help: README makefile
	sed -n '/USAGE/,/^\.$$/p' README | sed '/^.$$/d' >README.help
README.man: README makefile
	sed -n '1,/^\.$$/p' README | sed 's/\[\|\]/\\&/g' | tee README.man
# Release specific stuff
clean:
	-rm -rf jar .release
tarball: clean
	@echo TARBALL
	export TAG=`sed -rn 's/^u2b (.+)$$/\1/p' u2b`; \
	$(MAKE) balls
balls:
	@echo BALLS
	mkdir -p $(REL)/u2b-$(TAG); \
	cp -rt $(REL)/u2b-$(TAG) *; \
	cd $(REL); \
	tar -czf u2b_$(TAG).tar.gz u2b-$(TAG)
# Create a tagged commit for release
tag:
	@echo TAG
	@git status | grep -q 'nothing to commit' || ( echo Worktree dirty; exit 1 )
	@echo 'Chose old tag to follow: '; \
	select OLD in `git tag`; do break; done; \
	export TAG; \
	read -p 'Please Enter new tag name: ' TAG; \
	sed -r -e "s/^u2b.*$$/u2b $$TAG/" \
	       -e 's/([0-9]{4}-)[0-9]*/\1'`date +%Y`/ \
	       -i u2b || exit 1; \
	git commit -a -m "version $$TAG"; \
	echo Adding git tag $$TAG; \
	echo "u2b ($$TAG)" > changelog; \
	if [ -n "$$OLD" ]; then \
	  git log --pretty=format:"  * %h %an %s" $$OLD.. >> changelog; \
	  echo >> changelog; \
	else \
	  echo '  * Initial release' >> changelog; \
	fi; \
	echo " -- `git config user.name` <`git config user.email`>  `date -R`" >> changelog; \
	$$EDITOR changelog; \
	git tag -a -F changelog $$TAG HEAD; \
	rm changelog
utag:
	@echo UTAG
	TAG=`git log --oneline --decorate | head -n1 | sed -rn 's/^.+ version (.+)/\1/p'`; \
	[ "$$TAG" ] && git tag -d $$TAG && git reset --hard HEAD^
# Source and binary Debian packages
deb: tarball $(BIN)/$(TARGET)
	@echo DEB
	export TAG=`sed -rn 's/^u2b (.+)$$/\1/p' u2b`; \
	export DEB=$(REL)/u2b-$${TAG}/debian; \
	$(MAKE) debs
debs:
	@echo DEBS
	-rm $(REL)/*.deb
	cp -f $(REL)/u2b_$(TAG).tar.gz $(REL)/u2b_$(TAG).orig.tar.gz 
	mkdir -p $(DEB)
	echo 'Source: u2b'                                            >$(DEB)/control
	echo 'Section: web'                                          >>$(DEB)/control
	echo 'Priority: optional'                                    >>$(DEB)/control
	sed -nr 's/^C.+ [-0-9]+ (.+)$$/Maintainer: \1/p' u2b         >>$(DEB)/control
	echo 'Build-Depends: debhelper'                              >>$(DEB)/control
	echo 'Standards-version: 3.8.4'                              >>$(DEB)/control
	echo                                                         >>$(DEB)/control
	echo 'Package: u2b'                                          >>$(DEB)/control
	echo 'Architecture: all'                                     >>$(DEB)/control
	echo 'Depends: perl, curl, liburi-escape-perl,'              >>$(DEB)/control
	echo '  libjson-xs-perl, libyaml-perl'                       >>$(DEB)/control
	echo "$$DESCR"                                               >>$(DEB)/control
	grep Copyright u2b                               >$(DEB)/copyright
	echo 'License: LGPL 2.1'                        >>$(DEB)/copyright
	echo ' See /usr/share/common-licenses/LGPL-2.1' >>$(DEB)/copyright
	echo 7 > $(DEB)/compat
	for i in `git tag | sort -rg`; do git show $$i | sed -n '/^u2b/,/^ --/p'; done \
	| sed -r 's/^u2b \((.+)\)$$/u2b (\1-1) UNRELEASED; urgency=low/' \
	| sed -r 's/^(.{,79}).*/\1/' \
	> $(DEB)/changelog
	$(EDITOR) $(DEB)/changelog
	echo '#!/usr/bin/make -f' > $(DEB)/rules
	echo '%:'                >> $(DEB)/rules
	echo '	dh $$@'          >> $(DEB)/rules
	echo usr/bin             > $(DEB)/u2b.dirs
	echo usr/share/man/man1 >> $(DEB)/u2b.dirs
	echo usr/lib/perl5/lib  >> $(DEB)/u2b.dirs
	chmod 755 $(DEB)/rules
	mkdir -p $(DEB)/source
	echo '3.0 (quilt)' > $(DEB)/source/format
	@cd $(REL)/u2b-$(TAG) && \
	echo && echo List of PGP keys for signing package: && \
	gpg -K | grep uid && \
	read -ep 'Enter key ID (part of name or alias): ' KEYID; \
	if [ "$$KEYID" ]; then \
	  dpkg-buildpackage -k$$KEYID; \
	else \
	  dpkg-buildpackage -us -uc; \
	fi
	lintian $(REL)/*.deb
	fakeroot alien -kr $(REL)/*.deb; mv *.rpm $(REL)
# Release
release: tag deb
