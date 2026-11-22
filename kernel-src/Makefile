# Stand-in for the kernel tree: Neoteric's generated_kernel_includes runs
# headers_install here, so serve our prebuilt UAPI headers instead.
VERSION = 6
PATCHLEVEL = 12

headers_install:
	mkdir -p $(O)
	cp -a $(CURDIR)/../../../qcom/lahaina-kernel/kernel-headers/usr $(O)/
	# arm64 sigcontext.h breaks 32-bit builds; bionic ships its own asm headers
	rm -f $(O)/usr/include/asm/sigcontext.h
