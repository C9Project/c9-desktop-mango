# Convert the pinned FreeBSD update source records to a complete mtree spec.
# Input must be sorted by path, so every directory precedes its children.
BEGIN { FS="|"; print "#mtree" }
$1 == "src" && ($3 == "/usr/src" || index($3, "/usr/src/") == 1) {
    path="." substr($3, 9)
    if (seen[path]++ || path ~ /(^|\/)\.\.(\/|$)/ || $3 ~ /[\t\r\n]/) exit 1
    if ($4 != "f" && $4 != "d") exit 1
    if ($5 !~ /^[0-9]+$/ || $6 !~ /^[0-9]+$/ || $7 !~ /^0[0-7]+$/ || $8 != "0") exit 1
    # mtree uses vis(3) escapes in pathnames. A replacement constructed from
    # sprintf avoids awk's replacement-backslash interpretation.
    escaped=""
    for (i=1; i<=length(path); i++) {
        c=substr(path,i,1)
        if (c == "\\") c=sprintf("%c134",92)
        else if (c == " ") c=sprintf("%c040",92)
        else if (c == "#") c=sprintf("%c043",92)
        escaped=escaped c
    }
    printf "%s type=%s uid=%s gid=%s mode=%s", escaped, ($4 == "f" ? "file" : "dir"), $5, $6, $7
    if ($4 == "f") {
        if (length($9) != 64 || $9 ~ /[^0-9a-f]/) exit 1
        printf " sha256digest=%s", $9
        files++
    }
    print ""
    count++
}
END {
    # These counts are part of this release's pinned source inventory.
    if (count != 118606 || files != 109079 || !seen["."]) exit 1
}
