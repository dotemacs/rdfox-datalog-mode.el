## 0.1.1

### Fixed

- Fixed RDFox Datalog indentation so comma-separated rule body atoms
  align correctly and new clauses reset to top-level indentation after
  `.`.

## 0.1.0

### Added

- Added `rdfox-datalog-mode`, a major mode for editing RDFox Datalog
  `.dlog` files.
- Added syntax highlighting for RDFox Datalog keywords, built-ins,
  variables, IRIs, literals, prefixed names, blank nodes, operators, and
  numeric constants.
- Added support for `#` line comments.
- Added basic indentation support for RDFox Datalog rules.
- Added automatic activation for `.dlog` files.
- Added customizable indentation width via
  `rdfox-datalog-indent-offset`.
