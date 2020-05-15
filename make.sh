#!/usr/bin/env sh

root=$(cd $(dirname $0) && pwd)

build_type="Debug"
prefix="$root/install"
gen_arg=""
shared=0
target=check

mkdir -p "$prefix"

proj=$(cat CMakeLists.txt | \
           tr -s '\n' '|' | \
           grep -o "|project(.*\(\w+\\)" | \
           tr -d '|' | \
           tr -s ' ' | \
           cut -d' ' -f2)

usage() {
    cat <<EOF
make.sh TARGET
        [--prefix=INSTALL_PATH]
        [--generator=GENERATOR]
        [--type=TYPE]
        [--shared]
        [-h|--help]

Runs the CMake project in the current directory of the script.
  o TARGET can be (check, install, clean)
    All libraries and executables are built (unless TARGET is 'clean')
  o PREFIX is the installation directory
    Default: install
  o GENERATOR is the CMake generator to use
    Default: Platform's CMake default
  o TYPE is the build type (Debug, Release, MinSizeRel, RelWithDebInfo)
    Default: Debug
  o 'shared' is specified if shared library builds are requested
EOF
    exit 1
}

test "$#" -lt 1 && echo "TARGET not specified" && usage

target="$1"
shift

while [ "$1" != "" ]; do
    PARAM=`echo $1 | cut -d'=' -f1`
    VALUE=`echo $1 | cut -d'=' -f2`
    case $PARAM in
        -h|--help)
            usage
            exit 0
            ;;
        --type)
            build_type=$VALUE
            ;;
        --prefix)
            prefix=$VALUE
            ;;
        --generator)
            gen_arg="-G'$VALUE'"
            ;;
        --shared)
            shared=1
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

set -e

run_cmake() {
    cmd="cmake -H$root -B$root/build $gen_arg \
         -DCMAKE_INSTALL_PREFIX=\"$prefix\" \
         -DCMAKE_BUILD_TYPE=\"$build_type\" \
         -DBUILD_SHARED_LIBS=\"$shared\" \
         -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
         -Wno-dev"

    sh -c "$cmd"
    env VERBOSE=1 cmake --build $root/build \
                        --target $1 \
                        --config "$build_type"
}

if test "$target" = "clean"; then
    rm -fr $root/build
    exit 0
fi

run_cmake "$target"
