#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}

# ----------------- VARIABLES -----------------
ps_ret="$(ps -Ao pid,args)"
GPU_PARAMS_PATH="/sys/module/ged/parameters"
GPU_FREQ_PATH="/proc/gpufreq"
GPU_FREQ_PATHV2="/proc/gpufreqv2"
PVR_PATH="/sys/module/pvrsrvkm/parameters"
PVR_APPHINT_PATH="/sys/kernel/debug/pvr/apphint"
KGSL_PARAMS_PATH="/sys/class/kgsl/kgsl-3d0"
KGSL_PARAMS_PATH2="/sys/kernel/debug/kgsl/kgsl-3d0/profiling"
ADRENO_PARAMS_PATH="/sys/module/adreno_idler/parameters"
KERNEL_GED_PATH="/sys/kernel/debug/ged/hal"
KERNEL_FPSGO_PATH="/sys/kernel/debug/fpsgo/common"
MALI_PATH="/proc/mali"
PLATFORM_GPU_PATH="/sys/devices/platform/gpu"
GPUFREQ_TRACING_PATH="/sys/kernel/debug/tracing/events/mtk_events/gpu_freq"

# ----------------- HELPER FUNCTIONS -----------------
log() {
    echo "$1"
}

wait_until_boot_completed() {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 3; done
    while [ "$(dumpsys window policy | grep mInputRestricted=true)" != "" ]; do sleep 0.1; done
    while [ ! -d "/sdcard/Android" ]; do sleep 1; done
}

mask_val() {
    touch /data/local/tmp/mount_mask
    for p in $2; do
        if [ -f "$p" ]; then
            umount "$p"
            chmod 0666 "$p"
            echo "$1" >"$p"
            mount --bind /data/local/tmp/mount_mask "$p"
        fi
    done
}

lock_val() {
    for p in $2; do
        if [ -f "$p" ]; then
            chown root:root "$p"
            chmod 0666 "$p"
            echo "$1" >"$p"
            chmod 0444 "$p"
        fi
    done
}

write_val() {
    local file="$1"
    local value="$2"
    if [ -e "$file" ]; then
        chmod +w "$file" 2>/dev/null
        echo "$value" > "$file" && log "Write : $file → $value" || log "Failed to Write : $file"
    fi
}

change_task_cgroup() {
    # $1: task_name, $2: cgroup_name, $3: "cpuset" or "stune"
    local comm
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            echo "$temp_tid" >"/dev/$3/$2/tasks"
        done
    done
}

change_task_nice() {
    # $1: task_name, $2: nice value (relative to 120)
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            renice -n +40 -p "$temp_tid"
            renice -n -19 -p "$temp_tid"
            renice -n "$2" -p "$temp_tid"
        done
    done
}

send_notification() {
    # Notify user of optimization completion
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Celestial-Render-FlowX👾' tag 'Status : Optimization Completed!'" >/dev/null 2>&1
}

# ----------------- OPTIMIZATION SECTIONS -----------------
optimize_gpu_temperature() {
    # Adjust GPU and DDR temperature thresholds ( @Bias_khaliq )
    for THERMAL in /sys/class/thermal/thermal_zone*/type; do
        if grep -E "gpu|ddr" "$THERMAL" > /dev/null; then
          for ZONE in "${THERMAL%/*}"/trip_point_*_temp; do
            CURRENT_TEMP=$(cat "$ZONE")
            if [ "$CURRENT_TEMP" -lt "90000" ]; then
              echo "95000" > "$ZONE"
            fi
          done
        fi
    done
}

optimize_ged_parameters() {
    # Optimize GPU parameters via GED driver
    if [ -d "$GPU_PARAMS_PATH" ]; then
        write_val "$GPU_PARAMS_PATH/gpu_cust_boost_freq" "2000000"
        write_val "$GPU_PARAMS_PATH/gpu_cust_upbound_freq" "2000000" 
        write_val "$GPU_PARAMS_PATH/ged_smart_boost" "1000"
        write_val "$GPU_PARAMS_PATH/gpu_bottom_freq" "800000"
        write_val "$GPU_PARAMS_PATH/boost_upper_bound" "100"
        write_val "$GPU_PARAMS_PATH/gx_dfps" "$(dumpsys display | grep -oE 'fps=[0-9]+' | awk -F '=' '{print $2}' | head -n 1)"
        write_val "$GPU_PARAMS_PATH/g_gpu_timer_based_emu" "1"
        write_val "$GPU_PARAMS_PATH/boost_gpu_enable" "1"
        write_val "$GPU_PARAMS_PATH/ged_boost_enable" "1"
        write_val "$GPU_PARAMS_PATH/enable_gpu_boost" "1"
        write_val "$GPU_PARAMS_PATH/gx_game_mode" "1"
        write_val "$GPU_PARAMS_PATH/gx_boost_on" "1"
        write_val "$GPU_PARAMS_PATH/boost_amp" "1"
        write_val "$GPU_PARAMS_PATH/gx_3D_benchmark_on" "1"
        write_val "$GPU_PARAMS_PATH/is_GED_KPI_enabled" "1"
        write_val "$GPU_PARAMS_PATH/gpu_dvfs_enable" "1"
        write_val "$GPU_PARAMS_PATH/ged_monitor_3D_fence_disable" "0"
        write_val "$GPU_PARAMS_PATH/ged_monitor_3D_fence_debug" "0"
        write_val "$GPU_PARAMS_PATH/ged_log_perf_trace_enable" "0"
        write_val "$GPU_PARAMS_PATH/ged_log_trace_enable" "0"
        write_val "$GPU_PARAMS_PATH/ged_monitor_3D_fence_debug" "0"
        write_val "$GPU_PARAMS_PATH/gpu_bw_err_debug" "0"
        write_val "$GPU_PARAMS_PATH/gx_frc_mode" "0"
        write_val "$GPU_PARAMS_PATH/gpu_idle" "0"
        write_val "$GPU_PARAMS_PATH/gpu_debug_enable" "0"
    fi
}

