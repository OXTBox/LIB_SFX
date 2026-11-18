script "sfx_xt3d_cacophony"
-- LIB_SFX + xt3d: several sounds at once. FOR OWNER: it plays on the speakers.
-- LiveCode's own `play` plays one sound at a time; raylib's mixer (xt3d) plays many.
-- Needs both extensions built (C:/xtsfx/extension, C:/xt3d/extension). No window needed.
--
--   start using stack "<path>/LIB_SFX/demos/sfx_xt3d_cacophony.livecodescript"
--   Cacophony          -- all 8 presets at once, then a volley of overlapping copies
--   CacophonyStop      -- stop and free everything (Cacophony calls it itself at the end)

local sVoices, sAliases

constant kPresets = "coin,laser,explosion,powerup,hit,jump,blip,random"

on Cacophony
   local tN, tWhy
   CacophonyStop
   start using stack "//wsl$/Ubuntu/home/igame3d/projects/LIB_SFX/livecode/lib_sfx.livecodescript"
   if not Sfx.Ready() then
      Sfx.Start
      put the result into tWhy
      if tWhy is not empty then return "Sfx.Start: " & tWhy
   end if
   if "org.xtalk.xtbridge" is not among the lines of the loadedExtensions then
      load extension from file "C:/xt3d/extension/module.2.lcm" with resource path "C:/xt3d/extension"
      if the result is not empty then return "xt3d: " & the result
   end if
   xt3d_InitAudioDevice
   if not xt3d_IsAudioDeviceReady() then return "xt3d: no audio device"
   Sfx.SetFolder specialFolderPath("temporary") & "/xtsfx_cacophony"

   -- one voice per preset: Sfx makes the .wav, raylib loads it into its mixer
   put 0 into tN
   repeat for each item tP in kPresets
      add 1 to tN
      Sfx.Make "cac" & tN, tP, tN * 7
      put xt3d_LoadSound(Sfx.File("cac" & tN)) into sVoices[tN]
      xt3d_SetSoundVolume sVoices[tN], 0.5
      xt3d_SetSoundPan sVoices[tN], (tN - 1) / 7   -- spread them left to right
   end repeat

   -- 1. everything at once
   repeat with i = 1 to tN
      xt3d_PlaySound sVoices[i]
   end repeat

   -- 2. a volley: lasers and hits stacking on top of each other (aliases share the wave)
   repeat with i = 1 to 12
      send "CacophonyShot" && ((i mod 2) * 3 + 2) & "," & i to me in (900 + i * 90) milliseconds
   end repeat
   -- 3. the big one, and then quiet
   send "CacophonyShot 3, 0" to me in 2200 milliseconds
   send "CacophonyStop" to me in 5000 milliseconds
   return empty
end Cacophony

-- one more copy of voice pVoice, a little higher each time
on CacophonyShot pVoice, pStep
   local tA
   if sVoices[pVoice] is empty then exit CacophonyShot
   put xt3d_LoadSoundAlias(sVoices[pVoice]) into tA
   put tA into sAliases[the number of elements of sAliases + 1]
   xt3d_SetSoundVolume tA, 0.4
   xt3d_SetSoundPitch tA, 1 + pStep / 20
   xt3d_PlaySound tA
end CacophonyShot

on CacophonyStop
   repeat for each element tA in sAliases
      xt3d_StopSound tA
      xt3d_UnloadSoundAlias tA
   end repeat
   repeat for each element tV in sVoices
      xt3d_StopSound tV
      xt3d_UnloadSound tV
   end repeat
   put empty into sAliases
   put empty into sVoices
   -- the audio device stays open: opening it again is slow, and xt3d games may use it
end CacophonyStop
