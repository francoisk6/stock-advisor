/// Production beta builds pass `--dart-define=BETA=true`: shows the "Beta" label and the
/// closed-beta note on the sign-in screens.
const isBeta = bool.fromEnvironment('BETA');
