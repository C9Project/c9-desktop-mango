#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-2-Clause
"""Source checks for C9's Rio terminal migration (Python 3.11+).

Default: portable source checks only; no shell scripts or applications run.
On FreeBSD, --freebsd-user-init also runs a copy of c9-user-init as the current
non-root user in new fixture homes. The only helper edit redirects its installed
templates directory to the fixture. It never installs packages, modifies an
account, or runs Rio/Mango. --evidence-dir must name a new directory; fixtures
and command results are retained there. A requested runtime test is never
silently skipped.

Examples:
  python tests/test-terminal.py --evidence-dir /path/to/new-static-evidence
  python3 tests/test-terminal.py --freebsd-user-init \
      --evidence-dir /path/to/new-freebsd-evidence

TOML parsing checks syntax, not Rio's configuration schema or renderer.
"""

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tomllib


DEFAULTS = Path("ports/x11/c9-desktop-defaults")
RIO = ".config/rio/config.toml"
MANGO = ".config/mango/config.conf"
FUZZEL = ".config/fuzzel/fuzzel.ini"


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def make_values(text, variable):
    """Read literal assignments needed here; this is not a BSD make evaluator."""
    logical = re.sub(r"\\\r?\n[ \t]*", " ", text)
    return re.findall(r"^" + re.escape(variable) + r"\s*(?:\+|\?|:)?=\s*(.*?)\s*$",
                      logical, re.MULTILINE)


def ini(text):
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read_string(text)
    return parser


