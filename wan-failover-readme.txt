# WAN Failover for ASUS Routers using Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 06/29/2022
# Version: v1.5.4

WAN Failover is designed to replace the factory ASUS WAN Failover functionality, this script will monitor the WAN Interfaces using a Target IP Address and pinging these targets to determine when a failure occurs.  When a failure is detected, the script will switch to the Secondary WAN interface automatically and then monitor for failback conditions.  When the Primary WAN interface connection is restored based on the Target IP Address, the script will perform the failback condition and switch back to Primary WAN.

Requirements:
- ASUS Merlin Firmware v386.7
- JFFS custom scripts and configs Enabled
- Dual WAN Enabled
- ASUS Factory Failover Disabled (Network Monitoring Options, Allow Failback Option under WAN > Dual WAN)

Installation:
Install Command to run to install script:
/usr/sbin/curl -s "https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh" -o "/jffs/scripts/wan-failover.sh" && chmod 755 /jffs/scripts/wan-failover.sh && sh /jffs/scripts/wan-failover.sh install

Updating:
Update Command (Updating from v1.3.5 or older):
/usr/sbin/curl -s "https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh" -o "/jffs/scripts/wan-failover.sh" && chmod 755 /jffs/scripts/wan-failover.sh && sh /jffs/scripts/wan-failover.sh kill

Update Command (Updating from v1.3.7 or newer)
/jffs/scripts/wan-failover.sh update

Uninstallation (v1.3 or newer):
/jffs/scripts/wan-failover.sh uninstall

Configuration: During installation or reconfiguration, the following settings are configured:
-	WAN0 Target:  This is the target IP address for WAN0, the script will monitor this IP via ICMP Echo Requests “ping” over the WAN0 interface.  Verify the target IP address is a valid server for ICMP Echo Requests prior to installation or configuration.  It is recommended to use different Target IP Addresses for each WAN interface.  Example: 8.8.8.8
-	WAN1 Target:  This is the target IP address for WAN1, the script will monitor this IP via ICMP Echo Requests “ping” over the WAN1 interface.  Verify the target IP address is a valid server for ICMP Echo Requests prior to installation or configuration.  It is recommended to use different Target IP Addresses for each WAN interface.  Example: 8.8.4.4
-	Ping Count:  This is how many consecutive times a ping must fail before a WAN connection is considered disconnected.   
-	Ping Timeout:  This is how many seconds a single ping attempt will execute before timing out from no ICMP Echo Reply “ping”.  If using an ISP with high latency such as satellite internet services, consider setting this to a higher value such as 3 seconds or higher.
-	WAN Disabled Timer:  This is how many seconds the script pauses and checks again if Dual WAN, Failover Mode, or WAN links are disabled/disconnected.
- Boot Delay Timer: This is how many seconds System Uptime has to be before script begins checking WAN Status.
-	QoS Settings are configured for each WAN interface because both interfaces may not have the same bandwidth (download/upload speeds).  The script will automatically change these settings for each interface as they become the active WAN interface.  If QoS is disabled or QoS Automatic Settings are being used, these settings will not be applied.
  o	WAN0 QoS Download Bandwidth:  Value is in Mbps
  o	WAN1 QoS Download Bandwidth: Value is in Mbps
  o	WAN0 QoS Upload Bandwidth: Value is in Mbps
  o	WAN1 QoS Upload Bandwidth: Value is in Mbps
  o	WAN0 QoS Packet Overhead:  Value is in Bytes
  o	WAN1 QoS Packet Overhead: Value is in Bytes
  o	WAN0 QoS ATM:  This will enable or disable Asynchronous Transfer Mode (ATM) for WAN0, research this technology to verify it is not required for your ISP.  In most      use cases, this setting is Disabled.
  o	WAN1 QoS ATM:  This will enable or disable Asynchronous Transfer Mode (ATM) for WAN1, research this technology to verify it is not required for your ISP.  In most      use cases, this setting is Disabled.
