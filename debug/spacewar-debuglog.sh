#!/system/bin/sh
#
# Boot debugging for a boot that hangs or resets.
#
# Our pstore corrupts/truncates on reset, so stream kmsg and logcat to
# /metadata as they are produced instead. Keeps only the current boot, capped
# at ~5MB since /metadata is only 11MB and also holds vold's keys and OTA state.
# Dumps blocked-task (sysrq-w) and all-CPU (sysrq-l) stacks periodically.

BASE=/metadata/spacewar-debug

mkdir -p $BASE
# Only the current boot fits in /metadata; pull the logs before rebooting.
# Keep the last boot's kernel and crash logs (~1.3 MB) so a boot loop leaves evidence.
# A boot that still has tipc_try crashed with tipc loaded: keep its logs for good.
if [ -d $BASE/boot0 ]; then
    if [ -e $BASE/tipc_try ] && [ ! -e $BASE/tipc_bad ]; then
        rm -rf $BASE/crash-tipc
        mkdir -p $BASE/crash-tipc
        cp $BASE/boot0/dmesg.txt $BASE/boot0/kmsg.txt $BASE/boot0/crash.txt $BASE/crash-tipc/ 2>/dev/null
    fi
    rm -rf $BASE/prev
    mkdir -p $BASE/prev
    mv $BASE/boot0/dmesg.txt $BASE/boot0/kmsg.txt $BASE/boot0/crash.txt $BASE/prev/ 2>/dev/null
fi
rm -rf $BASE/boot*
DIR=$BASE/boot0
mkdir -p $DIR

echo 1 > /proc/sys/kernel/sysrq
echo on > /proc/sys/kernel/printk_devkmsg

# USB role/typec tracing: the gadget pulls up but DWC3 drops to low power 2 s later
mount -t debugfs none /sys/kernel/debug 2>/dev/null
for q in "module ucsi_glink +p" "file drivers/usb/typec/* +p" "file drivers/usb/common/usb-role-switch.c +p"; do
    echo "$q" > /sys/kernel/debug/dynamic_debug/control 2>/dev/null
done

# Flush every 100 ms: a hard reset power-cycles DDR, so pstore can't keep the last lines
(while true; do sync; sleep 0.1; done) &

# Kernel log: first 2 MB, then a full ring snapshot every tick (reads die when the ring wraps)
(cat /dev/kmsg | grep -v 'avc: ' | head -c 786432 > $DIR/kmsg.txt) &

# logcat, retried until logd is up. Rotated at 1 MB, 3 files at most.
(
    while true; do
        logcat -b main,system,events -v threadtime -f $DIR/logcat.txt -r 384 -n 3 \
            SystemServiceRegistry:S am_wtf:S BootAnimation:S \
            audioadsprpcd:S sscrpcd:S auditd:S android.hardwar:S
        sleep 1
    done
) &

# First 4 MB of logcat, never rotated, so early HAL errors survive the later spam
(
    while true; do
        logcat -b all -v threadtime adsprpcd:S cdsprpcd:S audioadsprpcd:S sscrpcd:S auditd:S android.hardwar:S '*:V'
        sleep 1
    done | head -c 1572864 > $DIR/logcat-early.txt
) &

# Crashes only, small but the most useful
(
    while true; do
        logcat -b crash -v threadtime -f $DIR/crash.txt -r 256 -n 1
        sleep 1
    done
) &

