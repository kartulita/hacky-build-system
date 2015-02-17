# Subshell configuration
SHELL = bash
.SHELLFLAGS = -euo pipefail -c

# Directories
export srcdir := src
export outdir := out
export mindir := $(outdir)/min
export testdir := $(outdir)/tests
export docdir := $(outdir)/doc

# Directories to delete on clean
cleandirs := $(outdir)

# Transient folders (not included in dependency checking, deleted on distclean)
transientpredicate := -name 'bower_components' -or -name 'node_modules'

# Predicate for total cleaning
distcleanpredicate := -type 'd' -and \( $(transientpredicate) \) -prune

# Get makefile directory
pwd := $(shell pwd)

# Get list of modules to build
modulejs = $(wildcard $(srcdir)/*/module.js)
all_modules = $(modulejs:$(srcdir)/%/module.js=%)
ifeq "$(select)" ""
modules := $(all_modules)
else
comma := ,
modules := $(subst $(comma), ,$(select))
endif

# Dependency resolution
ifneq ($(filter $(modules),err),)
modules := schedule $(modules)
endif

ifneq ($(filter $(modules),fields),)
modules := dsl directive-proxy transformations validators $(modules)
endif

ifneq ($(filter $(modules),schedule),)
modules := timeline show-viewer $(modules)
endif

ifneq ($(filter $(modules),show-viewer),)
modules := language $(modules)
endif

ifneq ($(filter $(modules),timeline),)
modules := language date-picker $(modules)
endif

export modules
moduletargets := $(modules:%=minify-module-%)

jsdoc := $(docdir)/index.html

# Build-system dependencies
export npm := npm
export jsdoc_template := node_modules/angular-jsdoc/template
PATH := $(pwd)/build:$(pwd)/node_modules/.bin:$(PATH)

export annotate := ng-annotate --add --single_quotes -
export bower := bower --allow-root
export uglifyjs := uglifyjs -c -m -
export uglifycss := uglifycss
export lessc := lessc -
export jsdoc := jsdoc

# Command alisaes
export rmrf := rm -rf --
export rmf := rm -f --
export mkdirp := mkdir -p --
export rmdir := rmdir --ignore-fail-on-non-empty --

.PHONY: default all docs stats release debug

.SECONDARY:

.SECONDEXPANSION:

default: all

deps: | node_modules bower_components
	@perl -e 'use IPC::Pipeline' || cpan install IPC::Pipeline
	@perl -e 'use IPC::Open2' || cpan install IPC::Open2

node_modules:
	$(npm) install

bower_components: node_modules
	$(bower) install

stats: $(mindir)/bundle.js $(moduletargets)
	stats.sh | less -r

syntax: node_modules
	syntax.sh

all: $(mindir)/bundle.js $(mindir)/bundle.css $(outdir)/bundle.less $(moduletargets)
	@true

release: all
	@true

debug: $(outdir)/bundle.js $(outdir)/bundle.css $(outdir)/bundle.less

clean:
	$(rmrf) $(cleandirs)

docs:
	$(jsdoc) $(srcdir) -d $(docdir) -c build/jsdoc.json -t $(jsdoc_template)

minify-module-%: $(mindir)/%.js $(mindir)/%.css $(outdir)/%.less | node_modules/ng-annotate
	@true

build-module-%: $$(shell find $(srcdir)/% '(' $(transientpredicate) ')' -prune -o '(' -name '*.js' -or -name '*.html' ')' ) | $(outdir) node_modules
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

-include makefile.local
