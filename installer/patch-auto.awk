# Keep upstream bsdinstall's interactive flow, with two explicit changes.
# A changed upstream script must fail the image build rather than half-patch it.
$0 == "if [ ! -f $BSDINSTALL_DISTDIR/MANIFEST ]; then" {
    mode_start++
    skipping = 1
    print "# C9: only the verified distribution sets bundled on this ISO."
    print "PKGBASE=no"
    next
}
skipping && $0 == "if [ \"$PKGBASE\" == yes ]; then" {
    mode_end++
    skipping = 0
}
skipping { next }
index($0, "[ -f /usr/libexec/bsdinstall/local.post-configure ]") == 1 {
    hook++
    print "# C9 is part of the installation, and failure must not report success."
    print "sh /usr/libexec/bsdinstall/local.post-configure \"$BSDINSTALL_CHROOT\" || error \"C9 desktop installation failed; see /tmp/c9-install.log\""
    next
}
{ print }
END {
    if (mode_start != 1 || mode_end != 1 || hook != 1 || skipping) {
        print "Unsupported bsdinstall auto script: C9 patch match counts differ" > "/dev/stderr"
        exit 1
    }
}
