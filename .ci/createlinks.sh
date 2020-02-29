#!/bin/bash

# modified https://github.com/archlinux/infrastructure/master/roles/sogrep/files/createlinks

target="$1"
repos=("$2")
arches=('x86_64' 'i686' 'arm' 'armv6h' 'armv7h' 'aarch64')
lock='/tmp/links.lck'
tmp="$(mktemp -d)"

[ -f "${lock}" ] && exit 1
touch "${lock}"

renice +10 -p $$ > /dev/null

getpkgname() {
	local tmp

	tmp=${1##*/}
	echo ${tmp%-*.pkg.tar.*}
}


for repo in ${repos[@]}; do
	for arch in ${arches[@]}; do
		repodir=${arch}
		[ ! -f ${target}/$repodir/$repo.db ] && continue
		mkdir -p ${tmp}/tmp/${repodir}

		# extract old file archive
		if [ -f ${target}/${repodir}/${repo}.links.tar.gz ]; then
			mkdir -p ${tmp}/cache/${repodir}
			bsdtar -xf ${target}/${repodir}/${repo}.links.tar.gz -C ${tmp}/cache/${repodir}
		fi

		# create file lists
		for pkg in $(find $target/$repodir -xtype f -name "*-${arch}.pkg.tar.*" ! -name "*.sig"); do
			pkgname=$(getpkgname $pkg)
			tmppkgdir=${tmp}/tmp/${repodir}/${pkgname}
			mkdir -p $tmppkgdir
			if [ -f "${tmp}/cache/${repodir}/${pkgname}/links" ]; then
				# reuse the cached file
				mv ${tmp}/cache/${repodir}/${pkgname}/links ${tmppkgdir}/links
			else
				echo "$repo/$arch: $pkgname"
				mkdir -p ${tmppkgdir}/pkg
				zstd -d --stdout $pkg | bsdtar -xof - -C ${tmppkgdir}/pkg --include={opt,{,usr/}{lib{,32},{s,}bin}}'/*' 2>/dev/null
				for f in $(find ${tmppkgdir}/pkg -type f); do
					readelf -d "$f" 2> /dev/null | sed -nr 's/.*Shared library: \[(.*)\].*/\1/p'
				done | sort -u > ${tmppkgdir}/links
				rm -rf ${tmppkgdir}/pkg
			fi
		done

		# create new file archive
		pkgdir=${target}/${repodir}
		mkdir -p $pkgdir
		bsdtar --exclude=*.tar.* -czf ${pkgdir}/${repo}.links.tar.gz -C ${tmp}/tmp/${repodir} .
	done
done

rm -rf ${tmp}
rm -f "${lock}"
