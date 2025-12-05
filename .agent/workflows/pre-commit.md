---
description: Verify code before committing
---

Before committing any changes, always run these steps:

1. Run flutter analyze to check for errors:

```bash
flutter analyze
```

2. If there are tests, run them:

```bash
flutter test
```

3. Try building the app (skip if toolchain issues):

```bash
flutter build linux --debug
```

4. Only commit if steps 1 and 2 pass with no errors.