def source_checks(project, report):
    inputs = report["source_sha256"]

    def read(relative):
        name = Path(relative).as_posix()
        data = (project / relative).read_bytes()
        inputs[name] = sha256(data)
        return data.decode("utf-8")

    release = re.findall(r"^C9_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$",
                         read("installer/release.conf"), re.MULTILINE)
    require(len(release) == 1, "release.conf must declare one literal C9_VERSION")
    version = release[0]
    require(tuple(map(int, version.split("."))) >= (0, 2, 1),
            "Rio defaults require C9 release 0.2.1 or later")
    ports = sorted(project.glob("ports/*/c9-*/Makefile"))
    require(len(ports) == 10, "expected all ten C9 package Makefiles")
    makefiles = {}
    for port in ports:
        relative = port.relative_to(project).as_posix()
        text = read(relative)
        makefiles[relative] = text
        require(make_values(text, "DISTVERSION") == [version],
                f"{relative}: DISTVERSION differs from release {version}")
        for value in make_values(text, "RUN_DEPENDS"):
            require(not re.search(r":x11/foot(?:\s|$)", value),
                    f"{relative}: still depends on Foot")
            for constraint in re.findall(r"\bc9-[\w-]+>=([^:\s]+):", value):
                require(constraint == version,
                        f"{relative}: C9 dependency constraint differs from {version}")
    expected = {
        "ports/x11/c9-desktop-mango/Makefile": "rio-terminal-emulator>=0:x11/rio",
        "ports/misc/c9-apps-essential/Makefile": "rio-terminal-emulator>=0:x11/rio",
        "ports/x11/c9-desktop-defaults/Makefile": "rio:x11/rio",
    }
    for relative, dependency in expected.items():
        dependencies = " ".join(make_values(makefiles[relative], "RUN_DEPENDS")).split()
        require(dependencies.count(dependency) == 1,
                f"{relative}: expected exactly one {dependency}")
    report["static_checks"].append("ten release versions, C9 constraints and Rio dependencies")

    helper = read(DEFAULTS / "files/c9-user-init")
    blocks = re.findall(r"<<'FILES'\r?\n(.*?)\r?\nFILES(?:\r?\n|$)", helper, re.DOTALL)
    require(len(blocks) == 1, "expected one user-init template inventory")
    initialized = blocks[0].splitlines()
    require(len(initialized) == len(set(initialized)), "duplicate user-init templates")
    for relative in initialized:
        require(relative.startswith(".config/") and ".." not in Path(relative).parts,
                f"unsafe or unexpected template path: {relative}")
    template_root = project / DEFAULTS / "files/skel"
    templates = {}
    for entry in sorted(template_root.rglob("*")):
        require(not entry.is_symlink(), f"template must not be a symlink: {entry}")
        if entry.is_file():
            relative = entry.relative_to(template_root).as_posix()
            templates[relative] = read(entry.relative_to(project))
    plist = read(DEFAULTS / "pkg-plist").splitlines()
    prefix = "%%DATADIR%%/skel/"
    packaged = [entry.removeprefix(prefix) for entry in plist if entry.startswith(prefix)]
    require(len(packaged) == len(set(packaged)), "duplicate packaged templates")
    require(set(initialized) == set(packaged) == set(templates),
            "user-init, pkg-plist and actual template files differ")
    require(RIO in templates and not (template_root / ".config/foot").exists(),
            "Rio template must replace the packaged Foot template")
    tomllib.loads(templates[RIO])
    report["static_checks"].append("TOML syntax and matching template/install inventories")

    bindings = []
    for line in templates[MANGO].splitlines():
        if line.strip().startswith("bind="):
            fields = [part.strip() for part in line.strip()[5:].split(",", 3)]
            if fields[:2] == ["SUPER", "Return"]:
                bindings.append(fields)
            if len(fields) == 4 and fields[2] == "spawn":
                argv = shlex.split(fields[3])
                require(not argv or Path(argv[0]).name not in ("foot", "footclient"),
                        "Mango still launches Foot")
    require(len(bindings) == 1 and bindings[0][2] == "spawn"
            and shlex.split(bindings[0][3]) == ["rio"], "Super+Return must launch rio")
    require(shlex.split(ini(templates[FUZZEL])["main"]["terminal"]) == ["rio", "-e"],
            "Fuzzel terminal command must be rio -e")
    desktop = ini(read(DEFAULTS / "files/c9-rio.desktop"))["Desktop Entry"]
    require(shlex.split(desktop["Exec"]) == ["rio"] and desktop["TryExec"] == "rio",
            "desktop launcher must resolve the same rio binary")
    require(desktop["Type"] == "Application" and desktop.get("Terminal") == "false",
            "Rio desktop launcher must not recursively open another terminal")
    require(plist.count("share/applications/c9-rio.desktop") == 1,
            "Rio desktop launcher missing or duplicated in plist")
    defaults_make = makefiles[(DEFAULTS / "Makefile").as_posix()]
    require(re.search(r"\$\{INSTALL_DATA\}\s+\$\{FILESDIR\}/c9-rio\.desktop\s+"
                      r"\$\{STAGEDIR\}\$\{PREFIX\}/share/applications/", defaults_make),
            "Rio desktop launcher lacks its install recipe")
    report["static_checks"].append("Mango, Fuzzel and packaged desktop launcher resolve Rio")
    report["release"] = version
    return template_root, helper, initialized


def tree_state(root):
    """Observe fixture paths without following symlinks, including empty dirs."""
    result = {}

    def visit(entry, relative):
        metadata = entry.lstat()
        record = [stat.S_IFMT(metadata.st_mode), stat.S_IMODE(metadata.st_mode),
                  metadata.st_uid, metadata.st_gid, metadata.st_mtime_ns]
        if entry.is_symlink():
            record.append(os.readlink(entry))
        elif entry.is_file():
            record.append(sha256(entry.read_bytes()))
        result[relative] = record
        if stat.S_ISDIR(metadata.st_mode):
            for child in sorted(entry.iterdir()):
                visit(child, relative + "/" + child.name)
    visit(root, ".")
    return result


