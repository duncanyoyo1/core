# muOS Core Builder

To build all cores defined in `core.json`, run:

```bash
./build.sh
```

To build specific cores, specify their names as arguments:

```bash
./build.sh "DOSBox Pure" "SameBoy"
```

### Please Note

* Before using this build system, run a manual build outside of it to verify that all required commands and variables
  are correctly configured.
* This build system assumes you have already configured and initialised a toolchain.

## Core Structure

* `source` - The repository URL where it the core will clone from.
* `directory` - Usually the name of the repository but can be anything.
* `output` - The end file that is compiled for processing.
* `make.file` - The file which make calls upon.
* `make.args` - Additional arguments that is used alongside make.
* `make.target` - A specific target to use with make if required.
* `symbols` - Set it to `1` if you require debug symbols.
* `commands.pre-make` - Commands to run _**before**_ make is run.
* `commands.post-make` - Commands that are run _**after**_ successful compilation.

The `commands` section is completely optional and can be omitted.

### Example Core (SameBoy)

```json
{
  "SameBoy": {
    "source": "https://github.com/LIJI32/SameBoy",
    "directory": "SameBoy",
    "output": "sameboy_libretro.so",
    "make": {
      "file": "Makefile",
      "args": "",
      "target": ""
    },
    "symbols": 0,
    "commands": {
      "pre-make": [
        "make clean >/dev/null 2>&1",
        "printf '\\n\\t\\tBuilding Boot ROMs\\n'",
        "make bootroms >/dev/null 2>&1",
        "printf '\\n\\t\\tPre-generating Libretro Source\\n'",
        "make libretro >/dev/null 2>&1",
        "cd libretro"
      ],
      "post-make": [
        "cd .."
      ]
    }
  }
}
```

## Additional Notes

* **SameBoy** core requires the [RGBDS (Rednex Game Boy Development System)](https://github.com/gbdev/rgbds/) to be
  installed to your existing toolchain, all instructions are on that page.
