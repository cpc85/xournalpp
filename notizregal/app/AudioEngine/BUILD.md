# Offline-Spracherkennung: Quellen und Build

Enthalten sind statisch gelinkte Windows-ARM64-Programme (ARMv8-A, CPU).
Kein CUDA, OpenMP, KleidiAI oder separater Laufzeit-Download erforderlich.

- whisper.cpp v1.8.5: https://github.com/ggml-org/whisper.cpp/releases/tag/v1.8.5
- Toolchain llvm-mingw 20260908, ucrt-ubuntu-22.04-x86_64:
  https://github.com/mstorsjo/llvm-mingw/releases/tag/20260908
- Mehrsprachiges Whisper base, Q5_1: Quelle und SHA256 in model-source.json.
- Decoder: source/audio-convert.c (MIT), stb_vorbis.c (MIT/Public Domain),
  dr_wav.h (MIT/Public Domain). Deren Lizenztexte stehen in den Quelldateien.
  Upstream: https://github.com/nothings/stb und https://github.com/mackron/dr_libs
- Originales whisper.cpp-Quellarchiv und libc++-Include-Patch liegen in source.
- Whisper/ggml, Modell und statisch eingebundene Runtime: LICENSE-*.txt.

## Reproduzieren unter Linux

Toolchain entpacken und deren bin-Verzeichnis zum PATH hinzufügen.
Quellarchiv entpacken, source/libcxx.patch mit patch -p1 anwenden.
CMake-Toolchain-Datei arm64.cmake erstellen:

```cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-w64-mingw32-clang)
set(CMAKE_CXX_COMPILER aarch64-w64-mingw32-clang++)
set(CMAKE_RC_COMPILER aarch64-w64-mingw32-windres)
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static")
```

```sh
cmake -S whisper.cpp-1.8.5 -B build-arm64 \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/arm64.cmake" -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF -DGGML_CPU_ARM_ARCH=armv8-a \
  -DGGML_OPENMP=OFF -DGGML_CPU_KLEIDIAI=OFF -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF -DGGML_CCACHE=OFF
cmake --build build-arm64 --target whisper-cli -j4
aarch64-w64-mingw32-clang -O2 -march=armv8-a -static -municode \
  source/audio-convert.c -o audio-convert.exe
```

Der Decoder liest Ogg Vorbis und WAV blockweise und schreibt 16-kHz-Mono-PCM16.
Tiefpass vor dem Herunterrechnen, maximal vier Stunden pro Datei. Der Erkenner
kann zusätzlichen Arbeitsspeicher proportional zur Aufnahmelänge beanspruchen.
Die ARM64-Dateien wurden gebaut und ihre PE-Imports geprüft. Ein Lauf auf einem
echten Windows-Surface wurde in der Bauumgebung nicht durchgeführt.
