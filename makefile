install:
	cp u2b $(DESTDIR)/usr/bin/
	[ -d $(DESTDIR)/usr/lib/perl5/WWW ] || mkdir -p $(DESTDIR)/usr/lib/perl5/WWW
	cp U2B.pm $(DESTDIR)/usr/lib/perl5/WWW
uninstall:
	rm $(DESTDIR)/usr/bin/u2b
	rm $(DESTDIR)/usr/lib/perl5/WWW/U2B.pm
