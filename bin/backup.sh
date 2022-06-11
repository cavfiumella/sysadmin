#!/bin/bash
#
# Duplicity encrypted backup
#
# Complete backup is forced after 3 days and backups older than 1 week are
# discarded
#


main() {
	if [[ $# -lt 3 ]]; then
		echo GPG key ID, source and target are needed! 1>&2
		return 1
	fi

	gpg="$1"
	src="$2"
	dst="$3"

	duplicity incremental \
		--full-if-older-than 3D \
		--encrypt-key "$gpg" \
		--asynchronous-upload \
		--s3-use-multiprocessing \
		--progress \
		"$src" "$dst"

	if [[ $? -ne 0 ]]; then
		return 1
	fi

	duplicity remove-older-than 1W --force "$dst"

	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}


main "$@"
exit $?
