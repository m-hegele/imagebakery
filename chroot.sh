#!/bin/bash
# chroot customized raspbian image for revolution pi

if [ "$#" != 1 ] ; then
	echo 1>&1 "Usage: `basename "$0"` <image>"
	exit 1
fi

if [ ! -x "$(which curl)" ]; then
	echo 1>&1 "Error: Command curl not found."
	exit 1
fi

if [ ! -x "$(which fsck.vfat)" ]; then
	echo 1>&1 "Error: Command fsck.vfat not found."
	exit 1
fi

if [ ! -x "$(which lsof)" ]; then
	echo 1>&1 "Error: Command lsof not found."
	exit 1
fi

PARTED="$(which parted)"
if [ "x$PARTED" = "x" ] ; then
	echo 1>&1 "Error: Command parted not found."
	exit 1
fi

if [ ! -x "$PARTED" ] ; then
	echo 1>&1 "Error: Command $PARTED is not executable."
	exit 1
fi

set -ex

# pivot to new PID namespace
if [ $$ != 2 ] && [ -x /usr/bin/newpid ] ; then
	exec /usr/bin/newpid "$0" "$@"
fi

IMAGEDIR=`mktemp -d -p /tmp img.XXXXXXXX`
BAKERYDIR=$(dirname "$0")
LOOPDEVICE=$(losetup -f)

cleanup_umount() {
	if [ -e "$IMAGEDIR" ] ; then
		lsof -t "$IMAGEDIR" | xargs --no-run-if-empty kill
	fi
	if [ -e "$IMAGEDIR/usr/bin/qemu-arm-static" ] ; then
		rm -f "$IMAGEDIR/usr/bin/qemu-arm-static"
	fi
	if mountpoint -q "$IMAGEDIR/tmp/debs-to-install" ; then
		umount "$IMAGEDIR/tmp/debs-to-install"
	fi
	if [ -e "$IMAGEDIR/tmp/debs-to-install" ] ; then
		rmdir "$IMAGEDIR/tmp/debs-to-install"
	fi
	if mountpoint -q "$IMAGEDIR/boot" ; then
		umount "$IMAGEDIR/boot"
	fi
	if mountpoint -q "$IMAGEDIR/proc" ; then
		umount "$IMAGEDIR/proc"
	fi
	if mountpoint -q "$IMAGEDIR" ; then
		umount "$IMAGEDIR"
	fi
	if [ -d "$IMAGEDIR" ] ; then
		rmdir "$IMAGEDIR"
	fi
}

cleanup_losetup() {
	if [ -e "$LOOPDEVICE"p1 ] ; then
		delpart "$LOOPDEVICE" 1
	fi
	if [ -e "$LOOPDEVICE"p2 ] ; then
		delpart "$LOOPDEVICE" 2
	fi
	if losetup "$LOOPDEVICE" 2>/dev/null ; then
		losetup -d "$LOOPDEVICE"
	fi
}

cleanup() {
	cleanup_umount
	cleanup_losetup
}

trap cleanup ERR SIGINT

# mount ext4 + FAT filesystems
losetup "$LOOPDEVICE" "$1"
partprobe "$LOOPDEVICE"
mount "$LOOPDEVICE"p2 "$IMAGEDIR"
mount "$LOOPDEVICE"p1 "$IMAGEDIR/boot"

# see https://wiki.debian.org/QemuUserEmulation
if [ -e /usr/bin/qemu-arm-static ] ; then
	cp /usr/bin/qemu-arm-static "$IMAGEDIR/usr/bin"
fi

# Move ld.so.preload until installation is finished. Otherwise we get errors
# from ld.so:
#   ERROR: ld.so: object '/usr/lib/arm-linux-gnueabihf/libarmmem-${PLATFORM}.so'
#   from /etc/ld.so.preload cannot be preloaded (cannot open shared object file): ignored.
mv "$IMAGEDIR/etc/ld.so.preload" "$IMAGEDIR/etc/ld.so.preload.bak" || true


# mount local packages
if [ "$(/bin/ls "$BAKERYDIR/debs-to-install/"*.deb 2>/dev/null)" ] ; then
	mkdir "$IMAGEDIR/tmp/debs-to-install"
	mount --bind "$BAKERYDIR/debs-to-install" "$IMAGEDIR/tmp/debs-to-install"
fi

# java command requires a mounted procfs (installation)
mount -t proc procfs "$IMAGEDIR/proc"

chroot "$IMAGEDIR"
#chroot "$IMAGEDIR" "eval \$(ssh-agent)"
#chroot "$IMAGEDIR" ps -p $SSH_AGENT_PID > /dev/null && running

# restore ld.so.preload
mv "$IMAGEDIR/etc/ld.so.preload.bak" "$IMAGEDIR/etc/ld.so.preload"

cleanup_umount

fsck.vfat -a "$LOOPDEVICE"p1
sleep 2
fsck.ext4 -f -p "$LOOPDEVICE"p2
sleep 2

cleanup_losetup
