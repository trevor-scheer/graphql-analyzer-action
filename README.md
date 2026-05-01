# GraphQL Analyzer Action

GitHub Action wrapping the [GraphQL Analyzer CLI](https://github.com/trevor-scheer/graphql-analyzer) for CI: inline PR annotations, optional SARIF, optional PR summary comment.

## Quickstart

```yaml
name: GraphQL
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: trevor-scheer/graphql-analyzer-action@v1
```

## Inputs

| Name                  | Default                   | Description                                            |
| --------------------- | ------------------------- | ------------------------------------------------------ |
| `command`             | `check`                   | One of `check`, `validate`, `lint`.                    |
| `config`              | (auto-discover)           | Path to `.graphqlrc.yaml`.                             |
| `project`             | (none)                    | Multi-project name.                                    |
| `version`             | `latest`                  | CLI version: `latest` or `X.Y.Z`.                      |
| `max-warnings`        | (none)                    | Threshold for `--max-warnings`.                        |
| `annotate`            | `true`                    | Emit inline PR annotations.                            |
| `sarif`               | `false`                   | Produce a SARIF file at `sarif-file`.                  |
| `sarif-file`          | `graphql-results.sarif`   | SARIF output path.                                     |
| `comment`             | `false`                   | Post (or update) a PR summary comment.                 |
| `working-directory`   | `.`                       | Where to run the CLI.                                  |

## Outputs

| Name         | Description                                  |
| ------------ | -------------------------------------------- |
| `errors`     | Number of error-severity diagnostics.        |
| `warnings`   | Number of warning-severity diagnostics.      |
| `sarif-file` | Path to the SARIF file when `sarif: true`.   |

## Examples

### Basic

```yaml
- uses: trevor-scheer/graphql-analyzer-action@v1
```

### With SARIF upload

```yaml
permissions:
  contents: read
  security-events: write

steps:
  - uses: actions/checkout@v4
  - uses: trevor-scheer/graphql-analyzer-action@v1
    id: graphql
    with:
      sarif: true
  - uses: github/codeql-action/upload-sarif@v3
    if: always()
    with:
      sarif_file: ${{ steps.graphql.outputs.sarif-file }}
```

### PR summary comment

```yaml
permissions:
  contents: read
  pull-requests: write

steps:
  - uses: actions/checkout@v4
  - uses: trevor-scheer/graphql-analyzer-action@v1
    with:
      comment: true
```

### Multi-project

```yaml
- uses: trevor-scheer/graphql-analyzer-action@v1
  with:
    project: web
```

### Pinning the CLI version

By default the action installs the latest released CLI. To pin:

```yaml
- uses: trevor-scheer/graphql-analyzer-action@v1
  with:
    version: 1.2.3
```

Pinning the action major (`@v1`) does **not** pin the CLI version.

## License

MIT
