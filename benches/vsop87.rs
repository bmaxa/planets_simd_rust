#[macro_use]
extern crate criterion;
extern crate rand;
extern crate planets;

//extern crate vsop87;

use criterion::Criterion;
use rand::{thread_rng, Rng};
use planets::*;

fn vsop87_mars(c: &mut Criterion) {
    let mut rng = thread_rng();
    let mut arg = Vec::new();
    for i in 1..10000{
        arg.push((rng.gen_range(-1000.,1000.),rng.gen_range(-1000.,1000.),rng.gen_range(-1000.,1000.)));
    }
    let clon = arg.clone();
    let clon1 = arg.clone();
    c.bench_function("VSOP87 Mars true agner", move |b| {
        b.iter(|| unsafe{calculate_var(true,true,1.5,&clon)})});
    c.bench_function("VSOP87 Mars true me", move |b| {
        b.iter(|| unsafe{calculate_var(true,false,1.5,&clon1)})});
    c.bench_function("VSOP87 Mars false", move |b| {
        b.iter(|| unsafe{calculate_var(false,false,1.5,&arg)})});
}

criterion_group!(
    vsop87_benches,
    vsop87_mars
);
criterion_main!(vsop87_benches);
