#!/bin/sh -e

cleanup() {
	sudo rm -rf "$tmp"
}

tmp="$(mktemp -d /tmp/genrootfs_virtualbox.XXXXXX)"
trap cleanup EXIT

ovl_dir="$(realpath $(dirname $0))/genrootfs_virtualbox-ovl"

while getopts "a:k:o:r:v:" opt; do
	case $opt in
	a) arch="$OPTARG";;
	k) keys_dir="$OPTARG";;
	o) out_dir="$OPTARG";;
	r) repositories_file="$OPTARG";;
	v) rel_ver="$OPTARG";;
	esac
done
shift $(( $OPTIND - 1))

if [ -z "$arch" ] || [ -z "$keys_dir" ] || [ -z "$out_dir" ] || [ -z "$repositories_file" ] || [ -z "$rel_ver" ]; \
then
	echo "-a, -k, -o, -r, -v options needed"
	exit 1
fi

apk_pkgs="
	alpine-baselayout
	apk-tools
	musl
	openrc

	busybox
	busybox-initscripts

	sudo
	shadow@repo-virtualbox

	chrony
	openssh-server
	openssh-client
	e2fsprogs
	sgdisk
	blkid
	rsync

	dbus
	virtualbox-guest-additions@repo-virtualbox
	docker@repo-virtualbox
	"
apks=""
for i in $apk_pkgs; do
	apks="$apks $i"
done

tmprootfs="$tmp/rootfs"

abuild-apk add --arch "$arch" --keys-dir "$keys_dir" --no-cache \
	--repositories-file "$repositories_file" \
	--root "$tmprootfs" --initdb

# dbus post-install script requires /dev/urandom
sudo mknod -m 644 "$tmprootfs/dev/urandom" c 1 9

abuild-apk add --arch "$arch" --keys-dir "$keys_dir" --no-cache \
	--repositories-file "$repositories_file" \
	--root "$tmprootfs" $apks

sudo rm -f  "$tmprootfs/dev/urandom"

# setup openrc
runlevel_sysinit="
	devfs
	dmesg
	mdev
	modloop
	hwdrivers
	"
for i in $runlevel_sysinit; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/sysinit/$i"
done

sudo sh -c "echo vboxsf >> $tmprootfs/etc/modules"
sudo sh -c "echo lambda2-virtualbox >> $tmprootfs/etc/hostname"

runlevel_boot="
	modules
	hwclock
	sysctl
	hostname
	bootmisc
	syslog
	urandom
	networking
	"
for i in $runlevel_boot; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/boot/$i"
done

runlevel_default="
	acpid
	chronyd
	crond
	dbus
	local
	sshd
	"
for i in $runlevel_default; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/default/$i"
done

runlevel_shutdown="
	killprocs
	mount-ro
	savecache
	"
for i in $runlevel_shutdown; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/shutdown/$i"
done

# setup ll-user account
# echo "ll-user" | openssl passwd -1 -stdin
# $1$KPh9fpbf$gelLEoa7wY9ZNZ1oKUK8q1
# NOTE: There is a `\` before the `$` in the hashed password. This is so that
# shell escapes are correctly handled
sudo sh -c "chroot $tmprootfs /usr/sbin/groupadd -g 500 ll-user"
# docker group is created by docker package post-install script
sudo sh -c "chroot $tmprootfs /usr/sbin/useradd -d /home/ll-user -g ll-user -s /bin/ash -G wheel,docker -m -N -u 500 ll-user -p '\$1\$KPh9fpbf\$gelLEoa7wY9ZNZ1oKUK8q1'"

# setup /etc/sudoers.d/ll-user
sudo sh -c "cp $ovl_dir/etc-sudoers.d-ll-user $tmprootfs/etc/sudoers.d/ll-user"
sudo sh -c "chown root:root $tmprootfs/etc/sudoers.d/ll-user"
sudo sh -c "chmod 440 $tmprootfs/etc/sudoers.d/ll-user"

# disable root password
sudo sh -c "sed -i -e 's/^root.*$/root:*LOCK*:14600::::::/' $tmprootfs/etc/shadow"

# update /etc/motd
sudo sh -c "cat $ovl_dir/etc-motd > $tmprootfs/etc/motd"
sudo sh -c "sed -i -e s/RELEASE_VERSION/${rel_ver}/ $tmprootfs/etc/motd"

# update /etc/os-release
sudo sh -c "cat $ovl_dir/etc-os-release > $tmprootfs/etc/os-release"
sudo sh -c "sed -i -e s/RELEASE_VERSION/${rel_ver}/ $tmprootfs/etc/os-release"

# setup networking
sudo sh -c "cp $ovl_dir/etc-network-interfaces $tmprootfs/etc/network/interfaces"
sudo sh -c "chown root:root $tmprootfs/etc/network/interfaces"
sudo sh -c "chmod 644 $tmprootfs/etc/network/interfaces"

sudo sh -c "mkdir -p $tmprootfs/etc/udhcpc/post-bound"
sudo sh -c "chmod 755 $tmprootfs/etc/udhcpc/post-bound"
sudo sh -c "cp $ovl_dir/etc-udhcpc-post-bound-set-hostname $tmprootfs/etc/udhcpc/post-bound/set-hostname"
sudo sh -c "chown root:root $tmprootfs/etc/udhcpc/post-bound/set-hostname"
sudo sh -c "chmod 755 $tmprootfs/etc/udhcpc/post-bound/set-hostname"

sudo sh -c "cp $ovl_dir/etc-udhcpc-udhcpc.conf $tmprootfs/etc/udhcpc/udhcpc.conf"
sudo sh -c "chown root:root $tmprootfs/etc/udhcpc/udhcpc.conf"
sudo sh -c "chmod 644 $tmprootfs/etc/udhcpc/udhcpc.conf"

# setup ssh server
# Lambda Linux uses keys for remote access
sudo sh -c "echo 'PasswordAuthentication no' >> $tmprootfs/etc/ssh/sshd_config"
sudo sh -c "echo 'ChallengeResponseAuthentication no' >> $tmprootfs/etc/ssh/sshd_config"
sudo sh -c "echo 'UseDNS no' >> $tmprootfs/etc/ssh/sshd_config"

# enable docker experimental flag
sudo sh -c "sed -i -e '/DOCKER_OPTS/d' $tmprootfs/etc/conf.d/docker"
sudo sh -c "echo 'DOCKER_OPTS=\"--experimental=true\"' >> $tmprootfs/etc/conf.d/docker"

# setup openrc local scripts
local_scripts="
	01-disk-setup.start
	02-disk-update-links.start
	03-vboxservice.start
	04-vbox-mount-sf.start
	05-bootsync.start
	06-docker.start
	07-bootlocal.start
"
for i in $local_scripts; do
	sudo sh -c "cp $ovl_dir/etc-local.d-${i} $tmprootfs/etc/local.d/${i}"
	sudo sh -c "chown root:root $tmprootfs/etc/local.d/${i}"
	sudo sh -c "chmod 755 $tmprootfs/etc/local.d/${i}"
done

sudo sh -c "cd $tmprootfs; find . | cpio -H newc -o | gzip > $tmp/rootfs.cpio.gz"

cp $tmp/rootfs.cpio.gz $out_dir/rootfs.cpio.gz
