# Contributing to scrim

Thank you for looking into scrim. Issues and pull requests are
welcome, in English or in Japanese.

## Before you start

- **A bug or a small fix** needs no ceremony: open an issue, or a pull
  request right away.
- **Something larger** is better talked over in an issue first. The scope is
  small on purpose, and [docs/planning.md](docs/planning.md) lists what was
  left out and why.
- **Compatibility is pinned to Agones v1.62.0.** Where scrim does what
  Agones does, it should do it the same way. A difference that is not
  written down in [docs/design.md](docs/design.md) is a bug worth reporting.
  A move to a newer release of Agones starts from the issue that the
  workflow `agones` opens for it, which lists the steps.
- **A security issue** does not belong in a public issue. See
  [SECURITY.md](SECURITY.md).

## Setting up

You need Go (the version in `go.mod`), Docker and `make`.

```sh
git clone --recurse-submodules https://github.com/ponyo877/scrim.git
cd scrim
make build sidecar-image
make test
```

Some checks need more, and only when you touch what they check:

| For | You need |
|---|---|
| `make lint` | [golangci-lint](https://golangci-lint.run) v2.15.0 |
| `make proto` | `protoc` 33.4 |
| The proofs in `formal/` | [elan](https://github.com/leanprover/elan), which installs the Lean version named in `formal/lean-toolchain` |
| The models in `formal/quint` (`make models`) | Node.js with npm, which installs the Quint version named in `formal/quint/package-lock.json`, `jq`, and a Java of version 21 or later |

## What the code is held to

The code is meant to be read, and the linters hold it to that.

- **Small functions.** A cognitive complexity of 10 or less, 50 lines or
  less outside tests, and no more than three levels of nesting.
- **Comments say why.** They are in English, they name the Agones file or
  function a piece of logic comes from, and they do not repeat the code.
- **Few dependencies.** What the standard library can do, it does.
- **A fix comes with its test**: one that fails without the fix. Tests are
  named as sentences that say what holds, such as
  `TestAWatcherThatLeftBeforeItWasToldIsLeftAlone`.
- **`third_party/agones` is a reference copy.** It is never edited.
- **Generated code is generated.** Change the `.proto` file and run
  `make proto`.

## Before a pull request

```sh
make check
```

runs what CI runs, as far as one machine can: the linters, every test under
the race detector in a shuffled order, a thousand tries of every property
test, the coverage floor, a short run of every fuzz target, the scan for
known vulnerabilities, the proofs, and the models.

`main` is protected. A pull request is merged when the job `ci` has passed
on a branch that is up to date with `main`.
[.github/workflows/ci.yml](.github/workflows/ci.yml) says what each of its
jobs holds. A check that fails only now and then is a bug like any other:
please do not re-run it away.

## Commit messages

A type, a colon, and a sentence that says what is true once the change is
in:

```text
fix: a Static port without its host port is refused
test: benchmarks of the store's writes and reads
docs: what CI checks before a change reaches main
```

The types in use are `feat`, `fix`, `test`, `docs`, `refactor`, `build` and
`ci`. The body says why, and what was found on the way.

## License

By contributing you agree that your contribution is licensed under the
[Apache License 2.0](LICENSE), as the rest of scrim is.
