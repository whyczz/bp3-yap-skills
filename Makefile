HARNESS ?= pi

.PHONY: build check test fmt hooks install install-skills

build:
	dune build

check: build
	dune build @render
	dune test

test:
	dune test

fmt:
	dune fmt

hooks:
	./scripts/install-hooks.sh

install:
	dune install

install-skills: build
	dune exec yap -- install --root . --harness $(HARNESS) -g
