#!/bin/bash

set -e

builder="${1}"
reposrc="${2}"
reponame="${3}"
alarch="${4}"

PATH="$PATH:/home/${builder}/arch-install-scripts"
alchroot=/home/${builder}/abs/${alarch}

setup_x86_64_chroot() {
	distro=archlinux

	wget -q -nc -P /home/${builder}/ -r -l 1 -nd -A 'archlinux-bootstrap-*-x86_64.tar.gz' 'https://mirror.pkgbuild.com/iso/latest/'
	tar -x -z --strip-components 1 -C /home/${builder}/abs/${alarch}/ -f /home/${builder}/archlinux-bootstrap-*-x86_64.tar.gz
	printf "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch\n" >> ${alchroot}/etc/pacman.d/mirrorlist
}

setup_arm_chroot() {
	distro=archlinuxarm
	cpu=arm946

	wget -q -nc -P /home/${builder}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-armv5-latest.tar.gz'
	tar -x -C /home/${builder}/abs/${alarch}/ -f /home/${builder}/ArchLinuxARM-armv5-latest.tar.gz
	cp -f /usr/bin/qemu-arm-static /home/${builder}/abs/${alarch}/usr/bin/
}

setup_armv6h_chroot() {
	distro=archlinuxarm
	cpu=arm1176

	wget -q -nc -P /home/${builder}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz'
	tar -x -C /home/${builder}/abs/${alarch}/ -f /home/${builder}/ArchLinuxARM-rpi-latest.tar.gz
	cp -f /usr/bin/qemu-arm-static /home/${builder}/abs/${alarch}/usr/bin/
}

setup_armv7h_chroot() {
	distro=archlinuxarm
	cpu=cortex-a9

	wget -q -nc -P /home/${builder}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz'
	tar -x -C /home/${builder}/abs/${alarch}/ -f /home/${builder}/ArchLinuxARM-armv7-latest.tar.gz
	cp -f /usr/bin/qemu-arm-static /home/${builder}/abs/${alarch}/usr/bin/
}

setup_aarch64_chroot() {
	distro=archlinuxarm
	cpu=cortex-a53

	wget -q -nc -P /home/${builder}/ 'http://mirror.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz'
	tar -x -C /home/${builder}/abs/${alarch}/ -f /home/${builder}/ArchLinuxARM-aarch64-latest.tar.gz
	cp -f /usr/bin/qemu-aarch64-static /home/${builder}/abs/${alarch}/usr/bin/
}

mkdir -p ${alchroot}
mount --bind ${alchroot} ${alchroot}
setup_${alarch}_chroot

if [ -n "${cpu}" ]; then
	export QEMU_CPU=${cpu}
fi

sed \
	-e 's/Required/Never TrustAll/g' \
	-e 's/DatabaseOptional//g' \
	-e '/LocalFileSigLevel/d' \
	-i ${alchroot}/etc/pacman.conf
printf "en_US.UTF-8 UTF-8\n" > ${alchroot}/etc/locale.gen
cp --remove-destination /etc/resolv.conf ${alchroot}/etc/
arch-chroot ${alchroot} /bin/bash -c "source /etc/profile; pacman -S -y -u --noconfirm base-devel; locale-gen; useradd -m -G wheel -s /bin/bash ${builder}"
printf "%%wheel ALL=(ALL) NOPASSWD: ALL\n" > ${alchroot}/etc/sudoers.d/wheel

mkdir -p ${alchroot}/home/${builder}/{repo,src,${reponame}}
mkdir -p /home/${builder}/{repo/${alarch},src}
mount --bind /home/${builder}/repo ${alchroot}/home/${builder}/repo
mount --bind /home/${builder}/src ${alchroot}/home/${builder}/src
mount --bind ${reposrc} ${alchroot}/home/${builder}/${reponame}
printf "[${reponame}]\nSigLevel = Never TrustAll\nServer = file:///home/${builder}/repo/\$arch\n" >> ${alchroot}/etc/pacman.conf
printf "MAKEFLAGS='-j2'\nPACKAGER=\"${reponame} build bot\"\nSRCDEST=/home/${builder}/src\n" >> ${alchroot}/etc/makepkg.conf
if [ ! -f ${alchroot}/home/${builder}/repo/${alarch}/${reponame}.db.tar.gz ]; then
	arch-chroot ${alchroot} /bin/bash -c "/usr/bin/repo-add /home/${builder}/repo/${alarch}/${reponame}.db.tar.gz"
fi
wget -q -nc -P ${alchroot}/usr/bin 'https://github.com/M-Reimer/repo-make/raw/master/repo-make'
chmod 755 ${alchroot}/usr/bin/repo-make
printf "BUILDUSER=${builder}\n" > ${alchroot}/etc/repo-make.conf
arch-chroot ${alchroot} /bin/bash -c "source /etc/profile; repo-make -C /home/${builder}/${reponame} -t /home/${builder}/repo/${alarch}"

exit
