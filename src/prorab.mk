# prorab - the build system


#once
ifneq ($(prorab_included),true)
    prorab_included := true

    #for storing list of included makefiles
    prorab_included_makefiles :=


    #check if running minimal supported GNU make version
    prorab_min_gnumake_version := 3.81
    ifeq ($(filter $(prorab_min_gnumake_version),$(firstword $(sort $(MAKE_VERSION) $(prorab_min_gnumake_version)))),)
        $(error GNU make $(prorab_min_gnumake_version) or higher is needed, but found only $(MAKE_VERSION))
    endif


    #check that prorab.mk is the first file included
    ifneq ($(words $(MAKEFILE_LIST)),2)
        $(error prorab.mk is not a first include in the makefile, include prorab.mk should be the very first thing done in the makefile.)
    endif


    #define arithmetic functions
    prorab-num = $(words $1) #get number from variable
    prorab-add = $1 $2 #add two variables
    prarab-inc = x $1 #increment variable
    prorab-dec = $(wordlist 2,$(words $1),$1) #decrement variable
    prorab-max = $(subst xx,x,$(join $1,$2)) #get maximum of two variables
    prorab-gt = $(filter-out $(words $2),$(words $(call prorab-max,$1,$2))) #greater predicate
    prorab-eq = $(filter $(words $1),$(words $2)) #equals predicate
    prorab-gte = $(call prorab-gt,$1,$2)$(call prorab-eq,$1,$2) #greater or equals predicate
    prorab-sub = $(if $(call prorab-gte,$1,$2),$(filter-out xx,$(join $1,$2)),$(error subtraction goes negative)) #subtract one variable from another, negative result is clamped to zero

    #calculate number of ../ in a file path
    prorab-calculate-stepups = $(foreach var,$(filter ..,$(subst /, ,$(dir $1))),x)

    #define this directory for parent makefile
    prorab_this_makefile := $(word $(call prorab-num,$(call prorab-dec,$(MAKEFILE_LIST))),$(MAKEFILE_LIST))
    prorab_this_dir := $(dir $(prorab_this_makefile))
    d = $(prorab_this_dir)

    #define local variables used by prorab
    this_name :=
    this_soname :=
    this_cflags :=
    this_cxxflags :=
    this_ldflags :=
    this_ldlibs :=
    this_srcs :=


    .PHONY: clean all install uninstall distclean doc phony

    #define the very first default target
    all:

    #define dummy phony target
    phony:

    #define distclean target which does same as clean. This is to make some older versions of debhelper happy.
    distclean: clean

    #directory of prorab.mk
    prorab_dir := $(dir $(lastword $(MAKEFILE_LIST)))

    #initialize standard vars for "install" and "uninstall" targets
    ifeq ($(PREFIX),) #PREFIX is environment variable, but if it is not set, then set default value
        PREFIX := /usr/local
    endif

    #Detect operating system
    prorab_private_os := $(shell uname)
    prorab_private_os := $(patsubst MINGW%,Windows,$(prorab_private_os))
    prorab_private_os := $(patsubst CYGWIN%,Windows,$(prorab_private_os))
    ifeq ($(prorab_private_os), Windows)
        prorab_os := windows
    else ifeq ($(prorab_private_os), Darwin)
        prorab_os := macosx
    else ifeq ($(prorab_private_os), Linux)
        prorab_os := linux
    else
        $(info Warning: unknown OS, assuming linux)
        prorab_os := linux
    endif

    os := $(prorab_os)

    #set library extension
    ifeq ($(prorab_os), windows)
        prorab_lib_extension := .dll
    else ifeq ($(prorab_os), macosx)
        prorab_lib_extension := .dylib
    else
        prorab_lib_extension := .so
    endif

    soext := $(prorab_lib_extension)

    ifeq ($(verbose),true)
        prorab_echo :=
    else
        prorab_echo := @
    endif



    define prorab-private-app-specific-rules
        #need empty line here to avoid merging with adjacent macro instantiations

        $(if $(this_name),,$(error this_name is not defined))

        $(eval prorab_private_ldflags := )

        $(if $(filter windows,$(prorab_os)), \
                $(eval prorab_this_name := $(abspath $(prorab_this_dir)$(this_name).exe)) \
            , \
                $(eval prorab_this_name := $(abspath $(prorab_this_dir)$(this_name))) \
            )

        $(eval prorab_this_symbolic_name := $(prorab_this_name))

        install:: $(prorab_this_name)
		$(prorab_echo)install -d $(DESTDIR)$(PREFIX)/bin/
		$(prorab_echo)install $(prorab_this_name) $(DESTDIR)$(PREFIX)/bin/

        uninstall::
		$(prorab_echo)rm -f $(DESTDIR)$(PREFIX)/bin/$(notdir $(prorab_this_name))

        #need empty line here to avoid merging with adjacent macro instantiations
    endef



    define prorab-private-dynamic-lib-specific-rules-nix-systems
        #need empty line here to avoid merging with adjacent macro instantiations

        $(if $(this_soname),,$(error this_soname is not defined))

        $(if $(filter macosx,$(prorab_os)), \
                $(eval prorab_this_symbolic_name := $(abspath $(prorab_this_dir)lib$(this_name)$(prorab_lib_extension))) \
                $(eval prorab_this_name := $(abspath $(prorab_this_dir)lib$(this_name).$(this_soname)$(prorab_lib_extension))) \
                $(eval prorab_private_ldflags += -dynamiclib -Wl,-install_name,$(prorab_this_name),-headerpad_max_install_names,-undefined,dynamic_lookup,-compatibility_version,1.0,-current_version,1.0) \
            ,\
                $(eval prorab_this_symbolic_name := $(abspath $(prorab_this_dir)lib$(this_name)$(prorab_lib_extension))) \
                $(eval prorab_this_name := $(prorab_this_symbolic_name).$(this_soname)) \
                $(eval prorab_private_ldflags := -shared -Wl,-soname,$(notdir $(prorab_this_name))) \
            )

        #symbolic link to shared library rule
        $(prorab_this_symbolic_name): $(prorab_this_name) $(prorab_this_makefile)
			@echo "Creating symbolic link $$(notdir $$@) -> $$(notdir $$<)..."
			$(prorab_echo)(cd $$(dir $$<); ln -f -s $$(notdir $$<) $$(notdir $$@))

        all: $(prorab_this_symbolic_name)

        install:: $(prorab_this_symbolic_name)
		$(prorab_echo)install -d $(DESTDIR)$(PREFIX)/lib/
		$(prorab_echo)(cd $(DESTDIR)$(PREFIX)/lib/; ln -f -s $(notdir $(prorab_this_name)) $(notdir $(prorab_this_symbolic_name)))

        uninstall::
		$(prorab_echo)rm -f $(DESTDIR)$(PREFIX)/lib/$(notdir $(prorab_this_symbolic_name))

        clean::
		$(prorab_echo)rm -f $(prorab_this_symbolic_name)

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    
    define prorab-private-lib-install-headers-rule
        #need empty line here to avoid merging with adjacent macro instantiations

        #foreach is used to filter out all files which are not inside of a directory
        $(eval prorab_private_headers := $(foreach v,$(patsubst $(prorab_this_dir)%,%,$(shell find $(prorab_this_dir) -type f -name "*.hpp" -o -name "*.h")),$(if $(findstring /,$(v)),$(v),)))

        install::
		$(prorab_echo)for i in $(prorab_private_headers); do \
		    install -d $(DESTDIR)$(PREFIX)/include/$$$${i%/*}; \
		    install -m 644 $(prorab_this_dir)$$$$i $(DESTDIR)$(PREFIX)/include/$$$$i; \
		done

        uninstall::
		$(prorab_echo)for i in $(dir $(prorab_private_headers)); do \
		    rm -rf $(DESTDIR)$(PREFIX)/include/$$$$i; \
		done

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    define prorab-private-dynamic-lib-specific-rules
        #need empty line here to avoid merging with adjacent macro instantiations

        $(if $(this_name),,$(error this_name is not defined))

        $(if $(filter windows,$(prorab_os)), \
                $(eval prorab_this_name := $(abspath $(prorab_this_dir)lib$(this_name)$(prorab_lib_extension))) \
                $(eval prorab_private_ldflags := -shared -s) \
                $(eval prorab_this_symbolic_name := $(prorab_this_name)) \
            , \
                $(prorab-private-dynamic-lib-specific-rules-nix-systems) \
            )

        install:: $(prorab_this_name)
		$(prorab_echo)install -d $(DESTDIR)$(PREFIX)/lib/
		$(prorab_echo)install $(prorab_this_name) $(DESTDIR)$(PREFIX)/lib/
		$(if $(filter macosx,$(prorab_os)), \
		        $(prorab_echo)install_name_tool -id "$(PREFIX)/lib/$(notdir $(prorab_this_name))" $(DESTDIR)$(PREFIX)/lib/$(notdir $(prorab_this_name)) \
		    )

        uninstall::
		$(prorab_echo)rm -f $(DESTDIR)$(PREFIX)/lib/$(notdir $(prorab_this_name))
	
        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    define prorab-private-lib-static-library-rule
        #need empty line here to avoid merging with adjacent macro instantiations

        $(if $(this_name),,$(error this_name is not defined))

        $(eval prorab_this_staticlib := $(abspath $(prorab_this_dir)lib$(this_name).a))

        all: $(prorab_this_staticlib)

        clean::
		$(prorab_echo)rm -f $(prorab_this_staticlib)

        install:: $(prorab_this_staticlib)
		$(prorab_echo)install -d $(DESTDIR)$(PREFIX)/lib/
		$(prorab_echo)install -m 644 $(prorab_this_staticlib) $(DESTDIR)$(PREFIX)/lib/

        uninstall::
		$(prorab_echo)rm -f $(DESTDIR)$(PREFIX)/lib/$(notdir $(prorab_this_staticlib))

        #static library rule
        $(prorab_this_staticlib): $(prorab_this_objs) $(prorab_this_makefile)
		@echo "Creating static library $$(notdir $$@)..."
		$(prorab_echo)ar cr $$@ $$(filter %.o,$$^)

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    define prorab-private-flags-file-rules
        #need empty line here to avoid merging with adjacent macro instantiations

        $1: $(if $(shell echo '$2' | cmp $1 2>/dev/null), phony,)
		$(prorab_echo)mkdir -p $$(dir $$@)
		$(prorab_echo)touch $$@
		$(prorab_echo)echo '$2' > $$@

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    define prorab-private-compile-rules
        #need empty line here to avoid merging with adjacent macro instantiations

        #calculate max number of steps up in source paths and prepare obj directory spacer
        $(eval prorab_private_numobjspacers := )
        $(foreach var,$(this_srcs),\
                $(eval prorab_private_numobjspacers := $(call prorab-max,$(call prorab-calculate-stepups,$(var)),$(prorab_private_numobjspacers))) \
            )
        $(eval prorab_private_objspacer:= )
        $(foreach var,$(prorab_private_numobjspacers), $(eval prorab_private_objspacer := $(prorab_private_objspacer)_prorab/))

        $(eval prorab_this_obj_dir := obj_$(this_name)/)

        #Prepare list of object files
        $(eval prorab_this_cpp_objs := $(addprefix $(prorab_this_dir)$(prorab_this_obj_dir)cpp/$(prorab_private_objspacer),$(patsubst %.cpp,%.o,$(filter %.cpp,$(this_srcs)))))
        $(eval prorab_this_c_objs := $(addprefix $(prorab_this_dir)$(prorab_this_obj_dir)c/$(prorab_private_objspacer),$(patsubst %.c,%.o,$(filter %.c,$(this_srcs)))))
        $(eval prorab_this_objs := $(prorab_this_cpp_objs) $(prorab_this_c_objs))

        $(eval prorab_cxxflags := $(CXXFLAGS) $(CPPFLAGS) $(this_cxxflags))
        $(eval prorab_cflags := $(CFLAGS) $(CPPFLAGS) $(this_cflags))

        $(eval prorab_cxxflags_file := $(prorab_this_dir)$(prorab_this_obj_dir)cxxflags.txt)
        $(eval prorab_cflags_file := $(prorab_this_dir)$(prorab_this_obj_dir)cflags.txt)

        #compile command line flags dependency
        $(call prorab-private-flags-file-rules, $(prorab_cxxflags_file),$(CXX) $(prorab_cxxflags))
        $(call prorab-private-flags-file-rules, $(prorab_cflags_file),$(CC) $(prorab_cflags))

        #compile .cpp static pattern rule
        $(prorab_this_cpp_objs): $(prorab_this_dir)$(prorab_this_obj_dir)cpp/$(prorab_private_objspacer)%.o: $(prorab_this_dir)%.cpp $(prorab_this_makefile) $(prorab_cxxflags_file)
		@echo "Compiling $$<..."
		$(prorab_echo)mkdir -p $$(dir $$@)
		$(prorab_echo)$$(CXX) -c -MF "$$(patsubst %.o,%.d,$$@)" -MD -o "$$@" $(prorab_cxxflags) $$<

        #compile .c static pattern rule
        $(prorab_this_c_objs): $(prorab_this_dir)$(prorab_this_obj_dir)c/$(prorab_private_objspacer)%.o: $(prorab_this_dir)%.c $(prorab_this_makefile) $(prorab_cflags_file)
		@echo "Compiling $$<..."
		$(prorab_echo)mkdir -p $$(dir $$@)
		$(prorab_echo)$$(CC) -c -MF "$$(patsubst %.o,%.d,$$@)" -MD -o "$$@" $(prorab_cflags) $$<

        #include rules for header dependencies
        include $(wildcard $(addsuffix *.d,$(dir $(prorab_this_objs))))

        clean::
		$(prorab_echo)rm -rf $(prorab_this_dir)$(prorab_this_obj_dir)

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    define prorab-private-link-rules
        #need empty line here to avoid merging with adjacent macro instantiations

        $(if $(prorab_this_obj_dir),,$(error prorab_this_obj_dir is not defined))

        $(eval prorab_ldflags := $(this_ldlibs) $(this_ldflags) $(LDLIBS) $(LDFLAGS) $(prorab_private_ldflags))
        $(eval prorab_ldflags_file := $(prorab_this_dir)$(prorab_this_obj_dir)ldflags.txt)

        $(call prorab-private-flags-file-rules, $(prorab_ldflags_file),$(CC) $(prorab_ldflags))

        all: $(prorab_this_name)

        #link rule
        $(prorab_this_name): $(prorab_this_objs) $(prorab_this_makefile) $(prorab_ldflags_file)
		@echo "Linking $$@..."
		$(prorab_echo)$$(CC) $$(filter %.o,$$^) -o "$$@" $(prorab_ldflags)

        clean::
		$(prorab_echo)rm -f $(prorab_this_name)

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    #if there are no any sources in this_srcs then just install headers, no need to build binaries
    define prorab-build-lib
        #need empty line here to avoid merging with adjacent macro instantiations

        $(prorab-build-static-lib)
        $(if $(this_srcs), \
                $(prorab-private-dynamic-lib-specific-rules) \
                $(prorab-private-link-rules) \
                , \
            )

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    define prorab-build-static-lib
        #need empty line here to avoid merging with adjacent macro instantiations

        $(prorab-private-lib-install-headers-rule)
        $(if $(this_srcs), \
                $(prorab-private-compile-rules) \
                $(prorab-private-lib-static-library-rule) \
                , \
            )

        #need empty line here to avoid merging with adjacent macro instantiations
    endef


    define prorab-build-app
        #need empty line here to avoid merging with adjacent macro instantiations

        $(prorab-private-app-specific-rules)
        $(prorab-private-compile-rules)
        $(prorab-private-link-rules)

        #need empty line here to avoid merging with adjacent macro instantiations
    endef




    define prorab-include
        #need empty line here to avoid merging with adjacent macro instantiations

        $(if $(filter $(abspath $1),$(prorab_included_makefiles)), \
            , \
                $(eval prorab_included_makefiles += $(abspath $1)) \
                $(call prorab-private-include,$1) \
            )

        #need empty line here to avoid merging with adjacent macro instantiations
    endef


    #for storing previous prorab_this_makefile when including other makefiles
    prorab_private_this_makefiles :=

    #include file with correct prorab_this_dir
    define prorab-private-include
        #need empty line here to avoid merging with adjacent macro instantiations

        prorab_private_this_makefiles += $$(prorab_this_makefile)
        prorab_this_makefile := $1
        prorab_this_dir := $$(dir $$(prorab_this_makefile))
        include $1
        prorab_this_makefile := $$(lastword $$(prorab_private_this_makefiles))
        prorab_this_dir := $$(dir $$(prorab_this_makefile))
        prorab_private_this_makefiles := $$(wordlist 1,$$(call prorab-num,$$(call prorab-dec,$$(prorab_private_this_makefiles))),$$(prorab_private_this_makefiles))

        #need empty line here to avoid merging with adjacent macro instantiations
    endef
    #!!!NOTE: the trailing empty line in 'prorab-private-include' definition is needed so that include files would be separated from each other

    #include all makefiles in subdirectories
    define prorab-build-subdirs
        #need empty line here to avoid merging with adjacent macro instantiations

        $(foreach path,$(wildcard $(prorab_this_dir)*/makefile),$(call prorab-include,$(path)))

        #need empty line here to avoid merging with adjacent macro instantiations
    endef


    prorab-clear-this-vars = $(foreach var,$(filter this_%,$(.VARIABLES)),$(eval $(var) := ))



    #doxygen docs are only possible for libraries, so install path is lib*-doc
    define prorab-build-doxygen
        #need empty line here to avoid merging with adjacent macro instantiations

        all: doc

        doc:: $(prorab_this_dir)doxygen

        $(prorab_this_dir)doxygen.cfg: $(prorab_this_dir)doxygen.cfg.in $(prorab_this_dir)../debian/changelog
		$(prorab_echo)prorab-apply-version.sh -v $$(shell prorab-deb-version.sh $(prorab_this_dir)../debian/changelog) $$(firstword $$^)

        $(prorab_this_dir)doxygen: $(prorab_this_dir)doxygen.cfg
		@echo "Building docs..."
		$(prorab_echo)(cd $(prorab_this_dir); doxygen doxygen.cfg || true)

        clean::
		$(prorab_echo)rm -rf $(prorab_this_dir)doxygen
		$(prorab_echo)rm -rf $(prorab_this_dir)doxygen.cfg
		$(prorab_echo)rm -rf $(prorab_this_dir)doxygen_sqlite3.db

        install:: $(prorab_this_dir)doxygen
		$(prorab_echo)install -d $(DESTDIR)$(PREFIX)/share/doc/lib$(this_name)-doc
		$(prorab_echo)install -m 644 $(prorab_this_dir)doxygen/* $(DESTDIR)$(PREFIX)/share/doc/lib$(this_name)-doc || true #ignore error, not all systems have doxygen

        uninstall::
		$(prorab_echo)rm -rf $(DESTDIR)$(PREFIX)/share/doc/lib$(this_name)-doc

        #need empty line here to avoid merging with adjacent macro instantiations
    endef


    define prorab-pkg-config
        #need empty line here to avoid merging with adjacent macro instantiations

        install:: $(shell ls $(prorab_this_dir)*.pc.in)
		$(prorab_echo)prorab-apply-version.sh -v `prorab-deb-version.sh $(prorab_this_dir)../debian/changelog` $(prorab_this_dir)*.pc.in
		$(prorab_echo)install -d $(DESTDIR)$(PREFIX)/lib/pkgconfig
		$(prorab_echo)install -m 644 $(prorab_this_dir)*.pc $(DESTDIR)$(PREFIX)/lib/pkgconfig

        #need empty line here to avoid merging with adjacent macro instantiations
    endef

    #define function to find all source files from specified directory recursively
    #NOTE: removing trailing '/' or '/.' before invoking 'find'.
    prorab-src-dir = $(patsubst $(prorab_this_dir)%,%,$(shell find $(patsubst %/.,%,$(patsubst %/,%,$(prorab_this_dir)$1)) -type f -name "*.cpp" -o -name "*.c"))

endif #~once


$(if $(filter $(prorab_this_makefile),$(prorab_included_makefiles)), \
        \
    , \
        $(eval prorab_included_makefiles += $(abspath $(prorab_this_makefile))) \
    )

$(prorab-clear-this-vars)
