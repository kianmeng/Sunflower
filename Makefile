# directories
WORKING_DIRECTORY := $(dir $(lastword $(MAKEFILE_LIST)))
BUILD_DIRECTORY ?= $(WORKING_DIRECTORY)build
DEBIAN_BUILD_DIRECTORY = $(BUILD_DIRECTORY)/Debian
ARCH_BUILD_DIRECTORY = $(BUILD_DIRECTORY)/Arch
FEDORA_BUILD_DIRECTORY = $(BUILD_DIRECTORY)/Fedora

# version
VERSION_MAJOR := $(shell cat $(WORKING_DIRECTORY)/sunflower/gui/main_window.py | grep \'major\': | cut -f 2 -d : | tr -d [:space:][,])
VERSION_MINOR := $(shell cat $(WORKING_DIRECTORY)/sunflower/gui/main_window.py | grep \'minor\': | cut -f 2 -d : | tr -d [:space:][,])
VERSION_BUILD := $(shell cat $(WORKING_DIRECTORY)/sunflower/gui/main_window.py | grep \'build\': | cut -f 2 -d : | tr -d [:space:][,])
VERSION_STAGE := $(shell cat $(WORKING_DIRECTORY)/sunflower/gui/main_window.py | grep \'stage\': | cut -f 2 -d : | tr -d [:space:][\'][,])

# generate file name based on version
ifeq ($(VERSION_STAGE),f)
VERSION = $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_BUILD)
FILE_NAME = sunflower-$(VERSION_MAJOR).$(VERSION_MINOR)-$(VERSION_BUILD)
else
VERSION = $(VERSION_MAJOR).$(VERSION_MINOR)$(VERSION_STAGE).$(VERSION_BUILD)
FILE_NAME = sunflower-$(VERSION_MAJOR).$(VERSION_MINOR)$(VERSION_STAGE)-$(VERSION_BUILD)
endif

# variables used in packages
RELEASE ?= 1
PACKAGER ?= ""

# additional directories
FILE_PATH = $(BUILD_DIRECTORY)/$(FILE_NAME)
DEB_FILE_PATH = $(BUILD_DIRECTORY)/sunflower-$(VERSION)-$(RELEASE).all.deb
PKG_FILE_PATH = $(BUILD_DIRECTORY)/sunflower-$(VERSION)-$(RELEASE)-any.pkg.tar.xz
RPM_FILE_PATH = $(BUILD_DIRECTORY)/sunflower-$(VERSION)-$(RELEASE).noarch.rpm
RPM_OPENSUSE_FILE_PATH = $(BUILD_DIRECTORY)/sunflower-$(VERSION)-$(RELEASE).noarch.opensuse.rpm
RPM_PCLINUXOS_FILE_PATH = $(BUILD_DIRECTORY)/sunflower-$(VERSION)-$(RELEASE).noarch.pclinuxos.rpm

# prepare help
define HELP
Usage:
	dist               - create a distribution tgz file
	dist-py            - create a python egg distribution file
	dist-deb           - create a .deb package for Debian, Mint, Ubuntu
	dist-arch          - create a .pkg.tar.gz package for ArchLinux
	dist-rpm           - create a .rpm package for Fedora, Mageia, Mandriva
	dist-rpm-opensuse  - create a .rpm package for OpenSUSE
	dist-rpm-pclinuxos - create a .rpm package for PCLinuxOS
	dist-all           - create all packages
	language-template  - update language template
	language-compile   - compile language files to .mo format
	clean              - remove all build files
	version            - print Sunflower version
	help               - print this help

Options for dist-* passed through environment variables:
	RELEASE=1   - release number
	PACKAGER="" - packagers name (e.i. "John Smith <mail@example.com>")
endef
export HELP

# install program to fake root (this needs to be the same as dist/PKGBUILD)
define DEBIAN_INSTALL
	mkdir -p "$(DEBIAN_BUILD_DIRECTORY)"
	mkdir -p "$(DEBIAN_BUILD_DIRECTORY)/usr/local/bin"
	mkdir -p "$(DEBIAN_BUILD_DIRECTORY)/usr/share/locale"
	mkdir -p "$(DEBIAN_BUILD_DIRECTORY)/usr/share/applications"
	mkdir -p "$(DEBIAN_BUILD_DIRECTORY)/usr/share/sunflower"
	mkdir -p "$(DEBIAN_BUILD_DIRECTORY)/usr/share/icons/hicolor/scalable/apps"
	install -d "$(DEBIAN_BUILD_DIRECTORY)/usr/share/pixmaps/sunflower"
	install -d "$(DEBIAN_BUILD_DIRECTORY)/usr/lib/python3/dist-packages/sunflower"

	tar -xf $(FILE_PATH).tar -C $(BUILD_DIRECTORY)
	install -Dm755 $(WORKING_DIRECTORY)/dist/sunflower "$(DEBIAN_BUILD_DIRECTORY)/usr/local/bin/sunflower"
	cp -r $(BUILD_DIRECTORY)/Sunflower/sunflower/* "$(DEBIAN_BUILD_DIRECTORY)/usr/lib/python3/dist-packages/sunflower"
	cp -r $(BUILD_DIRECTORY)/Sunflower/styles "$(DEBIAN_BUILD_DIRECTORY)/usr/share/sunflower"
	cp -r $(BUILD_DIRECTORY)/Sunflower/images "$(DEBIAN_BUILD_DIRECTORY)/usr/share/sunflower"
	rsync -r $(BUILD_DIRECTORY)/Sunflower/translations/* "$(DEBIAN_BUILD_DIRECTORY)/usr/share/locale" --exclude "*.po*"
	install -Dm644 "$(BUILD_DIRECTORY)/Sunflower/images/sunflower.svg" "$(DEBIAN_BUILD_DIRECTORY)/usr/share/icons/hicolor/scalable/apps/sunflower.svg"
	install -Dm644 "$(BUILD_DIRECTORY)/Sunflower/Sunflower.desktop" "$(DEBIAN_BUILD_DIRECTORY)/usr/share/applications/sunflower.desktop"
endef

# replace variables in spec file
define CREATE_RPM_SPEC_FILE
	cp $(WORKING_DIRECTORY)/dist/sunflower.spec $(BUILD_DIRECTORY)
	sed -i s/@version@/$(VERSION)/ $(BUILD_DIRECTORY)/sunflower.spec
	sed -i s/@release@/$(RELEASE)/ $(BUILD_DIRECTORY)/sunflower.spec
	sed -i s/@packager@/"$(PACKAGER)"/ $(BUILD_DIRECTORY)/sunflower.spec
endef

# configuration options
all: version help

archive:
	$(info Creating release archive...)
	mkdir -p $(BUILD_DIRECTORY)
	git archive --format=tar --output=$(FILE_PATH).tar --prefix=Sunflower/ HEAD

dist: archive
	$(info Compressing release archive...)
	gzip -9 $(FILE_PATH).tar
	mv $(FILE_PATH).tar.gz $(FILE_PATH).tgz
	sha256sum $(FILE_PATH).tgz > $(FILE_PATH).tgz.sha256

dist-py:
	$(info Building package for Python...)
	python3 setup.py sdist
	rm -rf build Sunflower.egg-info
	mv dist/Sunflower*.tar.gz ./

dist-deb: archive
	$(info Building package for Debian, Mint, Ubuntu...)
	$(DEBIAN_INSTALL)
	mkdir -p $(DEBIAN_BUILD_DIRECTORY)/DEBIAN
	cp $(WORKING_DIRECTORY)/dist/control $(DEBIAN_BUILD_DIRECTORY)/DEBIAN
	sed -i "s/@version@/$(VERSION)/" $(DEBIAN_BUILD_DIRECTORY)/DEBIAN/control
	sed -i "s/@packager@/$(PACKAGER)/" $(DEBIAN_BUILD_DIRECTORY)/DEBIAN/control
	sed -i "s/@size@/`du --summarize $(DEBIAN_BUILD_DIRECTORY) | cut -f 1`/" $(DEBIAN_BUILD_DIRECTORY)/DEBIAN/control
	fakeroot dpkg-deb --build $(DEBIAN_BUILD_DIRECTORY)
	mv $(DEBIAN_BUILD_DIRECTORY).deb $(DEB_FILE_PATH)
	sha256sum $(DEB_FILE_PATH) > $(DEB_FILE_PATH).sha256

dist-arch: dist
	$(info Building package for ArchLinux...)
	mkdir -p $(ARCH_BUILD_DIRECTORY)
	cp $(FILE_PATH).tgz $(ARCH_BUILD_DIRECTORY)
	cp $(WORKING_DIRECTORY)/dist/PKGBUILD $(WORKING_DIRECTORY)/dist/sunflower $(ARCH_BUILD_DIRECTORY)
	sed -i s/@version@/$(VERSION)/ $(ARCH_BUILD_DIRECTORY)/PKGBUILD
	sed -i s/@release@/$(RELEASE)/ $(ARCH_BUILD_DIRECTORY)/PKGBUILD
	cd $(ARCH_BUILD_DIRECTORY); makepkg -g >> PKGBUILD
	cd $(ARCH_BUILD_DIRECTORY); makepkg
	mv $(ARCH_BUILD_DIRECTORY)/sunflower-$(VERSION)-$(RELEASE)-any.pkg.tar.xz $(PKG_FILE_PATH)
	sha256sum $(PKG_FILE_PATH) > $(PKG_FILE_PATH).sha256

dist-rpm: archive
	$(info Building package for Fedora, Mageia, Mandriva...)
	$(CREATE_RPM_SPEC_FILE)
	sed -i "s/@requires@/python3, python3-gobject, python3-chardet, gtk3/" $(BUILD_DIRECTORY)/sunflower.spec
	rpmbuild -bb $(BUILD_DIRECTORY)/sunflower.spec --build-in-place --buildroot "$(abspath $(FEDORA_BUILD_DIRECTORY))"
	cp ~/rpmbuild/RPMS/noarch/sunflower-$(VERSION)-$(RELEASE).noarch.rpm $(RPM_FILE_PATH)
	sha256sum $(RPM_FILE_PATH) > $(RPM_FILE_PATH).sha256

dist-rpm-opensuse: archive
	$(info Building package for OpenSUSE...)
	$(CREATE_RPM_SPEC_FILE)
	sed -i "s/@requires@/python-gtk, python-chardet/" $(BUILD_DIRECTORY)/sunflower.spec
	rpmbuild -bb $(BUILD_DIRECTORY)/sunflower.spec --build-in-place --buildroot "$(abspath $(FEDORA_BUILD_DIRECTORY))"
	cp ~/rpmbuild/RPMS/noarch/sunflower-$(VERSION)-$(RELEASE).noarch.rpm $(RPM_OPENSUSE_FILE_PATH)
	sha256sum $(RPM_OPENSUSE_FILE_PATH) > $(RPM_OPENSUSE_FILE_PATH).sha256

dist-rpm-pclinuxos: archive
	$(info Building package for PCLinuxOS...)
	$(CREATE_RPM_SPEC_FILE)
	sed -i "s/@requires@/pygtk2.0, python-chardet/" $(BUILD_DIRECTORY)/sunflower.spec
	rpmbuild -bb $(BUILD_DIRECTORY)/sunflower.spec --build-in-place --buildroot "$(abspath $(FEDORA_BUILD_DIRECTORY))"
	cp ~/rpmbuild/RPMS/noarch/sunflower-$(VERSION)-$(RELEASE).noarch.rpm $(RPM_PCLINUXOS_FILE_PATH)
	sha256sum $(RPM_PCLINUXOS_FILE_PATH) > $(RPM_PCLINUXOS_FILE_PATH).sha256

dist-all: dist-deb dist-rpm dist-rpm-opensuse dist-rpm-pclinuxos dist-pkg dist-py

language-template:
	$(info Updating language template...)
	find sunflower/ -iname "*.py" | xargs xgettext --language=Python --package-name=Sunflower --package-version=0.1 --output $(WORKING_DIRECTORY)/translations/sunflower.pot

language-compile:
	$(info Compiling language templates...)
	find translations -iname "*.po" -execdir msgfmt sunflower.po -o sunflower.mo \;

clean:
	$(RM) -rf $(BUILD_DIRECTORY)
	$(RM) -rf sunflower.*

version:
	$(info Sunflower $(VERSION))

standalone:
	zip --quiet sunflower -r sunflower images styles -x *.pyc -x __pycache__ -x *.xcf
	zip --quiet --junk-paths sunflower sunflower/__main__.py
	echo '#!/usr/bin/env python3' > sunflower.app
	cat sunflower.zip >> sunflower.app
	rm sunflower.zip
	chmod a+x sunflower.app

help:
	@echo "$$HELP"

.PHONY: default dist dist-py dist-deb dist-pkg dist-rpm dist-rpm-opensuse dist-rpm-pclinuxos dist-all language-template clean version help

