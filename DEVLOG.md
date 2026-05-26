# AmiBootEnv Non-Root Installation - Development Log

## Overview

This document describes modifications made to AmiBootEnv to support running as a non-root user after
installation. The original `Install.sh` runs Amiberry as root; the modified `Install-nonroot.sh`
creates a dedicated `amiberry` user and runs the emulator with reduced privileges.

## Issues Identified

### Issue 1: Exit Menu Options Not Working

**Affected Options:** "Edit AmiBootEnv Options" and "Terminal"

**Symptoms:**
- Selecting "Terminal" restarted Amiberry instead of dropping to a shell
- Selecting "Edit Options" restarted Amiberry instead of opening the editor

**Root Cause:**

The original `main.sh` uses a single `while` loop structure:

```bash
while [[ 1 ]]; do
    launch_amiberry
    # ... build menu ...
    . abe-menu.sh

    if [[ "$selection" == "Terminal" ]]; then
        exit  # <-- Problem: exits script entirely
    elif [[ "$selection" == "Options" ]]; then
        micro options.sh
        # <-- Problem: loop continues to top, runs launch_amiberry
    fi
done
```

- **Terminal:** The `exit` command terminates `main.sh`. When running via systemd getty, the service
-   restarts automatically, which relaunches Amiberry.
- **Options:** After the editor closes, the loop continues to the top, calling `launch_amiberry`
-   before showing the menu again.

**Solution:**

Added an inner loop around the exit menu. This allows Terminal and Options to return to the menu
without restarting Amiberry:

```bash
while [[ 1 ]]; do
    launch_amiberry

    # Inner loop for exit menu
    while [[ 1 ]]; do
        # ... build and show menu ...

        if [[ "$selection" == *"(A)"* ]]; then
            break  # Break inner loop to restart Amiberry
        elif [[ "$selection" == *"(T)"* ]]; then
            bash   # Spawn shell; returns to menu when user exits
        elif [[ "$selection" == *"(E)"* ]]; then
            # Edit options; inner loop continues to show menu
            script -q -c "micro options.sh" /dev/null
        elif [[ "$selection" == *"(R)"* ]]; then
            sudo /sbin/shutdown -r now
        elif [[ "$selection" == *"(S)"* ]]; then
            sudo /sbin/shutdown -h now
        fi
    done
done
```

---

### Issue 2: String Comparison Failures

**Symptoms:** The Options menu item comparison failed intermittently.

**Root Cause:**

The Options menu item uses variable expansion:
```bash
menu_item_options="(E)dit ${application_name_cc} Options"
```

Exact string comparison could fail due to subtle differences in how the string was written to the
menu file and read back.

**Solution:**

Changed all menu comparisons to use substring pattern matching with unique hotkey letters:

```bash
# Before (exact match)
if [[ "${abe_menu_selection}" == "${menu_item_options}" ]]; then

# After (substring pattern match)
if [[ "${abe_menu_selection}" == *"(E)"* ]]; then
```

Each menu item has a unique hotkey letter: (A)miberry, (E)dit, (T)erminal, (R)eboot, (S)hutdown.
This approach is more robust.

---

### Issue 3: Editor Fails to Open (TTY Error)

**Symptoms:**
```
open /dev/tty: no such device or address
Fatal: Micro could not initialize a Screen.
```

**Root Cause:**

The non-root installation uses a systemd getty override to launch AmiBootEnv:

```bash
ExecStart=-/usr/bin/su - amiberry -c "/AmiBE/bin/launch.sh"
```

The `su -c` command does not allocate a controlling terminal (tty) for the child process.
Terminal-based editors like `micro` and `nano` require a tty to function.

**Solution:**

Wrapped the editor command with `script` to allocate a pseudo-terminal:

```bash
# Before
micro -colorscheme=material-tc -keymenu=true "${my_path}/options.sh"

# After
script -q -c "micro -colorscheme=material-tc -keymenu=true '${my_path}/options.sh'" /dev/null
```

The `script` command:
- `-q` - Quiet mode (no start/done messages)
- `-c "command"` - Run specified command instead of interactive shell
- `/dev/null` - Discard the typescript file (recording not needed)

