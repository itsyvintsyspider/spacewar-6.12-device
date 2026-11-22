$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/nothing/phone1/device.mk)
$(call inherit-product, vendor/neoteric/target/product/neoteric-target.mk)

PRODUCT_NAME := neoteric_phone1
PRODUCT_DEVICE := phone1
PRODUCT_BRAND := Nothing
PRODUCT_MODEL := Phone (1)
PRODUCT_MANUFACTURER := Nothing
