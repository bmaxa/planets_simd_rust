#![feature(simd_ffi)]
extern crate rand;
extern crate planets;
use std::time::*;
use rand::Rng;

fn main() {
    let mut arg:Vec<(f64,f64,f64)> = Vec::new();
    let mut rng =rand::thread_rng();
    for i in 1..=1000000 {
        arg.push((rng.gen_range(0.,1000.),rng.gen_range(0.,1000.),rng.gen_range(0.,1000.)));
    }
    let start = Instant::now();
    let res = unsafe {planets::calculate_var(true,true,1.0,&arg)};
    let end = start.elapsed();
    let diff = (end.as_secs()*1000000000+end.subsec_nanos() as u64) as f64 / 1000000000.0;
    println!("{:?} {}",res,diff);
    let start = Instant::now();
    let res = unsafe {planets::calculate_var(true,false,1.0,&arg)};
    let end = start.elapsed();
    let diff = (end.as_secs()*1000000000+end.subsec_nanos() as u64) as f64 / 1000000000.0;
    println!("{:?} {}",res,diff);
    let start = Instant::now();
    let res = unsafe {planets::calculate_var(false,false,1.0,&arg)};
    let end = start.elapsed();
    let diff = (end.as_secs()*1000000000+end.subsec_nanos() as u64) as f64 / 1000000000.0;
    println!("{:?} {}",res,diff);
}
