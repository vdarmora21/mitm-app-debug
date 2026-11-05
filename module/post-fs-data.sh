#!/system/bin/sh
# Android 13 and older: Magisk overlays $CERTS onto /system/etc/security/cacerts.
MODDIR=${0%/*}
CERTS=$MODDIR/system/etc/security/cacerts

mkdir -p "$CERTS"
# Promote any CA installed through Settings > Security (user store) to system.
for d in /data/misc/user/*/cacerts-added; do
  [ -d "$d" ] && cp -f "$d"/* "$CERTS"/ 2>/dev/null
done
rm -f "$CERTS/.keep"

chown -R 0:0 "$CERTS"
chmod 755 "$CERTS"
chmod 644 "$CERTS"/* 2>/dev/null
chcon -R u:object_r:system_file:s0 "$CERTS"
