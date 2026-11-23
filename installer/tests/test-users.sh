#!/bin/sh
# These deliberately invalid hash markers are schema fixtures, not credentials.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
result=$(awk -f "$root/installer/overlay/usr/local/libexec/c9/eligible-users.awk" <<'EOF'
root:*:0:0::0:0:System Administrator:/root:/bin/sh
valid:INVALID-HASH-FIXTURE:1001:1001::0:0:Example User:/home/valid:/bin/sh
locked:*LOCKED*INVALID:1002:1002::0:0:Locked User:/home/locked:/bin/sh
disabled:!:1003:1003::0:0:Disabled User:/home/disabled:/bin/sh
empty::1004:1004::0:0:Empty Password:/home/empty:/bin/sh
service:INVALID-HASH-FIXTURE:1005:1005::0:0:Service User:/home/service:/usr/sbin/nologin
false_shell:INVALID-HASH-FIXTURE:1006:1006::0:0:No Shell:/home/false:/usr/bin/false
nohome:INVALID-HASH-FIXTURE:1007:1007::0:0:Bad Home:relative:/bin/sh
noshell:INVALID-HASH-FIXTURE:1008:1008::0:0:Missing Shell:/home/noshell:
upper:INVALID-HASH-FIXTURE:65000:65000::0:0:Boundary:/home/upper:/bin/csh
outside:INVALID-HASH-FIXTURE:65001:65001::0:0:Outside Range:/home/outside:/bin/sh
EOF
)
expected=$(printf 'valid\nupper')
[ "$result" = "$expected" ] || { printf 'Unexpected eligible accounts: %s\n' "$result" >&2; exit 1; }
echo 'PASS: FreeBSD master.passwd home/shell columns and account exclusions.'
