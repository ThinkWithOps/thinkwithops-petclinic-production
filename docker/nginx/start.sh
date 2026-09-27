#!/bin/sh
# Internal Alpine entrypoint (POSIX sh because this image does not include bash).
set -eu
case ${PUBLIC_SCHEME:-http} in
    http|https) ;;
    *) echo 'PUBLIC_SCHEME must be http or https' >&2; exit 1 ;;
esac
export PUBLIC_SCHEME="${PUBLIC_SCHEME:-http}"
# Substitute only this allowlisted variable; preserve all Nginx $variables.
# shellcheck disable=SC2016
envsubst '${PUBLIC_SCHEME}' < /etc/nginx/petclinic.conf.template > /tmp/petclinic.conf
nginx -t
exec nginx -g 'daemon off;'
