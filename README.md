# Screendump — PortMaster port for Knulli / Batocera (aarch64)

> **Portmaster console build of [screendump](https://github.com/DigiAlchemydsp/screendumpTUI)** —
> see your Elektron instrument's screen on the handheld, over MIDI, using the
> instrument's own screenshot command. **Nothing on the machine is modified.**
>
> This branch adds the Anbernic H700 / Knulli **PortMaster packaging**, the
> vaixterm terminal + gptokeyb **control layer**, and the **pairing loop** that
> cycles Digitone / Digitakt / Syntakt and streams the first machine that answers.

Connect an Elektron **Digitone / Digitakt / Syntakt** by USB-MIDI
(`GLOBAL → USB CFG → USB MIDI` on the machine), launch the port, and the
handheld mirrors the machine's screen at its own refresh rate (~30 fps).

## Requirements

| Dependency | Source | Notes |
|---|---|---|
| `python3` | ships with Knulli | runs the screendump tool |
| `python-rtmidi` | **bundled** in the port (`Screendump/py/`) | vendored at build time |
| `vaixterm` terminal emulator | ships with Knulli (`/usr/bin/vaixterm`) | also called VAxTerm |
| PortMaster control layer (`control.txt`, `gptokeyb`) | ships with Knulli at `/userdata/system/.local/share/PortMaster/` | gamepad → keys |
| Elektron machine + USB-MIDI | — | nothing else |

## Install

Final layout on the device:

```
/userdata/roms/ports/
├── Screendump.sh          (executable launcher, shown in the Ports menu)
└── Screendump/
    ├── port.json
    ├── gameinfo.xml
    ├── Screendump.gptk    (gamepad → TUI keys)
    ├── pair.sh            (the pairing loop, run inside vaixterm)
    ├── screendump         (the tool, single file)
    ├── py/                (vendored python-rtmidi, aarch64)
    └── userdata/          (created at first run)
```

```bash
# from any machine with scp/ssh (Linux, macOS, WSL, Git Bash):
bash scripts/install-ssh.sh root@<knulli-ip>
# then restart EmulationStation (or reboot) and launch Screendump from the Ports menu.
```

Or by SD card: unzip `release/Screendump.zip` into `userdata/roms/ports/`
(`chmod +x Screendump.sh Screendump/pair.sh` if the port won't launch).

## How it works

The launcher (`Screendump.sh`) is a standard PortMaster shim: sources
`control.txt`, disables USB autosuspend (Knulli's 2 s idle timeout would
otherwise drop the USB-MIDI connection), and starts **vaixterm** with the
pairing loop. It also bundles `python-rtmidi` so nothing has to be installed
on the device.

`pair.sh` is the small loop that runs inside the terminal:

1. Probe each instrument in turn — `dn`, `dt`, `sy` — with a one-second
   single-shot capture (`screendump -x --timeout 1 --instrument <x>`).
2. The **first machine that answers** wins; launch the live stream
   (`screendump -x --framerate 30 --instrument <x>`).
3. When the stream ends (press `q`/B), loop back and pair again — so you can
   swap machines or unplug/replug without relaunching the port.
4. If nothing answers, it keeps retrying until a machine appears.

Because the Digitakt and Digitone answer the screenshot RPC on the **same id**,
either name finds either machine — the order just picks a label. The Syntakt
entry joins the cycle automatically once it is implemented in screendump.

## Controls (gamepad → TUI keys)

| Gamepad | Key | Screendump action |
|---|---|---|
| A | `s` | save the current frame as a `.syx` |
| B | `q` | quit the stream (back to the pairing loop) |
| X | `m` | render mode: braille → blocks → ascii |
| Y | `i` | invert lit and unlit |
| L1 | `h` | show the key help |
| R1 | `f` | flip vertically |
| L2 / R2 | `p` / `space` | pause / resume the stream |
| Start | `space` | pause / resume |
| Guide | `h` | show the key help |

- **Fully exit the port** with the EmulationStation hotkey.
- Want different bindings? Edit `Screendump/Screendump.gptk` on the device
  (flat format — the device's gptokeyb v1 rejects a `[controls]` section).

## Building from source

`release/Screendump.zip` is built with `scripts/build-port.sh` — run it **on
the device** (aarch64 Linux, where `pip` resolves the right `python-rtmidi`
wheel for the device's Python), or on any host with Python 3:

```bash
# on the device:
ssh root@<knulli-ip>
cd /tmp
bash scripts/build-port.sh        # produces release/Screendump.zip
```

What it does:

1. Vendors `python-rtmidi` for aarch64 into `py/` (native `pip --target` on
   the device; a `manylinux2014_aarch64` wheel download on a host — set
   `RTPYTHON_VERSION` to the device's `cpXY` if the host Python differs).
2. Copies `screendump` + the `portmaster/` metadata into the port dir.
3. Assembles and zips `Screendump.sh` + `Screendump/` into `release/Screendump.zip`.

Known build quirks:

- `/userdata` is exFAT — no symlinks; the build never creates any.
- `vaixterm -e` execs a **single path**, no shell → `pair.sh` is that path.
- gptokeyb v1 rejects a `[controls]` header → flat `.gptk` format.
- The `python-rtmidi` wheel dlopens its **bundled `libjack`** from
  `py/python_rtmidi/` — the launcher adds that dir to `LD_LIBRARY_PATH`.

## Repository layout

```
screendump-portmaster/
├── README.md               (this file)
├── LICENSE                 (MIT)
├── screendump              the tool (single file, from the screendump repo)
├── portmaster/             small versioned source files used by build-port.sh
│   ├── Screendump.sh       PortMaster launcher (PORTMASTER header)
│   ├── pair.sh             the pairing loop (vaixterm -e target)
│   ├── Screendump.gptk     gamepad → keys
│   ├── port.json           PortMaster metadata
│   └── gameinfo.xml        EmulationStation metadata
├── scripts/
│   ├── build-port.sh       full build → release/Screendump.zip
│   ├── install-ssh.sh      SSH install helper
│   └── uninstall-ssh.sh    SSH remove helper
└── release/                built Screendump.zip (gitignored)
```

> `python-rtmidi` is several MB — it is **not tracked in git**. Publish the
> built zip as a GitHub Release; `scripts/build-port.sh` reproduces it.

## Troubleshooting

- **Port doesn't appear in the menu**: EmulationStation rescans at startup —
  restart ES (or reboot). Check the layout matches the tree above.
- **Blank screen on launch**: check `Screendump/log.txt` on the device;
  over SSH run `python3 -c "import rtmidi"` from `Screendump/` to confirm the
  bundled wheel loads.
- **Keeps saying "no machine found"**: confirm the Elektron box is in
  `GLOBAL → USB CFG → USB MIDI` (not Overbridge), and that it enumerates:
  `python3 screendump --list-midi`.
- **Gamepad does nothing**: confirm gptokeyb started (`[GPTK]` in `log.txt`);
  Knulli's hotkey should still exit the port.