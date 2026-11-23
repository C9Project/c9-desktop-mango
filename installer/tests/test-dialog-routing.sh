#!/bin/sh
# Simulate bsdinstall logging stderr while the dialog must retain terminal UI.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sed -n '/^choose_dialog() {$/,/^}$/p' \
    "$root/installer/overlay/usr/local/libexec/c9/install-target" > "$work/functions.sh"
. "$work/functions.sh"
(
    exec 2> "$work/installer.log"
    exec 5>&1
    bsddialog() {
        printf 'SCREEN: %s\n' "$1"
        case "$1" in
            profile) printf 'intel\n' >&2 ;;
            checklist) printf 'Development\nOffice\n' >&2 ;;
        esac
    }
    selected_profile=$(choose_dialog profile)
    [ "$selected_profile" = intel ]
    selected_groups=$(choose_dialog checklist)
    [ "$selected_groups" = "$(printf 'Development\nOffice')" ]
    printf 'normal diagnostic\n' >&2
) > "$work/terminal.out"
[ "$(cat "$work/terminal.out")" = "$(printf 'SCREEN: profile\nSCREEN: checklist')" ]
[ "$(cat "$work/installer.log")" = 'normal diagnostic' ]
echo 'PASS: curses output stays on terminal, selections are captured, and diagnostics remain in the stderr log.'
