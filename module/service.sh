#!/system/bin/sh
# Android 14+: the system CA store moved to the conscrypt APEX, which the
# /system overlay doesn't reach. Mount a merged copy over it in every namespace.
MODDIR=${0%/*}
CERTS=$MODDIR/system/etc/security/cacerts
APEX=/apex/com.android.conscrypt/cacerts
TMP=/data/local/tmp/mitm-cacerts

[ "$(getprop ro.build.version.sdk)" -ge 34 ] || exit 0
[ -d "$APEX" ] || exit 0

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done

mkdir -p "$TMP"
mountpoint -q "$TMP" || mount -t tmpfs tmpfs "$TMP"
cp -f "$APEX"/* "$TMP"/
cp -f "$CERTS"/* "$TMP"/ 2>/dev/null
chown -R 0:0 "$TMP"
chmod 755 "$TMP"
chmod 644 "$TMP"/*
chcon -R u:object_r:system_file:s0 "$TMP"

bind() { nsenter --mount="/proc/$1/ns/mnt" -- mount --bind "$TMP" "$APEX"; }

mount --bind "$TMP" "$APEX"
# Zygote and every app already forked from it have their own mount namespace.
for Z in $(pidof zygote zygote64); do
  bind "$Z"
  for P in $(ps -o pid= -P "$Z"); do bind "$P"; done
done
