#!/system/bin/sh
#
# Load tipc (netmgrd opens AF_TIPC) with a boot-loop latch.
# A live tipc + netmgrd start once bootlooped the phone until a data wipe.
# tipc_try is set before the load and cleared 150 s after boot completes; if
# the next boot still sees it, the last boot crashed: mark tipc_bad and skip.

B=/metadata/spacewar-debug
mkdir -p $B

[ -e $B/tipc_bad ] && exit 0
if [ -e $B/tipc_try ]; then
    rm -f $B/tipc_try
    touch $B/tipc_bad
    sync
    exit 0
fi

touch $B/tipc_try
sync
/system/bin/insmod /vendor_dlkm/lib/modules/tipc.ko
