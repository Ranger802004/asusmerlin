# Domain VPN Routing for ASUS Routers using Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 10/02/2023
# Version: v2.1.0-beta3

Domain VPN Routing allows you to create policies to add domains and select which VPN interface you want them routed to, the script will query the Domains via cronjob and add the queried IPs to a Policy File that will create the routes necessary.

Requirements:
- ASUS Merlin Firmware v386.7
- JFFS custom scripts and configs Enabled
- OpenVPN

Installation Command:
/usr/sbin/curl -s "https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/domain_vpn_routing-beta.sh" -o "/jffs/scripts/domain_vpn_routing.sh" && chmod 755 /jffs/scripts/domain_vpn_routing.sh && sh /jffs/scripts/domain_vpn_routing.sh install

Update Command:
/jffs/scripts/domain_vpn_routing.sh update

Uninstallation Command:
/jffs/scripts/domain_vpn_routing.sh uninstall

Accessing Menu:
domain_vpn_routing

Run Modes:
- Menu Mode: SSH User Interface for Domain VPN Routing, access by executing script without any arguments.
- install: Install Domain VPN Routing and the configuration files necessary for it to run.
- createpolicy: Create a new policy.
- showpolicy: Show the policy specified or all policies. Use all as 2nd argument for All Policies.
- querypolicy: Query domains from a policy or all policies and create IP Routes necessary. Use all as 2nd argument for All Policies.
- adddomain: Add a domain to the policy specified.
- editpolicy: Modify an existing policy.
- update: Download and update to the latest version.
- cron: Create the Cron Jobs to automate Query Policy functionality.
- deletedomain: Delete a specified domain from a selected policy.
- deletepolicy: Delete a specified policy or all policies. Use all as 2nd argument for All Policies.
- deleteip: Delete a queried IP from a policy.
- kill: Kill any instances of the script.
- uninstall: Uninstall the configuration files necessary to stop the script from running.

Global Configuration Options (/jffs/configs/domain_vpn_routing/global.conf)
- DEVMODE: This defines if the Script is set to Developer Mode where updates will apply beta releases.  Default: Disabled
- CHECKNVRAM: This defines if the Script is set to perform NVRAM checks before peforming key functions.  Default: Disabled 
- PROCESSPRIORITY: This defines the process priority for WAN Failover on the system.  Default: Normal
- CHECKINTERVAL: This defines the policy check interval via cron job, value range is from 1 to 59 minutes. Default: 15 Minutes
- BOOTDELAYTIMER: This will delay execution until System Uptime reaches this time. Default: 0 Seconds
- OVPNC1FWMARK: This defines the FWMark value for OpenVPN Client 1. Default: 0x1000
- OVPNC1MASK: This defines the Mask value for OpenVPN Client 1. Default: 0x1000
- OVPNC2FWMARK: This defines the FWMark value for OpenVPN Client 2. Default: 0x2000
- OVPNC2MASK: This defines the Mask value for OpenVPN Client 2. Default: 0x2000
- OVPNC3FWMARK: This defines the FWMark value for OpenVPN Client 3. Default: 0x4000
- OVPNC3MASK: This defines the Mask value for OpenVPN Client 3. Default: 0x4000
- OVPNC4FWMARK: This defines the FWMark value for OpenVPN Client 4. Default: 0x7000
- OVPNC4MASK: This defines the Mask value for OpenVPN Client 4. Default: 0x7000
- OVPNC5FWMARK: This defines the FWMark value for OpenVPN Client 5. Default: 0x3000
- OVPNC5MASK: This defines the Mask value for OpenVPN Client 5. Default: 0x3000
- WGC1FWMARK: This defines the FWMark value for WireGuard Client 1. Default: 0x1100
- WGC1MASK: This defines the Mask value for WireGuard Client 1. Default: 0x1100
- WGC2FWMARK: This defines the FWMark value for WireGuard Client 2. Default: 0x2100
- WGC2MASK: This defines the Mask value for WireGuard Client 2. Default: 0x2100
- WGC3FWMARK: This defines the FWMark value for WireGuard Client 3. Default: 0x4100
- WGC3MASK: This defines the Mask value for WireGuard Client 3. Default: 0x4100
- WGC4FWMARK: This defines the FWMark value for WireGuard Client 4. Default: 0x7100
- WGC4MASK: This defines the Mask value for WireGuard Client 4. Default: 0x7100
- WGC5FWMARK: This defines the FWMark value for WireGuard Client 5. Default: 0x3100
- WGC5MASK: This defines the Mask value for WireGuard Client 5. Default: 0x3100

