#!/bin/sh
# Disposable VM acceptance evidence. Does not install, configure or restart anything.
# Only the explicitly new evidence directory is written.
set -eu
set -o pipefail
umask 077
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
LC_ALL=C
export PATH LC_ALL

usage() {
    echo "Usage: $0 bios-essential|efi-all NEW_ABSOLUTE_EVIDENCE_DIRECTORY [PRIOR_EVIDENCE_DIRECTORY]" >&2
    exit 2
}
[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage
selection=$1
out=$2
baseline=${3:-}
case "$selection" in bios-essential|efi-all) ;; *) usage ;; esac
[ "$(uname -s)" = FreeBSD ] && [ "$(id -u)" = 0 ] || { echo 'Run as root inside the installed test VM.' >&2; exit 1; }
case "$out" in /root/*|/tmp/*) ;; *) echo 'Evidence must be a new directory below /root or /tmp.' >&2; exit 1 ;; esac
case "$out" in *[!a-zA-Z0-9_./-]*|*/../*|*/..|*/./*|*/.) echo 'Use a simple absolute evidence path.' >&2; exit 1 ;; esac
parent=$(realpath "$(dirname "$out")")
case "$parent" in /root|/root/*|/tmp|/tmp/*) ;; *) echo 'Resolved parent is outside the permitted evidence locations.' >&2; exit 1 ;; esac
out="$parent/$(basename "$out")"
[ ! -e "$out" ] && [ ! -L "$out" ] || { echo 'Evidence already exists; choose a new directory.' >&2; exit 1; }
if [ -n "$baseline" ]; then
    baseline=$(realpath "$baseline")
    [ -f "$baseline/user-config-state.txt" ] || { echo 'Prior evidence lacks a configuration baseline.' >&2; exit 1; }
fi
mkdir -m 0700 "$out"
mkdir "$out/logs" "$out/configuration"
failures=0
note() { printf '%s\n' "$*" | tee -a "$out/checks.txt"; }
reject() { failures=$((failures + 1)); note "FAIL: $*"; }
finish() {
    result=$?
    trap - EXIT
    printf '%s\n' "$result" > "$out/exit-status"
    [ "$result" -eq 0 ] || printf '%s\n' 'Collection or one or more checks failed; retained evidence must be reviewed.' >> "$out/checks.txt"
    printf 'Evidence: %s\nExit status: %s\n' "$out" "$result"
    exit "$result"
}
trap finish EXIT
trap 'exit 1' HUP INT TERM
printf '%s\n' "$selection" > "$out/selection"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$out/collected-at"
cp "$0" "$out/collector.sh"

# Credentials, account databases and private keys are never copied. Sanitize
# any crypt-form password hash that may have reached ordinary diagnostic logs.
sanitize() {
    awk '
        /^-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----/ {private=1; print "[REDACTED PRIVATE KEY]"; next}
        private {if ($0 ~ /^-----END ([A-Z0-9]+ )*PRIVATE KEY-----/) private=0; next}
        {gsub(/\$(1|2[abxy]?|5|6|y|argon2[[:alnum:]]*)\$[^[:space:]:"]+/, "[REDACTED PASSWORD HASH]"); print}
    '
}
save_public_config() {
    source_file=$1
    destination=$2
    if [ -f "$source_file" ]; then
        sanitize < "$source_file" > "$out/configuration/$destination"
        sha256 "$source_file" >> "$out/configuration/source-files.sha256"
    else
        reject "Missing configuration: $source_file"
    fi
}
capture() {
    capture_name=$1; shift
    if "$@" > "$out/$capture_name" 2>&1; then
        printf '0\n' > "$out/$capture_name.exit-status"
    else
        capture_status=$?
        printf '%s\n' "$capture_status" > "$out/$capture_name.exit-status"
        reject "Command failed: $capture_name (exit $capture_status)"
    fi
}

for item in k r u; do
    version=$(freebsd-version "-$item")
    printf '%s %s\n' "$item" "$version" >> "$out/freebsd-versions.txt"
    [ "$version" = 15.1-RELEASE-p6 ] || reject "FreeBSD -$item is $version, expected p6"
done
capture uname.txt uname -a
capture kernel-modules.txt kldstat
capture kernel-config.txt /usr/sbin/config -x /boot/kernel/kernel
awk '$1 == "ident" && $2 == "GENERIC" {found=1} END {exit !found}' "$out/kernel-config.txt" || reject 'Installed kernel is not GENERIC'
capture interfaces.txt ifconfig -a
capture mounts.txt mount -p
capture processes.txt ps -axo user,pid,ppid,comm

capture package-inventory.txt pkg -C /dev/null -o PKG_ENABLE_PLUGINS=no query -a '%n|%v|%o'
sort -o "$out/package-inventory.txt" "$out/package-inventory.txt"
wc -l < "$out/package-inventory.txt" > "$out/package-count"
awk -F '|' '$1 ~ /^c9-/' "$out/package-inventory.txt" > "$out/c9-packages.txt"
required_c9='c9-workstation c9-desktop-mango c9-apps-essential c9-desktop-defaults c9-system-config c9-artwork c9-hardware-virtualbox'
required_apps='mango sddm firefox foot thunar zathura zathura-pdf-mupdf virtualbox-ose-additions-72 xterm xmessage'
if [ "$selection" = efi-all ]; then
    required_c9="$required_c9 c9-apps-development c9-apps-office"
    required_apps="$required_apps vscode git cmake-core python312 node24 npm-node24 libreoffice"
else
    for package in c9-apps-development c9-apps-office; do
        if awk -F '|' -v name="$package" '$1 == name {found=1} END {exit !found}' "$out/package-inventory.txt"; then
            reject "Unselected optional group is installed: $package"
        fi
    done
fi
for package in $required_c9; do
    awk -F '|' -v name="$package" '$1 == name && $2 == "0.2.0" {found++} END {exit (found != 1)}' "$out/package-inventory.txt" || reject "Missing or incorrect C9 package: $package"
done
for package in $required_apps; do
    awk -F '|' -v name="$package" '$1 == name {print; found=1} END {exit !found}' "$out/package-inventory.txt" >> "$out/selected-applications.txt" || reject "Missing selected application: $package"
done
if awk -F '|' '$1 == "c9-hardware-intel" {found=1} END {exit !found}' "$out/package-inventory.txt"; then
    reject 'Intel hardware metaport is installed on the VirtualBox test target'
fi
[ -f /var/db/c9/profile ] && [ "$(cat /var/db/c9/profile)" = virtualbox ] || reject 'Recorded hardware profile is not virtualbox'
[ ! -f /var/db/c9/profile ] || cp /var/db/c9/profile "$out/hardware-profile"

for variable in sddm_enable dbus_enable seatd_enable vboxguest_enable vboxservice_enable; do
    value=$(sysrc -n "$variable" 2>/dev/null || true)
    printf '%s=%s\n' "$variable" "$value" >> "$out/rc-services.txt"
    [ "$value" = YES ] || reject "$variable is not YES"
done
for variable in hostname kld_list; do
    value=$(sysrc -n "$variable" 2>/dev/null || true)
    printf '%s=%s\n' "$variable" "$value" >> "$out/rc-services.txt"
done
for service_name in dbus sddm seatd vboxservice; do
    capture "service-$service_name.txt" service "$service_name" onestatus
done
kldstat -q -m pci/vboxguest || reject 'VirtualBox guest kernel module is not loaded'
save_public_config /usr/local/etc/sddm.conf.d/90-c9.conf sddm-90-c9.conf
save_public_config /usr/local/etc/sddm.conf.d/91-c9-profile.conf sddm-91-c9-profile.conf
save_public_config /usr/local/etc/pam.d/sddm pam-sddm.conf
save_public_config /usr/local/etc/pam.d/sddm-autologin pam-sddm-autologin.conf
save_public_config /usr/local/etc/pam.d/sddm-greeter pam-sddm-greeter.conf
save_public_config /etc/pam.d/system pam-system.conf
[ ! -f /usr/local/etc/sddm.conf ] || save_public_config /usr/local/etc/sddm.conf sddm-main.conf
grep -q '^SessionDir=/usr/local/share/c9/sessions/empty$' /usr/local/etc/sddm.conf.d/91-c9-profile.conf || reject 'VirtualBox X11 session directory differs'
grep -q '^HideUsers=root$' /usr/local/etc/sddm.conf.d/90-c9.conf || reject 'C9 root-login hiding policy differs'
find /usr/local/share/c9/sessions -type f -print > "$out/session-files.txt"
for config_file in /usr/local/lib/sddm/sddm.conf.d/*.conf /usr/local/etc/sddm.conf.d/*.conf /usr/local/etc/sddm.conf /etc/sddm.conf; do
    [ -f "$config_file" ] || continue
    awk '
        /^[ \t]*[;#]/ {next}
        /^[ \t]*\[/ {section=$0; gsub(/[ \t\r]/,"",section); next}
        section == "[Autologin]" && /^[ \t]*User[ \t]*=/ {
            value=$0; sub(/^[^=]*=/,"",value); gsub(/^[ \t]+|[ \t\r]+$/,"",value)
            if (value != "" && value != "\"\"") exit 1
        }
        section == "[Autologin]" && /^[ \t]*Relogin[ \t]*=/ {
            value=$0; sub(/^[^=]*=/,"",value); gsub(/[ \t\r]/,"",value)
            if (tolower(value) == "true" || tolower(value) == "yes" || value == "1") exit 1
        }
    ' "$config_file" || reject "Automatic login is configured in $config_file"
done

desktop_user=c9tester
awk -F: '{print $1 ":" $3 ":" $4 ":" $9 ":" $10}' /etc/master.passwd > "$out/account-identities.txt"
user_uid=$(awk -F: -v name="$desktop_user" '$1 == name {print $3}' /etc/master.passwd)
user_home=$(awk -F: -v name="$desktop_user" '$1 == name {print $9}' /etc/master.passwd)
awk -F: -v name="$desktop_user" '$1 == name {found=1; if ($3 < 1000 || $3 > 65000 || $2 == "" || $2 ~ /^[!*]/ || $10 ~ /(nologin|false)$/) bad=1} END {exit (!found || bad)}' /etc/master.passwd || reject 'c9tester lacks a usable nonroot authenticated account'
capture user-id.txt id "$desktop_user"
case " $(id -Gn "$desktop_user" 2>/dev/null || true) " in *" video "*) ;; *) reject 'c9tester is not in video' ;; esac
case "$user_home" in /*) ;; *) reject 'c9tester home is missing or invalid'; user_home= ;; esac

: > "$out/user-config-state.txt"
: > "$out/template-state.txt"
if [ -n "$user_home" ] && [ -d "$user_home" ]; then
    stat -f '%N|uid=%u|gid=%g|mode=%Lp|type=%HT' "$user_home" > "$out/home-mode.txt"
    [ "$(stat -f %u "$user_home")" = "$user_uid" ] || reject 'Home ownership differs from c9tester'
    while IFS= read -r relative; do
        template="/usr/local/share/c9/skel/$relative"
        destination="$user_home/$relative"
        if [ -f "$template" ]; then
            printf '%s|%s\n' "$relative" "$(sha256 -q "$template")" >> "$out/template-state.txt"
        else
            reject "Missing packaged template: $relative"
        fi
        if [ -L "$destination" ]; then
            printf '%s|symlink|%s\n' "$relative" "$(readlink "$destination")" >> "$out/user-config-state.txt"
            [ -n "$baseline" ] || reject "Fresh user configuration is a symlink: $relative"
        elif [ -f "$destination" ]; then
            printf '%s|file|%s|%s\n' "$relative" "$(sha256 -q "$destination")" "$(stat -f '%u|%g|%Lp' "$destination")" >> "$out/user-config-state.txt"
            [ "$(stat -f %u "$destination")" = "$user_uid" ] || reject "User configuration ownership differs: $relative"
            if [ -z "$baseline" ]; then
                cmp -s "$template" "$destination" || reject "Fresh user configuration differs from its template: $relative"
            fi
        else
            printf '%s|missing-or-nonregular\n' "$relative" >> "$out/user-config-state.txt"
            reject "User configuration is missing or nonregular: $relative"
        fi
    done <<'FILES'
.config/mango/config.conf
.config/waybar/config.jsonc
.config/waybar/style.css
.config/foot/foot.ini
.config/fuzzel/fuzzel.ini
.config/mako/config
.config/gtk-3.0/settings.ini
.config/xdg-desktop-portal/mango-portals.conf
.config/mimeapps.list
FILES
else
    reject 'User home directory does not exist'
fi
if [ -n "$baseline" ]; then
    cmp -s "$baseline/user-config-state.txt" "$out/user-config-state.txt" || reject 'User configurations changed from the supplied baseline'
fi

save_public_config /usr/local/etc/pkg/repos/C9.conf C9-repository.conf
save_public_config /usr/local/etc/pkg/repos/FreeBSD.conf FreeBSD-repository.conf
key=/usr/local/etc/ssl/certs/c9-repository.pub
if [ -f "$key" ]; then
    cp "$key" "$out/configuration/c9-repository.pub"
    sha256 "$key" > "$out/repository-public-key.sha256"
    [ "$(sha256 -q "$key")" = e4cbc1752b7b95ecaf7679112f766e405ad895f34dc8b4c6943b14cff0dbbf25 ] || reject 'Repository public key differs from the build server signer'
    capture repository-public-key-check.txt openssl pkey -pubin -in "$key" -noout
else
    reject 'C9 repository public key is missing'
fi
grep -q 'url: "http://192.168.178.55/packages/c9151amd64-default-c9"' /usr/local/etc/pkg/repos/C9.conf || reject 'Update repository URL differs'
grep -q 'FreeBSD: { enabled: no }' /usr/local/etc/pkg/repos/FreeBSD.conf || reject 'Default FreeBSD package repository is not disabled'
expected_build=c9release-20261122T094945Z
[ -f /usr/local/share/c9/build/package-build-id ] && [ "$(cat /usr/local/share/c9/build/package-build-id)" = "$expected_build" ] || reject 'Installed build provenance differs'
for record in package-build-id c9-version freebsd-version ports-revision; do
    [ ! -f "/usr/local/share/c9/build/$record" ] || cp "/usr/local/share/c9/build/$record" "$out/$record"
done
for leftover in /etc/rc.local /tmp/c9-pkg-static /tmp/c9-repos/C9Offline.conf; do
    [ ! -e "$leftover" ] && [ ! -L "$leftover" ] || reject "Installer leftover: $leftover"
done
if mount -p | awk '$2 == "/mnt/c9-packages" {found=1} END {exit !found}'; then
    reject 'Installer package repository remains mounted'
fi
for logfile in /var/log/c9-install.log /var/log/auth.log /var/log/messages /var/log/sddm.log; do
    if [ -f "$logfile" ]; then
        tail -n 1500 "$logfile" | sanitize > "$out/logs/$(basename "$logfile").sanitized"
    fi
done
if [ -n "$user_home" ]; then
    for session_log in "$user_home/.local/share/sddm/xorg-session.log" "$user_home/.local/share/sddm/wayland-session.log" "$user_home/.xsession-errors"; do
        [ ! -f "$session_log" ] || tail -n 500 "$session_log" | sanitize > "$out/logs/$(basename "$session_log").sanitized"
    done
fi
note "Recorded $selection; checks failed: $failures"
note 'Scope: read-only installed-state evidence. This does not prove SDDM password rejection/success, logout, reboot, an actual package upgrade, or native Mango graphics.'
[ "$failures" -eq 0 ]
