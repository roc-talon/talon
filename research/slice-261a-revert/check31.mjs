const { verify } = await import(process.argv[2]);
const A = Buffer.alloc(32), sig = Buffer.concat([Buffer.alloc(31), Buffer.from([0x80]), Buffer.alloc(32)]);
const m = Number(process.argv[3]);
console.log("Go-rule verify:", verify(A, Buffer.from([m]), sig));
