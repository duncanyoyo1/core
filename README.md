# muOS Core Builder

Run `build.sh` to build all cores within `core.json` or to build specific cores run `build.sh Core_One Core_Two` etc.

Please ensure a build is run manually outside of this build system to ensure that all commands and variables are taken
into consideration. Efforts have been made to ensure the build works however there may be some esoteric cores that
build with weird settings or perhaps even additional arguments on `make`.

### Additional Notes

* **SameBoy** core requires the [RGBDS (Rednex Game Boy Development System)](https://github.com/gbdev/rgbds/) to be
  installed to your existing toolchain, all instructions are on that page.