---

### Issue 4: options_ex.sh Permission Errors

**Symptoms:**

On every boot, two errors flash briefly on screen before AmiBootEnv starts:

```
/AmiBE/bin/config.sh: line 42: /AmiBE/bin/options_ex.sh: Permission denied
/AmiBE/bin/config.sh: line 44: /AmiBE/bin/options_ex.sh: Permission denied
```

Additionally, `options_ex.sh` may not be executable after install.

**Root Cause:**

`config.sh` lines 42 and 44 write to `options_ex.sh` on every run (it is a generated cache
file rebuilt from `options.sh` when `options.sh` is newer). The `amiberry` user did not have
write permission on the file.

The installer uses `chmod -R u+rwX` on `/AmiBE`, where capital `X` only adds the execute bit
if the file is already executable. If `options_ex.sh` arrives from the archive without the
execute bit, `u+rwX` gives `rw-` (no execute, no guaranteed write path). The glob
`chmod +x "*.sh"` may also miss `options_ex.sh` depending on glob expansion.

**Solution:**

Added explicit `chmod +x` and `chmod u+w` for `options_ex.sh` after the glob line:

```bash
chmod +x "${base_path}/bin/"*.sh
chmod +x "${base_path}/bin/options_ex.sh"
# options_ex.sh is rewritten by config.sh on every run - must be writable
chmod u+w "${base_path}/bin/options_ex.sh"
```

---

### Issue 5: /etc/sudoers.d/amiberry Not Created (Invalid Sudoers Syntax)

**Symptoms:** The file `/etc/sudoers.d/amiberry` is absent after installation despite the
installer writing it.

**Root Cause:**

The sudoers entry added to the heredoc had invalid syntax in the command field:

```
amiberry ALL=(ALL:ALL) (ALL)
```

The `(ALL)` in parentheses is not valid syntax for the command field. Sudoers format is:

```
user host=(runas_user:runas_group) commands
```

The command field must be a path or `ALL` (without parentheses). The installer validates the
file with `visudo -c` and removes it on failure:

```bash
if ! visudo -c -f /etc/sudoers.d/amiberry; then
    echo "WARNING: sudoers file validation failed, removing..."
    rm -f /etc/sudoers.d/amiberry
fi
```

Since `visudo` rejected the file, it was silently removed.

**Solution:**

Removed the parentheses from the command field:

```bash
# Before (invalid)
${amiberry_user} ALL=(ALL:ALL) (ALL)

# After (valid)
${amiberry_user} ALL=(ALL:ALL) ALL
```

---

### Issue 6: Exit Menu Briefly Flashes and Jumps to .uae Selector

**Symptoms:**

After quitting Amiberry, the exit menu (Amiberry / Edit / Terminal / Reboot / Shutdown) appears
briefly and immediately jumps to the .uae config selector without waiting for user input.

**Root Cause:**

When Amiberry exits, it can leave characters in the terminal's stdin buffer (e.g. the Enter or
keypress used to quit the emulator). `abe-menu.sh` uses `read -rsn1 -t 1` to poll for input.
On its very first iteration it immediately reads the buffered character. If that character is
Enter (`""`), `abe-menu.sh` breaks its loop instantly (line 125-126), returning with the
currently highlighted item selected - which defaults to `(A)miberry`. This breaks out of the
inner loop and re-enters `launch_amiberry`, which shows the .uae selector.

**Solution:**

Drain stdin in `main.sh` immediately after `launch_amiberry` returns, before the
inner loop starts:

```bash
# Flush any buffered terminal input left by Amiberry before showing exit menu.
read -r -t 0.1 -N 10000 discard 2>/dev/null || true
```

`-t 0.1` limits the drain to 100ms. `-N 10000` reads up to 10000 characters in one call.
The `|| true` prevents a non-zero exit code from halting the script.

---

### Issue 7: Reboot and Shutdown Menu Options Not Working

**Symptoms:** Selecting (R)eboot or (S)hutdown from the exit menu has no effect.

**Root Cause:**

Two contributing factors:

