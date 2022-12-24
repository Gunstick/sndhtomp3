#!/bin/bash
if [ "$1" = "" ]
then
  echo "usage: [LOOPCOUNT=n] [SPECIAL={--sc68-asid}] $0 sndhfile [songname] [subtune] [starttrimseconds] [endtrim_milliseconds]"
  echo "default LOOPCOUNT=0"
  echo "endtrim_milliseconds=0 => do not try to detect loops and don't fade out"
  echo "endtrim_milliseconds>0 => remove this much at the end"
  echo "endtrim_milliseconds<0 => loop the song and add this much"
  echo "if endtrim_milliseconds = 'nnn!' then do not fade at end" 
  exit
fi
infile="$1"
songname="$(basename "$infile" .sndh)"
if [ "$2" != "" ]
then
  songname="$2"
fi
if [ "$3" != "" ]
then
  subtune="-t $3"
fi
if [ "$4" != "" ]
then
  trim="$4"
else
  trim=0
fi
checkloop=1
if [ "$5" != "" ]
then
  if [ "${5%\!}" = "$5" ]
  then
    fadeout="yes"
  else
    fadeout="no"
  fi
  trimendms="${5%\!}"
  if [ "$5" = "0" ]
  then
    checkloop=0
  fi
else
  trimendms=0
fi
LoopCount=${LOOPCOUNT:0}
LoopCount=$((LoopCount+1))    # 1=do not loop, play once

info="$(sc68 -r48000  $subtune -n "$infile" | head -10)"
length="$(echo "$info" |awk '/Track/{sub("^Track *: [^ ]+ +","",$0);t=substr($0,1,2)*60+substr($0,4,2);print t-1;exit}')"
origlength=$length
if [ $length -gt 5000 ]
then
  if [ "$SNDLENGTH" = "" ]
  then
    echo "set SNDLENGTH environemnt variable (in seconds) as I don't know the length"
    exit 1
  else
    length="$SNDLENGTH"
  fi
fi
length=$((length*$LoopCount))
lengthms=$((((length-trim)*1000-trimendms)))
length=$((lengthms/1000))
if [ "$((trimend))" -lt 0 ] && [ "$LOOPCOUNT" = "" ]
then
  LoopCount=$((LoopCount*(-1*(trimend/origlength/1000+1))+1))
  length=$((origlength+(length*$LoopCount)))
  LOOPCOUNT=1
  echo GOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO $LoopCount
fi
echo "$length s"
musician="$(echo "$info" |awk -F: '/Artist/{
   sub("^ *","",$2)
   gsub("/"," ",$2)
   print $2;exit}')"
# trim 0 $((length+10))    => cut off file at loop size + 10s
# fade 0 0 5               => fade out the last 5 seconds
#sc68 -qqq --ym-engine=pulse --loop=$((LoopCount+1)) -c "$infile" | 
#-C320.0 is 320mbps and 0=insane quality
  precisetrim=$(echo "$lengthms/1000+10"|bc -l|sed 's/0*$//;s/\.$//')
  if [ "${infile#*/DMA/}" = "$infile" ]
  then   # it is standard YM
    if [ "$fadeout" = "no" ]
    then
      echo "CUTTING AT END"
      sc68 -r48000  $subtune $SPECIAL -qqq --loop=$((LoopCount+1)) -c "$infile" | 
        sox -b 16 -e signed-integer -c 2 -r 48000 -t raw - -t mp3 -C320.0 "$musician - $songname".mp3 trim "$trim" $precisetrim norm
    else
      echo "FADING OUT"
      sc68 -r48000  $subtune $SPECIAL -qqq --loop=$((LoopCount+1)) -c "$infile" | 
        sox -b 16 -e signed-integer -c 2 -r 48000 -t raw - -t mp3 -C320.0 "$musician - $songname".mp3 trim "$trim" $precisetrim fade 0.03 0 5 norm
    fi
  else # it is STE
    rm "$(basename "$infile" .sndh)".mp3 2>/dev/null
    ste-sndh-grab.sh "$infile"
    ls "$(basename "$infile" .sndh)".mp3
    if [ "$fadeout" = "no" ]
    then
      echo "$fadeoput not supported with DMA"
      sox "$(basename "$infile" .sndh)".mp3 -t mp3 -C320.0 "$musician - $songname".mp3 trim "$trim" $precisetrim fade 0.03 0 5 norm 
    else
      sox "$(basename "$infile" .sndh)".mp3 -t mp3 -C320.0 "$musician - $songname".mp3 trim "$trim" $precisetrim fade 0.03 0 5 norm 
    fi
    echo "Result: $(ls -l "$musician - $songname".mp3)"
    #rm "$(basename "$infile" .sndh)".mp3
  fi
if [ "$LOOPCOUNT" != "" ]
then
  exit
fi
# play 1s before and 1 after loop
subsecond="$(sc68 -r48000  $subtune $SPECIAL -qqq --loop=1 -c "$infile" |
             sox -b 16 -e signed-integer -c 2 -r 48000 -t raw - -n stat 2>&1|
             awk -F. '/^Length/{print "1"$2}')"
echo "subsecond=$subsecond"
#subsecond=.693312 => 1693312 - 1000000 = 693312
echo "End"
sox "$musician - $songname".mp3 -t wav - trim $((length-1)).$((subsecond-1000001)) 1 2>/dev/null | cvlc - vlc://quit
sleep 1
echo "Loop"
sox "$musician - $songname".mp3 -t wav - trim $((length)).$((subsecond-999999)) 1 2>/dev/null | cvlc - vlc://quit
echo "ok"
# test seconds -11 to -10 if they are silent
echo "pre $((length-1)).$((subsecond-1000001))"
endvol=$(
  sox "$musician - $songname".mp3 -t wav - trim $((length-1)).$((subsecond-1000001)) 1 2>/dev/null| 
    sox -t wav - -n stat 2>&1|
    awk '/Maximum amplitude:/{print int($NF*100)}')
# test seconds -10 to -9 to see if after loop it's silent
echo "post ${length}.$((subsecond-999999))"
loopvol=$(
  sox "$musician - $songname".mp3 -t wav - trim $((length)).$((subsecond-999999)) 1 2>/dev/null| 
    sox -t wav - -n stat 2>&1|
    awk '/Maximum amplitude:/{print int($NF*100)}')
echo "endvol=$endvol, loopvol=$loopvol"
if [ "$endvol" -lt 3 ] || [ "$loopvol" -lt 3 ] || [ "$checkloop" = "0" ]
then
  if [ "${infile#*/DMA/}" = "$infile" ]
  then
    echo "endvol=$endvol, non looped, no fade, len=$length"
    # fade 0.03 is to remove plopp from sc68
    (sc68 -r48000  $subtune $SPECIAL -qqq --ym-engine=pulse --loop=1 -c "$infile" 
     sox -b 16 -e signed-integer -c 2 -r 48000 -n -t raw - trim 0.0 1.0 ) | 
    sox -b 16 -e signed-integer -c 2 -r 48000 -t raw - -t mp3 -C320.0 "$musician - $songname".mp3 trim "$trim" $((length+10)) fade 0.03 0 0 norm
  else
    echo "DMA no support yet for auto check non-looped tracks"
  fi
fi 
