start: data/exit-policies data/langs i18n
	@./check

rsync_server = metrics.torproject.org
consensuses_dir = metrics-recent/relay-descriptors/consensuses/
exit_lists_dir = metrics-recent/exit-lists/
descriptors_dir = metrics-recent/relay-descriptors/server-descriptors/

data/:
	@mkdir -p data

data/descriptors/: data/
	@mkdir -p data/descriptors

data/consensuses/: data/
	@mkdir -p data/consensuses

data/exit-lists/: data/
	@mkdir -p data/exit-lists

data/consensus: data/consensuses/
	@echo Getting latest consensus documents
	@rsync -avz $(rsync_server)::$(consensuses_dir) --delete ./data/consensuses/
	@echo Consensuses written

data/exit-addresses: data/exit-lists/
	@echo Getting latest exit lists
	@rsync -avz $(rsync_server)::$(exit_lists_dir) --delete ./data/exit-lists/
	@echo Exit lists written

data/exit-policies: data/consensus data/exit-addresses data/cached-descriptors
	@echo Generating exit-policies file
	@python scripts/exitips.py
	@echo Done

data/cached-descriptors: descriptors
	@echo "Concatenating data/descriptors/* into data/cached-descriptors"
	@rm -f data/cached-descriptors
	@touch data/cached-descriptors
	@for f in 0 1 2 3 4 5 6 7 8 9 a b c d e f; \
	do \
		cat  data/descriptors/$$f* >> data/cached-descriptors; \
	done
	@echo "Done"

descriptors: data/descriptors/
	@echo "Getting latest descriptors (This may take a while)"
	@rsync -avz $(rsync_server)::$(descriptors_dir) --delete ./data/descriptors/
	@echo Done

data/langs: data/
	curl -k https://www.transifex.com/api/2/languages/ > data/langs

build:
	go fmt
	go build

# Add -i for installing latest version, -v for verbose
test: build
	go test -v -run "$(filter)"

cover: build
	go test -coverprofile cover.out

filter?=.
bench: build
	go test -i
	go test -benchtime 10s -bench "$(filter)" -benchmem

profile: build
	go test -cpuprofile ../../cpu.prof -memprofile ../../mem.prof -benchtime 40s -bench "$(filter)"

i18n: locale/

locale/:
	rm -rf locale
	git clone -b torcheck_completed https://git.torproject.org/translation.git locale
	pushd locale; \
	for f in *; do \
		if [ "$$f" != "templates" ]; then \
			pushd "$$f"; \
			mkdir LC_MESSAGES; \
			msgfmt -o LC_MESSAGES/check.mo torcheck.po; \
			popd; \
		fi \
	done

.PHONY: start build i18n test bench cover profile descriptors