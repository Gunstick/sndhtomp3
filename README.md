# sndhtomp3
converts SNDH files to mp3

if these tools look bizzare, well they are. This toolchain is part of the scripts used to create the **Atari Undeground Chiptune Resistance** podcast

## sndhtomp3.sh

Main program, give it an sndh file and it spits out an mp3

Several options:

```
usage: [LOOPCOUNT=n] [SPECIAL={--sc68-asid}] /data/home/georges/bin/sndhtomp3.sh sndhfile [songname] [subtune] [starttrimseconds] [endtrim_milliseconds]
default LOOPCOUNT=0
endtrim_milliseconds=0 => do not try to detect loops and don't fade out
endtrim_milliseconds>0 => remove this much at the end
endtrim_milliseconds<0 => loop the song and add this much
if endtrim_milliseconds = 'nnn!' then do not fade at end
```


## ste-sndh-grab.sh


This is an additional program which is called by `sndhtomp3.sh` if the path to the file contains `/DMA/`.

It runs hatari in fast mode in the background creating an mp3 as result. For this a whole lot of tools is used, which you need to have installed.
* hatari  (obviously needed)
* hatari-prg-args   (should be included with hatari)
* sc68   (used to gather the track length)
* readlink  (should be already on your OS)
* xdotool   (apt install xdotool)
* pacmd   (pulseaudio, used to mute hatari while it's running in background. if you not running pulseaudio, well sorry)
* ffmpeg  (apt install ffmpeg)
* sox     (apt install sox)

```
usage: ste-sndh-grab.sh tune.sndh
```

This is the first release, and it's not yet well integrated