-	Packet Loss Logging:  This will log packet loss detections that are less than 100% packet loss but more than 0% packet loss.  These events are not enough to trigger a WAN Failover/Failback condition but may be informal data as to the performance of a WAN interface.  If the Ping Timeout setting is too low (1-2 seconds) combined with a high latency WAN interface such as satellite internet services, this logging can become excessive with the described configuration.

Optional Configuration:
- To enable or disable email notifications, pass the command arguments "email enable" or "email disable", default mode is Enabled.  Example: "/jffs/scripts/wan-failover.sh email enable"  ***Email Notifications work with amtm or AIProtection Alert Preferences****

Run Modes (v1.3 or newer):
- Install Mode: This will install the script and configuration files necessary for it to run. Add the command argument "install" to use this mode.
- Uninstall Mode: This will uninstall the configuration files necessary to stop the script from running. Add the command argument "uninstall" to use this mode.
- Run Mode: This mode is for the script to run in the background via cron job. Add the command argument "run" to use this mode.
- Update Mode: This mode will check to see if there is an update available from the GitHub Repository and update.  (Must be on v1.3.7 or newer)
- Configuration Mode: This will allow reconfiguration of WAN Failover to update or change settings. Add the command argument "config" to use this mode (Must be on v1.4.2 or newer)
- Manual Mode: This will allow you to run the script in a command console. Add the command argument "manual" to use this mode.
- Switch WAN Mode: This will manually switch the Primary WAN. Add the command argument "switchwan" to use this mode.
- Monitor Mode: This will monitor the log file of the script. Add the command argument "monitor" to use this mode.
- Kill Mode: This will kill any running instances of the script. Add the command argument "kill" to use this mode.
- Cron Job Mode: This will create the Cron Jobs necessary for the script to run and also perform log cleaning. Add the command argument "logclean" to use this mode.

Release Notes:
v1.5.4 - 06/29/2022
- Added delay in WAN Status for when NVRAM is inaccessible.
- Added support for Load Balance Mode
- Changed from using NVRAM Variables: wan0_ifname & wan1_ifname to using NVRAM Variables: wan0_gw_ifname & wan1_gw_ifname.
- Improved DNS Settings detection during Switch WAN function.
- Improved Switch WAN Logic to verify NVRAM Variables: wan_gateway, wan_gw_ifname, and wan_ipaddr are properly updated.
- Added warning message when attempting to execute Run or Manual Mode if the script is already running.
- Support for ASUS Merlin Firmware 386.7
- Added Boot Delay Timer
- Target IP Routes are now created using IP Rules from Local Router to Routing Table 100 (WAN0) and Routing Table 200 (WAN1) so client devices on the network do not use the created routes.
- Moved Email Variables from Global Variables so Email Configuration is checked every time a switch occurs instead of when script restarts.
- Email Notification will not be sent if System Uptime is less than 60 seconds + Boot Delay Timer if configured.  This is created because the firmware will start up with WAN1 as Active Connection and switch to WAN0 with the script.
- Added integration for amtm email notifications, if amtm is properly configured, it will be used for Email Notifications, otherwise it will attempt to use AIProtection Alerts.

v1.4.6 - 06/06/2022
- Fixed issue where if Gateway IP Address changed, script would not return to WAN Status to check if route is created for the monitoring target.
- Created an enable / disable function for email (Instructions added to Configuration of Readme).
- Optimized logic for handling no arguments being inputted from the console.
- Configuration options will not allow WAN0 and WAN1 Target IP Addresses to be the same or match their respective Gateway IP Address.

v1.4.3 - 05/28/2022
- Fixed issue where Installation Mode would not set WAN1 Target IP Address.
- Fixed issue where Packet Loss Logging was not properly logging if enabled.
- During WAN Status Check, the log to message "***Verify (Target IP) is a valid server for ICMP Echo Requests***" will only occur if there is 100% loss on the initial check.