def runtime_checks(template_root, helper, initialized, evidence, report):
    require(platform.system() == "FreeBSD", "runtime mode requires actual FreeBSD")
    require(os.geteuid() != 0, "runtime mode must run as a non-root user")
    fixture = evidence / "user-init fixture"
    fixture.mkdir()
    templates = fixture / "templates"
    shutil.copytree(template_root, templates)
    assignment = "templates=/usr/local/share/c9/skel"
    require(helper.splitlines().count(assignment) == 1,
            "expected one exact installed templates assignment")
    replacement = "templates=" + shlex.quote(str(templates))
    adapted = "".join(replacement + line[len(assignment):]
                      if line.rstrip("\r\n") == assignment else line
                      for line in helper.splitlines(keepends=True))
    helper_path = fixture / "c9-user-init"
    helper_path.write_text(adapted, encoding="utf-8", newline="\n")
    report["runtime_helper"] = {
        "source_sha256": sha256(helper.encode()),
        "fixture_sha256": sha256(adapted.encode()),
        "only_change": {"from": assignment, "to": replacement},
    }
    (evidence / "helper-substitution.json").write_text(
        json.dumps(report["runtime_helper"], indent=2) + "\n", encoding="utf-8")
    uid = os.geteuid()
    homes = fixture / "homes"
    homes.mkdir()

    def home(name):
        directory = homes / name
        directory.mkdir()
        return directory

    def put(directory, relative, content):
        target = directory / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return target

    def invoke(name, directory, *, xdg=None, args=(), succeeds=True):
        environment = os.environ.copy()
        environment.pop("XDG_CONFIG_HOME", None)
        environment["HOME"] = str(directory)
        if xdg is not None:
            environment["XDG_CONFIG_HOME"] = str(xdg)
        command = ["/bin/sh", str(helper_path), *args]
        completed = subprocess.run(command, env=environment, capture_output=True,
                                   text=True, timeout=20, cwd=fixture)
        record = {"command": command, "HOME": str(directory), "XDG_CONFIG_HOME": xdg,
                  "exit_status": completed.returncode, "stdout": completed.stdout,
                  "stderr": completed.stderr}
        (evidence / (name + ".json")).write_text(json.dumps(record, indent=2) + "\n",
                                                encoding="utf-8")
        require((completed.returncode == 0) == succeeds,
                f"{name}: unexpected helper exit {completed.returncode}")
        return completed

    fresh = home("fresh")
    invoke("fresh", fresh)
    for relative in initialized:
        target = fresh / relative
        require(not target.is_symlink() and target.is_file(), f"missing fresh {relative}")
        require(target.read_bytes() == (templates / relative).read_bytes(),
                f"fresh {relative} differs from template")
        require(target.stat().st_uid == uid, f"fresh {relative} has wrong owner")
    require(not (fresh / ".config/foot").exists(), "fresh user unexpectedly received Foot")
    report["runtime_checks"].append("fresh user gets exact Rio and matching launch templates")
    before = tree_state(fresh)
    invoke("repeat", fresh)
    require(tree_state(fresh) == before, "second initialization changed existing defaults")
    report["runtime_checks"].append("second run preserves all contents and metadata")

    custom = home("custom")
    for relative in (RIO, MANGO, FUZZEL, ".config/foot/foot.ini"):
        put(custom, relative, "user content for " + relative + "\n")
    old_files = {relative: tree_state(custom / relative)
                 for relative in (RIO, MANGO, FUZZEL, ".config/foot/foot.ini")}
    invoke("custom", custom)
    for relative, state in old_files.items():
        require(tree_state(custom / relative) == state, f"custom {relative} overwritten")
    require((custom / ".config/waybar/config.jsonc").is_file(),
            "custom terminal prevented other missing defaults")
    report["runtime_checks"].append("custom Rio/Mango/Fuzzel and legacy Foot stay untouched")

    for relative in (".config", ".config/rio", RIO):
        case = "symlink-" + relative.replace("/", "-").replace(".", "")
        directory = home(case)
        outside = fixture / (case + "-target")
        if relative == RIO:
            outside.write_text("private custom terminal\n", encoding="utf-8")
        else:
            outside.mkdir()
            put(outside, "sentinel", "keep\n")
        link = directory / relative
        link.parent.mkdir(parents=True, exist_ok=True)
        link.symlink_to(outside, target_is_directory=relative != RIO)
        before = tree_state(outside)
        link_before = tree_state(link)
        invoke(case, directory)
        require(tree_state(outside) == before and tree_state(link) == link_before,
                f"{case}: symlink or target changed")
    report["runtime_checks"].append("symlinked config ancestors and Rio file are preserved")

    real_home = home("symlink-home-target")
    linked_home = homes / "symlink-home"
    linked_home.symlink_to(real_home, target_is_directory=True)
    before = tree_state(real_home)
    invoke("symlink-home", linked_home)
    require(linked_home.is_symlink() and tree_state(real_home) == before,
            "symlinked home was initialized")
    custom_xdg_home = home("custom-xdg-home")
    custom_xdg = home("custom-xdg-target")
    put(custom_xdg, "sentinel", "keep\n")
    before = (tree_state(custom_xdg_home), tree_state(custom_xdg))
    invoke("custom-xdg", custom_xdg_home, xdg=str(custom_xdg))
    require((tree_state(custom_xdg_home), tree_state(custom_xdg)) == before,
            "custom XDG_CONFIG_HOME changed")
    report["runtime_checks"].append("symlinked home and custom XDG_CONFIG_HOME stay untouched")

    guards = home("guards")
    before = tree_state(guards)
    invoke("unexpected-argument", guards, args=("unexpected",), succeeds=False)
    invoke("relative-home", "relative", succeeds=False)
    invoke("missing-home", fixture / "absent", succeeds=False)
    # Read-only negative test against FreeBSD's protected empty directory.
    # With no .config and no write permission, even a broken ownership guard
    # cannot create a path there. No root action or chown is needed.
    wrong_home = Path("/var/empty")
    require(wrong_home.is_dir() and not wrong_home.is_symlink()
            and wrong_home.stat().st_uid != uid and not os.access(wrong_home, os.W_OK)
            and not os.path.lexists(wrong_home / ".config"),
            "wrong-owner fixture requires protected /var/empty without .config")
    rejected = invoke("wrong-owner-home", wrong_home, succeeds=False)
    require("HOME is not owned by this user" in rejected.stderr,
            "wrong-owner guard did not reject HOME explicitly")
    require(tree_state(guards) == before, "argument guards modified the fixture home")
    report["runtime_checks"].append("argument, relative/missing HOME and wrong-owner guards")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--evidence-dir", type=Path, help="new directory; never overwrite evidence")
    parser.add_argument("--freebsd-user-init", action="store_true",
                        help="also run isolated user-init fixtures on FreeBSD as non-root")
    args = parser.parse_args()
    if args.freebsd_user_init and args.evidence_dir is None:
        parser.error("--freebsd-user-init requires --evidence-dir")
    evidence = None
    if args.evidence_dir is not None:
        evidence = args.evidence_dir.absolute()
        try:
            evidence.mkdir(parents=False, exist_ok=False)
        except OSError as error:
            parser.error(f"cannot create new evidence directory: {error}")
        evidence = evidence.resolve()
    report = {"project": str(args.project.resolve()), "platform": platform.platform(),
              "test_sha256": sha256(Path(__file__).read_bytes()),
              "python": sys.version, "static_checks": [], "source_sha256": {},
              "runtime_requested": args.freebsd_user_init, "runtime_checks": [],
              "runtime_status": "not run", "status": "failed",
              "limitations": ["Source checks do not build or install packages.",
                              "TOML syntax is not Rio schema or rendering validation.",
                              "Runtime fixtures, when requested, use one templates-path substitution; "
                              "they do not prove package installation or upgrades."]}
    try:
        template_root, helper, initialized = source_checks(args.project.resolve(), report)
        if args.freebsd_user_init:
            report["runtime_status"] = "failed"
            runtime_checks(template_root, helper, initialized, evidence, report)
            report["runtime_status"] = "passed"
        report["status"] = "passed"
    except (AssertionError, OSError, ValueError, KeyError, configparser.Error,
            subprocess.SubprocessError) as error:
        report["error"] = str(error)
    result = json.dumps(report, indent=2) + "\n"
    if evidence is not None:
        (evidence / "RESULTS.json").write_text(result, encoding="utf-8")
    print(result, end="")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
