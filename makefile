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