Creating a Policy:
Step 1: Create a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh createpolicy

Step 2: Select a name for the Policy (Case Sensitive).
	Example: Google

Step 3: Select an existing OpenVPN Interface.  Type the name of the interface as displayed.

Step 4: Select to enable or disable Verbose Logging for the Policy

Step 5: Select to enable or disable Private IP Addresses (This will allow or disallow Private IP Addresses from being added to the policy rules when queried).

Step 6: Policy is created, proceed to Section: Adding a Domain.

Adding a Domain:
Step 1: Add a domain to an existing policy by running the following command: /jffs/scripts/domain_vpn_routing.sh adddomain <Insert Domain>
	Example: /jffs/scripts/domain_vpn_routing.sh adddomain google.com

Step 2: Select a policy from the list provided by typing the name of the Policy (Case Sensitive).

Step 3: Domain is added to Policy, proceed to Section: Querying a Policy.

Querying a Policy:
- Query a Policy or All Policies by using the following command: /jffs/scripts/domain_vpn_routing.sh querypolicy <Insert Policy/all>
	Example: /jffs/scripts/domain_vpn_routing.sh querypolicy all
	Note: Cron Job is created to query all policies every 5 minutes.

Step 2: Querying Policy will add the IP Addresses associated with the domains in the Policy and create routes to the assigned Route Table for the OpenVPN Interface.

Show Policies:
- To show a Policy or All Policies (Name Only), type the following command: /jffs/scripts/domain_vpn_routing.sh showpolicy <Insert Policy/all>
	Example: /jffs/scripts/domain_vpn_routing.sh showpolicy all
	Note: When querying all policies, only the policy names will be displayed.  When selecting a specific policy, the Policy Name, Interface, and Domains added to the Policy will be displayed.

Editing a Policy:
Step 1: Edit a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh editpolicy <Insert Name>

Step 2: Select the existing or new interface

Step 3: Select whether to enable Verbose Logging for the Policy.

Step 4: Select to enable or disable Private IP Addresses (This will allow or disallow Private IP Addresses from being added to the policy rules when queried).

Step 5: Allow the routes for the Policy to be recreated.

Deleting a Policy:
- Delete a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh deletepolicy <Insert Name/all>
	Example: /jffs/scripts/domain_vpn_routing.sh deletepolicy all
	Note: When selecting all policies, all policies will be deleted as well as domains and routes that are created.

Deleting a Domain:
Step 1: Delete a domain from a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh deletedomain <Insert Domain>
	Example: /jffs/scripts/domain_vpn_routing.sh deletedomain google.com

Step 2: Type the Policy (Case Sensitive) that the Domain is added to and select Enter.
	Example: Google

Considerations:
- If a domain is accesssed while the IP has not yet been added to the policy will not take effect until it is added and a route is created.  
  ***WARNING*** Proper syntax must be used or script will break.  The IP can be manually added by opening the Policy domaintoIP File under /jffs/configs/domain_vpn_routing/.  Add using the following syntax Domain>>IP
  
 - To bulk add domains, you can manually add them to the Policy domainlist File under /jffs/configs/domain_vpn_routing/
  ***WARNING*** Only add 1 domain per line and make sure no extra characters are added.

Release Notes:
v2.1.0-beta3 - 10/02/2023
Enhancements:
- DNSMasq log is now utilized if enabled to query for domain records to route.  The log path will be captured from the DNSMasq Configuration.
- IPSets, IPTables Rules, and IP Rules using FWMarks have been implemented to reduce the amount of routes / rules that are created for policies.
- Added Check Interval configuration options to Configuration Menu to modify the cron job schedule between 1 - 59 minutes.  Default: 15 minutes
- The current interface for a Policy will be displayed when in the Edit Policy configuration menu.
- Added default FWMark and Mask values for OpenVPN and WireGuard clients that can be changed in the configuration menu.  Reboot required for changes.
- Log priority values added (Critical, Error, Warning, Notice, Informational, Debug)
- Additional logging messages have been added.
- Added Boot Delay Timer configuration setting to delay execution to wait and allow VPN tunnels to initalize during start up before querying for policies. Default: 0 Seconds

