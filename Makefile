PYTHON=python3
VENV=.venv
VENVPATH=$(VENV)/$(shell uname)-$(shell uname -m)-sdk-python

ENV=prod
REGION=.learnosity.com
# Data API
VER=v1

define venv-activate
	. $(VENVPATH)/bin/activate; \
	unset PYTHONPATH
endef

devbuild: build
prodbuild: dist-check-version build
build: venv pip-requirements-dev
	$(call venv-activate); \
		$(PYTHON) setup.py sdist

release:
	@./release.sh
	@echo '*** You can now use \`make dist-upload\` to publish the new version to PyPI'

test: test-unit test-integration-dev dist-check-version
test-unit: venv pip-requirements-test
	$(call venv-activate); \
		pytest --pyargs tests.unit

test-integration-env: venv pip-requirements-test
	$(call venv-activate); \
		ENV=$(ENV) \
		pytest  --pyargs tests.integration

test-integration-dev: venv pip-requirements-dev pip-requirements-test
	$(call venv-activate); \
		tox

build-clean: real-clean

dist: distclean venv pip-requirements-dev
	$(call venv-activate); \
		$(PYTHON) setup.py sdist; \
		$(PYTHON) setup.py bdist_wheel --universal
dist-upload: dist-check-version clean test dist-upload-twine
dist-check-version: PKG_VER=v$(shell sed -n "s/^.*__version__\s*=\s*'\([^']\+\)'.*$$/\1/p" learnosity_sdk/_version.py)
dist-check-version: GIT_TAG=$(shell git describe --tags)
dist-check-version:
ifeq ('$(shell echo $(GIT_TAG) | grep -qw "$(PKG_VER)")', '')
	$(error Version number $(PKG_VER) in learnosity_sdk/_version.py does not match git tag $(GIT_TAG))
endif
dist-upload-twine: venv pip-requirements-dev dist # This target doesn't do any safety check!
	$(call venv-activate); \
		twine upload dist/*

clean: test-clean distclean
	test ! -d build || rm -r build
	find . -path __pycache__ -delete
	find . -name *.pyc -delete
test-clean:
	test ! -d .tox || rm -r .tox
distclean:
	test ! -d dist || rm -r dist
real-clean: clean
	test ! -d $(VENV) || rm -r $(VENV)
	test ! -d learnosity_sdk.egg-info || rm -r learnosity_sdk.egg-info

# Python environment and dependencies
venv: $(VENVPATH)
$(VENVPATH):
	unset PYTHONPATH; virtualenv -p$(PYTHON) $(VENVPATH)
	$(call venv-activate); \
		pip install -e .

pip-requirements-dev: venv
	$(call venv-activate); \
		pip install -e ".[dev]" > /dev/null

pip-requirements-test: venv
	$(call venv-activate); \
		pip install -e ".[test]" > /dev/null

.PHONY: dist
