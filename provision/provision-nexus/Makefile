all: binaries sources

sources: sources-download
	mkdir -p sources
	cd sources && \
		find ~/.m2/repository/org/sonatype/nexus \
			-name '*-sources.jar' \
			-exec bash -c 'mkdir -p "$$(basename {})"' \; \
			-exec bash -c '7z -y "-o$$(basename {})" x {}' \;
	#find sources -type f -name '*.groovy'
	#grep -r 'NuGet API-Key Realm' sources

sources-download:
	mvn dependency:sources

binaries: binaries-download

binaries-download:
	mkdir -p binaries
	wget -qO- https://download.sonatype.com/nexus/3/nexus-3.82.0-08-unix.tar.gz \
		| tar xzf - --strip-components 1 -C binaries

clean:
	rm -rf sources binaries

.PHONY: sources sources-download binaries-download clean
