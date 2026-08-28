# Upstream boundary

`v0200/ImagePicker.qml` and `v0200/ImagePickerModel.js` are derived from
Omarchy's `omarchy.image-picker` at commit
`83881e979b35468c3e7d60b171e319ede61a88fd`.

At that revision, the upstream file hashes were:

- `ImagePicker.qml`:
  `0d882dcb6fc593d35fdfa6a9c4a87f04f5876dc2d221aac3eebf854f96dccedf`
- `ImagePickerModel.js`:
  `2eecf32b70811d0a39981e351ebe9843384aaf97b43dad1216651d2535a9a5da`

The theme and wallpaper models/controllers, filter UI, catalog and inventory
helpers, and tests are project-owned. `list.sh` remains equivalent to the
native image-picker helper.

The complete executable QML/JavaScript graph lives in one versioned runtime
directory so Qt cannot mix cached files from different plugin builds.

Before updating the derived files, compare them with
`$OMARCHY_PATH/shell/plugins/image-picker`, preserve both context-gated
integration paths, then run `npm run quality` and the disposable VM scenario
documented in the README.

The modern JavaScript syntax is intentional. Compatibility is protected by
tests and by running `qmllint` over both QML and imported JavaScript files.
