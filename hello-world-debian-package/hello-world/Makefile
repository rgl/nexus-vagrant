prefix = /usr

all: hello-world

hello-world: main.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDCFLAGS) -o $@ $^

install: hello-world
	install -D hello-world $(DESTDIR)$(prefix)/bin/hello-world

clean:
	rm -f hello-world

distclean: clean

uninstall:
	rm -f $(DESTDIR)$(prefix)/bin/hello-world

.PHONY: all install clean distclean uninstall
