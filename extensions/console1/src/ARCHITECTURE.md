on init:
- [x] check that realearn's installed
  ```lua
      local parse = IniParse:parse_file(reaper.GetResourcePath() .. os_separator .. "reaper-fxtags.ini")
  ```
  - [x] search for the string `Realearn` in the file. Probably no need to do any kind of parsing.
- [ ] load controller config (ControllerConfig.zig, à revoir)
  - use `ini.parseToStruct` 
  - [ ] store list of fx chains configs (INI)
        reacomp
        reaEq
        reaGate
  - [ ] store list of matching realearn maps
    une fois les listes d'effets enregistrées? on peut trouver les mappings pour realearn.
    tôt ou tard faudra avoir une state machine pour passer d'un mode à l'autre. Heureusement les choses vont être relativement plus simples que pour reavim. Si j'ai juste trois modes et qu'ils ne peuvent pas se combiner, chaque bouton devrait être une terminale. Même dans le cas des non-terminales, ça ne devrait pas être difficile de persister le state du système. Y a-t-il un autre moyen d'appeler des scripts que de passer par la liste d'actions? Pas sûr. Ce serait un peu être un tidy freak que de refuser d'inclure ça.
  - [ ] load user prefs 
    - récrire en utilisant une comptime static string map
- [x] check for realearn instances on fx monitoring chain (1 instance per console module)
- if not present, load rfx chain containing the 3 realearn instances.
```lua 
C: MediaTrack* GetMasterTrack(ReaProject* proj)
-- get a track from a project by track count (zero-based) (proj=0 for active project)
C: int TrackFX_GetRecCount(MediaTrack* track)
-- On the master track, this accesses monitoring FX rather than record input FX.
reaper.TrackFX_GetRecCount(reaper.GetMasterTrack(0))
-- iterate
C: bool TrackFX_GetFXName(MediaTrack* track, int fx, char* bufOut, int bufOut_sz)
-- FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track)
```
- register custom actions corresponding to controller buttons
- put together mapping for buttons (tbd if in json or using luau)
  - Monter sous forme de script risque de poser problème - vérifier l'api pourrait n'être pas de tout repos.
- load realearn mapping
```lua
-- see https://github.com/helgoboss/realearn/issues/656
reaper.TrackFX_SetNamedConfigParm(reaper.GetSelectedTrack(0 , 0),0,"set-state",jsonConfig)
```
- test the calls to custom actions from realearn

on track selection:
- validate track config 
  - are the three fx modules there?
  - do they match the current realearn setup?
    - if not, load realearn mapping
      - find if realearn mapping is already in memory
      - if not, load it from disk

This diagram might be wrong. If it's not possible to send updates directly via csurf, 
we'll have to do it via the state module.
```
              USER INPUT 
                  ^
                  |
     ----------> IMGUI -------
     |            |          | send update
     |            |read      |
     |            |          v
REAPER <-------------------> CSURF
          *init   |          | 
          *trkslct|          | store update upon event
                  v          | persist ext state
                STATE <-------
```


controller_dir
├── userPrefs.ini
├── modules
│   ├── EQ
│   │   ├── reaeq.json
│   │   └── proq.json
│   ├── CMP
│   │   ├── reacomp.json
│   │   └── 1167.json
│   └── SHP
│       ├── reagate.json
│       └── prog.json
