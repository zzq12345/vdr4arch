#!/bin/bash

set -e

builduser="${1}"
home="${2}"
reposrc="${3}"
alarch="${4}"

reponame=$(basename ${reposrc})

setup_x86_64_chroot() {
	distro=archlinux

	wget -q -nc -P ${home}/ -r -l 1 -nd -A 'archlinux-bootstrap-*-x86_64.tar.gz' 'https://mirror.pkgbuild.com/iso/latest/'
	tar -x -z --strip 1 -C ${home}/abs/${alarch}/ -f ${home}/archlinux-bootstrap-*-x86_64.tar.gz
	printf "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch\n" >> ${alchroot}/etc/pacman.d/mirrorlist
}

setup_arm_chroot() {
	distro=archlinuxarm
	cpu=arm946

	wget -q -nc -P ${home}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-armv5-latest.tar.gz'
	tar -x -z -C ${home}/abs/${alarch}/ -f ${home}/ArchLinuxARM-armv5-latest.tar.gz
	cp -f /usr/bin/qemu-arm-static ${home}/abs/${alarch}/usr/bin/
}

setup_armv6h_chroot() {
	distro=archlinuxarm
	cpu=arm1176

	wget -q -nc -P ${home}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz'
	tar -x -z -C ${home}/abs/${alarch}/ -f ${home}/ArchLinuxARM-rpi-latest.tar.gz
	cp -f /usr/bin/qemu-arm-static ${home}/abs/${alarch}/usr/bin/
}

setup_armv7h_chroot() {
	distro=archlinuxarm
	cpu=cortex-a9

	wget -q -nc -P ${home}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz'
	tar -x -z -C ${home}/abs/${alarch}/ -f ${home}/ArchLinuxARM-armv7-latest.tar.gz
	cp -f /usr/bin/qemu-arm-static ${home}/abs/${alarch}/usr/bin/
}

setup_aarch64_chroot() {
	distro=archlinuxarm

	wget -q -nc -P ${home}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz'
	tar -x -z -C ${home}/abs/${alarch}/ -f ${home}/ArchLinuxARM-aarch64-latest.tar.gz
	cp -f /usr/bin/qemu-aarch64-static ${home}/abs/${alarch}/usr/bin/
}

alchroot=${home}/abs/${alarch}

mkdir -p ${alchroot}
mount --bind ${alchroot} ${alchroot}
setup_${alarch}_chroot
mount -t proc /proc ${alchroot}/proc
mount --make-rslave --rbind /sys ${alchroot}/sys
mount --make-rslave --rbind /dev ${alchroot}/dev
mount --make-rslave --rbind /run ${alchroot}/run

$(if [ -n "${cpu}" ]; then cpu="QEMU_CPU=${cpu};"; fi)

printf "en_US.UTF-8 UTF-8\n" > ${alchroot}/etc/locale.gen
cp -f /etc/resolv.conf ${alchroot}/etc/
SHELL=/bin/bash unshare --fork --pid chroot -- ${alchroot} /bin/bash -c "${cpu} source /etc/profile; pacman-key --init; pacman-key --populate ${distro}; pacman -S -y -u --noconfirm base-devel; locale-gen; usermod -a -G docker ${builduser}"
printf "%%docker ALL=(ALL) NOPASSWD: ALL\n" > ${alchroot}/etc/sudoers.d/docker

printf "==> Build packages for ${alarch}\n"
mkdir -p ${alchroot}${home}/{repo,src,${reponame}}
mkdir -p ${home}/{repo/${alarch},src}
mount --bind ${home}/repo ${alchroot}${home}/repo
mount --bind ${home}/src ${alchroot}${home}/src
mount --bind ${reposrc} ${alchroot}${home}/${reponame}
printf "[${reponame}]\nSigLevel = Never TrustAll\nServer = file:///${home}/repo/\$arch\n" >> ${alchroot}/etc/pacman.conf
printf "MAKEFLAGS='-j2'\nPACKAGER=\"${reponame} build bot\"\nSRCDEST=${home}/src\n" >> ${alchroot}/etc/makepkg.conf
if [ ! -f ${alchroot}${home}/repo/${alarch}/${reponame}.db.tar.gz ]; then
	SHELL=/bin/bash unshare --fork --pid chroot -- ${alchroot} /bin/bash -c "${cpu} /usr/bin/repo-add ${home}/repo/${alarch}/${reponame}.db.tar.gz"
fi
wget -q -nc -P ${alchroot}/usr/bin 'https://github.com/M-Reimer/repo-make/raw/master/repo-make'
chmod 755 ${alchroot}/usr/bin/repo-make
printf "BUILDUSER=${builduser}\n" > ${alchroot}/etc/repo-make.conf
chown -R ${builduser} ${alchroot}${home}/${reponame}
SHELL=/bin/bash unshare --fork --pid chroot -- ${alchroot} /bin/bash -c "${cpu} source /etc/profile; printenv; repo-make -C ${home}/${reponame} -t ${home}/repo/${alarch}"

exit
