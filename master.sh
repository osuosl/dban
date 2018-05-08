#!/bin/bash
set -eu

BR2_CONFIG=buildroot/.config

test ! -d $(readlink -e ./buildroot) && echo "$0: Incorrect working directory: ./buildroot/ is missing. " && exit 1
test ! -r "$BR2_CONFIG" && echo "$0: $BR2_CONFIG is missing." && exit 2

eval $(grep -E '^BR2_(ARCH|GCC_TARGET_ARCH|LINUX_KERNEL_VERSION)=' "$BR2_CONFIG")
. dban.def

BR2_BZIMAGE="buildroot/output/images/bzImage"

OUTDIR=isoroot/${BR2_ARCH}/output
INDIR=isoroot/${BR2_ARCH}/input
VOLUME="DBAN v$DBAN_VERSION ($BR2_ARCH)"

ISOHYBRID=0
PRERELEASE=0

GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || true)
if [ -z "$GIT_TAG" -o "${GIT_TAG%/*}" = "nightly" ]; then
	GIT_VERSION=$(git log -1 --date=format:"%Y%m%d" --pretty=format:"%cd-g%h")
	VOLUME="DBAN $GIT_VERSION"
	PRERELEASE=1
fi

BZIMAGE_DIR=

MKISOFS_ARGS=()
case "${BR2_ARCH}" in
	i586)
		test ! -r "$INDIR/isolinux.bin" && echo "$0: $INDIR/isolinux.bin is missing." && exit 3
		MKISOFS_ARGS+=(-b isolinux.bin -c isolinux.cat -no-emul-boot -boot-load-size 4 -boot-info-table)
		MKISOFS_ARGS+=(-V "$VOLUME")
		ISOHYBRID=1
	;;
	powerpc)
		test ! -r "$INDIR/ppc/yaboot" && echo "$0: $INDIR/ppc/yaboot is missing." && exit 3
		MKISOFS_ARGS+=(-chrp-boot -hfs -no-cache-inodes -no-desktop -part -r)
		MKISOFS_ARGS+=(-map "$OUTDIR/ppc/map")
		MKISOFS_ARGS+=(-hfs-bless "$OUTDIR/ppc")
		MKISOFS_ARGS+=(-hfs-volid "$VOLUME")

		BR2_BZIMAGE="buildroot/output/images/zImage"
		BZIMAGE_DIR=ppc
	powerpc64)
		test ! -r "$INDIR/boot/grub/powerpc-ieee1275/core.elf" && echo "$0: $INDIR/boot/grub/powerpc-ieee1275/core.elf is missing." && exit 3
		MKISOFS_ARGS+=(-chrp-boot -no-cache-inodes -no-desktop -part -r)
		MKISOFS_ARGS+=(-map "$OUTDIR/ppc/mapping")
		MKISOFS_ARGS+=(-hfs-bless "$OUTDIR/ppc")
		MKISOFS_ARGS+=(-hfs-volid "$VOLUME")

		BR2_BZIMAGE="buildroot/output/images/zImage"
		BZIMAGE_DIR=ppc
	;;
esac

test ! -r "$BR2_BZIMAGE" && echo "$0: $BR2_BZIMAGE is missing." && exit 4

if [ "$PRERELEASE" = "0" ]; then
	OUTNAME="dban-${DBAN_VERSION}_linux-${BR2_LINUX_KERNEL_VERSION}_${BR2_ARCH}.iso"
else
	OUTNAME="dban-${GIT_VERSION}_linux-${BR2_LINUX_KERNEL_VERSION}_${BR2_ARCH}.iso"
fi

rm -rf $OUTDIR
mkdir -p $OUTDIR
cp -r isoroot/generic/* $OUTDIR/
cp -r $INDIR/* $OUTDIR/
cp -v "$BR2_BZIMAGE" "$OUTDIR/$BZIMAGE_DIR/dban.bzi"
mkisofs -o "$OUTNAME" "${MKISOFS_ARGS[@]}" "$OUTDIR"
[ "$ISOHYBRID" = "1" ] && ./isohybrid "$OUTNAME"
ls -ll "$OUTNAME"
