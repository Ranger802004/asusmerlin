# WAN Failover for ASUS Routers using Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 05/23/2022
# Version: v1.3.3

Install:
/usr/sbin/curl -s "https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh" -o "/jffs/scripts/wan-failover.sh" && chmod 755 /jffs/scripts/wan-failover.sh && sh /jffs/scripts/wan-failover.sh install

Update:
/usr/sbin/curl -s "https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh" -o "/jffs/scripts/wan-failover.sh" && chmod 755 /jffs/scripts/wan-failover.sh && sh /jffs/scripts/wan-failover.sh kill

v1.3.3 Notes - 05/23/2022
General:
- Log Cleaner sleeps if there are less than 1000 messages in the log.
- Optimized WAN Status
- Optimized WAN Disabled
- If the Target IP Address is the same IP as the Default Gateway, route will not be added.

WAN Monitor:
- Resolved an issue where there IP Route for the WAN Monitor would delete during a WAN interface restart, added a check in the Monitor to return to WAN Status if the route is not in the Route Table.

v1.3 Notes - 05/22/2022
General:
- If you are using a version prior to v1.3 of Wan-Failover, delete your configuration and install fresh using the provided installation command.
- During install the script will try and add the Cron Job line to Wan-Event during install and create Wan-Event if it does not exist.
- During install the script will verify that the following is enabled: Administration > System > JFFS custom scripts and configs
- If the ASUS Factory Dual WAN Watchdog is enabled, the script will go to Disabled Mode until it is turned off.
- Enhanced WAN Status Detection by checking for Real IP in NVRAM. This is to ensure script goes into disabled state if Both WAN links are disconnected.

Run Modes:
- Install Mode: This will install the script and configuration files necessary for it to run. Add the command argument "install" to use this mode.
- Uninstall Mode: This will uninstall the configuration files necessary to stop the script from running. Add the command argument "uninstall" to use this mode.
- Run Mode: This mode is for the script to run in the background via cron job. Add the command argument "run" to use this mode.
- Manual Mode: This will allow you to run the script in a command console. Add the command argument "manual" to use this mode.
- Monitor Mode: This will monitor the log file of the script. Add the command argument "monitor" to use this mode.
- Kill Mode: This will kill any running instances of the script. Add the command argument "kill" to use this mode.
- Cron Job Mode: This will create the Cron Jobs necessary for the script to run and also perform log cleaning. Add the command argument "logclean" to use this mode.
- Log Clean Mode: This will clean the log file leaving only the last 1000 messages. Add the command argument "logclean" to use this mode.

WAN IP Address Targets:
- The script will now attempt to create a route for each WAN IP Address Target if it does not exist, this will allow the ping monitor to work for both interfaces simultaneously.
- Test the IP Addresses you configure during install prior to installing to make sure that server allows ICMP Echo Requests "ping".
- Use Different IP Addresses for each interface

Configuration:
- User Set Variables that are created on install will be created under /jffs/configs/wan-failover.conf and used by the script for these custom variables.

v1.2 Notes - 05/21/2022:
- DNS Logic Update to account for missing variables.
- DNS Manual Settings are checked before Automatic ISP Settings.
- Check if wan-event script exists before calling it.
- Changed Switch WAN Until Loop to && instead of & for checking Primary WAN and Default Route.
- Will check WAN Status such as being in Cold Standby mode and if it is will restart interface before attempting to get Packet Loss in WAN Status.
- Added Log Maintainer to delete older records in the /tmp/ log file created.


