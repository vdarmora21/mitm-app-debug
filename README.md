# mitm-app-debug

Android app traffic debugging with mitmproxy, running on GitHub Actions instead of a desktop.

## Workflows

- **Emulator smoke test** (`emulator-smoke.yml`, run manually): boots a Pixel 4 Play Store emulator
  on a GitHub runner, routes it through mitmdump and uploads `flows.har`, a screenshot and logcat.
  Open the HAR in Chrome DevTools (Network tab, import). Magisk rooting and CA install come next.
- **Build Magisk CA module** (`build-module.yml`): builds `user-ca-mitm.zip` from `module/`.
  Set the `MITM_CA_CERT` secret to your mitmproxy public cert so the module matches your proxy.

## Magisk module

`module/` trusts the mitmproxy CA and any user-installed CAs as system CAs, on Android 13 and older
(`/system` overlay) and on Android 14+ (bind mount over the conscrypt APEX store).
Build locally with `./build_module.sh ~/.mitmproxy/mitmproxy-ca-cert.pem`.
