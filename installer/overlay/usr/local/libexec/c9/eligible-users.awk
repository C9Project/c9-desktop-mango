# FreeBSD master.passwd fields: name:hash:uid:gid:class:change:expire:gecos:home:shell
# Emit account names only. Password hashes never enter installer logs.
BEGIN { FS = ":" }
$3 >= 1000 && $3 <= 65000 && $2 != "" && $2 !~ /^[!*]/ && \
    $9 ~ /^\// && $10 ~ /^\// && $10 !~ /\/(nologin|false)$/ { print $1 }
