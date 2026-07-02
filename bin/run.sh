#!/usr/bin/env sh

# Synopsis:
# Run the test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: path to solution folder
# $3: path to output directory

# Output:
# Writes the test results to a results.json file in the passed-in output directory.
# The test results are formatted according to the specifications at https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md

# Example:
# ./bin/run.sh two-fer path/to/solution/folder/ path/to/output/directory/

# If any required arguments is missing, print the usage and exit
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "usage: ./bin/run.sh exercise-slug path/to/solution/folder/ path/to/output/directory/"
    exit 1
fi

slug="$1"
solution_dir=$(realpath "${2%/}")
output_dir=$(realpath "${3%/}")
results_file="${output_dir}/results.json"

# zig needs a writable global cache (it creates lock/manifest files even on
# cache hits). The production harness mounts the image read-only with only /tmp
# writable, so when the baked cache is not writable, copy it to /tmp once.
# cp -a preserves mtimes, keeping the warmed musl/compiler_rt artifacts as cache
# hits (no ~50 s rebuild).
: "${ZIG_GLOBAL_CACHE_DIR:=/opt/zig-cache}"
if ! ( : > "${ZIG_GLOBAL_CACHE_DIR}/.write-test" ) 2>/dev/null; then
    [ -d /tmp/zig-global ] || cp -a "${ZIG_GLOBAL_CACHE_DIR}" /tmp/zig-global
    export ZIG_GLOBAL_CACHE_DIR=/tmp/zig-global
else
    rm -f "${ZIG_GLOBAL_CACHE_DIR}/.write-test"
fi

cwd=$(pwd)
test_file=$(echo "${slug}" | sed 's/-/_/g')_test.c
cd "${solution_dir}" || exit
sed -i 's#TEST_IGNORE();#// &#' "${test_file}"
make clean
make -s > "${output_dir}/results.out" 2>&1
python3 "${cwd}"/process_results.py "${output_dir}/results.out"
