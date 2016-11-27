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

clean:
	rm -rf sources

.PHONY: sources sources-download clean
