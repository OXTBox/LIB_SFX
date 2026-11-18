script "SfxDemo"
-- LIB_SFX demo: File > Open Stack. Needs LIB_SFX/build.bat to have run once.
-- Click a preset to make and hear a sound; Mutate nudges it; the numbers can be edited and applied.
-- Open it from the LIB_SFX folder (not a copy) so it finds ../livecode/lib_sfx.livecodescript.
-- If the IDE asks to save when closing: Don't Save (a script-only stack keeps no controls).

constant kPresets = "coin,laser,explosion,powerup,hit,jump,blip,random"
constant kTitle = "FOR OWNER | Click a preset to hear it. Mutate changes it a little"

on preOpenStack
   demoBuild
end preOpenStack

on openStack
   demoStart
end openStack

on closeStackRequest
   Sfx.Stop
   set the destroyStack of this stack to true
   close stack (the mainStack of this stack)
end closeStackRequest

command demoStart
   local tLib
   set the itemDelimiter to "/"
   put item 1 to -3 of the effective filename of me & "/livecode/lib_sfx.livecodescript" into tLib
   if there is no file tLib then
      demoSay "Cannot find" && tLib & ". Open this demo from the LIB_SFX folder."
      exit demoStart
   end if
   start using stack tLib
   Sfx.Start
   if the result is not empty then
      demoSay the result
      exit demoStart
   end if
   demoSay Sfx.Version() && "is ready. Click a preset."
end demoStart

command demoBuild
   local tX, tP, tName, tAbout
   set the defaultStack to the short name of me
   lock screen
   set the destroyStack of me to true
   set the title of me to kTitle
   set the width of me to 568
   set the height of me to 470
   if there is a field "params" of card 1 of me then
      unlock screen
      exit demoBuild
   end if
   set the name of card 1 of me to "Sounds"

   put 12 into tX
   repeat for each item tP in kPresets
      create button tP
      set the rect of it to tX, 12, tX + 64, 38
      add 68 to tX
   end repeat

   create field "seedLabel"
   set the rect of it to 12, 48, 200, 70
   demoLabel it, "Seed (empty = new each time):"
   create field "seed"
   set the rect of it to 204, 46, 284, 70

   put 296 into tX
   repeat for each item tName in "Play,Mutate,About"
      create button tName
      set the rect of it to tX, 46, tX + 84, 70
      add 88 to tX
   end repeat

   create graphic "wave"
   set the style of it to "polygon"
   set the foregroundColor of it to 40,90,160
   set the lineSize of it to 1
   set the rect of it to 12, 80, 556, 180
   create graphic "frame"
   set the style of it to "rectangle"
   set the opaque of it to false
   set the rect of it to 12, 80, 556, 180

   create field "params"
   set the rect of it to 12, 190, 284, 426
   set the vScrollbar of it to true
   set the textSize of it to 11

   put 296 into tX
   create button "Apply numbers"
   set the rect of it to 296, 190, 556, 216
   create button "Save .rfx..."
   set the rect of it to 296, 222, 556, 248
   create button "Open .rfx..."
   set the rect of it to 296, 254, 556, 280
   create button "Export .wav..."
   set the rect of it to 296, 286, 556, 312
   create field "hint"
   set the rect of it to 296, 322, 556, 426
   demoLabel it, "waveType: 0 square, 1 sawtooth, 2 sine, 3 noise." & return & \
         "Most other numbers run from 0 to 1, some from -1 to 1." & return & \
         "Change a number on the left, then Apply numbers."

   create field "status"
   set the rect of it to 12, 434, 556, 458
   demoLabel it, empty

   put the long date & return & return & \
         "Stack: SfxDemo" & return & \
         "Title:" && kTitle & return & return & \
         "Built to: show that LIB_SFX makes game sound effects from 24 numbers (rfxgen, the sfxr family)," && \
         "with no sound files and no 3D engine." & return & return & \
         "How:" & return & \
         "  - click one of the eight preset buttons: a sound is made, drawn and played" & return & \
         "  - a number in Seed gives the same sound every time; empty gives a new one" & return & \
         "  - click Mutate to nudge it, Play to hear it again" & return & \
         "  - edit a number in the list and click Apply numbers" & return & \
         "  - Save .rfx keeps the 24 numbers (rFXGen opens that file); Export .wav writes the sound" & return & return & \
         "Report: did each preset sound like its name? Tell Claude what was wrong, with the preset and seed." && \
         "No other process is watching this window." & return & return & \
         "Click anywhere here to go back." into tAbout
   create card "About"
   create field "about"
   set the rect of it to 12, 12, 556, 458
   demoLabel it, tAbout
   go card "Sounds"
   unlock screen
