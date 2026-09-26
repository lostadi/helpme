# helpme

**Make things that are not visible actually visible** — so you don’t need hidden
knowledge to use Termux or any CLI.

`helpme` is a local command index and machine guide. It is implemented in
**[OSTADIX](https://github.com/lostadi/OSTADIX)** (`.O` programs) with a
thin bash launcher. It harvests man / whatis / `--help` / tldr / info, indexes
shell builtins, documents package managers, and teaches the commands for the
most important everyday tasks on *this* system.

---

## Dependencies

### Required

| Dependency | Role | How helpme gets it |
|------------|------|--------------------|
| **[OSTADIX](https://github.com/lostadi/OSTADIX)** | Runtime for every `.O` program (`O` binary + language backends) | `./OSTADIX` if present, otherwise `~/OSTADIX` (cloned and built by `install.sh`) |
| **Rust / cargo** | Build OSTADIX | [rustup](https://rustup.rs) |
| **Python 3** | OSTADIX Python backend (logic in most `.O` files) | OS package / Termux `pkg install python` |
| **sqlite3** | Local index (`~/.local/share/helpme/db/index.db`) | Usually preinstalled; else OS package |

OSTADIX is the **primary runtime dependency**. Without a built `O` binary,
helpme cannot run.

```text
helpme/
├── helpme              # bash launcher
├── install.sh          # bootstrap (builds OSTADIX, installs .O programs)
├── *.O                 # OSTADIX programs
└── OSTADIX/            # optional checkout; otherwise ~/OSTADIX
    ├── target/release/O
    └── backends/
```

### Optional (auto-installed per system via `helpme setup`)

| Tool | Why |
|------|-----|
| `fzf` | Fuzzy TUI (`helpme` with no args) |
| `man` / `mandoc` | Manual pages for reindex |
| `tldr` / `tealdeer` | Community examples |
| `bat` | Syntax-highlighted lookup |
| `info` / `texinfo` | GNU info pages |
| Ollama or llama.cpp | `helpme ai <cmd>` summaries |

`helpme setup` detects your package manager (`pkg`, `apt`, `brew`, `dnf`,
`pacman`, `apk`, …) and installs the right package *names* for that OS.

---

## Quick start

```bash
git clone https://github.com/lostadi/helpme.git ~/helpme
cd ~/helpme
./install.sh
```

`install.sh` will:

1. Ensure **OSTADIX** is present (`./OSTADIX`, or `~/OSTADIX`, cloning
   https://github.com/lostadi/OSTADIX.git when the tree is missing) and
   `cargo build --release` → `O` binary  
2. Install all `.O` programs to `~/.local/share/helpme/`  
3. Install the `helpme` wrapper to `~/.local/bin/helpme`  
4. Run **`helpme setup`** (optional packages for this OS)  
5. Run **`helpme reindex`**

Add `~/.local/bin` to your `PATH` if needed:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # or ~/.bashrc
```

Then:

```bash
helpme system       # this machine, package managers, essential commands
helpme setup        # (re)install/upgrade optionals
helpme doctor       # health check
helpme              # fuzzy-browse every indexed command
```

### Environment overrides

| Variable | Default | Meaning |
|----------|---------|---------|
| `OLANG` | `~/OSTADIX/target/release/O` or baked path | Path to OSTADIX `O` binary |
| `OLANG_DIR` | `./OSTADIX` or `~/OSTADIX` | Tree used by `install.sh` |
| `HELPME_DIR` | `~/.local/share/helpme` | Installed `.O` programs + DB |
| `HELPME_DB` | `$HELPME_DIR/db/index.db` | SQLite index |
| `HELPME_WORKERS` | `16` | Parallel reindex workers |

---

## Commands

```text
helpme system              # machine + package managers + essential commands
helpme system packages     # package-manager cheat sheets only
helpme system do           # “how do I …?” everyday commands
helpme packages            # alias → system packages
helpme essentials          # alias → system do
helpme setup               # install + upgrade all optionals for this OS
helpme setup --dry-run     # plan only

helpme                     # fzf TUI — fuzzy-search all indexed commands
helpme <cmd>               # direct lookup (man / --help / tldr / AI)
helpme search <words>      # full-text search (find by what it does)
helpme map                 # PATH, Termux, doc tools, coverage
helpme doctor              # missing deps / broken setup
helpme stats               # index coverage report
helpme undoc               # commands still without any docs
helpme topics              # curated hidden-knowledge catalog
helpme topic <id>          # one topic (storage, path, pkg, …)
helpme reindex             # re-scan $PATH + shell builtins
helpme reindex --force     # full rebuild (keeps AI summaries)
helpme ai <cmd>            # plain-language summary (local LLM)
helpme --version
helpme --help
```

---

## Why

| Invisible | helpme surface |
|-----------|----------------|
| What machine am I on? | `helpme system` / `helpme system machine` |
| How do I install software? | `helpme packages` / `helpme setup` |
| Everyday “how do I …?” commands | `helpme essentials` |
| What’s on `$PATH` | TUI + `helpme map` |
| What a binary does | `helpme <cmd>` |
| Shell builtins (`cd`, `export`) | reindex indexes them |
| Docs split across man / info / tldr / `--help` | one DB, one lookup |
| Concepts that aren’t binaries | `helpme topics` |
| Broken setup | `helpme doctor` |

---

## How it works

1. **OSTADIX** runs each `.O` program (Python / SQL / … backends).  
2. `reindex.O` scans `$PATH` + shell builtins and harvests documentation.  
3. Results live in SQLite with **FTS5** full-text search.  
4. The bash wrapper `helpme` dispatches subcommands to the right `.O` file.

| File | Role |
|------|------|
| `reindex.O` | PATH + builtins → man/whatis/--help/tldr/info → SQLite + FTS |
| `lookup.O` | Format one entry (binary / builtin) |
| `search.O` | Full-text search across harvested docs |
| `map.O` | Environment map |
| `doctor.O` | Health check |
| `stats.O` | Coverage report |
| `undoc.O` | Commands with nothing harvested |
| `topics.O` | Curated Termux/CLI knowledge |
| `system.O` | Machine, package managers, essential how-tos |
| `setup.O` | Auto install/upgrade optionals per OS |
| `ai_explain.O` | Local LLM summary → cached in DB |

---

## OSTADIX dependency details

- **Repo:** https://github.com/lostadi/OSTADIX  
- **Checkout:** `./OSTADIX` if that tree is in the helpme repo, otherwise `~/OSTADIX`  
- **Binary:** `$OLANG_DIR/target/release/O`  
- **Backends:** `$OLANG_DIR/backends/` (symlinked into `HELPME_DIR` on install)

Build only:

```bash
cargo build --release --manifest-path="${OLANG_DIR:-$HOME/OSTADIX}/Cargo.toml"
```

Logic lives in `python^(...)_python` blocks (and `O^(...)_O` in `stats.O`).
OSTADIX parses `$IDENT` anywhere in a block as a binding — use `\$IDENT` when
a backend must see a literal `$` (e.g. shell `$PATH`).

---

## Re-index

```bash
helpme reindex                 # incremental
helpme reindex --force         # full rebuild
HELPME_WORKERS=32 helpme reindex
```

After `helpme setup` installs man/tldr, run `helpme reindex --force` so new
docs are harvested.

---

## Platform notes

| Platform | Install optionals | Notes |
|----------|-------------------|--------|
| **Termux** | `helpme setup` → `pkg` | Uses `mandoc`, `tealdeer`, etc. |
| **Debian/Ubuntu** | `apt` | May need `sudo` |
| **macOS** | `brew` | |
| **Fedora** | `dnf` | |
| **Arch** | `pacman` | |
| **Alpine** | `apk` | |

---

## License

MIT

OSTADIX is a separate project with its own license; see
`~/OSTADIX/LICENSE` (or `./OSTADIX/LICENSE` when that checkout is present).
