# NoMAD Login AD - AppleStagedUpdates Workaround

Currently NoMAD Login does not support AppleStagedUpdates, which does not complete the user-level macOS update process or autologin the user after completion.
This script will engage when macOS updates or upgrades are staged on the device

### What does it do?
- Disables NoMAD Login only during staged macOS updates and upgrades requiring reboot
- Allows macOS to complete the "last mile" user-level updates
- Allows autologin of the user logged in before the update
- Restores authorizationdb at the next restart folowing the update (restores NoMADLogin functionality)

### How to install

`sudo /bin/sh /path/to/.sh`

### How to uninstall

`sudo /bin/sh /path/to/.sh "uninstall"`
