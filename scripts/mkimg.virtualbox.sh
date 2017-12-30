profile_virtualbox() {
	kernel_flavors="virtualbox"
	kernel_flavors_repo="@repo-virtualbox"
	initfs_features="ata base bootchart cdrom squashfs ext2 ext3 ext4 scsi"

	initfs_cmdline="modules=loop,squashfs rootfs_cpio"

	arch="x86_64"
	output_format="isovbox"

	title="VirtualBox"
	desc="VirtualBox flavor image"
	kernel_addons=
	kernel_cmdline="console=tty0"
	syslinux_serial="0 115200"

	# volume label `lambda-linux-vX.Y.Z` is used by lambda-machine-local.
	# We can have only one `-v` in this string. Hence we don't include
	# `-vbox` in the label
	lambda2_volume_label="lambda-linux-v1801.0.0"
	lambda2_rel_ver="2018.01.0"
}

section_rootfs_isovbox() {
	[ "$ARCH" = x86 -o "$ARCH" = x86_64 ] || return 0
	[ "$output_format" = "isovbox" ] || return 0
	build_section rootfs_isovbox $(echo "rootfs_isovbox" | checksum)
}

build_rootfs_isovbox() {
	local _script="${PWD}/genrootfs_virtualbox.sh"
	$_script -a x86_64 -r "$APKROOT/etc/apk/repositories" -k /etc/apk/keys -o "$DESTDIR" -v "$lambda2_rel_ver"
}

create_image_isovbox() {
	local ISO="${OUTDIR}/lambda-linux-vbox.iso"
	local _isolinux

	_isolinux="
		-isohybrid-mbr ${DESTDIR}/boot/syslinux/isohdpfx.bin
		-eltorito-boot boot/syslinux/isolinux.bin
		-eltorito-catalog boot/syslinux/boot.cat
		-no-emul-boot
		-boot-load-size 4
		-boot-info-table
		"

	xorrisofs \
		-output ${ISO} \
		-publisher 'Lambda Linux Project' \
		-full-iso9660-filenames \
		-joliet \
		-rock \
		-volid "${lambda2_volume_label}" \
		$_isolinux \
		-follow-links \
		${DESTDIR}
}

section_syslinux_isovbox() {
	[ "$ARCH" = x86 -o "$ARCH" = x86_64 ] || return 0
	[ "$output_format" = "isovbox" ] || return 0
	build_section syslinux $(apk fetch --root "$APKROOT" --simulate syslinux | sort | checksum)
}

section_syslinux_cfg_isovbox() {
	[ "$ARCH" = x86 -o "$ARCH" = x86_64 ] || return 0
	[ "$output_format" = "isovbox" ] || return 0

	syslinux_cfg="boot/syslinux/syslinux.cfg"
	build_section syslinux_cfg_isovbox $syslinux_cfg $(syslinux_gen_config_isovbox | checksum)
}

syslinux_gen_config_isovbox() {
	local _vmlinuz=$(basename ${WORKDIR}/kernel_*/boot/vmlinuz-*)
	local _fullkver=${_vmlinuz#vmlinuz-}

	[ -z "$syslinux_serial" ] || echo "SERIAL $syslinux_serial"
	echo "TIMEOUT ${syslinux_timeout:-1}"
	echo "PROMPT ${syslinux_prompt:-1}"
	echo "DEFAULT ${kernel_flavors%% *}"

	cat <<- EOF
	LABEL virtualbox
		MENU LABEL Linux virtualbox
		KERNEL /boot/vmlinuz-$_fullkver
		INITRD /boot/initramfs-$_fullkver
		DEVICETREEDIR /boot/dtbs
		APPEND $initfs_cmdline $kernel_cmdline
	EOF
}

build_syslinux_cfg_isovbox() {
	local syslinux_cfg="$1"
	mkdir -p "${DESTDIR}/$(dirname $syslinux_cfg)"
	syslinux_gen_config_isovbox > "${DESTDIR}"/$syslinux_cfg
}
