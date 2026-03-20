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
currently highlighted item selected — which defaults to `(A)miberry`. This breaks out of the
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
command (including reboot/poweroff) and silently required a password — which could not be
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
