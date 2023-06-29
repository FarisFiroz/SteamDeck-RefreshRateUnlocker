#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'

clear

echo Refresh Rate Unlocker Script by ryanrudolf
echo Discord user dan2wik for the idea on overclocking the display panel to 70Hz
echo https://github.com/ryanrudolfoba/SteamDeck-RefreshRateUnlocker
sleep 2

# Make sure ur running as root
if [ "$USER" != "root" ]
then
    echo "Please run this as root or with sudo"
    exit 2
fi

###### Main menu. Ask user for the preferred refresh rate limit

Choice=$(zenity --width 700 --height 300 --list --radiolist --multiple --title "Refresh Rate Unlocker - https://github.com/ryanrudolfoba/SteamOS-RefreshRateUnlocker"\
	--column "Select One" \
	--column "Refresh Rate Limit" \
	--column="Description - Read this carefully!"\
	FALSE 20,60 "Set the refresh rate limit to 20Hz - 60Hz."\
	FALSE 30,60 "Set the refresh rate limit to 30Hz - 60Hz."\
	FALSE 20,70 "Set the refresh rate limit to 20Hz - 70Hz."\
	FALSE 30,70 "Set the refresh rate limit to 30Hz - 70Hz."\
	FALSE 40,70 "Set the refresh rate limit to 40Hz - 70Hz."\
	TRUE EXIT "Don't make any changes and exit immediately.")

if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]
then
	echo User pressed CANCEL / EXIT. Make no changes. Exiting immediately.
	exit
else
	steamos-readonly disable
	echo Perform cleanup first.
	rm /bin/gamescope-session.backup &> /dev/null
	echo Backup existing gamescope-session.
	cp /bin/gamescope-session /bin/gamescope-session.backup
	echo Patch the gamescope-session.
	
	# patch gamescope-session based on the user choice
	sed -i "s/STEAM_DISPLAY_REFRESH_LIMITS=..,../STEAM_DISPLAY_REFRESH_LIMITS=$Choice/g" /bin/gamescope-session
	steamos-readonly enable
	grep STEAM_DISPLAY_REFRESH_LIMITS /bin/gamescope-session
	echo -e "$GREEN"gamescope-session has been patched to use $Choice. Reboot Steam Deck for changes to take effect.
fi

#################################################################################
################################ post install ###################################
#################################################################################

# create /tmp/1RefreshRateUnlocker and place the additional scripts in there
mkdir /tmp/1RefreshRateUnlocker &> /dev/null

# RefreshRateUnlocker.sh - script that gets called by refresh-rate-unlocker.service on startup
cat > /tmp/1RefreshRateUnlocker/RefreshRateUnlocker.sh << EOF
#!/bin/bash

RefreshRateUnlockerLog=/var/log/RefreshRateUnlocker.log

echo RefreshRateUnlocker > \$RefreshRateUnlockerLog
date >> \$RefreshRateUnlockerLog
cat /etc/os-release >> \$RefreshRateUnlockerLog

# check gamescope file if it needs to be patched
grep STEAM_DISPLAY_REFRESH_LIMITS=$Choice /bin/gamescope-session
if [ \$? -eq 0 ]
then	echo gamescope-session already patched, no action needed. >> \$RefreshRateUnlockerLog
else
	echo gamescope-session needs to be patched! >> \$RefreshRateUnlockerLog
	steamos-readonly disable >> \$RefreshRateUnlockerLog
	echo Backup existing gamescope-session. >> \$RefreshRateUnlockerLog
	cp /bin/gamescope-session /bin/gamescope-session.backup
	echo Patch the gamescope-session. >> \$RefreshRateUnlockerLog
	sed -i "s/STEAM_DISPLAY_REFRESH_LIMITS=40,60/STEAM_DISPLAY_REFRESH_LIMITS=$Choice/g" /bin/gamescope-session
	ls /bin/gamescope* >> \$RefreshRateUnlockerLog
	steamos-readonly enable
fi
EOF

# refresh-rate-unlocker.service - systemd service that calls RefreshRateUnlocker.sh on startup
cat > /tmp/1RefreshRateUnlocker/refresh-rate-unlocker.service << EOF

[Unit]
Description= Custom systemd service that unlocks custom refresh rates for gamescope-session.

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '/var/lib/1RefreshRateUnlocker/RefreshRateUnlocker.sh'

[Install]
WantedBy=multi-user.target
EOF

################################################################################
####################### Refresh Rate Unlocker Toolbox ##########################
################################################################################
cat > /tmp/1RefreshRateUnlocker/RefreshRateUnlocker-Toolbox.sh << EOF
#!/bin/bash
zenity --password --title "Password Authentication" | sudo -S ls &> /dev/null
if [ \$? -ne 0 ]
then
	echo sudo password is wrong! | \\
		zenity --text-info --title "Clover Toolbox" --width 400 --height 200
	exit
