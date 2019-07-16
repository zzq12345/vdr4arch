#!/bin/bash

set -e

builduser="${1}"
reposrc="${2}"
alarch="${3}"

alchroot=/home/${builduser}/abs/${alarch}
reponame=$(basename ${reposrc})

setup_x86_64_chroot() {
	distro=archlinux

	wget -q -nc -P /home/${builduser}/ -r -l 1 -nd -A 'archlinux-bootstrap-*-x86_64.tar.gz' 'https://mirrors.ocf.berkeley.edu/archlinux/iso/latest/'
	tar -x -z --strip 1 -C /home/${builduser}/abs/${alarch}/ -f /home/${builduser}/archlinux-bootstrap-*-x86_64.tar.gz
	printf "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch\n" >> ${alchroot}/etc/pacman.d/mirrorlist
}

mkdir -p ${alchroot}
mount --bind ${alchroot} ${alchroot}
setup_${alarch}_chroot

printf "en_US.UTF-8 UTF-8\n" > ${alchroot}/etc/locale.gen
cp -f /etc/resolv.conf ${alchroot}/etc/
arch-chroot ${alchroot} /bin/bash -c "source /etc/profile; pacman-key --init; pacman-key --populate ${distro}; pacman -S -y -u --noconfirm base-devel; locale-gen; useradd -m -G wheel -s /bin/bash ${builduser}"
printf "%%wheel ALL=(ALL) NOPASSWD: ALL\n" > ${alchroot}/etc/sudoers.d/wheel

printf "==> Build packages for ${alarch}\n"
mkdir -p ${alchroot}/home/${builduser}/{repo,src,${reponame}}
mkdir -p /home/${builduser}/{repo/${alarch},src}
mount --bind /home/${builduser}/repo ${alchroot}/home/${builduser}/repo
mount --bind /home/${builduser}/src ${alchroot}/home/${builduser}/src
mount --bind ${reposrc} ${alchroot}/home/${builduser}/${reponame}
printf "MAKEFLAGS='-j2'\nPACKAGER=\"${reponame} build bot\"\nSRCDEST=/home/${builduser}/src\n" >> ${alchroot}/etc/makepkg.conf
sed -e 's|\.xz|\.zst|' -i ${alchroot}/etc/makepkg.conf
#if [ ! -f ${alchroot}/home/${builduser}/repo/${alarch}/${reponame}.db.tar.gz ]; then
#	arch-chroot ${alchroot} /bin/bash -c "/usr/bin/repo-add /home/${builduser}/repo/${alarch}/${reponame}.db.tar.gz"
#fi
#printf "[${reponame}]\nSigLevel = Never TrustAll\nServer = file:///home/${builduser}/repo/\$arch\n" >> ${alchroot}/etc/pacman.conf

wget -q -nc -P ${alchroot}/usr/bin 'https://github.com/M-Reimer/repo-make/raw/master/repo-make'
sed -e 's|-Rs|-Rss|' -i ${alchroot}/usr/bin/repo-make
chmod 755 ${alchroot}/usr/bin/repo-make
printf "BUILDUSER=${builduser}\n" > ${alchroot}/etc/repo-make.conf
arch-chroot ${alchroot} /bin/bash -c "source /etc/profile; printenv; repo-make -C /home/${builduser}/${reponame} -t /home/${builduser}/repo/${alarch}"

exit
