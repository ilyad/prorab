include $(d)../../../src/prorab.mk

include $(d)../../common.mk

define this_rules
.PHONY: test
test::
	@$(this_running) outdir/$(this_test)
	+$(prorab_echo)$(MAKE) -C $(d)src clean || $(this_err) "initial 'make clean' failed"
	+$(prorab_echo)$(MAKE) -C $(d)src || $(this_err) "'make' failed"
	$(prorab_echo)if [ ! -f $(d)src/out1/tests ]; then $(this_err) "src/out1/tests file not found"; fi
	$(prorab_echo)if [ ! -f $(d)src/out2/tests_no_install ]; then $(this_err) "src/out2/tests_no_install file not found"; fi
	$(prorab_echo)if [ ! -d $(d)src/out2/obj_tests_no_install ]; then $(this_err) "src/out2/obj_tests_no_install directory not found"; fi

	$(prorab_echo)rm -rf $(d)src/tmp
	+$(prorab_echo)$(MAKE) -C $(d)src install DESTDIR=tmp PREFIX=/usr || $(this_err) "'make install' failed"
	$(prorab_echo)if [ ! -f $(d)src/tmp/usr/bin/tests$(exeext) ]; then $(this_err) "src/tmp/usr/bin/tests$(exeext) file not found"; fi
	$(prorab_echo)if [ -f $(d)src/tmp/usr/bin/tests_no_install$(exeext) ]; then $(this_err) "src/tmp/usr/bin/tests_no_install$(exeext) file found, must not be there"; fi

	+$(prorab_echo)$(MAKE) -C $(d)src uninstall DESTDIR=tmp PREFIX=/usr || $(this_err) "'make uninstall' failed"
	$(prorab_echo)if [ -f $(d)src/tmp/usr/bin/tests$(exeext) ]; then $(this_err) "src/tmp/usr/bin/tests$(exeext) file found"; fi

	$(prorab_echo)if [ ! -d $(d)src/tmp/usr/bin ]; then $(this_err) "src/tmp/usr/bin directory not found"; fi
	$(prorab_echo)rm -rf src/tmp

	+$(prorab_echo)$(MAKE) -C $(d)src clean || $(this_err) "final 'make clean' failed"
	$(prorab_echo)if [ -f $(d)src/out1/tests ]; then $(this_err) "src/out1/tests file remained after clean"; fi
	$(prorab_echo)if [ -f $(d)src/out2/tests_no_install ]; then $(this_err) "src/out2/tests_no_install file remained after clean"; fi
	$(prorab_echo)if [ -d $(d)src/out1/obj_tests ]; then $(this_err) "src/out1/obj_tests directory remained after clean"; fi
	$(prorab_echo)if [ -d $(d)src/out2/obj_tests_no_install ]; then $(this_err) "src/out2/obj_tests_no_install directory remained after clean"; fi
	@$(this_pass)
endef
$(eval $(this_rules))
