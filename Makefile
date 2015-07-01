PATH        := ./node_modules/.bin:${PATH}

NPM_PACKAGE := $(shell node -e 'console.log(require("./package.json").name)')
NPM_VERSION := $(shell node -e 'console.log(require("./package.json").version)')

TMP_PATH    := /tmp/${NPM_PACKAGE}-$(shell date +%s)

REMOTE_NAME ?= origin
REMOTE_REPO ?= $(shell git config --get remote.${REMOTE_NAME}.url)

CURR_HEAD   := $(firstword $(shell git show-ref --hash HEAD | cut -b -6) master)
GITHUB_PROJ := nodeca/${NPM_PACKAGE}


help:
	echo "make help          - Print this help"
	echo "make lint          - Lint sources with JSHint"
	echo "make test          - Lint sources and run all tests"
	echo "make test-slimerjs - Lint sources and run all tests in SlimerJS"
	echo "make doc           - Build API docs"
	echo "make gh-pages      - Build and push API docs into gh-pages branch"
	echo "make publish       - Set new version tag and publish npm package"


lint:
	eslint --reset .


test: lint
	@if test ! `which mocha` ; then \
		echo "You need 'mocha' installed in order to run tests." >&2 ; \
		echo "  $ npm install" >&2 ; \
		exit 128 ; \
		fi
	NODE_ENV=test mocha

test-slimerjs:
	ENGINE=slimerjs make test

doc:
	@if test ! `which ndoc` ; then \
		echo "You need 'ndoc' installed in order to generate docs." >&2 ; \
		echo "  $ npm install -g ndoc" >&2 ; \
		exit 128 ; \
		fi
	rm -rf ./doc
	ndoc --link-format "{package.homepage}/blob/${CURR_HEAD}/{file}#L{line}"


gh-pages:
	@if test -z ${REMOTE_REPO} ; then \
		echo 'Remote repo URL not found' >&2 ; \
		exit 128 ; \
		fi
	$(MAKE) doc && \
		cp -r ./doc ${TMP_PATH} && \
		touch ${TMP_PATH}/.nojekyll
	cd ${TMP_PATH} && \
		git init && \
		git add . && \
		git commit -q -m 'Recreated docs'
	cd ${TMP_PATH} && \
		git remote add remote ${REMOTE_REPO} && \
		git push --force remote +master:gh-pages
	rm -rf ${TMP_PATH}


publish:
	@if test 0 -ne `git status --porcelain | wc -l` ; then \
		echo "Unclean working tree. Commit or stash changes first." >&2 ; \
		exit 128 ; \
		fi
	@if test 0 -ne `git fetch ; git status | grep '^# Your branch' | wc -l` ; then \
		echo "Local/Remote history differs. Please push/pull changes." >&2 ; \
		exit 128 ; \
		fi
	@if test 0 -ne `git tag -l ${NPM_VERSION} | wc -l` ; then \
		echo "Tag ${NPM_VERSION} exists. Update package.json" >&2 ; \
		exit 128 ; \
		fi
	git tag ${NPM_VERSION} && git push origin ${NPM_VERSION}
	npm publish https://github.com/${GITHUB_PROJ}/tarball/${NPM_VERSION}


.PHONY: publish lint test test-slimerjs doc gh-pages
.SILENT: help lint test doc
