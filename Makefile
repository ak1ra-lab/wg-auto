
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

shellcheck:  ## run shellcheck on shell scripts
	@echo "shellcheck on wg-auto.sh"
	@cat wg-auto.env.sh wg-auto.sh | shellcheck --shell=dash -
	@echo "shellcheck on wg-vpc.sh"
	@cat wg-vpc.env.sh wg-vpc.sh | shellcheck --shell=dash -
.PHONY: shellcheck

clean:  ## clean up
	rm -rf ./bin
	git gc --aggressive
.PHONY: clean
