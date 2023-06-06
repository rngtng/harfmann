PROJECT     ?= $(shell basename $(shell pwd))
BUILD_TAG   ?= dev
REGISTRY_TAG = $(PROJECT):$(BUILD_TAG)

include .env

URL = https://confluence.solarisbank.de
# https://confluence.solarisbank.de/display/ADAC/Schemas
PAGE_ID  = 248760353

export PARTNER

help:
	@grep '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/\1 $(shell echo "\t") \2/' | sort | expand -t20

table.html:
	curl -s -H "Authorization: Bearer ${TOKEN}" ${URL}/rest/api/content/${PAGE_ID}?expand=body.storage | jq -r '.body.storage.value' > table.html

.PHONY: extract # Extract the latest schema
extract: clean table.html
	ruby extract.rb

.PHONY: clean # Delete any generated files
clean:
	rm -f table.html

inspect: build
	docker run --rm -it -v "$(realpath ../../docs):/docs" $(REGISTRY_TAG) \
		ruby inspect.rb /docs/bundle-onboarding.json

build:
	docker build -t $(REGISTRY_TAG) .

dev:
	docker run --rm -it \
  -v "$(shell pwd)/src:/app" \
	-v "$(shell pwd)/output:/output" \
	--entrypoint bash $(REGISTRY_TAG)