end demoBuild

-- a field used as plain text on the card
command demoLabel pField, pText
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the showBorder of pField to false
   set the opaque of pField to false
   set the dontWrap of pField to false
   set the text of pField to pText
end demoLabel

command demoSay pText
   if there is a field "status" of card "Sounds" of me then put pText into field "status" of card "Sounds" of me
end demoSay

on mouseUp
   local tName, tWhy, tFile
   put the short name of the target into tName
   if the short name of this card is "About" then
      go card "Sounds"
      exit mouseUp
   end if
   if word 1 of the target is not "button" then pass mouseUp
   if not Sfx.Ready() then
      demoStart
      if not Sfx.Ready() then exit mouseUp
   end if
   if tName is among the items of kPresets then
      Sfx.Make "demo", tName, field "seed"
      put the result into tWhy
      if tWhy is empty then demoSay tName && "seed" && Sfx.Get("demo", "randSeed") & "," && round(Sfx.Duration("demo") * 1000) && "ms"
      demoShow tWhy, true
      exit mouseUp
   end if
   switch tName
      case "About"
         go card "About"
         break
      case "Play"
         demoShow empty, true
         break
      case "Mutate"
         Sfx.Mutate "demo"
         demoShow the result, true
         break
      case "Apply numbers"
         Sfx.SetParams "demo", field "params"
         demoShow the result, true
         break
      case "Save .rfx..."
         if not demoHas() then exit mouseUp
         ask file "Save the 24 numbers as:" with "sound.rfx"
         if it is empty then exit mouseUp
         put it into tFile
         if not (tFile ends with ".rfx") then put ".rfx" after tFile
         Sfx.Save "demo", tFile
         put the result into tWhy
         if tWhy is empty then put "Saved" && tFile into tWhy
         demoSay tWhy
         break
      case "Open .rfx..."
         answer file "Open a .rfx sound:"
         if it is empty then exit mouseUp
         Sfx.Load "demo", it
         demoShow the result, true
         break
      case "Export .wav..."
         if not demoHas() then exit mouseUp
         ask file "Export the sound as:" with "sound.wav"
         if it is empty then exit mouseUp
         put it into tFile
         if not (tFile ends with ".wav") then put ".wav" after tFile
         Sfx.Export "demo", tFile
         put the result into tWhy
         if tWhy is empty then put "Exported" && tFile into tWhy
         demoSay tWhy
         break
   end switch
end mouseUp

function demoHas
   if Sfx.Has("demo") then return true
   demoSay "Click a preset first."
   return false
end demoHas

-- after a change: say why it failed, or show the numbers, draw the shape and play
command demoShow pWhy, pPlay
   if pWhy is not empty then
      demoSay pWhy
      exit demoShow
   end if
   if not demoHas() then exit demoShow
   put Sfx.Params("demo") into field "params"
   demoDraw
   if pPlay then Sfx.Play "demo"
end demoShow

command demoDraw
   local tPeaks, tPoints, tX, tMid, tHalf, tPeak, tTall
   put Sfx.Peaks("demo", 272) into tPeaks
   put 14 into tX
   put 130 into tMid
   put 46 into tHalf
   repeat for each item tPeak in tPeaks
      put max(1, round(tPeak * tHalf / 1000)) into tTall
      put tX & "," & (tMid - tTall) & return & tX & "," & (tMid + tTall) & return & return after tPoints
      add 2 to tX
   end repeat
   lock screen
   set the points of graphic "wave" to tPoints
   unlock screen
end demoDraw