1. On Debian 13 (Trixie), `/sbin` is a symlink to `/usr/sbin`. Some sudo builds canonicalise
   paths before matching against sudoers rules, so a rule for `/sbin/shutdown` may not match
   when the real binary is `/usr/sbin/shutdown`.

2. The systemd getty override launches AmiBootEnv via `su - amiberry -c`, which may not
   allocate a controlling TTY. By default, sudo requires a TTY (`requiretty`). Without one,
   sudo silently refuses the command.

**Solution:**

Added `Defaults:amiberry !requiretty` to the sudoers file to allow sudo without a TTY.

Added explicit `systemctl` rules alongside the existing `/sbin/` entries for portability:

```
Defaults:amiberry !requiretty
amiberry ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot, /usr/bin/systemctl poweroff, /usr/bin/systemctl halt
amiberry ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot, /sbin/poweroff
```

A third factor was also found on retest: the catch-all sudoers line lacked `NOPASSWD`:

```
# Before - overrides all NOPASSWD rules above it (last match wins)
amiberry ALL=(ALL:ALL) ALL

# After
amiberry ALL=(ALL:ALL) NOPASSWD: ALL
```

In sudo, the last matching rule wins. Without `NOPASSWD` on the catch-all, it matched every
command (including reboot/poweroff) and silently required a password - which could not be
entered with no TTY, causing sudo to fail with no visible error.

Changed `main.sh` to use `systemctl` instead of `/sbin/shutdown`:

```bash
# Before
sudo /sbin/shutdown -r now
sudo /sbin/shutdown -h now

# After
sudo systemctl reboot
sudo systemctl poweroff
```

---

### Issue 8: Amiberry Pinned to 7.1.1 Due to 8.x Renderer Issues

**Symptoms:** Earlier 8.0.0 builds had renderer issues that broke display output, so the
installer was pinned to 7.1.1 as the last known good version.

**Root Cause:**

Renderer regressions in the initial Amiberry 8.x releases.

**Solution:**

Upstream has resolved the 8.x renderer issues. Updated `Install-nonroot.sh` to install
Amiberry 8.1.6 (latest release at time of writing) for both `amiberry` and `amiberry-lite`
flavours:

```bash
# Before
# Pinned to 7.1.1 - last known good version. 8.0.0 has renderer issues.
if [[ ! $(which amiberry) ]]; then
    install_amiberry_flavour amiberry "7.1.1"
fi
install_amiberry_flavour amiberry-lite "7.1.1"

# After
# Using 8.1.6 - 8.x renderer issues are now resolved.
if [[ ! $(which amiberry) ]]; then
    install_amiberry_flavour amiberry "8.1.6"
fi
install_amiberry_flavour amiberry-lite "8.1.6"
```

---

### Issue 9: Amiberry .deb Downloaded but Not Installed (Filename Mismatch)

**Context:** Surfaced during the first VM test of the AmiDeb installer ISO (which runs
`Install-nonroot.sh --unattended` from a first-boot service). See
`docs/superpowers/specs/2026-05-24-amideb-amibootenv-design.md`.

**Symptoms:**

The first-boot log showed the Amiberry release zip downloading and unpacking fine, then:

```
inflating: amiberry_8.1.6+trixie_amd64.deb
amiberry installer not found! Please download and install manually.
```

Amiberry was never installed, so the non-root getty override was never written and the
system booted to the upstream root-mode autologin instead of Amiberry.

**Root Cause:**

The pinned-version path in `install_amiberry_flavour` built an exact filename from version
and architecture only:

```bash
debfile="./${package_name}_${package_version}_${arch}.deb"   # amiberry_8.1.6_amd64.deb
```

BlitterStudio's packages embed the Debian codename in the .deb name
(`amiberry_8.1.6+trixie_amd64.deb`), so the constructed path never matched and
`[[ -f $debfile ]]` failed. (The unpinned/"latest" path already used a glob and was
unaffected - only the pinned-version path was broken.)

**Solution:**

Resolve the .deb by glob in the pinned-version path, both before and after the unzip, so
the `+trixie` suffix is matched:

