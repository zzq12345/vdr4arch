#!/bin/bash

# modified https://github.com/pierres/repo-tools/raw/master/createlinks

target="$1"
repos=("$2")
arches=('x86_64' 'i686' 'arm' 'armv6h' 'armv7h' 'aarch64')
lock='/tmp/mirrorsync.lck'
tmp="$(mktemp -d)"

extractinc=(--include={opt,{,usr/}{lib{,32},{s,}bin}}'/*')

getpkgname() {
	local tmp

	tmp=${1##*/}
	echo ${tmp%-*.pkg.tar.*}
}

create_file_list() {
	local pkgname=$(getpkgname "$1")

	tmppkgdir=$tmp/tmp/$repodir/$pkgname
	mkdir -p "$tmppkgdir"
	if [[ -f $tmp/cache/$repodir/$pkgname/links ]]; then
		# reuse the cached file
		mv "$tmp/cache/$repodir/$pkgname/links" "$tmppkgdir/links"
		return 0
	else
		echo "$repo: $arch: $pkgname"
		mkdir -p "$tmppkgdir/pkg"
		bsdtar -xof "$pkg" -C "$tmppkgdir/pkg" "${extractinc[@]}" 2>/dev/null
		find "$tmppkgdir/pkg" -type f -exec readelf -d {} + 2>/dev/null |
				sed -nr 's/.*Shared library: \[(.*)\]$/\1/p' | sort -u >"$tmppkgdir/links"
		rm -rf "$tmppkgdir/pkg"
		return 1
	fi
}

generate_links() {
	for repo in ${repos[@]}; do
		for arch in ${arches[@]}; do
			repodir=${arch}
			[ ! -f ${target}/$repodir/$repo.db ] && continue
			echo "$repo: $arch..."
			cached=false

			# extract old file archive
			if [ -f ${target}/${repodir}/${repo}.links.tar.gz ]; then
				mkdir -p ${tmp}/cache/${repodir}
				bsdtar -xf ${target}/${repodir}/${repo}.links.tar.gz -C ${tmp}/cache/${repodir}
				cached=true
			fi

			# create file lists
			for pkg in "$target/$repodir"/*.pkg.tar.?z; do
				# not a file or symlink to file
				[[ -f $pkg ]] || continue

				# skip -any packages
				[[ $pkg = *-any.pkg.tar.?z ]] && continue

				create_file_list "$pkg"
				if (( $? != 0 )); then
					cached=false
				fi
			done

			# create new file archive
			if ! $cached; then
				# at least one package has changed, so let's rebuild the archive
				pkgdir=${target}/${repodir}
				mkdir -p $pkgdir
				bsdtar --exclude=*.tar.* -czf ${pkgdir}/${repo}.links.tar.gz -C ${tmp}/tmp/${repodir} .
			fi
		done
	done
}

trap "rm -rf '${tmp}' '${lock}'" EXIT
renice +10 -p $$ > /dev/null

{
	flock -n 9 || exit 42
	generate_links
} 9>"$lock"
