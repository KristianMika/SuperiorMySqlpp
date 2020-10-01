#!/usr/bin/make -f
initial_variables :=$(.VARIABLES)

# temporary prefix for copying files in install rule
# if set then must end with '/'
DESTDIR :=

VERSION := 0.6.1
version_numbers :=$(subst ., ,$(VERSION))
version_major :=$(word 1,$(version_numbers))

# Common prefix for installation directories.
prefix :=/usr/local
libdir =$(prefix)/lib
includedir =$(prefix)/include

INSTALL :=install
INSTALL_LIB =$(INSTALL) --mode=644
INSTALL_INCLUDE =$(INSTALL) --mode=644

# Test for presence of boost_system. Currently, only actually needed part is Asio
# that is used in extended tests and this seems to be reasonably efficient way to detect it.
BOOST_LIB_PATHS = $(shell /sbin/ldconfig --print-cache | grep 'libboost_system')
ifneq ($(BOOST_LIB_PATHS),)
	HAVE_BOOST_SYSTEM = 1
else
	HAVE_BOOST_SYSTEM = 0
endif

.PHONY: _print-variables test test-basic test-extended install clean
.NOTPARALLEL: test

collapse-slashes =$(if $(findstring //,$1),$(call collapse-slashes,$(subst //,/,$1)),$(subst //,/,$1))
list-directories =$(filter-out $(call collapse-slashes,$(dir $1/)),$(dir $(wildcard $(call collapse-slashes,$1/*/))))
define make-directory
$(call collapse-slashes,mkdir --parents $1)

endef

define recursive-install-impl
$(call collapse-slashes,$1 $2/$3 $4/$(patsubst $5%,%,$(dir $(call collapse-slashes,$2/$3))))
$(foreach dir,$(call list-directories,$2),$(call make-directory,$4/$(patsubst $5%,%,$(dir)))$(call recursive-install-impl,$1,$(dir),$3,$4,$5))
endef
recursive-install =$(call recursive-install-impl,$1,$2,$3,$4,$2)


all:
	$(error "make without target")


# for debugging purposes
_print-variables:
	$(foreach v,$(filter-out $(initial_variables) initial_variables,$(.VARIABLES)),$(info $(v) = $($(v))))


# pravidlo pro vsechny adresare (makefile nechape v pravidlech "%/:")
%/.:
	mkdir --parents $@


test-basic:
	+$(MAKE) --directory ./tests/ test
test-extended:
ifeq ($(HAVE_BOOST_SYSTEM),1)
	+$(MAKE) --directory ./tests-extended/ test
else
	$(error Extended tests skipped - Boost (libboost_system) is required and was not detected)
endif

test: test-basic test-extended


libsuperiormysqlpp.pc: libsuperiormysqlpp.pc.in makefile
	sed \
         --expression='s,@VERSION@,$(VERSION),' \
         --expression='s,@PREFIX@,$(prefix),' \
         libsuperiormysqlpp.pc.in > $@


install: $(DESTDIR)$(libdir)/.
install: $(DESTDIR)$(includedir)/.
install: libsuperiormysqlpp.pc
install:
	$(call recursive-install,$(INSTALL_INCLUDE),./include,*.hpp,$(DESTDIR)$(includedir)/)
	$(INSTALL) --directory $(DESTDIR)/$(libdir)/pkgconfig
	$(INSTALL) --target-directory=$(DESTDIR)/$(libdir)/pkgconfig --mode=644 libsuperiormysqlpp.pc


clean:
	find ./ -type f -name "core" -exec $(RM) {} \;
	+$(MAKE) --directory ./tests/ clean
	+$(MAKE) --directory ./tests-extended/ clean