fi

while true
do
Choice=\$(zenity --width 750 --height 350 --list --radiolist --multiple \
	--title "Refresh Rate Unlocker  Toolbox - https://github.com/ryanrudolfoba/SteamDeck-RefreshRateUnlocker"\\
	--column "Select One" \\
	--column "Option" \\
	--column="Description - Read this carefully!"\\
	FALSE Status "Choose this to check the status of the service!"\\
	FALSE 20,60 "Set the refresh rate limit to 20Hz - 60Hz."\
	FALSE 30,60 "Set the refresh rate limit to 30Hz - 60Hz."\
	FALSE 20,70 "Set the refresh rate limit to 20Hz - 70Hz."\
	FALSE 30,70 "Set the refresh rate limit to 30Hz - 70Hz."\
	FALSE 40,70 "Set the refresh rate limit to 40Hz - 70Hz."\
	FALSE Uninstall "Choose this to uninstall and revert any changes made."\\
	TRUE EXIT "***** Exit the Clover Toolbox *****")

if [ \$? -eq 1 ] || [ "\$Choice" == "EXIT" ]
then
	echo User pressed CANCEL / EXIT.
	exit

elif [ "\$Choice" == "Status" ]
then
	zenity --warning --title "Refresh Rate Unlocker Toolbox" --text "\$(fold -w 120 -s /var/log/RefreshRateUnlocker.log)" --width 400 --height 600

elif [ "\$Choice" == "20,60" ] || [ "\$Choice" == "30,60" ] || [ "\$Choice" == "20,70" ] || [ "\$Choice" == "30,70" ] || [ "\$Choice" == "40,70" ]
then
	sudo steamos-readonly disable
	sudo sed -i "s/STEAM_DISPLAY_REFRESH_LIMITS=..,../STEAM_DISPLAY_REFRESH_LIMITS=\$Choice/g" /bin/gamescope-session
	sudo steamos-readonly enable
	grep STEAM_DISPLAY_REFRESH_LIMITS /bin/gamescope-session
	zenity --warning --title "Refresh Rate Unlocker Toolbox" \\
	--text "Refresh rate is now set to \$Choice. \nReboot for changes to take effect!" --width 400 --height 75

elif [ "\$Choice" == "Uninstall" ]
then
	# restore gamescope-session from backup if it exists
	sudo steamos-readonly disable
	sudo mv /bin/gamescope-session.backup /bin/gamescope-session

	# verify that gamescope-session is now using the default 40,60
	grep STEAM_DISPLAY_REFRESH_LIMITS=40,60 /bin/gamescope-session > /dev/null
	if [ \$? -ne 0 ]
	then	
		sudo sed -i "s/STEAM_DISPLAY_REFRESH_LIMITS=..,../STEAM_DISPLAY_REFRESH_LIMITS=40,60/g" /bin/gamescope-session
		echo gamescope-session is now using the default value 40,60.
        else
		echo Error: gamescope-session could not be reverted to the default value.
	fi
 	sudo steamos-readonly enable
 
	# delete systemd service
	sudo systemctl disable --now refresh-rate-unlocker.service
	sudo rm /etc/systemd/system/refresh-rate-unlocker.service
 	sudo systemctl daemon-reload

 	# delete /var/lib/1RefreshRateUnlocker/
 	sudo rm -rf /var/lib/1RefreshRateUnlocker/
	
	rm -rf ~/1RefreshRateUnlocker
	rm -rf ~/SteamDeck-RefreshRateUnlocker
 	rm -rf /tmp/1RefreshRateUnlocker/*
	rm ~/Desktop/RefreshRateUnlocker-Toolbox

	zenity --warning --title "Refresh Rate Unlocker Toolbox" --text "Uninstall complete! Reboot for changes to take effect!" --width 400 --height 75
	exit
fi
done
EOF

################################################################################
######################### continue with the install ############################
################################################################################
# Move files as necessary to the correct places
mv /tmp/1RefreshRateUnlocker/refresh-rate-unlocker.service /etc/systemd/system/refresh-rate-unlocker.service
mkdir /var/lib/1RefreshRateUnlocker/
mv /tmp/1RefreshRateUnlocker/* /var/lib/1RefreshRateUnlocker/
chmod +x /var/lib/1RefreshRateUnlocker/*.sh

# start the service
systemctl daemon-reload
systemctl enable --now refresh-rate-unlocker.service


# create desktop icon for Refresh Rate Unlocker Toolbox
ln -s /var/lib/1RefreshRateUnlocker/RefreshRateUnlocker-Toolbox.sh /home/deck/Desktop/RefreshRateUnlocker-Toolbox
echo -e "$RED"Desktop icon for Refresh Rate Unlocker Toolbox has been created!
