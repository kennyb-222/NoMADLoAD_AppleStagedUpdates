#!/bin/bash
# Disable NoMAD Login AD only during staged macOS updates and upgrades requiring reboot
## Allows macOS to complete the "last mile" user-level updates
## Allows autologin of the user logged in before the update
## Restores NoMAD Login authorizationdb after the OS update is complete
#
# Source: https://github.com/kennyb-222/NoMADLoAD_AppleStagedUpdates/
# Author: Kenny Botelho
# Version: 1.0

# Set variables
ScriptPath="/var/db/.nomadLogin_StagedUpgrade.sh"
PlistPath="/Library/LaunchDaemons/com.NoLoAD.StagedAppleUpgrade.plist"

# Check if uninstall arg was passed
if [[ $1 == "uninstall" || $4 == "uninstall" ]]; then
    echo "removing NoMADLoAD_AppleStagedUpdates..."
    rm ${ScriptPath}
    rm ${PlistPath}
    rm /var/db/.nomadLogin_authdb_bkp.xml
    rm /var/db/.nomadLogin_revertAuthdb.sh
    rm /Library/LaunchDaemons/com.NoLoAD.PostAppleUpgradeRestore.plist
    /bin/launchctl remove com.NoLoAD.StagedAppleUpgrade
    /bin/launchctl remove com.NoLoAD.PostAppleUpgradeRestore
    exit 0
fi

# NoLoAD StagedUpgrade Script
cat > ${ScriptPath} << \EOF
#!/bin/bash
# StagedAppleUpgrade Workflow

# Backup loginwindow settings and revert to macOS default
/usr/bin/security authorizationdb read system.login.console > /var/db/.nomadLogin_authdb_bkp.xml
rm /var/db/auth.db

# Create LaunchDaemon plist
cat > /Library/LaunchDaemons/com.NoLoAD.PostAppleUpgradeRestore.plist << \E0F
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.NoLoAD.PostAppleUpgradeRestore</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>/var/db/.nomadLogin_revertAuthdb.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
E0F

# Set Permissions
chmod 755 /Library/LaunchDaemons/com.NoLoAD.PostAppleUpgradeRestore.plist

# Revert loginwindow script
cat > /var/db/.nomadLogin_revertAuthdb.sh << \E0F
#!/bin/bash
# NoMAD Login AD revert loginwindow

# Wait up to 90 miinutes to complete the Apple Upgrade
c=0
while [[ -f /var/db/.AppleUpgrade ]]; do
    sleep 60
((c++)) && ((c==90)) && c=0 && break
done

# Get the authorizationdb values for comparison
curr_authdb=$(/usr/bin/security -q authorizationdb read system.login.console | \
                sed '1,/<array>/d;/<\/array>/,$d')
bkp_authdb=$(cat /var/db/.nomadLogin_authdb_bkp.xml | \
                sed '1,/<array>/d;/<\/array>/,$d')

# If upgrade is complete, reset authorizationdb
if [[ ! -f /var/db/.AppleUpgrade && ! -f /var/db/.StagedAppleUpgrade && \
        ${curr_authdb} != ${bkp_authdb} ]]; then
    # Restore previous loginwindow settings
    /usr/bin/security authorizationdb write system.login.console < /var/db/.nomadLogin_authdb_bkp.xml
    # Cleanup
    rm /var/db/.nomadLogin_authdb_bkp.xml
    rm /Library/LaunchDaemons/com.NoLoAD.PostAppleUpgradeRestore.plist
    rm $0
    /bin/launchctl remove com.NoLoAD.PostAppleUpgradeRestore
fi
exit
E0F

# Allow script execution
chmod +x /var/db/.nomadLogin_revertAuthdb.sh

exit
EOF

# Set script permissions
chmod 755 ${ScriptPath}

# Create LaunchDaemon to watch for "Stagged Apple Upgrades"
cat > ${PlistPath} << \EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.NoLoAD.StagedAppleUpgrade</string>
    <key>LaunchOnlyOnce</key>
    <true/>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>/private/var/db/.nomadLogin_StagedUpgrade.sh</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>WatchPaths</key>
    <array>
        <string>/private/var/db/.StagedAppleUpgrade</string>
    </array>
</dict>
</plist>
EOF

# Set Permissions
chmod 755 ${PlistPath}

# Load LaunchDaemon
/bin/launchctl load ${PlistPath}

exit 0
