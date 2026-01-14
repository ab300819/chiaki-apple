# Chiaki-ng Patches for Apple Platforms

These patches are applied to chiaki-ng during the build process to enable
compilation for iOS, tvOS, and other Apple platforms.

## Patch List

### 0001-ios-compatibility-takion.patch

**Purpose**: Fix iOS/tvOS compilation by making CoreServices/Gestalt macOS-only

**Problem**: `CoreServices/CoreServices.h` and `Gestalt()` API are only available
on macOS, not on iOS/tvOS.

**Solution**: Wrap the include and usage with `TARGET_OS_OSX` checks.

**Files Modified**:
- `lib/src/takion.c`

**Upstream Status**: Not submitted yet. Consider submitting as PR.

---

### 0002-mbedtls-api-compatibility.patch

**Purpose**: Fix mbedtls 2.17+ API compatibility

**Problem**: `mbedtls_gcm_starts()` signature changed in mbedtls 2.17:
- Old (2.16-): `mbedtls_gcm_starts(ctx, mode, iv, iv_len)`
- New (2.17+): `mbedtls_gcm_starts(ctx, mode, iv, iv_len, add, add_len)`

**Solution**: Add `NULL, 0` parameters for empty additional data.

**Files Modified**:
- `lib/src/gkcrypt.c`

**Upstream Status**: Not submitted yet. The upstream may be using older mbedtls.

---

## Maintenance

### When chiaki-ng is updated

1. Try applying patches:
   ```bash
   cd chiaki-ng
   git apply --check ../Patches/*.patch
   ```

2. If patches fail, regenerate them:
   ```bash
   # Make the fix manually, then:
   git diff lib/src/takion.c > ../Patches/0001-ios-compatibility-takion.patch
   git diff lib/src/gkcrypt.c > ../Patches/0002-mbedtls-api-compatibility.patch
   ```

3. Update this README with any changes.

### Checking if patches are still needed

```bash
# Check if upstream has similar fixes
cd chiaki-ng
git log --oneline --all --grep="iOS" --grep="Gestalt" --grep="gcm_starts"
```

## Upstream Contribution

These patches should ideally be submitted to upstream chiaki-ng:
- Repository: https://github.com/streetpea/chiaki-ng
- Consider creating PRs with proper Apple platform support

## Version Compatibility

| Patch | chiaki-ng version | Tested |
|-------|-------------------|--------|
| 0001  | main (2024-01)    | Yes    |
| 0002  | main (2024-01)    | Yes    |