optimize_gpu_frequency() {
    # Optimize GPU frequency configurations
    gpu_freq="$(cat $GPU_FREQ_PATH/gpufreq_opp_dump | grep -o 'freq = [0-9]*' | sed 's/freq = //' | sort -nr | head -n 1)"
    if [ -d "$GPU_FREQ_PATH" ]; then
        for i in $(seq 0 8); do
            lock_val "$i 0 0" "$GPU_FREQ_PATH/limit_table"
        done
        lock_val "$GPU_FREQ_PATH/limit_table" "1 1 1"
        write_val "$GPU_FREQ_PATH/gpufreq_limited_thermal_ignore" "1"
        write_val "$GPU_FREQ_PATH/gpufreq_limited_oc_ignore" "1"
        write_val "$GPU_FREQ_PATH/gpufreq_limited_low_batt_volume_ignore" "1"
        write_val "$GPU_FREQ_PATH/gpufreq_limited_low_batt_volt_ignore" "1"
        write_val "$GPU_FREQ_PATH/gpufreq_fixed_freq_volt" "0"
        write_val "$GPU_FREQ_PATH/gpufreq_opp_freq" "$gpu_freq"
        write_val "$GPU_FREQ_PATH/gpufreq_opp_stress_test" "0"
        write_val "$GPU_FREQ_PATH/gpufreq_power_dump" "0"
        write_val "$GPU_FREQ_PATH/gpufreq_power_limited" "0"
    fi
}

optimize_gpu_frequencyv2() {
    # Optimize GPU frequency v2 configurations (Matt Yang)（吟惋兮改)
    gpu_freq="$(cat $GPU_FREQ_PATHV2/gpu_working_opp_table | awk '{print $3}' | sed 's/,//g' | sort -nr | head -n 1)"
	gpu_volt="$(cat $GPU_FREQ_PATHV2/gpu_working_opp_table | awk -v freq="$freq" '$0 ~ freq {gsub(/.*, volt: /, ""); gsub(/,.*/, ""); print}')"
    if [ -d "$GPU_FREQ_PATHV2" ]; then
		lock_val "$GPU_FREQ_PATHV2/fix_custom_freq_volt" "${gpu_freq} ${gpu_volt}"
        lock_val "$GPU_FREQ_PATHV2/aging_mode" "disable"
        for i in $(seq 0 10); do
            lock_val "$i 0 0" "$GPU_FREQ_PATHV2/limit_table"
        done
        lock_val "$GPU_FREQ_PATHV2/limit_table" "3 1 1"
    fi
}

optimize_pvr_settings() {
    # Adjust PowerVR settings for performance
    if [ -d "$PVR_PATH" ]; then
        write_val "$PVR_PATH/gpu_power" "2"
        write_val "$PVR_PATH/HTBufferSizeInKB" "256"
        write_val "$PVR_PATH/DisableClockGating" "0"
        write_val "$PVR_PATH/EmuMaxFreq" "2"
        write_val "$PVR_PATH/EnableFWContextSwitch" "1"
        write_val "$PVR_PATH/gPVRDebugLevel" "0"
        write_val "$PVR_PATH/gpu_dvfs_enable" "1"
    fi
}

optimize_pvr_apphint() {
    # Additional settings power vr apphint
    if [ -d "$PVR_APPHINT_PATH" ]; then
        write_val "$PVR_APPHINT_PATH/CacheOpConfig" "1"
        write_val "$PVR_APPHINT_PATH/CacheOpUMKMThresholdSize" "512"
        write_val "$PVR_APPHINT_PATH/EnableFTraceGPU" "0"
        write_val "$PVR_APPHINT_PATH/HTBOperationMode" "2"
        write_val "$PVR_APPHINT_PATH/TimeCorrClock" "1"
        write_val "$PVR_APPHINT_PATH/0/DisableFEDLogging" "0"
        write_val "$PVR_APPHINT_PATH/0/EnableAPM" "0"
    fi
}