```bash
# Before
debfile="./${package_name}_${package_version}_${arch}.deb"

# After
debfile=$(ls -vr ./${package_name}_${package_version}*${arch}.deb 2>/dev/null | head -1)
```

The `[[ -f $debfile ]]` test was also quoted (`[[ -f "$debfile" ]]`) so an empty glob
result is handled correctly.

---

### Issue 10: First-Boot Setup Silently "Succeeded" With No Amiberry

**Symptoms:**

After Issue 9, the first-boot service reported success, removed itself, and rebooted - even
though Amiberry had not installed - leaving a system with no emulator and the wrong getty.

**Root Cause:**

`Install-nonroot.sh` ended its "Amiberry not found" branch with a plain `echo` and exited 0,
so the calling first-boot wrapper (`if bash Install-nonroot.sh --unattended; then`) treated
the run as successful.

**Solution:**

Made the failure path exit non-zero so callers detect it and retry:

```bash
echo "Amiberry not found. Installation did not complete successfully. Damn!"
exit 1
```

The first-boot service now stays enabled on failure (retries next boot, keeps the log) rather
than rebooting into a broken state.

---

### Issue 11: amiberry-lite Attempted on amd64 (404)

**Symptoms:**

```
amiberry-lite-v8.1.6-...-amd64.zip ... HTTP request sent, awaiting response... 404 Not Found
```

**Root Cause:**

`amiberry-lite` is the Raspberry Pi / ARM (SDL2) build. Its release track is separate (latest
is v5.9.2) and it has no amd64 or Trixie assets, yet `Install-nonroot.sh` always tried to
install it, pinned to `8.1.6`.

**Solution:**

Only attempt `amiberry-lite` on arm64, and let it resolve its own latest release (no version
pin):

```bash
if [[ "${arch}" == "arm64" ]]; then
    install_amiberry_flavour amiberry-lite
fi
```

---

### Issue 12: Premature chmod of Generated options_ex.sh

**Symptoms:**

```
chmod: cannot access '/AmiBE/bin/options_ex.sh': No such file or directory
```

(Non-fatal, printed twice during install.)

**Root Cause:**

The explicit `chmod` of `options_ex.sh` (added for Issue 4) ran before the file existed -
it is a cache file generated later by `boot-handler.sh` -> `config.sh`, and is not shipped in
the upstream archive.

**Solution:**

Guard the early chmod so it only runs if the file is already present; the post-generation
chmod near the end of the script handles the normal case:

```bash
if [[ -f "${base_path}/bin/options_ex.sh" ]]; then
    chmod +x "${base_path}/bin/options_ex.sh"
    chmod u+w "${base_path}/bin/options_ex.sh"
fi
```

---

### Issue 13: Data-Loss Warning Shown During Unattended Install

**Symptoms:**

On the AmiDeb first-boot (unattended) install, the interactive data-loss warning still
printed:

```
WARNING!

AmiBootEnv should ONLY be installed on a clean, minimal Debian Linux system.
...
This installer MUST be run as ROOT. ...
```

This is meaningless during an automated CD install (there is no operator to read it, and the
disk has just been freshly partitioned), but it must remain for manual installs on amd64 or
Raspberry Pi.

**Root Cause:**

The WARNING block printed unconditionally, before the `unattended` check that guards the
`Proceed? (Y/N)` prompt.

**Solution:**

Moved the whole WARNING block into the interactive (non-unattended) branch, so it prints only
when a human is being asked to confirm:

```bash
if [[ $unattended -eq 1 ]]; then
    # Unattended (e.g. AmiDeb first-boot) install: skip warning + confirmation.
    answer="Y"
    echo "Unattended mode: proceeding with installation."
else
    echo "WARNING!"
    # ... full warning text ...
    echo -n "Proceed with installation? (Y/N) : "
    read answer
fi
```

Unattended runs now print only a one-line "Unattended mode: proceeding with installation."
notice; manual installs are unchanged (full warning plus the Y/N prompt).

---

### Issue 14: PipeWire Audio Errors at Amiberry Start/Quit

**Symptoms:**

