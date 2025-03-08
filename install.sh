#!/bin/sh
SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true

REPLACE="
"

# array / variabel
NAME="Celestial-Render-FlowX | Kzyo"
VERSION="1.2S"
ANDROIDVERSION=$(getprop ro.build.version.release)
DATE="Mon 11 Nov 2024"
DEVICES=$(getprop ro.product.board)
MANUFACTURER=$(getprop ro.product.manufacturer)
API=$(getprop ro.build.version.sdk)

# trimming
trim_partition () {
    fstrim -v /system
    sleep 0.1
    fstrim -v /vendor
    sleep 0.1
    fstrim -v /data
    sleep 0.1
    fstrim -v /cache
    sleep 0.1
    fstrim -v /metadata
    sleep 0.1
    fstrim -v /odm
    sleep 0.1
    fstrim -v /system_ext
    sleep 0.1
    fstrim -v /product
}

cleanup_gpu() {
for i in "$(find /data -type f -name '*shader*')"; do
    rm -f $i
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

# Delete Logs
rm -rf /data/{anr,log,tombstones,log_other_mode}/* \
       /cache/*.{apk,tmp} \
       /dev/log/* \
       /data/system/{dropbox,usagestats,package_cache}/* \
       /sys/kernel/debug/* \
       /data/local/tmp* \
       /data/dalvik-cache \
       /data/media/0/{DCIM,Pictures,Music,Movies}/.thumbnails \
       /data/media/0/{mtklog,MIUI/Gallery,MIUI/.debug_log,MIUI/BugReportCache} \
       /data/vendor/thermal/{config,*.dump,*_history*.dump}
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
ui_print "- Clean Gpu Shader"
cleanup_gpu &>/dev/null

# Set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
