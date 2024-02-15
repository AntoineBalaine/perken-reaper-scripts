Rack - an FX rack for Reaper

Full re-write of Bryan Chi's FX Devices

# Why, though?
Bryan's project is amazing, there's no discussing it. But it's also full of very messy code, and after months of re-factoring it, I was still very confused as to how it worked. 
The current rewrite was born out of frustration with the original codebase, with the goal of making the new version readable and more approachable to newcomers.

# Installation
Via reapack!

# Usage 
## Examples
### Architecture

# Testing
- In your terminal, install busted, using luarocks:
```bash
sudo luarocks install busted
```
- run the tests from the project's root folder:
```bash
busted .
```
ps: I don't know how to do this in Windows…

# Contributing
Want to help ? Awesome, please take a look at [CONTRIBUTING.md](docs/CONTRIBUTING.md).

# How does the app work?
Same, you'll find answers in [CONTRIBUTING.md](docs/CONTRIBUTING.md).

# To do
- [x] INI file parser
- [x] theme reader that can parse reaper's currently-used theme (rewrite based on XRaym's theme parser)
- [ ] styling rack's colors so that they consistently use the reaper theme
- [ ] use the reaper theme's fonts in the rack
- [x] keyboard shortcut parser
- [ ] [TENTATIVE] create shortcut pass-through between rack and reaper's TCP
- [x] Fx Browser (rewrite based on Sexan's fx browser)
- [ ] Setup tests for the state module 
- [ ] Drag and drop FX
    - [x] reorder
    - [x] duplicate
    - [x] remove 
    - [ ] setup tests for drag and drop's reorder/duplicate/remove 
- [ ] Auto-generate docs based on doc-comments in the code
- [ ] Fx layout editor
- [ ] JSFX/EEL2 parser
- [ ] Hook-up the JSFX/EEL2 parser with Gfx2ImGui, so that we can display JSFX's graphics in the rack

…and more to come…
