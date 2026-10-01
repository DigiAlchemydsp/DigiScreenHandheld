# screendump

See your Elektron instrument's screen in the terminal, over MIDI, using the
instrument's own screenshot command. **Nothing on the instrument is modified.**

One file, one dependency (`python-rtmidi`), macOS/Linux/Windows.

## Install

```
pip install python-rtmidi
```

`screendump` is a single file: put it on your `PATH` and make it executable, or
run it from the repo.

| for | install |
|---|---|
| the screen, recording, GIF | `pip install python-rtmidi` |
| `--save-audio` | `pip install sounddevice` |
| `--save-video` | ffmpeg — `brew install ffmpeg`, `apt install ffmpeg`, `winget install ffmpeg` |

## Find your MIDI ports

```
$ screendump --list-midi
MIDI inputs (instrument -> computer):
  [0] Elektron Digitakt
MIDI outputs (computer -> instrument):
  [0] Elektron Digitakt
```

## Live view (the TUI)

```
$ screendump -x --framerate 30 --midi-in 0 --midi-out 0 --instrument dt
```

Streams the screen into a full-screen TUI until you quit. Your terminal is left
exactly as it was — the live view never enters the scrollback.

| key | |
|---|---|
| `q` / `esc` | quit (Ctrl+C works too) |
| `m` / `tab` | render mode: braille → blocks → ascii |
| `i` | invert lit and unlit |
| `f` | flip vertically |
| `p` / `space` | pause / resume the stream |
| `s` | save the current frame as a `.syx` |
| `h` / `?` | show this help |

The rate is capped at 30, the instrument's own refresh. Over DIN expect about 3.

## Single screenshot

```
$ screendump -x --midi-in 0 --midi-out 0 --instrument dt --blocks
```

`-x` is the only mode that talks to hardware. Output goes to stdout, so it pipes
and tees like anything else.

Ports can be given three ways: an index from `--list-midi`, an instrument short
form (`--midi-in dt`), or any fragment of the port name (`--midi-in MOTU`). A
fragment has to identify exactly one port.

## Keep the data, render differently later

```
$ screendump -x --save-syx shot.syx
$ screendump --from-file shot.syx --blocks
$ screendump --from-file shot.syx --ascii --invert
```

## Record while you watch

```
$ screendump -x --framerate 15 --save-mid cap.mid --save-gif out.gif
```

Only frames that actually **changed** are kept, each with the length of time it
was on screen. Add `-H` / `--hide` to record without drawing anything.

```
$ screendump --from-file cap.mid --save-gif out.gif
```

## Sound and video

```
$ screendump -x --framerate 30 --audio-in dt \
             --save-mid cap.mid --save-audio cap.wav
$ screendump --from-file cap.mid --from-audio cap.wav --save-video out.mp4
```

Or both halves in one go:

```
$ screendump -x --framerate 30 --audio-in dt --save-video out.mp4
```

## Set it once per session

```
$ export SCREENDUMP_MIDI_IN=0             # [0] from --list-midi
$ export SCREENDUMP_MIDI_OUT=0            # [0] from --list-midi
$ export SCREENDUMP_AUDIO_IN=dt           # short form, or an index
$ export SCREENDUMP_INSTRUMENT=Digitakt   # or DT, or dt

$ screendump -x
```

An option always beats the environment. PowerShell: `$env:SCREENDUMP_MIDI_IN = "0"`.
cmd.exe: `set SCREENDUMP_MIDI_IN=0`.

## Options

| | |
|---|---|
| `-x`, `--external` | capture from the instrument |
| `--list-midi` | list MIDI ports |
| `--list-audio` | list audio inputs |
| `--midi-in`, `--midi-out` | port index or name fragment |
| `--audio-in` | audio input index or name fragment |
| `--instrument` | which machine — required, no default |
| `--blocks` | half-block rendering, no row gaps |
| `--ascii` | full resolution, one character per pixel |
| `--invert`, `--flip` | swap lit/unlit, flip vertically |
| `--framerate N` | with `-x`, stream until you quit (capped at 30); also the frame rate of a video |
| `-H`, `--hide` | while streaming, don't draw to the terminal |
| `--save-syx PATH` | also save the frame |
| `--save-raw PATH` | also save just the pixel bytes |
| `--save-mid PATH` | also save the recording, with timing, as a MIDI file |
| `--save-gif PATH` | also save an animated GIF |
| `--save-audio PATH` | also record the instrument's audio to a stereo WAV |
| `--save-video PATH` | write an mp4 of picture and sound together |
| `--upscale N` | enlarge each pixel to N × N in a GIF or video (default 4) |
| `--from-file PATH` | render a saved `.syx`, `.mid` or raw dump instead |
| `--from-audio PATH` | the `.wav` to pair with `--from-file` for a video |
| `--bench N` | measure the frame rate over N captures |
| `--self-test` | check the tool without an instrument |
| `--timeout` | reply timeout in seconds, default 2 |

Nothing is written to disk unless you ask.

## If braille looks gappy

Braille shows seams between rows in many terminals. **Use `--blocks`** — it fills
the cell edge to edge and always looks solid. Iosevka and JuliaMono draw tight
braille; SF Mono and Menlo are heavily padded.

## Instruments

`--instrument` is spelled exactly — the short form, its lowercase form, or the
full name. `digitakt` and `DigiTAKT` are rejected on purpose: the instrument
decides what goes on the wire, so a typo should be an error rather than a guess.

**Implemented**

| | |
|---|---|
| `DT` | `dt` | Digitakt |
| `DN` | `dn` | Digitone |

**Known, not implemented** (no instrument id is known, so there is no request to send)

| | |
|---|---|
| `DTII` | `dtii` | `"Digitakt II"` |
| `DNII` | `dnii` | `"Digitone II"` |
| `ST` | `st` | `Syntakt` |
| `AR` | `ar` | `"Analog Rytm"` |
| `A4` | `a4` | `"Analog Four"` |
| `AH` | `ah` | `"Analog Heat"` |
| `M:S` | `m:s` | `Model:Samples` |
| `M:C` | `m:c` | `Model:Cycles` |
| `OT` | `ot` | `Octatrack` |
| `MD` | `md` | `Machinedrum` |

Names containing a space need quoting: `--instrument "Digitakt II"`. The short
forms never do.

An instrument moves to the implemented list once a screen has been captured from
it and read. Adding one is a few lines — see the notes at the top of the script.