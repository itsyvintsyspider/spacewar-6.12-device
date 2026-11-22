# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a76

# AVB - Disable Verification
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# AVB - Recovery
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# AVB - VBMeta System
BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2

# Board Info
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt

# Boot
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_BOOT_HEADER_VERSION := 3
BOARD_MKBOOTIMG_ARGS := --header_version $(BOARD_BOOT_HEADER_VERSION)

# Build
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true

# Display
TARGET_SCREEN_DENSITY := 420
TARGET_RECOVERY_UI_MARGIN_HEIGHT := 107

# DTBO
BOARD_KERNEL_SEPARATED_DTBO := true
BOARD_INCLUDE_RECOVERY_DTBO := true

# Kernel
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_CMDLINE := \
    androidboot.hardware=qcom \
    androidboot.memcg=1 \
    lpm_levels.sleep_disabled=1 \
    msm_rtb.filter=0x237 \
    service_locator.enable=1 \
    androidboot.usbcontroller=a600000.dwc3 \
    swiotlb=0 \
    loop.max_part=7 \
    cgroup.memory=nokmem,nosocket \
    pcie_ports=compat \
    iptable_raw.raw_before_defrag=1 \
    ip6table_raw.raw_before_defrag=1 \
    binder.impl=rust \
    iommu.strict=1 \
    deferred_probe_timeout=30 \
    fw_devlink.sync_state=timeout \
    clk_ignore_unused \
    pd_ignore_unused \
    irqchip.gicv3_pseudo_nmi=1
# clk/pd_ignore_unused: 6.12 gates unused clocks/power domains before the
# display driver takes the bootloader splash, which can kill the panel.
# deferred_probe_timeout+fw_devlink.sync_state: let unconnected suppliers
# sync_state so interconnect/DDR votes don't get stuck at boot-time max.
# pseudo_nmi: lets the hard lockup detector catch hangs with IRQs masked.
BOARD_KERNEL_PAGESIZE    := 4096
BOARD_RAMDISK_USE_LZ4 := true

# kernel/msm-5.4 (old qti_kernel_headers source) isn't part of this port; point at our 6.12 exported UAPI headers instead.
TARGET_BOARD_KERNEL_HEADERS := device/qcom/lahaina-kernel/kernel-headers

# Kernel (prebuilt from the spacewar-6.12 branches)
KERNEL_PREBUILT_DIR := device/qcom/lahaina-kernel
BOARD_KERNEL_IMAGE_NAME := Image
TARGET_PREBUILT_KERNEL := $(KERNEL_PREBUILT_DIR)/Image
TARGET_PREBUILT_KERNEL_HEADERS := $(TARGET_BOARD_KERNEL_HEADERS)
# Source dir only serves headers_install; the kernel itself stays prebuilt.
TARGET_KERNEL_SOURCE := $(DEVICE_PATH)/kernel-src
TARGET_KERNEL_CONFIG := lahaina_defconfig
TARGET_FORCE_PREBUILT_KERNEL := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(KERNEL_PREBUILT_DIR)/dtbs
BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_PREBUILT_DIR)/dtbo.img
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(addprefix $(KERNEL_PREBUILT_DIR)/modules/,$(file < $(KERNEL_PREBUILT_DIR)/boot.modules.load))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(file < $(KERNEL_PREBUILT_DIR)/boot.modules.load)
BOARD_VENDOR_KERNEL_MODULES := $(filter-out $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES),$(wildcard $(KERNEL_PREBUILT_DIR)/modules/*.ko))
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(file < $(KERNEL_PREBUILT_DIR)/vendor.modules.load)

# OTA
TARGET_OTA_ASSERT_DEVICE := Spacewar|spacewar

# Partitions - A/B
AB_OTA_PARTITIONS := boot dtbo odm product system system_ext vendor vendor_dlkm vendor_boot vbmeta vbmeta_system
AB_OTA_UPDATER := true

# Partitions - Dynamic
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := product system system_ext odm vendor vendor_dlkm

# Partitions - Filesystems
BOARD_EXT4_SHARE_DUP_BLOCKS := true
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_F2FS := true

# Partitions - Metadata
BOARD_USES_METADATA_PARTITION := true

# Partitions - Paths
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor

# Partitions - Sizes
BOARD_BOOTIMAGE_PARTITION_SIZE := 0x06000000
BOARD_DTBOIMG_PARTITION_SIZE := 0x1800000
BOARD_FLASH_BLOCK_SIZE := 131072 # (BOARD_KERNEL_PAGESIZE * 32)
BOARD_KERNEL-GKI_BOOTIMAGE_PARTITION_SIZE := $(BOARD_BOOTIMAGE_PARTITION_SIZE)
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 6438256640
BOARD_SUPER_PARTITION_SIZE := 6442450944
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 0x06000000

# PowerShare
TARGET_POWERSHARE_NODE := /sys/class/qcom-battery/wireless_boost_en

# Properties
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/properties/system.prop
TARGET_PRODUCT_PROP := $(DEVICE_PATH)/properties/product.prop
TARGET_ODM_PROP := $(DEVICE_PATH)/properties/odm.prop
TARGET_VENDOR_PROP := $(DEVICE_PATH)/properties/vendor.prop

# Radio
ADD_RADIO_FILES := true

# Recovery
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
TARGET_NO_RECOVERY := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/init/fstab.default

# SELinux
-include vendor/aospa/sepolicy/libion/sepolicy.mk
# Own copy of QC lahaina policy (stock one redeclares vendor_hal_perf2_service).
# BOARD_SEPOLICY_DIRS is ordered after QC common, which declares the types.
TARGET_SEPOLICY_DIR := phone1
BOARD_SEPOLICY_DIRS += \
    $(DEVICE_PATH)/sepolicy/qcom/generic \
    $(DEVICE_PATH)/sepolicy/qcom/qva
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/private

# UFS
#namespace definition for librecovery_updater
#differentiate legacy 'sg' or 'bsg' framework
SOONG_CONFIG_NAMESPACES += ufsbsg
SOONG_CONFIG_ufsbsg += ufsframework
SOONG_CONFIG_ufsbsg_ufsframework := bsg