optimize_kgsl_settings() {
    # Additional kgsl settings to stabilize the gpu (Matt Yang)（吟惋兮改)
    if [ -d "$KGSL_PARAMS_PATH" ]; then
        MIN_PWRLVL=$(($(cat $KGSL_PARAMS_PATH/num_pwrlevels) - 1))
        mask_val "$MIN_PWRLVL" "$KGSL_PARAMS_PATH/default_pwrlevel"
        mask_val "$MIN_PWRLVL" "$KGSL_PARAMS_PATH/min_pwrlevel"
        mask_val "0" "$KGSL_PARAMS_PATH/thermal_pwrlevel"
        mask_val "0" "$KGSL_PARAMS_PATH/force_bus_on"
        mask_val "0" "$KGSL_PARAMS_PATH/force_clk_on"
        mask_val "0" "$KGSL_PARAMS_PATH/force_no_nap"
        mask_val "0" "$KGSL_PARAMS_PATH/force_rail_on"
        mask_val "0" "$KGSL_PARAMS_PATH/throttling"
    fi
}

optimize_kernel_ged_settings() {
    # Additional kernel-ged GPU optimizations
    if [ -d "$KERNEL_GED_PATH" ]; then
         write_val "$KERNEL_GED_PATH/gpu_boost_level" "2"
    fi
}

optimize_kernel_fpsgo_settings() {
    # Additional kernel-fpsgo GPU optimizations
    if [ -d "$KERNEL_FPSGO_PATH" ]; then
        write_val "$KERNEL_FPSGO_PATH/gpu_block_boost" "100 120 0"
    fi
}

optimize_mali_driver() {
    # Mali GPU-specific optimizations ( @Bias_khaliq )
    if [ -d "$MALI_PATH" ]; then
         write_val "$MALI_PATH/dvfs_enable" "1"
         write_val "$MALI_PATH/max_clock" "550000"
         write_val "$MALI_PATH/min_clock" "100000"
    fi
}

optimize_platform_gpu() {
    # Additional GPU settings for MediaTek ( @Bias_khaliq )
    if [ -d "$PLATFORM_GPU_PATH" ]; then
         write_val "$PLATFORM_GPU_PATH/dvfs_enable" "1"
         write_val "$PLATFORM_GPU_PATH/gpu_busy" "1"
    fi
}

optimize_task_cgroup_nice() {
    # thx to (Matt Yang)（吟惋兮改)
    change_task_cgroup "surfaceflinger" "" "cpuset"
    change_task_cgroup "system_server" "foreground" "cpuset"
    change_task_cgroup "netd|allocator" "foreground" "cpuset"
    change_task_cgroup "hardware.media.c2|vendor.mediatek.hardware" "background" "cpuset"
    change_task_cgroup "aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|disp_feature|hif_thread|main_thread|rx_thread|ged_" "background" "cpuset"
    change_task_cgroup "pp_event|crtc_" "background" "cpuset"
    change_task_cgroup "android.hardware.graphics.composer" "top-app" "cpuset"
    change_task_cgroup "android.hardware.graphics.composer" "foreground" "stune"
    change_task_nice "android.hardware.graphics.composer" "-15"
}

final_optimize_gpu() {
    # disable pvr tracing
    for pvrtracing in $(find /sys/kernel/debug/tracing/events/pvr_fence -name 'enable'); do
        if [ -d "/sys/kernel/debug/tracing/events/pvr_fence" ]; then
            write_val "$pvrtracing" "0"
        fi
    done
        
    # disable gpu tracing for mtk
    write_val "$GPUFREQ_TRACING_PATH/enable" "0"
   
    # disable kgsl profiling
    write_val "$KGSL_PARAMS_PATH2/enable" "0"
    
    # disable adreno idler
    write_val "$ADRENO_PARAMS_PATH/adreno_idler_active" "0"
    
   # Disable auto voltage scaling for mtk
    lock_val "0" "$GPU_FREQ_PATH/gpufreq_aging_enable"
}

cleanup_memory() {
    # Clean up memory and cache
     write_val "/proc/sys/vm/drop_caches" "3"
     write_val "/proc/sys/vm/compact_memory" "1"
}

# ----------------- MAIN EXECUTION -----------------
main() {
    wait_until_boot_completed
    optimize_gpu_temperature
    optimize_ged_parameters
    optimize_gpu_frequency
    optimize_gpu_frequencyv2
    optimize_pvr_settings
    optimize_pvr_apphint
    optimize_kgsl_settings
    optimize_kernel_ged_settings
    optimize_kernel_fpsgo_settings
    optimize_mali_driver
    optimize_platform_gpu
    optimize_task_cgroup_nice
    cleanup_memory
}

# Main Execution & Exit script successfully
sync && main && send_notification && exit 0

# This script will be executed in late_start service mode
