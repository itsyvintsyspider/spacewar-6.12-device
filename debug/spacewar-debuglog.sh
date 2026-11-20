#!/system/bin/sh
#
# Boot debugging for a boot that hangs or resets.
#
# Our pstore corrupts/truncates on reset, so stream kmsg and logcat to
# /metadata as they're produced instead. Keeps the last 2 boots, capped
# at ~6MB total since /metadata also holds vold's keys and OTA state.
# Dumps blocked-task (sysrq-w) and all-CPU (sysrq-l) stacks periodically.

BASE=/metadata/spacewar-debug

mkdir -p $BASE
rm -rf $BASE/boot1 $BASE/boot2 $BASE/boot3 $BASE/boot4
[ -d $BASE/boot0 ] && mv $BASE/boot0 $BASE/boot1
DIR=$BASE/boot0
mkdir -p $DIR

echo 1 > /proc/sys/kernel/sysrq
echo on > /proc/sys/kernel/printk_devkmsg

# Kernel log, up to 2 MB
(cat /dev/kmsg | head -c 2097152 > $DIR/kmsg.txt) &

# logcat, retried until logd is up. Rotated at 1 MB, 3 files at most.
(
    while true; do
        logcat -b main,system,events -v threadtime -f $DIR/logcat.txt -r 1024 -n 2 \
            SystemServiceRegistry:S am_wtf:S BootAnimation:S
        sleep 1
    done
) &

# Crashes only, small but the most useful
(
    while true; do
        logcat -b crash -v threadtime -f $DIR/crash.txt -r 512 -n 1
        sleep 1
    done
) &

i=0
while [ $i -lt 120 ]; do
    echo "spacewar-debug: tick $i" > /dev/kmsg
    echo w > /proc/sysrq-trigger
    echo l > /proc/sysrq-trigger
    (
        timeout 4 ps -A -o PID,PPID,STAT,WCHAN,NAME > $DIR/ps.txt.new 2>&1
        mv $DIR/ps.txt.new $DIR/ps.txt
        grep -E " D | R " $DIR/ps.txt | while read l; do
            echo "spacewar-debug: $i $l" > /dev/kmsg
        done
        timeout 4 getprop > $DIR/props.txt.new 2>&1
        mv $DIR/props.txt.new $DIR/props.txt
    ) &
    sleep 5
    i=$((i + 1))
done
