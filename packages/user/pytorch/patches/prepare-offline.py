from pathlib import Path


edits = (
    (
        Path("setup.py"),
        '''def get_submodule_folders() -> list[Path]:
    git_modules_file = CWD / ".gitmodules"
''',
        '''def get_submodule_folders() -> list[Path]:
    offline_submodules = os.getenv("PYTORCH_OFFLINE_SUBMODULES")
    if offline_submodules:
        return [CWD / path for path in offline_submodules.split(":")]

    git_modules_file = CWD / ".gitmodules"
''',
    ),
    (
        Path("setup.py"),
        '''    check_for_files(
        THIRD_PARTY_DIR / "fbgemm" / "external" / "asmjit",
        ["CMakeLists.txt"],
    )
''',
        '''    if THIRD_PARTY_DIR / "fbgemm" in folders:
        check_for_files(
            THIRD_PARTY_DIR / "fbgemm" / "external" / "asmjit",
            ["CMakeLists.txt"],
        )
''',
    ),
    (
        Path("torch/headeronly/macros/Macros.h"),
        '''    void
    __assert_fail(
        const char* assertion,
        const char* file,
        unsigned int line,
        const char* function) noexcept __attribute__((__noreturn__));
''',
        '''#if defined(__GLIBC__)
    void
    __assert_fail(
        const char* assertion,
        const char* file,
        unsigned int line,
        const char* function) noexcept __attribute__((__noreturn__));
#endif
''',
    ),
)

for path, old, new in edits:
    source = path.read_text()
    if source.count(old) != 1:
        raise RuntimeError(f"pinned PyTorch source no longer matches edit: {path}")
    source = source.replace(old, new, 1)
    path.write_text(source)
