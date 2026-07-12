#!/usr/bin/env bash
#
# mayhem/build.sh — build the aria fuzz harness, its standalone reproducer, and the
# functional-oracle interpreter. aria is a single-translation-unit C89 lisp (aria.c
# + aria.h), so every artifact is a direct clang compile of aria.c.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# 1) Fuzz target: harness + the interpreter (aria.c compiled WITHOUT AR_STANDALONE so
#    there is no main()), instrumented with the sanitizers + libFuzzer, DWARF < 4.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    -I"$SRC" \
    "$SRC/mayhem/fuzz_aria.c" "$SRC/aria.c" \
    -o /mayhem/fuzz_aria

# 2) Standalone run-once reproducer: same harness + interpreter, linked against the
#    base image's non-fuzzer driver instead of the fuzzing engine.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS \
    -I"$SRC" \
    "$STANDALONE_FUZZ_MAIN" \
    "$SRC/mayhem/fuzz_aria.c" "$SRC/aria.c" \
    -o /mayhem/fuzz_aria-standalone

# 3) Functional oracle: the real standalone interpreter, built with the project's
#    normal flags (no sanitizers). mayhem/test.sh only RUNS this — never compiles.
$CC -O2 -DAR_STANDALONE $COVERAGE_FLAGS \
    -I"$SRC" \
    "$SRC/aria.c" \
    -o /mayhem/aria-oracle
