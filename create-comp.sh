#!/usr/bin/env sh

root=$(cd $(dirname $0) && pwd)

comp_path=""
lang=CXX
private=0

usage() {
    cat <<EOF
create-comp.sh PATH [--lang=LANG] [-h|--help] [--private]

Creates a C/C++ component
  o PATH is the components hierarchy, e.g. foo/bar
    This would create 3 files:
      o src/foo/bar.LANG_EXT_SRC
      o include/foo/bar.LANG_EXT_HDR
      o tests/foo/bar.cxx
  o LANG can be either C or CXX
    Note that:
      o C implies that headers are '.h' and source files are '.c'
      o CXX implies that headers are '.hxx' and source files are '.cxx'
  o If '--private' is specified, the files created are:
      o src/foo/bar.LANG_EXT_SRC
      o src/foo/bar.LANG_EXT_HDR
EOF
    exit 0
}


if ! test -f "${root}/build/CMakeCache.txt"; then
    echo "Could not detect layout style: expected file ${root}/build/CMakeCache.txt"
    exit 1
fi

layout=$(cat ${root}/build/CMakeCache.txt | grep CSKEL_LAYOUT_STYLE | cut -d'=' -f2)

if test "$layout" = "subdir"; then
    comp_path=$(echo "$1" | sed 's|\.|/|g')
else
    comp_path=$(echo "$1" | sed 's|\/|_|g' | sed 's|\.|_|g')
fi

shift

while test "$#" -gt 0; do
    PARAM=$(echo "$1" | cut -d'=' -f1)
    VALUE=$(echo "$1" | cut -d'=' -f2)
    case $PARAM in
        -h|--help)
            usage
            exit 0
            ;;
        --lang)
            lang=$VALUE
            ;;
        --private)
            private=1
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

cpp_src_ext='.cpp'
if test "$lang" = CXX; then
    hdr_ext='.hpp'
    src_ext=$cpp_src_ext
elif test "$lang" = C; then
    hdr_ext='.h'
    src_ext='.c'
else
    >&2 echo Invalid language: "$lang"
    exit 1
fi

comp_name=$(basename "$comp_path")
comp_dir=$(dirname "$comp_path")

test "$comp_dir" = "." && comp_dir=""

reverse_word_order() {
    result=""
    for word in $@; do
        result="$word $result"
    done
    echo "$result"
}

print_include_guard() {
    echo "INCLUDED_${comp_path}${hdr_ext}" | \
      tr '[:lower:]' '[:upper:]' | \
      sed 's|\.|_|g' | \
      sed 's|\/|_|g' | \
      sed 's|\\|_|g'
}

print_namespace_begin() {
    comp_parent=$(dirname $(echo "$comp_path" | sed 's|_|\/|g') | sed 's|\/|_|g')
    list=$(echo $comp_parent | \
      sed 's|\.| |g' | \
      sed 's|\/| |g' | \
      sed 's|_| |g'  | \
      sed 's|\\| |g')
    for item in ${list};
    do
        echo "namespace $item {"
    done
}

print_namespace_end() {
    comp_parent=$(dirname $(echo "$comp_path" | sed 's|_|\/|g') | sed 's|\/|_|g')
    list=$(echo $comp_parent | \
      sed 's|\.| |g' | \
      sed 's|\/| |g' | \
      sed 's|_| |g'  | \
      sed 's|\\| |g')
    for item in $(reverse_word_order "$list");
    do
        echo "} // namespace $item"
    done
}

print_starred_license() {
    cat "$root/LICENSE.md" | sed 's|^| * |g' | sed 's|[[:space:]]*$||'
}

cd $root

guard=$(print_include_guard)

if test "$private" = "1"; then
    where=src/
else
    where=include/
fi

mkdir -p "${where}${comp_dir}"
if test "$lang" = C; then

cat <<EOF > "${where}${comp_path}${hdr_ext}"
/// @file ${comp_name}${hdr_ext}
/// @brief description
/*
$(print_starred_license)
 */

#ifndef $guard
#define $guard



#endif/*$guard*/
EOF

else

cat <<EOF > "${where}${comp_path}${hdr_ext}"
/// @file ${comp_name}${hdr_ext}
/// @brief description
/*
$(print_starred_license)
 */

#ifndef $guard
#define $guard

$(print_namespace_begin)



$(print_namespace_end)

#endif/*$guard*/
EOF

fi

mkdir -p "src/${comp_dir}"
if test "$private" = "1"; then
    incl_beg='"'
    incl_end='"'
else
    incl_beg='<'
    incl_end='>'
fi

if test "$lang" = C; then

cat <<EOF > "src/${comp_path}${src_ext}"
/// @file ${comp_name}${src_ext}
/*
$(print_starred_license)
 */

#include ${incl_beg}${comp_path}${hdr_ext}${incl_end}



EOF

else

cat <<EOF > "src/${comp_path}${src_ext}"
/// @file ${comp_name}${src_ext}
/*
$(print_starred_license)
 */

#include ${incl_beg}${comp_path}${hdr_ext}${incl_end}

$(print_namespace_begin)



$(print_namespace_end)
EOF

fi

if test "$private" = "1"; then
    exit 0
fi

mkdir -p "tests/${comp_dir}"
cat <<EOF > "tests/${comp_path}${cpp_src_ext}"
/// @file ${comp_name}${cpp_src_ext}

#include <${comp_path}${hdr_ext}>

#include <gtest/gtest.h>

class t${comp_name} : public ::testing::Test
{
  public:
    ~t${comp_name}() noexcept override = default;

    /// Suite level set up.
    using Test::SetUpTestSuite;

    /// Suite level tear down.
    using Test::TearDownTestSuite;

  protected:
    /// Test case set up.
    using Test::SetUp;

    /// Test case tear down.
    using Test::TearDown;
};

TEST_F(t${comp_name}, basic)
{
    EXPECT_EQ(0, 0);
}
EOF
