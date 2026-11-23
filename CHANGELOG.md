# Changelog

## Project identity and source control — 23 November 2026

- Set `c9_project@proton.me` as maintainer for the ten C9 ports and record the
  C9Project GitHub account. Retain upstream port maintainer addresses.
- Preserve the verified source as the Git baseline, with a separate contact
  change and a private `C9Project/c9-desktop-mango` source-control remote.
- Keep existing package versions and release artifacts unchanged. Cached
  packages can retain their original contact metadata until a later release.

## Rebuild automation — 22 November 2026

- Add a detached/foreground incremental package-to-ISO runner with retained
  source snapshots, exclusive locking, per-stage logs and explicit final status.
- Reuse verified p6 image inputs with separate historical kernel and current
  package build identities; retain all existing package and ISO checks.
- Add read-only image-input preflight and isolated orchestration regressions.
  Preserve package versions, port contents, resource limits and publication policy.

## Maintenance documentation — 22 November 2026

- Record the user's successful Dell installation report without inferring
  additional graphics/application qualification.
- Add a complete customization/rebuild guide covering source changes,
  coordinated C9 versions, deployment, package reuse, fresh image-jail
  provenance, ISO verification and failure recovery.

## 0.2.0 installer ZFS correction — 22 November 2026

- Reproduce the p6 adduser doubled-altroot home mount on the Dell and in an
  isolated ZFS fixture; preserve the correctly owned user files.
- Add a selected-home mount correction outside the installer chroot before
  C9 account setup, retaining the existing ownership/authentication checks.
- Document resuming the failed C9 stage without repeating disk/base setup.
- Pass exact-p6 ZFS repair, correct-mount repeat, genuine wrong-owner rejection
  and real UFS preservation tests. Rebuild the ISO and pass static checks and
  the complete F: checksum verification. Fresh EFI/ZFS installation validation
  remains pending; the completed original BIOS/EFI tests used UFS.

## 0.2.0 build and ISO validation — 22 November 2026

- Complete all ten C9 packages and dependencies, retaining compatible packages
  from earlier builds; verify the signed 545-package combined install plan.
- Apply the approved VS Code-only memory/file limits and correct the
  Development meta-port's Python runtime dependency.
- Prepare the isolated p6 image jail with a standard source-built GENERIC
  kernel and preserve the authenticated source/payload provenance.
- Build the offline BIOS/EFI hybrid ISO, including all offered package groups,
  and pass static boot, payload, signature and dependency-closure checks.
- Verify the full local ISO copy on C: NTFS after the original E: USB volume
  reports hardware I/O errors; recover the source and documentation to C:.
- Pass BIOS Essential-only and EFI Essential+Development+Office offline
  installations, SDDM password rejection, authenticated non-root test sessions,
  logout and authentication after actual software reboots. Optional application
  version commands and Mango configuration parsing pass as the regular user.
  Physical desktop and package-upgrade acceptance remain separate checks.
- Add a short quick-start guide and retain detailed reproduction/evidence
  records. Test-only X11 session files are excluded from production artifacts.

## 0.2.0 source — 14 November 2026

- Add workstation, Essential, Development and Office package groups.
- Add authenticated SDDM/native Mango integration, Waybar, preserved user
  defaults, explicit system setup and original artwork.
- Replace initial desktop utility options with fixed Fuzzel/Mako/Swaybg.
- Add Dell Latitude 5591 / UHD 630 and VirtualBox hardware packages;
  VirtualBox covers installer/login tests only, with no nested Mango or AMD.
- Add checked Poudriere release workflow and offline ISO/bsdinstall source
  using signed packages and matched FreeBSD 15.1-RELEASE-p6 inputs.
- Document package-first gates, compatible package reuse, reproduction inputs
  and separate installer/login versus physical graphics acceptance.
- Preserve the active 0.1.0 server build and overlay until it finishes.

This records source implementation. No successful 0.2.0 package build, ISO,
installation or graphical runtime validation is claimed yet.

## 0.1.0 — 10 November 2026

- Add the dependency-only `x11/c9-desktop-mango` port.
- Select eight core packages and three optional desktop utilities.
- Document Poudriere overlays, testing, building, and local installation.
- Explain all code and configuration examples; retain primary-source links.
- Include the original project baseline without changing its login requirement.
- Record reference-source hashes and distinguish inspection from FreeBSD tests.