At Amiberry start and on quit, the console showed (audio still worked):

```
error: XDG_RUNTIME_DIR is invalid or not set in the environment.
[E] pw.conf | [ conf.c: 1215 pw_conf_load_conf_for_context()] can't load config client.conf: No such file or directory
```

(The `IPC: Listening on /tmp/amiberry.sock` line on the same screen is normal Amiberry output,
not an error.)

**Root Cause:**

Amiberry's SDL2 audio probes PipeWire first. Because Amiberry is launched via
`su - amiberry -c` from the getty service - not a full login session - `systemd-logind` never
created `/run/user/<uid>` or set `XDG_RUNTIME_DIR`, and there is no per-user PipeWire instance
or `client.conf`. PipeWire's client library prints the errors, then SDL falls back to ALSA
(which is what actually produced the sound, since the `amiberry` user is in the `audio` group
and Master is unmuted).

**Solution (two parts):**

1. Force SDL straight to ALSA so the failing PipeWire probe never happens - this removed the
   `pw.conf ... client.conf` lines. Direct ALSA is the right backend for a single-application
   kiosk (lower latency, no audio daemon or user session needed); the only things given up
   (multi-app mixing, Bluetooth audio) are not needed here.

2. The `XDG_RUNTIME_DIR is invalid or not set` warning persisted (a separate library probe,
   not the audio path). Since the `su -c` getty launch is not a login session, logind never
   sets `XDG_RUNTIME_DIR`. A private runtime dir is created via tmpfiles (recreated each boot)
   and passed on the launch.

The getty override written by `Install-nonroot.sh` now sets both:

```bash
# /etc/tmpfiles.d/amiberry.conf
d /run/amiberry 0700 amiberry amiberry -

# getty@tty1 override ExecStart
ExecStart=-/usr/bin/su - amiberry -c "XDG_RUNTIME_DIR=/run/amiberry SDL_AUDIODRIVER=alsa /AmiBE/bin/launch.sh"
```

---

### Issue 15: No Volume Control in the Exit Menu

**Symptoms:**

The AmiBootEnv exit menu offered only Amiberry / Edit / Terminal / Reboot / Shutdown, with no
way to adjust the system volume without dropping to a shell. The original AmiDeb menu had an
Alsamixer entry.

**Solution:**

Added a `(V)olume` entry to the `main.sh` exit menu that launches `alsamixer`. Like the editor
and terminal entries, it is wrapped with `script -q -c` to allocate a pseudo-terminal under
the `su -c` session (alsamixer is an ncurses TUI). On exit it runs `sudo alsactl store` so the
chosen level persists across reboots (the sudoers rules already allow this without a password):

```bash
elif [[ "${abe_menu_selection}" == *"(V)"* ]]; then
    if command -v alsamixer &> /dev/null; then
        script -q -c "alsamixer" /dev/null
        sudo alsactl store 2>/dev/null
    fi
fi
```

Volume can also be adjusted inside Amiberry's own Sound panel (emulated output level) or, for
the system master, via `amixer set Master 5%+` / `5%-` from the Terminal entry.

---

### Issue 16: No Way Back From the System Selector to the Exit Menu

**Symptoms:**

Selecting `(A)miberry` from the exit menu opens the system-to-emulate selector (AROS / A500 /
A1200, etc.). Once there, the only way forward was to boot a system - there was no way to get
back to the exit menu (shutdown / reboot / volume) without launching an emulation and quitting
it.

**Solution:**

Added a `(B)ack to Menu` entry to the system selector in `main.sh` (the
`abe_use_postboot_selector` path). When chosen, `launch_amiberry` returns *without* launching
Amiberry, so the exit menu is shown again:

```bash
echo "${menu_item_back}" >> "${systems_list_file}"
...
if [[ "${abe_menu_selection}" == *"(B)"* ]]; then
    echo "${abe_default_config}" > "${systems_list_file}.selection"  # don't remember Back
    abe_back_to_menu=1
    return
fi
```

Because the exit menu normally auto-times-out and relaunches Amiberry (~3s), arriving via Back
would otherwise bounce straight back to the selector. So when `abe_back_to_menu` is set, the
first exit-menu iteration waits for an explicit choice instead of timing out:

