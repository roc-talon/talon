# host-link (Q16)

Question: do platform hosts link statically? A dynamic link is the only run-time dependency of a global tool (`DESIGN-CLI.md` 6.4).

| File | Content |
| --- | --- |
| `apps/` | One small app per platform |
| `run.sh` | Builds each app for each target in the platform `targets/` dir, then runs `inspect.py` on the binary |
| `inspect.py` | Prints the format and the run-time library imports: ELF `NEEDED` and interpreter, Mach-O `LC_LOAD_DYLIB`, PE import table, wasm import modules |
| `results.tsv` | Last run |

Run: put a roc binary in `bin/<tag>/roc` for each tag in `run.sh`, then `./run.sh`. The packages come from `~/.cache/roc/packages`.

## Result (2026-10-14, Linux x86_64 host)

| Platform | Nightly | Linux | macOS | Windows |
| --- | --- | --- | --- | --- |
| basic-cli 0.29.0, 0.25.0 | 10-12 | `x64musl`, `arm64musl`: static | No link: no `macos-sysroot` in the platform | No link: `mainCRTStartup` missing |
| roc-platform-template-zig 1.0.0 | 10-12 | `x64musl`, `arm64musl`: static | No link: no `macos-sysroot` | No link: `mainCRTStartup` missing |
| template (hash `ABFg...`) | 10-12 | `x64musl`, `x64v1musl`, `arm64musl`, `arm64v1musl`: static | No link: no `macos-sysroot` | No link: `mainCRTStartup` missing |
| basic-webserver 0.17.0 | 10-06 | `x64musl`, `arm64musl`: static | `libSystem.B.dylib` only | No link: `WindowsSDKNotFound` |
| roc-ray 0.10.0 | 10-06 | `x64v1glibc` only: `libc.so.6`, `libm.so.6`, `libX11.so.6` | `libSystem`, `libobjc`, 6 system frameworks | No link: `WindowsSDKNotFound` |

| Fact | Evidence |
| --- | --- |
| Each musl binary is static: no `NEEDED`, no interpreter. The `x64` ones run and print the expected output. | `file`, `ldd`: "not a dynamic executable" |
| The roc-ray glibc binary has no symbol versions, so it does not need a new glibc. It needs `libX11` at run time. | `readelf -V`: "No version information" |
| `roc build` with no `--target` picks the musl target when the platform has one, else the glibc target (roc-ray). | Build with no `--target` |
| No platform links OpenSSL. basic-cli uses rustls, linked in. | Strings in the binary, `targets` in `main.roc` |
| Windows targets link only Windows system libraries (`kernel32.lib`, `ws2_32.lib`, `opengl32.lib`, and others). | `targets` in each `main.roc` |

The macOS and Windows link failures are limits of a cross link from Linux, not of the hosts. They are not part of Q16.
