# remotetable pin

| | |
|--|--|
| **Upstream** | `davidelang/remotetable` @ `65366fc917a5abcc8efc74014be4d524226ffbb3` (`master`) |
| **Profile** | Co-dev library + consumer pin (RO builds supported) |
| **build_time** | `minutes` |
| **reproducible** | `true` (same pin + AGP/Kotlin/JDK; verified bit-identical host rebuild) |
| **Product** | `artifact/remotetable.aar` (~95KB, pure Kotlin library) |

## Reproduce (RO)

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=$HOME/Android/Sdk
./third_party/fetch-deps ro remotetable
./third_party/fetch-deps build remotetable
```

Optional host: `~/git/remotetable` (orchestration + `master/` worktree).

## RO build hygiene

- Pin sources stay RO after `fetch-deps ro`.
- `./build` only unlocks `src/android/.gradle` and `src/android/remotetable/` (Gradle outputs).
- Does **not** require `requires_writable_src`.
- Product path: `src/android/remotetable/build/outputs/aar/remotetable-release.aar` → `get-artifacts`.

## Tests in build

1. `python3 src/conformance/harness.py` (mock; live smoke optional via env)
2. `src/scripts/build-aar.sh` → `assembleRelease`

## Co-develop (rw)

```bash
./third_party/fetch-deps rw remotetable   # branch = VE branch
# edit under src/
./third_party/fetch-deps build remotetable
# promote: library PR → bump libpin.toml git_sha + artifact
```
