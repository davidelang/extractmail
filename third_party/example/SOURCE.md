# example — toy third_party pin

Demonstrates the pin contract without network or heavy toolchains.

```bash
./third_party/fetch-deps ro example    # creates a tiny git tree in src/ + optional patch
./third_party/fetch-deps build example # build + get-artifacts
# or:  ./third_party/example/build && ./third_party/get-artifacts example
cat third_party/example/artifact/hello.bin
```

| Field | Demo value |
|-------|------------|
| `build_time` | `minutes` |
| `reproducible` | `false` (timestamp in output name) |
| `from` glob + `pick: newest` | `src/bin/hello-*.bin` |

Full rules: `docs/reference/THIRD_PARTY_PIN_BUILDS.md`.
