#include "vectormath_trig.h"
#include <immintrin.h>
#include <cmath>
extern "C"
#if 1
__m256d agner_cos(__m256d const p) {
  return __m256d(cos(Vec4d(p)));
}
#else
__m256d agner_cos(__m256d const p) {
  Vec4d tmp(p);
  double a[4];
  a[0] = cos(tmp[0]);
  a[1] = cos(tmp[1]);
  a[2] = cos(tmp[2]);
  a[3] = cos(tmp[3]);
  tmp.load(a);
  return __m256d(tmp);
}
#endif
