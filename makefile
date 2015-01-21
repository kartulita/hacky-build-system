SHELL = bash
.SHELLFLAGS = -euo pipefail -c

export srcdir := src
export outdir := out
export mindir := $(outdir)/min
export testdir := $(outdir)/tests
export docdir := $(outdir)/doc

cleandirs := $(outdir)

distcleanpredicate := -type 'd' -and \( -name 'bower_components' -or -name 'node_modules' \) -prune

pwd := $(shell pwd)

modulejs = $(wildcard $(srcdir)/*/module.js)
all_modules = $(modulejs:$(srcdir)/%/module.js=%)
ifeq "$(select)" ""
modules := $(all_modules)
else
modules := $(select)
endif

ifneq ($(filter fields,$(modules)),)
modules += dsl directive-proxy transformations validators
endif

ifneq ($(filter schedule,$(modules)),)
modules += timeline show-viewer
endif

jsdoc := $(docdir)/index.html

export npm := npm
export jsdoc_template := node_modules/angular-jsdoc/template
PATH := $(pwd)/build:$(pwd)/node_modules/.bin:$(PATH)

export annotate := ng-annotate --add --single_quotes -
export bower := bower --allow-root
export uglifyjs := uglifyjs -c -m -
export uglifycss := uglifycss
export lessc := lessc -
export jsdoc := jsdoc

export rmrf := rm -rf --
export rmf := rm -f --
export mkdirp := mkdir -p --
export rmdir := rmdir --ignore-fail-on-non-empty --

.PHONY: default all docs stats

.SECONDARY:

default: all

deps: | node_modules bower_components

node_modules:
	$(npm) install

bower_components: node_modules
	$(bower) install

stats: $(mindir)/bundle.js
	stats.sh | less -r

syntax: node_modules
	syntax.sh

all: $(mindir)/bundle.js $(mindir)/bundle.css $(outdir)/bundle.less $(modules:%=minify-module-%)
	@true

clean:
	$(rmrf) $(cleandirs)

docs:
	$(jsdoc) $(srcdir) -d $(docdir) -c build/jsdoc.json -t $(jsdoc_template)

minify-module-%: $(mindir)/%.js $(mindir)/%.css $(outdir)/%.less | node_modules/ng-annotate
	@true

build-module-%: $(wildcard $(srcdir)/%/*) | $(outdir) node_modules
	build-module.pl $(@:build-module-%=%) $(srcdir) $(outdir)

$(outdir):
	$(mkdirp) $(outdir)

$(mindir):
	$(mkdirp) $(mindir)

$(docdir):
	$(mkdirp) $(docdir)

$(testdir):
	$(mkdirp) $(testdir)

$(outdir)/bundle.js: $(modules:%=$(outdir)/%.js)
	cat -- $^ > $@

$(outdir)/bundle.css: $(modules:%=$(outdir)/%.css)
	cat -- $^ > $@

$(outdir)/bundle.less: $(modules:%=$(outdir)/%.less)
	cat -- $^ > $@

$(mindir)/%.js: $(outdir)/%.js | node_modules $(mindir)
	$(uglifyjs) < $< > $@ || ($(rmf) $@; false)

$(mindir)/%.css: $(outdir)/%.css | node_modules $(mindir)
	$(uglifycss) < $< > $@ || ($(rmf) $@; false)

$(outdir)/%.js: build-module-%
	@true

$(outdir)/%.css: $(outdir)/%.less build-module-%
	$(lessc) < $< >> $@

$(outdir)/%.less: build-module-%
	@true