i=0
while [ $i -lt 120 ]; do
    echo "spacewar-debug: tick $i" > /dev/kmsg
    if [ $((i % 6)) -eq 0 ]; then
        echo w > /proc/sysrq-trigger
        echo l > /proc/sysrq-trigger
    fi
    (
        timeout 4 ps -A -o PID,PPID,STAT,WCHAN,NAME > $DIR/ps.txt.new 2>&1
        mv $DIR/ps.txt.new $DIR/ps.txt
        grep -E " D | R " $DIR/ps.txt | while read l; do
            echo "spacewar-debug: $i $l" > /dev/kmsg
        done
        timeout 4 dmesg 2>&1 | grep -v 'avc: ' > $DIR/dmesg.txt.new && mv $DIR/dmesg.txt.new $DIR/dmesg.txt
        timeout 4 getprop > $DIR/props.txt.new 2>&1
        mv $DIR/props.txt.new $DIR/props.txt
    ) &
    # Perf state at a few points, for lag diagnosis
    case $i in 8|20|40|70|100)
        (
            P=$DIR/perf.txt
            echo "=== tick $i uptime $(cat /proc/uptime) load $(cat /proc/loadavg)" >> $P
            for c in 0 4 7; do
                d=/sys/devices/system/cpu/cpu$c/cpufreq
                echo "cpu$c cur=$(cat $d/scaling_cur_freq 2>&1) min=$(cat $d/scaling_min_freq 2>&1) max=$(cat $d/scaling_max_freq 2>&1) gov=$(cat $d/scaling_governor 2>&1)" >> $P
            done
            echo "online=$(cat /sys/devices/system/cpu/online)" >> $P
            for d in /sys/class/devfreq/*; do
                echo "devfreq ${d##*/} cur=$(cat $d/cur_freq 2>&1) min=$(cat $d/min_freq 2>&1) max=$(cat $d/max_freq 2>&1) gov=$(cat $d/governor 2>&1)" >> $P
            done
            k=/sys/class/kgsl/kgsl-3d0
            echo "gpu clk=$(cat $k/gpuclk 2>&1) busy=$(cat $k/gpu_busy_percentage 2>&1) maxclk=$(cat $k/max_gpuclk 2>&1) temp=$(cat $k/temp 2>&1)" >> $P
            for z in /sys/class/thermal/thermal_zone*; do
                echo "thermal $(cat $z/type 2>&1)=$(cat $z/temp 2>&1)" >> $P
            done
            for r in /sys/class/remoteproc/*; do
                echo "rproc $(cat $r/name 2>&1) state=$(cat $r/state 2>&1)" >> $P
            done
            echo "wifi mods: $(lsmod | grep -E 'wlan|icnss|cfg80211|mac80211|cnss' | cut -d' ' -f1 | tr '\n' ' ')" >> $P
            mount -t debugfs none /sys/kernel/debug 2>/dev/null
            echo "deferred: $(cat /sys/kernel/debug/devices_deferred 2>&1 | tr '\n' ';')" >> $P
            echo "wpss_boot: $(ls /sys/kernel/icnss/ 2>&1 | tr '\n' ' ')" >> $P
            grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|Dirty|Writeback:" /proc/meminfo >> $P
            timeout 6 top -b -n 1 -m 15 >> $P 2>&1
            sync
        ) &
        ;;
    esac
    if [ $i -eq 6 ]; then
        (
            for n in vendor.qti.hardware.display.composer-service surfaceflinger vendor.qti.hardware.display.allocator-service; do
                for pid in $(pidof $n); do
                    echo "=== $n $pid" >> $DIR/native-bt.txt
                    for t in /proc/$pid/task/*; do
                        echo "tid ${t##*/} $(cat $t/comm) wchan=$(cat $t/wchan)" >> $DIR/native-bt.txt
                    done
                    timeout 15 debuggerd -b $pid >> $DIR/native-bt.txt 2>&1
                done
            done
        ) &
    fi
    (
        # modules load after the script starts, so retry the dyndbg enables every tick (until tick 12)
        if [ $i -lt 12 ]; then
            for q in "module ucsi_glink +p" "file drivers/usb/typec/* +p" "file drivers/usb/common/usb-role-switch.c +p"; do
                echo "$q" > /sys/kernel/debug/dynamic_debug/control 2>/dev/null
            done
        fi
        {
            echo "=== tick $i $(cat /proc/uptime)"
            for r in /sys/class/usb_role/*; do echo "role ${r##*/}=$(cat $r/role 2>&1)"; done
            for u in /sys/class/udc/*; do echo "udc ${u##*/} state=$(cat $u/state 2>&1) speed=$(cat $u/current_speed 2>&1)"; done
            echo "gadget UDC=$(cat /config/usb_gadget/g1/UDC 2>&1)"
            for t in /sys/class/typec/*; do echo "typec ${t##*/} data=$(cat $t/data_role 2>&1) power=$(cat $t/power_role 2>&1)"; done
            for p in /sys/class/power_supply/*; do echo "ps ${p##*/} type=$(cat $p/type 2>&1) online=$(cat $p/online 2>&1)"; done
        } >> $DIR/usb.txt
    ) &
    sleep 5
    i=$((i + 1))
done
