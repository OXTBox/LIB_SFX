script "LIB_SFX"
-- LIB_SFX: game sound effects made from numbers (rfxgen / sfxr), for any xTalk stack.
--
--   start using stack "<path>/LIB_SFX/livecode/lib_sfx.livecodescript"
--   Sfx.Start                         loads the xtsfx extension (build.bat puts it in C:/xtsfx/extension)
--   Sfx.Make "pickup", "coin", 7      a sound named "pickup" from the preset "coin", seed 7
--   Sfx.Play "pickup"
--
-- A sound is 24 numbers. This library keeps them by name, writes each sound as a .wav file
-- when it is made or changed, and plays that file. Nothing here needs raylib or xt3d.
--
-- Commands (the result is empty when it worked, else one line saying why not):
--   Sfx.Start [pExtensionFolder]      load the extension; safe to call again
--   Sfx.SetFolder pFolder             where the .wav files go (default: the temporary folder /xtsfx)
--   Sfx.Make pName, pPreset, [pSeed]  presets: Sfx.Presets(). Same preset + seed = same sound, on any
--                                     machine. No seed (or 0) = a new one each time
--   Sfx.Play pName                    plays it (one sound at a time: the engine's own "play")
--   Sfx.Stop                          silence
--   Sfx.Set pName, pParam, pValue     change one number (names: the lines of Sfx.Params)
--   Sfx.SetParams pName, pText        change several: lines of name=value. Makes the sound if it is new
--   Sfx.Mutate pName, [pSeed]         nudge every number a little
--   Sfx.Save pName, pFile             the 24 numbers as a .rfx file (rFXGen opens it)
--   Sfx.Load pName, pFile             a sound from a .rfx file
--   Sfx.Export pName, pFile, [pRate], [pBits], [pChannels]   a .wav anywhere: 44100|22050, 16|8, 1|2
--   Sfx.Forget pName                  drop a sound and its .wav
--
-- Functions:
--   Sfx.Ready()            true once the extension is loaded
--   Sfx.Version()          "xtsfx 0.1.0 / rfxgen 5.0"
--   Sfx.Presets()          coin,laser,explosion,powerup,hit,jump,blip,random
--   Sfx.Names()            the sounds made so far, one a line
--   Sfx.Has(pName)
--   Sfx.Params(pName)      24 lines of name=value
--   Sfx.Get(pName, pParam) one number
--   Sfx.File(pName)        the .wav file of a sound (for xt3d_LoadSound or anything else)
--   Sfx.Duration(pName)    seconds
--   Sfx.Peaks(pName, pCount)   the sound's shape for drawing: pCount numbers 0..1000, comma separated

local sFolder       -- where the .wav files go
local sParams       -- sParams[name] = the 24 lines of name=value
local sFiles        -- sFiles[name] = the .wav file

---------------------------------------------------------------- start

command Sfx.Start pExtensionFolder
   local tErr, tCode
   if Sfx.Ready() then return empty
   if pExtensionFolder is empty then put "C:/xtsfx/extension" into pExtensionFolder
   if the last char of pExtensionFolder is "/" then delete the last char of pExtensionFolder
   if the platform is "Win32" then
      put pExtensionFolder & "/code/x86_64-win32/xtsfx.dll" into tCode
   else if the platform is "MacOS" then
      put pExtensionFolder & "/code/universal-mac/xtsfx.dylib" into tCode
   else
      put pExtensionFolder & "/code/x86_64-linux/xtsfx.so" into tCode
   end if
   if there is no file (pExtensionFolder & "/module.lcm") then
      return "LIB_SFX: no module.lcm in" && pExtensionFolder & ". Run LIB_SFX/build.bat first."
   end if
   if there is no file tCode then
      return "LIB_SFX:" && tCode && "is missing. Run LIB_SFX/build.bat first."
   end if
   try
      -- the mapping comes first: the DLL is bound on the first xtsfx call
      set the revLibraryMapping["xtsfx"] to tCode
      load extension from file (pExtensionFolder & "/module.lcm") with resource path pExtensionFolder
      get xtsfx_Version()
   catch tErr
      return "LIB_SFX: the extension did not load (" & line 1 of tErr & ")"
   end try
   return empty
end Sfx.Start

function Sfx.Ready
   return "org.xtalk.xtsfx" is among the lines of the loadedExtensions
end Sfx.Ready

function Sfx.Version
   if not Sfx.Ready() then return empty
   return xtsfx_Version()
end Sfx.Version

function Sfx.Presets
   return "coin,laser,explosion,powerup,hit,jump,blip,random"
end Sfx.Presets

command Sfx.SetFolder pFolder
   if the last char of pFolder is "/" then delete the last char of pFolder
   if pFolder is not empty and there is no folder pFolder then create folder pFolder
   if pFolder is empty or there is no folder pFolder then return "LIB_SFX: no such folder:" && pFolder
   put pFolder into sFolder
   return empty
end Sfx.SetFolder

function Sfx.Folder
   if sFolder is empty then
      put specialFolderPath("temporary") & "/xtsfx" into sFolder
      if there is no folder sFolder then create folder sFolder
   end if
   return sFolder
end Sfx.Folder

---------------------------------------------------------------- making sounds

command Sfx.Make pName, pPreset, pSeed
   local tWhy
   put sfxCheck(pName, false) into tWhy
   if tWhy is not empty then return tWhy
   if pSeed is not an integer then put 0 into pSeed
   if not xtsfx_Preset(pPreset, pSeed) then
      return "LIB_SFX: no preset called" && quote & pPreset & quote & ". There are:" && Sfx.Presets()
   end if
   put xtsfx_GetParams() into sParams[pName]
   return sfxWrite(pName)
end Sfx.Make

command Sfx.Set pName, pParam, pValue
   local tWhy
   put sfxCheck(pName, true) into tWhy
   if tWhy is not empty then return tWhy
   if pValue is not a number then return "LIB_SFX:" && pParam && "needs a number, not" && quote & pValue & quote
   get xtsfx_SetParams(sParams[pName])
   if not xtsfx_SetParam(pParam, pValue) then return "LIB_SFX: a sound has no number called" && quote & pParam & quote
   put xtsfx_GetParams() into sParams[pName]
   return sfxWrite(pName)
end Sfx.Set

command Sfx.SetParams pName, pText
   local tWhy
   put sfxCheck(pName, false) into tWhy
   if tWhy is not empty then return tWhy
   if sParams[pName] is empty then
      xtsfx_Reset
   else
      get xtsfx_SetParams(sParams[pName])
   end if
   if xtsfx_SetParams(pText) is 0 then return "LIB_SFX: no line of name=value was understood"
   put xtsfx_GetParams() into sParams[pName]
   return sfxWrite(pName)
end Sfx.SetParams

command Sfx.Mutate pName, pSeed
   local tWhy
   put sfxCheck(pName, true) into tWhy
   if tWhy is not empty then return tWhy
   if pSeed is not an integer then put 0 into pSeed
   get xtsfx_SetParams(sParams[pName])
   xtsfx_Mutate pSeed
   put xtsfx_GetParams() into sParams[pName]
   return sfxWrite(pName)
end Sfx.Mutate

command Sfx.Load pName, pFile
   local tWhy
   put sfxCheck(pName, false) into tWhy
   if tWhy is not empty then return tWhy
   if not xtsfx_LoadRfx(pFile) then return "LIB_SFX: not a .rfx file, or not there:" && pFile
   put xtsfx_GetParams() into sParams[pName]
   return sfxWrite(pName)
end Sfx.Load

command Sfx.Save pName, pFile
   local tWhy
   put sfxCheck(pName, true) into tWhy
   if tWhy is not empty then return tWhy
   get xtsfx_SetParams(sParams[pName])
   if not xtsfx_SaveRfx(pFile) then return "LIB_SFX: could not write" && pFile
   return empty
end Sfx.Save

command Sfx.Export pName, pFile, pRate, pBits, pChannels
   local tWhy
   put sfxCheck(pName, true) into tWhy
   if tWhy is not empty then return tWhy
   if pRate is not an integer then put 44100 into pRate
   if pBits is not an integer then put 16 into pBits
   if pChannels is not an integer then put 1 into pChannels
   get xtsfx_SetParams(sParams[pName])
   if xtsfx_ExportWav(pFile, pRate, pBits, pChannels) is 0 then return "LIB_SFX: could not write" && pFile
   return empty
end Sfx.Export

command Sfx.Forget pName
   if sFiles[pName] is not empty and there is a file sFiles[pName] then delete file sFiles[pName]
   delete variable sParams[pName]
   delete variable sFiles[pName]
   return empty
end Sfx.Forget

---------------------------------------------------------------- playing

command Sfx.Play pName
   if sFiles[pName] is empty then return "LIB_SFX: no sound called" && quote & pName & quote
   play sFiles[pName]
   return empty
end Sfx.Play

command Sfx.Stop
   play stop
   return empty
end Sfx.Stop

---------------------------------------------------------------- asking

function Sfx.Names
   local tNames
   put the keys of sParams into tNames
   sort lines of tNames
   return tNames
end Sfx.Names

function Sfx.Has pName
   return sParams[pName] is not empty
end Sfx.Has

function Sfx.Params pName
   return sParams[pName]
end Sfx.Params

function Sfx.Get pName, pParam
   local tLine
   set the itemDelimiter to "="
   repeat for each line tLine in sParams[pName]
      if item 1 of tLine is pParam then return item 2 of tLine
   end repeat
   return empty
end Sfx.Get

function Sfx.File pName
   return sFiles[pName]
end Sfx.File

function Sfx.Duration pName
   if sParams[pName] is empty or not Sfx.Ready() then return 0
   get xtsfx_SetParams(sParams[pName])
   return xtsfx_Duration()
end Sfx.Duration

function Sfx.Peaks pName, pCount
   if sParams[pName] is empty or not Sfx.Ready() then return empty
   if pCount is not an integer then put 100 into pCount
   get xtsfx_SetParams(sParams[pName])
   return xtsfx_Peaks(pCount)
end Sfx.Peaks

---------------------------------------------------------------- inside

-- empty when pName can be worked on, else why not
private function sfxCheck pName, pMustExist
   if not Sfx.Ready() then return "LIB_SFX: call Sfx.Start first"
   if pName is empty then return "LIB_SFX: a sound needs a name"
   if pMustExist and sParams[pName] is empty then return "LIB_SFX: no sound called" && quote & pName & quote
   return empty
end sfxCheck

-- a name as a file name: letters, digits, - and _ stay, the rest become _
private function sfxSafe pName
   local tOut, tChar
   repeat for each char tChar in pName
      if tChar is in "abcdefghijklmnopqrstuvwxyz0123456789-_" then
         put tChar after tOut
      else
         put "_" after tOut
      end if
   end repeat
   return tOut
end sfxSafe

-- writes the .wav of pName from its numbers; empty, or why not
private function sfxWrite pName
   local tFile, tFrames
   put Sfx.Folder() & "/" & sfxSafe(pName) & ".wav" into tFile
   get xtsfx_SetParams(sParams[pName])
   put xtsfx_ExportWav(tFile, 44100, 16, 1) into tFrames
   if tFrames is 0 then
      -- the file may still be open because it is playing: stop, try once more
      play stop
      put xtsfx_ExportWav(tFile, 44100, 16, 1) into tFrames
   end if
   if tFrames is 0 then return "LIB_SFX: could not write" && tFile
   put tFile into sFiles[pName]
   return empty
end sfxWrite
