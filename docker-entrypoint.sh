#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

is_include() {
	printf '%s\n' "$*" | grep -q "^#include "
}

include_file() {
	printf '%s\n' "$*" | sed -e 's#include#included from#'
	printf '%s\n' "$*" | awk '{print $2}' | xargs | xargs -n1 -I{} -r find ${include_path:-/usr/local/etc/haproxy} -name "{}" | head -1 | xargs -r cat
}

lines_in_config() {
	seq 1 $( ( cat "$config"; echo "" ) | wc -l | awk '{print $1}' )
}

preprocess_config() {
	local config="$1"
	include_path="$(dirname "$config")"
	for linenum in $(lines_in_config "$config" ); do
		line="$(head -n$linenum "$config" | tail -1)"
		is_include "$line" \
		&& include_file "$line" \
		|| head -n$linenum "$config" | tail -1
	done
}

if [ "$1" = 'haproxy' ]; then
	# if the user wants "haproxy", let's use "haproxy-systemd-wrapper" instead so we can have proper reloadability implemented by upstream
	shift # "haproxy"
	set -- "$(which haproxy-systemd-wrapper)" -p /run/haproxy.pid "$@"
	# wait for default route to arrive
	until ip route get 1.0.0.0 </dev/null >/dev/null 2>&1 ; do sleep .1; done
	echo "Got default route"
	cfg_num=0
	echo > /args
	while true; do
		arg=$1
		case "$arg" in
			-f)
				echo "-f" >> /args
				echo "Processing Config '$2'"
				preprocess_config "$2" > /tmp/haproxy.$cfg_num.cfg
				echo "/tmp/haproxy.$cfg_num.cfg" >> /args
				cfg_num=$((( $cfg_num + 1 )))
				shift
			;;
			*)
				echo "$arg" >> /args
			;;
		esac
		shift
		[[ "$1" ]] || break
	done
	set -- $(cat /args)
	rm /args
fi

exec "$@"