v1.4.2 - 05/28/2022
- Added Configuration Mode option to reconfigure configuration file, use argument "config".
- During Installation Mode or Configuration Mode, QoS Download/Upload Bandwidth inputs are now in Mbps instead of Kbps.  The script will automatically convert these into Kbps inside the configuration file.
- Added option to configuration for Packet Loss alerts under 100% loss to not be logged, if upgrading from v1.4.1 or older, run Configuration Mode to disable this new option.
- Added checks for configuration input to not allow invalid input(s).

v1.4.1 - 05/26/2022
- Email Notifications will generate if you have alerts configured under AiProtection > Alert Preferences.
- Redirected all logs to System Log, events will now show up under System Log tab in Web GUI as well as Monitor Mode.
- Monitor mode will now filter logs from System Log
- Log Cleanup Mode has been deprecated.  This will now cleanup the Log Clean Mode cron job and delete the old proprietary log file.
- Corrected issue where Monitor Mode would still run in background after it has been exited out.
- Corrected description for Cron Job mode where argument was stated as "cronjob" instead of "cron"
- Replaced ScriptStatus function with file lock.

v1.3.7 - 05/25/2022
General
- Tied system logs into built in logger method.
- Added Update Mode using argument "update", this will update the script from the GitHub Repository. (If updating from v1.3.5 or older, use the update command from the readme to update).

v1.3.5 - 05/24/2022
General:
- Renamed WAN0Monitor to WAN0 Failover Monitor
- Renamed WAN0RestoreMonitor to WAN0 Failback Monitor
- Optimized WAN Disabled Logic.
- During WAN Status Check, it will look for 0.0.0.0 as a WAN interface's Gateway or IP Address and mark it as Disconnected.
- Updated logging Verbiage for Switch WAN.
- Moved DNS Resolv File Variable to Global Variables
- Added key events to go to System Log that can be displayed in the ASUS System Log Web GUI.  This includes Failures, Primary WAN switching, and Packet Loss detection.

Monitor Mode:
- Monitor Mode will now not be killed by Kill Mode or Log Clean Mode

v1.3.3 - 05/23/2022
General:
- Log Cleaner sleeps if there are less than 1000 messages in the log.
- Optimized WAN Status
- Optimized WAN Disabled
- If the Target IP Address is the same IP as the Default Gateway, route will not be added.

WAN Monitor:
- Resolved an issue where there IP Route for the WAN Monitor would delete during a WAN interface restart, added a check in the Monitor to return to WAN Status if the route is not in the Route Table.

Run Modes:
- Added a new run mode "switchwan", this will manually change the Primary WAN.

v1.3 - 05/22/2022
General:
- If you are using a version prior to v1.3 of Wan-Failover, delete your configuration and install fresh using the provided installation command.
- During install the script will try and add the Cron Job line to Wan-Event during install and create Wan-Event if it does not exist.
- During install the script will verify that the following is enabled: Administration > System > JFFS custom scripts and configs
- If the ASUS Factory Dual WAN Watchdog is enabled, the script will go to Disabled Mode until it is turned off.
- Enhanced WAN Status Detection by checking for Real IP in NVRAM. This is to ensure script goes into disabled state if Both WAN links are disconnected.
- Intergrated Run Modes into the script

WAN IP Address Targets:
- The script will now attempt to create a route for each WAN IP Address Target if it does not exist, this will allow the ping monitor to work for both interfaces simultaneously.
- Test the IP Addresses you configure during install prior to installing to make sure that server allows ICMP Echo Requests "ping".
- Use Different IP Addresses for each interface

Configuration:
- User Set Variables that are created on install will be created under /jffs/configs/wan-failover.conf and used by the script for these custom variables.

v1.2 - 05/21/2022:
- DNS Logic Update to account for missing variables.
- DNS Manual Settings are checked before Automatic ISP Settings.
- Check if wan-event script exists before calling it.
- Changed Switch WAN Until Loop to && instead of & for checking Primary WAN and Default Route.
- Will check WAN Status such as being in Cold Standby mode and if it is will restart interface before attempting to get Packet Loss in WAN Status.
- Added Log Maintainer to delete older records in the /tmp/ log file created.
