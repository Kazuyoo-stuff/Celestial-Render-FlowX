#!/bin/sh
SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true

REPLACE="
"

# array / variabel
NAME="Celestial-Render-FlowX | Kzyo"
VERSION="1.3S"
ANDROIDVERSION=$(getprop ro.build.version.release)
DATE="Mon 11 Nov 2024"
DEVICES=$(getprop ro.product.board)
MANUFACTURER=$(getprop ro.product.manufacturer)
API=$(getprop ro.build.version.sdk)

# trimming
trim_partition () {
    for partition in system vendor data cache metadata odm system_ext product; do
        fstrim -v "/$partition"
        sleep 0.1
    done
}

# delete trash & log by @Bias_khaliq
delete_trash_logs () {
# Clear trash on /data/data
for DIR in /data/data/*; do
  if [ -d "${DIR}" ]; then
    rm -rf ${DIR}/cache/*
    rm -rf ${DIR}/no_backup/*
    rm -rf ${DIR}/app_webview/*
    rm -rf ${DIR}/code_cache/*
  fi
done

# Delete cache
find /data/{anr,log,tombstones,log_other_mode}/* -delete
find /cache/*.{apk,tmp} -delete
find /dev/log/* -delete
find /sys/kernel/debug/* -delete
find /data/local/tmp/* -delete
find /data/dalvik-cache/* -delete
find /data/media/0/{DCIM,Pictures,Music,Movies}/.thumbnails -delete
find /data/media/0/{mtklog,MIUI/Gallery,MIUI/.debug_log,MIUI/BugReportCache} -delete
find /data/vendor/thermal/{config,*.dump,*_history*.dump} -delete
find /sdcard/Android/data/*/cache -delete
}

sleep 0.2
ui_print ""
ui_print "░█▀▀█ ── ░█▀▀█ ░█▀▀▀ ░█─── ░█──░█ ▀▄░▄▀ 
░█─── ▀▀ ░█▄▄▀ ░█▀▀▀ ░█─── ░█░█░█ ─░█── 
░█▄▄█ ── ░█─░█ ░█─── ░█▄▄█ ░█▄▀▄█ ▄▀░▀▄"
ui_print ""
sleep 0.5
ui_print "      improvements to the gpu."
ui_print ""
sleep 0.2
ui_print "***************************************"
ui_print "- Name            : ${NAME}"
sleep 0.2
ui_print "- Version         : ${VERSION}"
sleep 0.2
ui_print "- Android Version : ${ANDROIDVERSION}"
sleep 0.2
ui_print "- Build Date      : ${DATE}"
sleep 0.2
ui_print "***************************************"
ui_print "- Devices         : ${DEVICES}"
sleep 0.2
ui_print "- Manufacturer    : ${MANUFACTURER}"
ui_print "***************************************"
sleep 0.2
ui_print "- Extracting module files"
sleep 2
unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
ui_print "- Trimming up Partitions"
sleep 2
trim_partition &>/dev/null
sleep 0.5
ui_print "- Delete trash and logs"
delete_trash_logs
sleep 0.5

# Set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
