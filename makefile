SRCDIR=src
OUTDIR=out
JSDIR=$(OUTDIR)
TAGDIR=$(OUTDIR)/tags
DOCDIR=$(OUTDIR)/doc
JSDOCDIR=$(DOCDIR)/jsdoc
DOCSRCDIR=$(SRCDIR)/$(DOCDIR)

CLEANDIRS=$(OUTDIR)

TITLE=Wheatley

PWD=$(shell pwd)

DOCS=$(patsubst $(SRCDIR)/%.md, %.html, $(wildcard $(DOCSRCDIR)/*.md))

MODULEHEADERS=$(shell find $(SRCDIR)/ -maxdepth 2 -type f -name 'module.js')

MODULES=$(patsubst $(SRCDIR)/%/module.js, $(JSDIR)/%.js, $(MODULEHEADERS))

JSDOC=$(JSDOCDIR)/index.html

SOURCEPREDICATES=-name '*.js' -and -not -path '*/demos/*' -and -not -path '*/tests/*' -and -not -path '*/.*'
SOURCES=$(shell find $(patsubst %/module.js, %/, $(MODULEHEADERS)) $(SOURCEPREDICATES))

BUNDLE=$(JSDIR)/bundle.js

export NPM=npm
export NODE_MODULES=node_modules
export NPM_NGDOC_DIR=$(NODE_MODULES)/angular-jsdoc
export NODE_BIN=$(NODE_MODULES)/.bin
PATH := $(PWD)/$(NODE_BIN):$(PATH)
export NPM_JSDOC=jsdoc
export NGANNOTATE=ng-annotate --add --single_quotes -
export NPM_HTTP=http-server

export BOWER=bower --allow-root
export BOWER_COMPONENTS=bower_components

ifdef TEST
export UGLIFY=uglifyjs -b -
else
export UGLIFY=uglifyjs -c -m -
endif

TAGS=sources modules bundle

export RMRF=rm -rf --
export RMF=rm -f --
export MKDIRP=mkdir -p --
export RMDIR=rmdir --ignore-fail-on-non-empty --

SHELL=bash
.SHELLFLAGS=-euo pipefail -c

.PHONY: \
	all deps bundle modules docs tags clean \
	serve syntax syntax-loop test test-loop \
	stats

.SECONDEXPANSION:

all: bundle modules docs tags
	@true

bundle: $(BUNDLE)
	@true

modules: $(MODULES)
	@true

docs: $(JSDOC)
	@true

tags: $(patsubst %,$(TAGDIR)/%,sources.html modules.html bundle.html)
	@true

deps: | $(NODE_MODULES) $(BOWER_COMPONENTS)

syntax:
	@build/syntax.sh $(SOURCES)

syntax-loop:
	@build/syntax.sh --loop $(SOURCES) || true

test:
	@build/test.sh

test-loop:
	@build/test.sh --loop || true

clean:
	$(RMRF) $(CLEANDIRS) || true

distclean: clean
	$(RMRF) $(NODE_MODULES) $(BOWER_COMPONENTS) || true

serve:
	http-server ./ -p 8000 -s -i0 >/dev/null 2>&1

stats:
	build/stats.sh | less -r
	
$(NODE_MODULES):
	$(NPM) install

$(BOWER_COMPONENTS):
	$(BOWER) install

$(JSDIR):
	$(MKDIRP) $(JSDIR)

$(TAGDIR):
	$(MKDIRP) $(TAGDIR)

$(DOCDIR):
	$(MKDIRP) $(DOCDIR)

$(JSDOCDIR):
	$(MKDIRP) $(JSDOCDIR)

$(TAGDIR)/sources.html: | $(TAGDIR)
	build/html-tags.pl >$(TAGDIR)/sources.html $(SOURCES:$(SRCDIR)/%=$(PREFIX)%)

$(TAGDIR)/modules.html: | $(TAGDIR)
	build/html-tags.pl >$(TAGDIR)/modules.html $(MODULES:$(JSDIR)/%=$(PREFIX)%)

$(TAGDIR)/bundle.html: | $(TAGDIR)
	build/html-tags.pl >$(TAGDIR)/bundle.html $(BUNDLE:$(JSDIR)/%=$(PREFIX)%)

$(BUNDLE): $(MODULES) | deps $(JSDIR)
	build/concatenate.pl $^ | $(UGLIFY) > $@ || ($(RMF) $@; false)

$(JSDIR)/%.js: $$(shell find $(SRCDIR)/%/ $(SOURCEPREDICATES)) | deps $(JSDIR)
	build/concatenate.pl $^ | $(NGANNOTATE) | $(UGLIFY) > $@ || ($(RMF) $@; false)

$(JSDOC): $(SOURCES) | $(JSDOCDIR)
	$(NPM_JSDOC) -r $(SRCDIR) -d $(JSDOCDIR) -c $(NPM_NGDOC_DIR)/conf.json -t $(NPM_NGDOC_DIR)/template

diag:
	@echo "Modules: "
	@printf -- " * %s\n" $(MODULES)
	@echo
	@echo "Sources: "
	@printf -- " * %s\n" $(SOURCES)
	@echo
