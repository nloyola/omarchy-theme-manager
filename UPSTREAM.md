# Upstream boundary

`ImagePicker.qml`, `ImagePickerModel.js`, and `list.sh` are derived from Omarchy
4.0's `omarchy.image-picker`. The manager controllers, catalog code, inventory
helper, and tests are project-owned.

Before updating the derived files, compare them with
`/usr/share/omarchy/shell/plugins/image-picker`, preserve the manager integration
points, then run `npm run quality` and test both theme and background selection.

The modern JavaScript syntax is intentional. Compatibility is protected by
tests and by running `qmllint` over both QML and imported JavaScript files.