Fixes:
- Fixed issue where adding a domain with the same partial name as an existing in a policy prevented it from being added.
- Fixed an issue that causes the update function to hang when complete as well as when terminating Domain VPN Routing.

v2.0.1 - 09/24/2023
Enhancements:
- Minor optimizations for performance
- The error log will explicitly state if an IPv6 route already exists when trying to create routes.
- Added NVRAM Checks and Process Priority configuration options to Configuration Menu.
- Major performance optimization for NVRAM Check function.

Fixes:
- Corrected issue where update process was terminating its own process during update.
- Corrected issue where IPv6 routes were attempting to be created when IPv6 Service is enabled but IPv6 wasn't available.
- Fixed issue where Dual WAN properties were not being accepted as null in a Single WAN configuration.
- Fixed issue where queried IPv6 addresses don't include complete prefix and cause an error when creating the route for them.

v2.0.0 - 07/06/2023
Enhancements:
- SSH UI
- Interfaces will now list the friendly name of the interface instead of the tunnel / physical interface name.
- Querying policies will take low CPU priority automatically.
- Cron Jobs will now be added to wan-event.
- NVRAM Checks have been integrated to prevent lock ups.
- Domain VPN Routing will now be called from wan-event in addition to openvpn-event.
- Global Configuration Menu.
- Developer Mode available for testing beta releases.
- Enhanced update function.
- If the IPV6 Service is disabled, IPV6 IP Addresses will not be queried or added to policies.  In addition, existing IPv6 IP Addresses in policy files will be removed for optimization.
- Added WireGuard VPN Clients for support
- Changed dark blue text prompts to light cyan for easier reading.
- NVRAM variables are now synchronized with error checking during initial load of Domain VPN Routing in order to reduce nvram calls and reduce potential failures during operation.
- General optimization.

Fixes:
- Visual errors when domain fails to perform DNS lookup.
- Visual bugs when Query Policy was executing domain queries.
- Fixed bug introducted in beta for deleting old routes when WAN interface was selected.
- False positive errors stating IP routes failed to create.
- Fixed issue with Edit Policy Mode erroring out due to unset parameters.
- False positive errors for IP rules / routes being created.

v1.4 - 03/13/2023
Enhancements:
- General optimization
- Added the ability to select WAN0 or WAN1 interfaces for a policy
- Added Alias as domain_vpn_routing (For initial load on terminals open during upgrade, execute ". /jffs/configs/profile.add" to load new alias)
- Query Policy Mode is ran in low priority

Fixes:
- Fixed issue in Routing Directory referencing WANPREFIX and TABLE variables accidentally
- Corrected issue where WAN Interface wouldn't show up if not using Dual WAN Mode

v1.3 - 07/24/2022
- Added Delete IP Function, this is to delete IPs not desired to be routed by the script.  ***This will not prevent the IP from being queried again***
- Created routingdirector function to handle all functions determination of creating routes / IP rules for queried IPs.
- Added configuration option for including or excluding Private IP Addresses per Policy.
- If VPN Director is enabled for an OpenVPN Interface, IP Rules will be created for queried IPv4 Addresses.
- Corrected spelling error for "adddomain" in script menu.
- Decreased Cron Job frequency to every 15 minutes.
- If a Domain is not Specified when using "adddomain", an error will be generated.
- Cron Job will execute "querypolicy all" if system up time is less than 15 minutes.

v1.1 - 06/26/2022
- Added logic during install to create openvpn-event if it doesn't exist.
- Added warning message when executing querypolicy if it is already currently running.
- Support for ASUS Merlin 386.7

v1.0 - 06/17/2022
- Added option for enabling or disabling Verbose Logging for each Policy, this allows messages such as Querying Policy, etc to not be logged in System Log.
- Added option to edit an existing policy's interface or verbose logging.
- If VPN Director is enabled, routes will now be added to the main routing table.
- Added option for Query Policy All to execute during OpenVPN Events. (If Option is missing run install command again)

v0.9-beta - 06/10/2022
- Initial Beta Release
