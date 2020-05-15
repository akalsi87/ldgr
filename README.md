## cskel

`cskel` is a clonable skeleton for C/C++ projects.

### Basics

It provides the following out of the box:
 - Automatic detection of source and header fies for a library/executable
 - A system to install and build with 3rd-party libraries
 - Automatic CMake exports using `cskel_add_library` and `cskel_add_executable`
   (should initialize project with `cskel_project`)
 - `GTest` and `GMock` for tests
 - Code coverage on debug linux builds
 - Doxygen support
 - `RPATH` support for dynamic libraries and for 3rd party dynamic libraries
 - GitHub actions CI support (`.github/workflows/tests.yml`)
 - Helper script `make.sh` for making CMake targets across platforms
 - Helper script `create-comp.sh` for creating a new canonical component
 - A `.clang-format` file
 - A bootstrapping `.gitignore`
 - Supports either BDE-style flat layout or per-target folder layout
 - Licenses are exported with library installation and 3rd-party installations
   also (defaults to Apache 2.0)

### Usage

Just:

```sh
$ git clone http://github.com/akalsi87/cskel <new-project>
```

After clone, you should update:
 - `LICENSE.md`
 - `README.md`

### Copying

This repository itself is provided under the following license:

```
cskel by Aaditya Kalsi

To the extent possible under law, the person who associated CC0 with
cskel has waived all copyright and related or neighboring rights
to cskel.

You should have received a copy of the CC0 legalcode along with this
work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

```