```bash
if [[ $abe_back_to_menu -eq 1 ]]; then
    exit_menu_timeout=86400
    abe_back_to_menu=0
else
    exit_menu_timeout=${abe_amiberry_exit_timeout:-3}
fi
. "${my_path}/abe-menu.sh" "${exit_menu_file}" ${exit_menu_timeout}
```

Picking Back also resets the selector's remembered default so "Back to Menu" never becomes the
auto-selected entry.

---

### Issue 17: Manual Install Missing Samba and an Install Log

**Symptoms:**

A manual install on a Raspberry Pi (running `sudo ./Install-nonroot.sh` as a normal user, the
non-CD path) completed but Samba was never installed, so the `Amiga` network share was
unavailable. There was also no install logfile to inspect after the fact.

**Cause:**

All Samba setup lived only in the AmiDeb CD/unattended flow:

- `preseed.cfg` installed the `samba` package and copied `smb.conf`.
- `amibootenv-firstboot.sh` ran `smbpasswd` and enabled `smbd`, and logged everything to
  `/var/log/amibootenv-firstboot.log` via `exec > >(tee -a ...)`.

`Install-nonroot.sh` itself touched neither Samba nor logging, so a manual run got no share and
left no log.

**Solution:**

Folded both into `Install-nonroot.sh` so the manual path (Raspberry Pi / amd64) matches the CD
path. All steps are idempotent, so running again on the CD path is harmless.

Logging, added right after the root check (writes to `/AmiBE/var/log/install.log`):

```bash
install_log="${base_path}/var/log/install.log"
mkdir -p "${base_path}/var/log" 2>/dev/null
exec > >(tee -a "${install_log}") 2>&1
echo "=== ${application_name} install started: $(date) ==="
```

Samba setup, added in the success branch (after the amiberry user exists and boot-handler has
run). It installs the package, copies the bundled `smb.conf` (preserving the distro original
once), sets the share login for the `amiberry` user to the default `amiberry` password to match
the CD install, then enables and restarts `smbd`:

```bash
install_package samba
cp "${my_path}/smb.conf" /etc/samba/smb.conf
printf 'amiberry\namiberry\n' | smbpasswd -s -a "${amiberry_user}"
systemctl enable smbd; systemctl restart smbd
```

---

## Files Modified

### New Files

| File                 | Description                               |
|----------------------|-------------------------------------------|
| `main.sh`            | Patched version of main.sh with all fixes |
| `Install-nonroot.sh` | Modified installer for non-root operation |
| `DEVLOG.md`          | This development log                      |

### Changes to Install-nonroot.sh

1. Creates dedicated `amiberry` user with appropriate group memberships
2. **Prompts for user password** during installation (for SSH/sudo access)
3. Configures udev rules for hardware access (input, video, USB)
4. Sets up sudoers for shutdown/reboot/mount commands
5. Configures systemd getty override for tty1
6. Copies patched `main.sh` instead of using sed patches

### Changes in main.sh

1. **Inner loop structure** for exit menu (lines 231-285)
2. **Substring pattern matching** for menu selection comparison
3. **`bash` spawn** instead of `exit` for Terminal option
4. **`script` wrapper** for editor to allocate pseudo-terminal
5. **`sudo` prefix** for shutdown commands (non-root operation)

---

## Notes for Upstream

The core issue is that the original script assumes it will always have a controlling terminal and
that `exit` will return to a login prompt. When running via systemd getty with `su -c`, these
assumptions don't hold.

The fixes are backward-compatible with the root installation if:
1. The inner loop structure is adopted (improves UX regardless of root/non-root)
2. The `script` wrapper is used conditionally (only when no tty is available)
3. The `sudo` commands are made conditional based on user privileges

Alternatively, the systemd getty override could use `agetty --autologin amiberry` instead of `su -c`,
which properly allocates a controlling terminal. However, this would require additional configuration
to run `launch.sh` from the user's profile.

---

## Author

Modifications by: VK3HEG
Date: March 2026
