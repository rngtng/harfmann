PROJECT     ?= $(shell basename $(shell pwd))
BUILD_TAG   ?= dev
REGISTRY_TAG = $(PROJECT):$(BUILD_TAG)

help:
	@grep '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/\1 $(shell echo "\t") \2/' | sort | expand -t20

build:
	docker build -t $(REGISTRY_TAG) .

run:
	docker run --rm -it \
	-v "$(shell pwd)/output:/output" \
	$(REGISTRY_TAG)

dev:
	docker run --rm -it \
  -v "$(shell pwd)/src:/app" \
	-v "$(shell pwd)/output:/output" \
	--entrypoint bash \
	$(REGISTRY_TAG)
