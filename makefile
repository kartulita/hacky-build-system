export SRCDIR=src
export OUTDIR=out
export JSDIR=$(OUTDIR)
export DOCDIR=$(OUTDIR)/doc
export JSDOCDIR=$(DOCDIR)/jsdoc
export DOCSRCDIR=$(SRCDIR)/$(DOCDIR)
export TESTDIR=$(OUTDIR)/tests

CLEANDIRS=$(OUTDIR)
DISTCLEANPREDICATE=-type 'd' -and \( -name 'bower_components' -or -name 'node_modules' \) -prune

export TITLE=Wheatley

PWD=$(shell pwd)

DOCS=$(patsubst $(SRCDIR)/%.md, %.html, $(wildcard $(DOCSRCDIR)/*.md))

MODULEHEADERS=$(shell find $(SRCDIR)/ -maxdepth 2 -type f -name 'module.js')

MODULES=$(patsubst $(SRCDIR)/%/module.js, $(JSDIR)/%.js, $(MODULEHEADERS))
MODULES_MIN=$(MODULES:%.js=%.min.js)

JSDOC=$(JSDOCDIR)/index.html

export SOURCEPREDICATES=-type 'f' -name '*.js' -not -path '*/demos/*' -not -path '*/tests/*' -not -path '*/.*' -not -path '*/node_modules/*' -not -path '*/bower_components/*'
SOURCES=$(shell find $(patsubst %/module.js, %/, $(MODULEHEADERS)) $(SOURCEPREDICATES))

BUNDLE=$(JSDIR)/bundle.js
BUNDLE_MIN=$(BUNDLE:%.js=%.min.js)

export STYLEPREDICATES=-type 'f' -name '*.css' -not -path '*/demos/*' -not -path '*/tests/*' -not -path '*/.*' -not -path '*/node_modules/*' -not -path '*/bower_components/*'
STYLES=$(shell find $(patsubst %/module.js, %/, $(MODULEHEADERS)) $(STYLEPREDICATES))

CSSBUNDLE=$(OUTDIR)/bundle.min.css

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

export UGLIFYCSS=uglifycss

TAGS=sources modules bundle

export RMRF=rm -rf --
export RMF=rm -f --
export MKDIRP=mkdir -p --
export RMDIR=rmdir --ignore-fail-on-non-empty --

SHELL=bash
.SHELLFLAGS=-euo pipefail -c

.PHONY: all deps bundle modules docs clean serve syntax test stats styles

.SECONDEXPANSION:

all: bundle modules docs styles
	@true

bundle: $(BUNDLE_MIN)
	@true

modules: $(MODULES_MIN)
	@true

docs: $(JSDOC)
	@true

deps: | $(NODE_MODULES) $(BOWER_COMPONENTS)

syntax:
	@syntax.sh

test:
	@test.sh

clean:
	$(RMRF) $(CLEANDIRS) || true

distclean: clean
	find . $(DISTCLEANPREDICATE) -exec $(RMRF) {} \; || true

serve:
	http-server ./ -p 8000 -s -i0 >/dev/null 2>&1

stats: all
	stats.sh | less -r

styles: $(CSSBUNDLE)
	@true

$(NODE_MODULES):
	$(NPM) install

$(NODE_MODULES)/%:
	$(NPM) install $(@:$(NODE_MODULES)/%=%)

$(BOWER_COMPONENTS): $(NODE_MODULES)/bower
	$(BOWER) install

$(OUTDIR):
	$(MKDIRP) $(OUTDIR)

$(DOCDIR):
	$(MKDIRP) $(DOCDIR)

$(JSDOCDIR):
	$(MKDIRP) $(JSDOCDIR)

%.min.js: %.js | deps
	$(UGLIFY) < $^ > $@ || ($(RMF) $@; false)

$(BUNDLE): $(MODULES) | deps $(JSDIR)
	concatenate.pl $^ > $@

$(JSDIR)/%.js: $$(shell find $(SRCDIR)/%/ $(SOURCEPREDICATES)) | deps $(JSDIR)
	concatenate.pl $^ | $(NGANNOTATE) > $@
	
$(JSDOC): $(SOURCES) | deps $(JSDOCDIR)
	$(NPM_JSDOC) -r $(SRCDIR) -d $(JSDOCDIR) -c $(NPM_NGDOC_DIR)/conf.json -t $(NPM_NGDOC_DIR)/template

$(CSSBUNDLE): $(STYLES) | $(OUTDIR)
	$(UGLIFYCSS) $^ > $@
	
diag:
	@echo "Modules: "
	@printf -- " * %s\n" $(MODULES)
	@echo
	@echo "Sources: "
	@printf -- " * %s\n" $(SOURCES)
	@echo
	@echo "Styles: "
	@printf -- " * %s\n" $(STYLES)
	@echo
