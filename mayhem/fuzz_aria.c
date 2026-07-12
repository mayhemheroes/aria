/* In-process libFuzzer harness for the aria lisp interpreter.
 *
 * Drives the full parse+eval pipeline (ar_do_string) over the fuzz input, which
 * is the same code path the standalone interpreter runs for a script file. The
 * interpreter's own setjmp/longjmp error handling (ar_try) contains aria-level
 * errors so a bad program unwinds instead of aborting the fuzzing process. The
 * built-in `exit` primitive is rebound to raise an aria error so a fuzzed
 * `(exit)` cannot terminate the fuzzer. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "aria.h"

static ar_Value *fuzz_no_exit(ar_State *S, ar_Value *args) {
  (void)args;
  ar_error_str(S, "exit disabled under fuzzing");
  return NULL;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  char *buf;
  ar_State *S;

  buf = (char *)malloc(size + 1);
  if (!buf) return 0;
  memcpy(buf, data, size);
  buf[size] = '\0';

  S = ar_new_state(NULL, NULL);
  if (!S) {
    free(buf);
    return 0;
  }

  ar_bind_global(S, "exit", ar_new_cfunc(S, fuzz_no_exit));

  ar_try(S, err, {
    ar_do_string(S, buf);
  }, {
    (void)err;
  });

  ar_close_state(S);
  free(buf);
  return 0;
}
