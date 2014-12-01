SRCDIR=src
OUTDIR=out
JSDIR=$(OUTDIR)
DOCDIR=$(OUTDIR)/doc
JSDOCDIR=$(DOCDIR)/jsdoc
DOCSRCDIR=$(SRCDIR)/$(DOCDIR)

CLEANDIRS=$(OUTDIR)

TITLE=Wheatley

PWD=$(shell pwd)

DOCS=$(patsubst $(SRCDIR)/%.md, %.html, $(wildcard $(DOCSRCDIR)/*.md))

MODULEHEADERS=$(shell find $(SRCDIR)/ -maxdepth 2 -type f -name 'module.js')

MODULES=$(patsubst $(SRCDIR)/%/module.js, $(JSDIR)/%.js, $(MODULEHEADERS))
MODULES_MIN=$(MODULES:%.js=%.min.js)

JSDOC=$(JSDOCDIR)/index.html

export SOURCEPREDICATES=-name '*.js' -and -not -path '*/demos/*' -and -not -path '*/tests/*' -and -not -path '*/.*'
SOURCES=$(shell find $(patsubst %/module.js, %/, $(MODULEHEADERS)) $(SOURCEPREDICATES))

BUNDLE=$(JSDIR)/bundle.js
BUNDLE_MIN=$(BUNDLE:%.js=%.min.js)

export NPM=npm
export NODE_MODULES=node_modules
export NPM_NGDOC_DIR=$(NODE_MODULES)/angular-jsdoc
export NODE_BIN=$(NODE_MODULES)/.bin
PATH := $(PWD)/build:$(PWD)/$(NODE_BIN):$(PATH)
export NPM_JSDOC=jsdoc
export NGANNOTATE=ng-annotate --add --single_quotes -
export NPM_HTTP=http-server

export BOWER=bower --allow-root
export BOWER_COMPONENTS=bower_components

export UGLIFY=uglifyjs -c -m - 

TAGS=sources modules bundle

export RMRF=rm -rf --
export RMF=rm -f --
export MKDIRP=mkdir -p --
export RMDIR=rmdir --ignore-fail-on-non-empty --

SHELL=bash
.SHELLFLAGS=-euo pipefail -c

.PHONY: \
	all deps bundle modules docs clean \
	serve syntax syntax-loop test test-loop \
	stats

.SECONDEXPANSION:

all: bundle modules docs
	@true

bundle: $(BUNDLE_MIN)
	@true

modules: $(MODULES_MIN)
	@true

docs: $(JSDOC)
	@true

deps: | $(NODE_MODULES) $(BOWER_COMPONENTS)

syntax:
	@syntax.sh $(SOURCES)

test:
	@test.sh

syntax-loop:
	@clear
	@if make -s syntax; then exec make -s syntax-loop; fi
	@clear

test-loop:
	@clear
	@if make -s test; then exec make -s test-loop; fi
	@clear

clean:
	$(RMRF) $(CLEANDIRS) || true

distclean: clean
	$(RMRF) $(NODE_MODULES) $(BOWER_COMPONENTS) || true

serve:
	http-server ./ -p 8000 -s -i0 >/dev/null 2>&1

stats: all
	stats.sh | less -r
	
$(NODE_MODULES):
	$(NPM) install

$(BOWER_COMPONENTS):
	$(BOWER) install

$(JSDIR):
	$(MKDIRP) $(JSDIR)

$(DOCDIR):
	$(MKDIRP) $(DOCDIR)

$(JSDOCDIR):
	$(MKDIRP) $(JSDOCDIR)

%.min.js: %.js
	$(UGLIFY) < $^ > $@ || ($(RMF) $@; false)

$(BUNDLE): $(MODULES) | deps $(JSDIR)
	concatenate.pl $^ > $@

$(JSDIR)/%.js: $$(shell find $(SRCDIR)/%/ $(SOURCEPREDICATES)) | deps $(JSDIR)
	concatenate.pl $^ | $(NGANNOTATE) > $@
	
$(JSDOC): $(SOURCES) | $(JSDOCDIR)
	$(NPM_JSDOC) -r $(SRCDIR) -d $(JSDOCDIR) -c $(NPM_NGDOC_DIR)/conf.json -t $(NPM_NGDOC_DIR)/template

diag:
	@echo "Modules: "
	@printf -- " * %s\n" $(MODULES)
	@echo
	@echo "Sources: "
	@printf -- " * %s\n" $(SOURCES)
	@echo
