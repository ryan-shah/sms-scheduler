/// Build version, stamped by CI via `--dart-define=APP_VERSION=...`.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
