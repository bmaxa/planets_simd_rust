#![feature(simd_ffi)]
use std::arch::x86_64::*;
use std::mem;
use std::f64;
extern "C"{
  fn cos_pd(a:__m256d)->__m256d;
  fn agner_cos(a:__m256d)->__m256d;
  fn sin_pd(a:__m256d)->__m256d;
  fn cosine(a:f64)->f64;
}
#[target_feature(enable = "avx")]
unsafe fn vector_term(
    (a1, b1, c1): (f64, f64, f64),
    (a2, b2, c2): (f64, f64, f64),
    (a3, b3, c3): (f64, f64, f64),
    (a4, b4, c4): (f64, f64, f64),
    t: f64,
    agner: bool,
) -> (f64, f64, f64, f64) {
	let a = _mm256_set_pd(a1, a2, a3, a4);
	let b = _mm256_set_pd(b1, b2, b3, b4);
	let c = _mm256_set_pd(c1, c2, c3, c4);
	let t = _mm256_set1_pd(t);
  let bct = _mm256_fmadd_pd(c,t,b);
  let tmp = if agner {agner_cos(bct)} else {cos_pd(bct)};
  let term = _mm256_mul_pd(a, tmp);
  let mut buf:[f64;4]=[0.;4];
  _mm256_storeu_pd(buf.as_mut_ptr(),term);
  (buf[3],buf[2],buf[1],buf[0])
}
pub unsafe fn calculate_var(avx:bool,agner:bool,t: f64, var: &[(f64, f64, f64)]) -> f64 {
    if avx {
        calculate_var_avx(t,var,agner)
    } else {
        var.iter()
                    .fold(0_f64, |term, &(a, b, c)| term + a * (b + c * t).cos())
    }
}
unsafe fn calculate_var_avx(t: f64, var: &[(f64, f64, f64)],agner:bool) -> f64 {
var.chunks(4)
    .map(|vec| match vec {
       &[(a1, b1, c1), (a2, b2, c2), (a3, b3, c3), (a4, b4, c4)] => {
            // The result is little endian in x86/x86_64.
            let (term4, term3, term2, term1) =
                vector_term((a1, b1, c1), (a2, b2, c2),
                            (a3, b3, c3), (a4, b4, c4), t,agner);

            term1 + term2 + term3 + term4
        },
       &[(a1, b1, c1), (a2, b2, c2), (a3, b3, c3)] => {
    // The result is little endian in x86/x86_64.
    let (_term4, term3, term2, term1) = vector_term(
        (a1, b1, c1),
        (a2, b2, c2),
        (a3, b3, c3),
        (f64::NAN, f64::NAN, f64::NAN),
        t,
        agner,
    );

    term1 + term2 + term3
    },
    &[(a1, b1, c1), (a2, b2, c2)] => {
    let (_term4, _term3, term2 , term1) = vector_term(
        (a1, b1, c1),
        (a2, b2, c2),
        (f64::NAN, f64::NAN, f64::NAN),
        (f64::NAN, f64::NAN, f64::NAN),
        t,
        agner,
    );
	  term1 + term2
	},
  &[(a, b, c)] => { let (_term4, _term3, _term2, term1) = vector_term(
        (a, b, c),
        (f64::NAN, f64::NAN, f64::NAN),
        (f64::NAN, f64::NAN, f64::NAN),
        (f64::NAN, f64::NAN, f64::NAN),
        t,
        agner,);
        term1},
   _ => unimplemented!(),
    })
    .sum::<f64>()
}
