
# https://www.client9.com/self-documenting-makefiles/
help:
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
	printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.DEFAULT_GOAL=help
.PHONY: help

shfmt:  ## reformat shell scripts
	shfmt -p -i 0 -ci -w *.sh
.PHONY: shfmt

SHELLCHECK := shellcheck --external-sources --shell=dash
shellcheck:  ## run shellcheck on shell scripts
	$(SHELLCHECK) wg-auto.sh
	$(SHELLCHECK) wg-vpc.sh
.PHONY: shellcheck

clean:  ## clean up
	rm -rf ./bin
	git gc --aggressive
.PHONY: clean
