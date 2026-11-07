#!/usr/bin/env bash
# Liftoff and TurboFan compile time of the 3 largest functions of a wasm file (V8 --trace-wasm-compilation-times, eager, one thread).
for tier in "--liftoff --no-wasm-tier-up" "--no-liftoff"; do
  echo "$tier: $1"
  node $tier --no-wasm-lazy-compilation --wasm-num-compilation-tasks=0 --trace-wasm-compilation-times -e "new WebAssembly.Module(require('fs').readFileSync('$1'))" 2>&1 \
    | sed -nE 's/.*#([0-9]+) using ([A-Za-z]+), took ([0-9]+) .s.*bodysize ([0-9]+) codesize ([0-9]+).*/\4 \3 \1 \5/p' | sort -n -r | head -3 \
    | awk '{printf "  func %s body %d bytes: %.1f ms, machine code %d bytes\n", $3, $1, $2/1000, $4}'
done
