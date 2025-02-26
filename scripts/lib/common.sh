#!/usr/bin/env sh

set -euf

is_help() {
    case "$1" in
    -h | --help | help)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

error() {
    if [ $# -le 1 ]; then
        printf '%s' "${1:-}" >&2
    else
        format="${1}"
        shift

        # shellcheck disable=SC2059
        printf "$format" "$@" >&2
    fi

    exit 1
}

on_macos() {
    [ "$(uname)" = "Darwin" ]
}

load_secret_driver() {
    driver="${1}"
    if [ -f "${SCRIPT_DIR}/drivers/${driver}.sh" ]; then
        # shellcheck source=scripts/drivers/sops.sh
        . "${SCRIPT_DIR}/drivers/${driver}.sh"
    else
        # Allow to load out of tree drivers.
        if [ ! -f "${driver}" ]; then
            error "Can't find secret driver: ${driver}"
        fi

        # shellcheck disable=SC2034
        HELM_SECRETS_SCRIPT_DIR="${SCRIPT_DIR}"

        # shellcheck source=tests/assets/custom-driver.sh
        . "${driver}"
    fi
}

_regex_escape() {
    # This is a function because dealing with quotes is a pain.
    # http://stackoverflow.com/a/2705678/120999
    sed -e 's/[]\/()$*.^|[]/\\&/g'
}

_trap() {
    if command -v _trap_hook >/dev/null; then
        _trap_hook
    fi

    rm -rf "${TMPDIR}"
}

# MacOS syntax and behavior is different for mktemp
# https://unix.stackexchange.com/a/555214
_mktemp() {
    mktemp "$@" "${TMPDIR}/XXXXXX"
}

# MacOS syntax is different for in-place
# https://unix.stackexchange.com/a/92907/433641
case $(sed --help 2>&1) in
*BusyBox* | *GNU*) _sed_i() { sed -i "$@"; } ;;
*) _sed_i() { sed -i '' "$@"; } ;;
esac
