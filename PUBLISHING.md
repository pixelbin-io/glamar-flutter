# PixelBin Dart SDK Publishing Guide

This is a minimal guide for publishing the PixelBin Dart SDK to pub.dev.

## Prerequisites

- Ensure you have the latest version code ready
- Update the version number in `pubspec.yaml`
- Make sure your email has access to the pixelbin.io publisher on pub.dev
- Dart SDK installed (version 3.4.3 or higher)

## Publishing Steps

### 1. Authenticate with pub.dev

```bash
# Log in to pub.dev
dart pub login
```

This will open a browser window for Google authentication. **Important**: Your email must have access to the pixelbin.io publisher on pub.dev, otherwise you won't be able to publish updates to the package.

#### Publisher Admins

The following users have admin access to the pixelbin.io publisher:

| Email              | Role  |
| ------------------ | ----- |
| social@pixelbin.io | admin |

If you need publishing access, please contact one of these admins.

To log out if needed:

```bash
dart pub logout
```

### 2. Validate Your Package

Before publishing, validate your package to ensure it meets pub.dev's requirements:

```bash
# Analyze your package for issues
dart analyze

# Run tests to ensure functionality
dart test

# Verify package structure and metadata
dart pub publish --dry-run
```

The dry run will check for common issues and validate your package without actually publishing it.

### 3. Publish Your Package

Once validation passes, publish your package:

```bash
# Publish to pub.dev
dart pub publish
```

Follow the prompts to confirm publication. Your package will be available on pub.dev shortly after successful publication.

### 4. Verify Publication

After publishing, verify your package is available:

- Visit [pub.dev](https://pub.dev/packages/pixelbin)
- Check the package score and suggestions for improvement
- Ensure documentation renders correctly

## Non-Interactive Publishing with Tokens

### Token Storage and Security

After generating a token, pub.dev creates a credentials file at `~/Library/Application Support/dart/pub-credentials.json`. This file contains:

- Access token
- Refresh token
- ID token
- Token expiration information

You can examine this file to extract tokens for CI/CD systems:

```bash
cat "~/Library/Application Support/dart/pub-credentials.json"
```

### Using Tokens for Non-Interactive Publishing

Set the required environment variables before publishing:

```bash
export PUB_DEV_PUBLISH_ACCESS_TOKEN="your_access_token"
export PUB_DEV_PUBLISH_REFRESH_TOKEN="your_refresh_token"
export PUB_DEV_PUBLISH_ID_TOKEN="your_id_token"
export PUB_DEV_PUBLISH_EXPIRATION="expiration_timestamp"

# Then publish without interaction
dart pub publish --force
```

## Troubleshooting

If you encounter authentication issues:

- Verify you have access to the correct Google account
- Run `dart pub logout` and then `dart pub login` to refresh credentials
- Check that your tokens are not expired

For validation errors:

- Address all issues reported by `dart pub publish --dry-run`
- Ensure your package version has been incremented
- Verify all required files are present and properly formatted
