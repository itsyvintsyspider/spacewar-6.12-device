LOCAL_PATH := $(call my-dir)

#----------------------------------------------------------------------
# Radio image
#----------------------------------------------------------------------
ifeq ($(ADD_RADIO_FILES), true)
radio_dir := $(LOCAL_PATH)/radio
RADIO_FILES := $(notdir $(wildcard $(radio_dir)/*))
$(foreach f, $(RADIO_FILES), \
    $(call add-radio-file,radio/$(f)))
endif

#----------------------------------------------------------------------
# KERNEL_OBJ/usr for the legacy .mk audio HAL (prebuilt kernel, no inline build)
#----------------------------------------------------------------------
KERNEL_OBJ_USR := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ/usr
$(KERNEL_OBJ_USR): $(LOCAL_PATH)/AndroidBoard.mk $(shell find $(TARGET_BOARD_KERNEL_HEADERS)/usr -type f)
	@rm -rf $@
	@mkdir -p $@
	@cp -a $(TARGET_BOARD_KERNEL_HEADERS)/usr/. $@/
	@rm -f $@/include/asm/sigcontext.h
	@vendor/neoteric/tools/clean_headers.sh $(abspath $(patsubst %/usr,%,$@))
