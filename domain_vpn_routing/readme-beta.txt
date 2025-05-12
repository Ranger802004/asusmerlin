# Domain VPN Routing for ASUS Routers using Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 05/12/2025
# Version: v3.2.0-beta1

Domain VPN Routing allows you to create policies to add domains and select which VPN interface you want them routed to, the script will query the Domains via cronjob and add the queried IPs to a Policy File that will create the routes necessary.

Requirements:
- ASUS Merlin Firmware v386.7 or newer.
- JFFS custom scripts and configs enabled
- OpenVPN or WireGuard clients configured.
- (Optional) Entware installed.
- (Optional) Grep installed via Entware, this is required for ASN querying.  It also allows for faster processing of queried policies.
- (Optional) Dig installed via Entware, this allows more optimized DNS querying as well as support for adding CNAMES to policies.  Dig will also allow the capability to configure DNS-over-TLS on an interface.
- (Optional) Jq installed via Entware, this is required for ASN querying and AdGuardHome log querying.
- (Optional) Python3 installed via Entware, this is required for AdGuardHome log querying.

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
- addasn: Add a new ASN.
- showpolicy: Show the policy specified or all policies. Use all as 2nd argument for All Policies.
- showasn: Show a specified ASN or all ASNs. Use all as 2nd argument for All ASNs.
- querypolicy: Query domains from a policy or all policies and create IP Routes necessary. Use all as 2nd argument for All Policies.
- queryasn: Query a specified ASN or all ASNs and create IP Routes necessary. Use all as 2nd argument for All ASNs.
- restorepolicy: Perform a restore of an existing policy. Use all as 2nd argument for All Policies.
- adddomain: Add a domain to the policy specified.
- editpolicy: Modify an existing policy.
- editasn: Modify an existing ASN.
- update: Download and update to the latest version.
- cron: Create the Cron Jobs to automate Query Policy functionality.
- deletedomain: Delete a specified domain from a selected policy.
- deletepolicy: Delete a specified policy or all policies. Use all as 2nd argument for All Policies.
- deleteasn: Delete a specified ASN or all ASNs. Use all as 2nd argument for All ASNs.
- deleteip: Delete a queried IP from a policy.
- kill: Kill any instances of the script.
- uninstall: Uninstall the configuration files necessary to stop the script from running.
- config: Configuration menu to change global configuration options.
- resetconfig: Will reset the global configuration of Domain VPN Routing to defaults.

Global Configuration Options (/jffs/configs/domain_vpn_routing/global.conf)
- ENABLE: This defines if the Script is enabled for execution. Default: Enabled
- DEVMODE: This defines if the Script is set to Developer Mode where updates will apply beta releases.  Default: Disabled
- CHECKNVRAM: This defines if the Script is set to perform NVRAM checks before peforming key functions.  Default: Disabled 
- PROCESSPRIORITY: This defines the process priority for Domain VPN Routing on the system.  Default: Normal
- CHECKINTERVAL: This defines the policy check interval via cron job, value range is from 1 to 59 minutes. Default: 15 Minutes
- BOOTDELAYTIMER: This will delay execution until System Uptime reaches this time. Default: 0 Seconds
- FIREWALLRESTORE: This will execute the restorepolicy mode during a firewall restart event.  Default: Disabled
- QUERYADGUARDHOMELOG: This defines if the Script queries the AdGuardHome log if it is enabled.  Default: Disabled
- ASNCACHE: This defines if Domain VPN Routing caches ASN IP subnets queried from API. Default: Disabled
- OVPNC1FWMARK: This defines the FWMark value for OpenVPN Client 1. Default: 0x1000
- OVPNC1MASK: This defines the Mask value for OpenVPN Client 1. Default: 0xf000
- OVPNC2FWMARK: This defines the FWMark value for OpenVPN Client 2. Default: 0x2000
- OVPNC2MASK: This defines the Mask value for OpenVPN Client 2. Default: 0xf000
- OVPNC3FWMARK: This defines the FWMark value for OpenVPN Client 3. Default: 0x4000
- OVPNC3MASK: This defines the Mask value for OpenVPN Client 3. Default: 0xf000
- OVPNC4FWMARK: This defines the FWMark value for OpenVPN Client 4. Default: 0x7000
- OVPNC4MASK: This defines the Mask value for OpenVPN Client 4. Default: 0xf000
- OVPNC5FWMARK: This defines the FWMark value for OpenVPN Client 5. Default: 0x3000
- OVPNC5MASK: This defines the Mask value for OpenVPN Client 5. Default: 0xf000
- WGC1FWMARK: This defines the FWMark value for WireGuard Client 1. Default: 0xa000
- WGC1MASK: This defines the Mask value for WireGuard Client 1. Default: 0xf000
- WGC2FWMARK: This defines the FWMark value for WireGuard Client 2. Default: 0xb000
- WGC2MASK: This defines the Mask value for WireGuard Client 2. Default: 0xf000
- WGC3FWMARK: This defines the FWMark value for WireGuard Client 3. Default: 0xc000
- WGC3MASK: This defines the Mask value for WireGuard Client 3. Default: 0xf000
- WGC4FWMARK: This defines the FWMark value for WireGuard Client 4. Default: 0xd000
- WGC4MASK: This defines the Mask value for WireGuard Client 4. Default: 0xf000
- WGC5FWMARK: This defines the FWMark value for WireGuard Client 5. Default: 0xe000
- WGC5MASK: This defines the Mask value for WireGuard Client 5. Default: 0xf000
- OVPNC1DNSSERVER: This defines the DNS server override for OpenVPN Client 1.  Default: N/A
- OVPNC1DOT: This defines if the DNS Server configured for OpenVPN Client 1 will use DNS-over-TLS. Default: Disabled
- OVPNC2DNSSERVER: This defines the DNS server override for OpenVPN Client 2.  Default: N/A
- OVPNC2DOT: This defines if the DNS Server configured for OpenVPN Client 2 will use DNS-over-TLS. Default: Disabled
- OVPNC3DNSSERVER: This defines the DNS server override for OpenVPN Client 3.  Default: N/A
- OVPNC3DOT: This defines if the DNS Server configured for OpenVPN Client 3 will use DNS-over-TLS. Default: Disabled
- OVPNC4DNSSERVER: This defines the DNS server override for OpenVPN Client 4.  Default: N/A
- OVPNC4DOT: This defines if the DNS Server configured for OpenVPN Client 4 will use DNS-over-TLS. Default: Disabled
- OVPNC5DNSSERVER: This defines the DNS server override for OpenVPN Client 5.  Default: N/A
- OVPNC5DOT: This defines if the DNS Server configured for OpenVPN Client 5 will use DNS-over-TLS. Default: Disabled
- WGC1DNSSERVER: This defines the DNS server override for WireGuard Client 1.  Default: N/A
- WGC1DOT: This defines if the DNS Server configured for WireGuard Client 1 will use DNS-over-TLS. Default: Disabled
- WGC2DNSSERVER: This defines the DNS server override for WireGuard Client 2.  Default: N/A
- WGC2DOT: This defines if the DNS Server configured for WireGuard Client 2 will use DNS-over-TLS. Default: Disabled
- WGC3DNSSERVER: This defines the DNS server override for WireGuard Client 3.  Default: N/A
- WGC3DOT: This defines if the DNS Server configured for WireGuard Client 3 will use DNS-over-TLS. Default: Disabled
- WGC4DNSSERVER: This defines the DNS server override for WireGuard Client 4.  Default: N/A
- WGC4DOT: This defines if the DNS Server configured for WireGuard Client 4 will use DNS-over-TLS. Default: Disabled
- WGC5DNSSERVER: This defines the DNS server override for WireGuard Client 5.  Default: N/A
- WGC5DOT: This defines if the DNS Server configured for WireGuard Client 5 will use DNS-over-TLS. Default: Disabled
- WANDNSSERVER: This defines the DNS server override for WAN (Active WAN in Dual WAN Mode).  Default: N/A
- WANDOT: This defines if the DNS Server configured for WAN will use DNS-over-TLS. Default: Disabled
- WAN0DNSSERVER: This defines the DNS server override for WAN0 (Dual WAN Mode).  Default: N/A
- WAN0DOT: This defines if the DNS Server configured for WAN0 will use DNS-over-TLS. Default: Disabled
- WAN1DNSSERVER: This defines the DNS server override for WAN1 (Dual WAN Mode).  Default: N/A
- WAN1DOT: This defines if the DNS Server configured for WAN1 will use DNS-over-TLS. Default: Disabled
- OVPNC1PRIORITY: This defines the priority value for the OpenVPN Client 1. Default: 1000
- OVPNC2PRIORITY: This defines the priority value for the OpenVPN Client 2. Default: 2000
- OVPNC3PRIORITY: This defines the priority value for the OpenVPN Client 3. Default: 3000
- OVPNC4PRIORITY: This defines the priority value for the OpenVPN Client 4. Default: 4000
- OVPNC5PRIORITY: This defines the priority value for the OpenVPN Client 5. Default: 5000
- WGC1PRIORITY: This defines the priority value for the WireGuard Client 1. Default: 6000
- WGC2PRIORITY: This defines the priority value for the WireGuard Client 2. Default: 7000
- WGC3PRIORITY: This defines the priority value for the WireGuard Client 3. Default: 8000
- WGC4PRIORITY: This defines the priority value for the WireGuard Client 4. Default: 9000
- WGC5PRIORITY: This defines the priority value for the WireGuard Client 5. Default: 100000
- WANPRIORITY: This defines the priority value for the Active WAN. Default: 150
- WAN0PRIORITY: This defines the priority value for WAN0. Default: 150
- WAN1PRIORITY: This defines the priority value for WAN1. Default: 150

Creating a Policy:
Step 1: Create a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh createpolicy

Step 2: Select a name for the Policy (Case Sensitive).
	Example: Google

Step 3: Select an existing Interface.  Type the name of the interface as displayed.

Step 4: Select to enable or disable Verbose Logging for the Policy

Step 5: Select to enable or disable Private IP Addresses (This will allow or disallow Private IP Addresses from being added to the policy rules when queried).

Step 6. Select to enable to add CNAMES (This will allow CNAMES to be added to the policy domain list automatically during query execution).

Step 7: Policy is created, proceed to Section: Adding a Domain.

Adding a Domain:
Step 1: Add a domain to an existing policy by running the following command: /jffs/scripts/domain_vpn_routing.sh adddomain <Insert Domain>
	Example: /jffs/scripts/domain_vpn_routing.sh adddomain google.com

Step 2: Select a policy from the list provided by typing the name of the Policy (Case Sensitive).

Step 3: Domain is added to Policy, proceed to Section: Querying a Policy.

Bulk add Domains:
Step 1: Locate the policy domain list file under /jffs/configs/domain_vpn_routing/.  (Example: /jffs/config/domain_vpn_routing/policy_Example_domainlist)

Step 2: Add new domains (one per line) to the file.  ***Make sure to leave a blank line at the end of the file***

Step 3: Save the file.

Adding an ASN:
Step 1: Add a domain to an existing policy by running the following command: /jffs/scripts/domain_vpn_routing.sh addasn <Insert ASN>
	Example: /jffs/scripts/domain_vpn_routing.sh addasn AS15169

Step 2: Select an existing Interface.  Type the name of the interface as displayed.

Step 3: ASN has been added and will start synchronizing IP Subnets belonging to the ASN.

Querying a Policy:
- Query a Policy or All Policies by using the following command: /jffs/scripts/domain_vpn_routing.sh querypolicy <Insert Policy/all>
	Example: /jffs/scripts/domain_vpn_routing.sh querypolicy all
	Note: Cron Job is created to query all policies every 5 minutes (Adjustable in Configuration).

Step 2: Querying a Policy will add the IP Addresses associated with the domains in the Policy and create routes to the assigned Route Table for the Interface.

Querying an ASN:
- Query an ASN or All ASNs by using the following command: /jffs/scripts/domain_vpn_routing.sh queryasn <Insert ASN/all>
	Example: /jffs/scripts/domain_vpn_routing.sh queryasn all
	Note: Cron Job is created to query all policies every 5 minutes (Adjustable in Configuration).

Step 2: Querying an ASN will add the IP Addresses associated with the ASN and create routes to the assigned Route Table for the Interface.

Show Policies:
- To show a Policy or All Policies (Name Only), type the following command: /jffs/scripts/domain_vpn_routing.sh showpolicy <Insert Policy/all>
	Example: /jffs/scripts/domain_vpn_routing.sh showpolicy all
	Note: When querying all policies, only the policy names will be displayed.  When selecting a specific policy, the Policy Name, Interface, and Domains added to the Policy will be displayed.
	
Show ASNs:
- To show an ASN or All ASNs (Name Only), type the following command: /jffs/scripts/domain_vpn_routing.sh showasn <Insert Policy/all>
	Example: /jffs/scripts/domain_vpn_routing.sh showasn all
	Note: When querying all ASNs, only the ASN names will be displayed.  When selecting a specific ASN, the ASN Name, Interface, and Status will be displayed.

Editing a Policy:
Step 1: Edit a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh editpolicy <Insert Name>

Step 2: Select the existing or new interface

Step 3: Select whether to enable Verbose Logging for the Policy.

Step 4: Select to enable or disable Private IP Addresses (This will allow or disallow Private IP Addresses from being added to the policy rules when queried).

Step 5. Select to enable to add CNAMES (This will allow CNAMES to be added to the policy domain list automatically during query execution).

Step 6: Allow the routes for the Policy to be recreated.

Editing an ASN:
Step 1: Edit an ASN by running the following command: /jffs/scripts/domain_vpn_routing.sh editasn <Insert Name>

Step 2: Select the existing or new interface

Step 3: Allow the routes for the Policy to be recreated.

Deleting a Policy:
- Delete a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh deletepolicy <Insert Name/all>
	Example: /jffs/scripts/domain_vpn_routing.sh deletepolicy all
	Note: When selecting all policies, all policies will be deleted as well as domains and routes that are created.
	
Deleting an ASN:
- Delete a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh deleteasn <Insert Name/all>
	Example: /jffs/scripts/domain_vpn_routing.sh deleteasn all
	Note: When selecting all ASNs, all ASNs will be deleted as well as routes that are created.

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

- Enabling AdGuardHome log querying can take a long time to process if the AdGuardHome log file is large.  The log file rotation interval can be lowered within AdGuardHome to reduce the size of the log file. 

Release Notes:
v3.2.0-beta1 - 05/12/2025
Enhancements:
- Added custom priority settings for interfaces that can be modified using the configuration menu.
- Enhance Query ASN logic to handle larger ASNs and optimize query time.  This requires grep to be installed from Entware.
- Querying policies now can use grep from Entware to efficiently process new IP addresses.
- Enhanced interface state detection logic.
- Showing policies now displays the associated interfaces and the connected state status.
- Minor optimization and performance enhancements.

Fixes:
- Querying policies will now properly delete temporary files generated under /tmp.
- Fixed UI bugs not allowing return in certain menus.
- Fixed configuration menu bug that was not showing Dual WAN DNS Settings when router was configured for Dual WAN.


v3.1.1 - 04/29/2025
Enhancements:
- If DNS-over-TLS is enabled and servers are configured on the system DNS-over-TLS DNS server list, dig will configure use for DNS-over-TLS by randomly selecting a DNS-over-TLS DNS server.  
	- Python3 and dig are required to be installed for this functionality.
	- An existing DNS configuration for the interface in Domain VPN Routing will override this functionality.
- Added debug logging for DNS-over-TLS configuration during querypolicy function execution.

Fixes:
- Fixed an issue with IPv4 unreachable rules being created for VPN interfaces due to a missing default route for the VPN routing table.
- Fixed an issue where restoreasncache was executing when restoring an individual policy, this will still execute when restoring all policies.
- Fixed issues with erroneous data being ingested by dig.
- Fixed an issue with dig applying DNS Server configuration incorrectly and causing unreturned data from queries.
- Minor fixes and optimizations

v3.1.0 - 04/12/2025
Enhancements:
- Added functionality to cache ASN IP Subnets for faster restoration from reboot or service restart.  This can be enabled or disabled via the ASNCACHE configuration option.  Default: Disabled
- ASN queries will now check existing IPSets for IP Subnets that are no longer applicable to the ASN and remove them.
- New configuration options to enable DNS-over-TLS for an interface if a custom DNS Server is configured for it, the options in the configuration menu will become displayed when a DNS Server is configured.  DoT requires dig to be installed to function properly.

Fixes:
- Fixed an issue when Domain VPN Routing is getting system parameters it was not applying the boot delay timer configuration.
- Fixed an issue where dig,jq,python3 packages were being checked before Entware was mounted.  Will now continue to check if Entware is mounted if Entware is detected as being installed until it times out after 30 checks.

v3.0.6 - 03/30/2025
Fixes:
- Fixed an issue causing errors during installation when the firewall-start script does not exist and the Firewall Restore setting is disabled.

v3.0.5 - 02/08/2025
Fixes:
- Fixed an issue where comments for IPSets were greater than 255 and causing the IP Addresses to not be added.
- Fixed an issue for errors being generated from null data being returned from AdGuardHome log parsing and ASN queries.
- Fixed other minor issues

v3.0.4 - 11/27/2024
Fixes:
- Fixed an issue that would add erroneous CNAME values into a policy domain list when dig was being used to lookup CNAMES.
- Fixed an issue when using the deleteip function to delete an IP address.

v3.0.3 - 11/08/2024
Fixes:
- Fixed an issue with new installations of Domain VPN Routing.

v3.0.2 - 11/05/2024
Enhancements:
- Added functionality to query the AdGuardHome log.  This can be enabled or disabled via the QUERYADGUARDHOMELOG configuration option.
- Created option to enable/disable Domain VPN Routing under configuration menu.
- During uninstallation, a prompt has been added to ask to back up the configuration.  When reinstalling Domain VPN Routing a backup file will be checked for existence and prompted to restore configuration.
- Removed log message regarding No ASNs being detected if queryasn function is being executed by querypolicy for all policies.
- Enhanced prompts in querypolicy mode.
- Added log message stating length of processing time for querypolicy function.
- Minor optimizations.

Fixes:
- Fixed script locking mechanism when executing querypolicy or queryasn from the UI menu.
- Fixed issue where ASNs were not queried by cron job if no domain policies were created.

v3.0.1 - 10/26/2024
Enhancements:
- Added functionality to add ASNs to be routed over an interface.
- Added ADDCNAMES to Show Policy menu when viewing a policy.
- Optimized functionality to generate interface list when creating or editing a policy or ASN.
- Optimized functionality for boot delay timer and setting process priority.
- System Information under Configuration menu now shows status of dig and jq being installed.
- Domain VPN Routing will now check for WAN being connected and will error out when executing querypolicy, queryasn, or update if WAN is not connected.
- Minor optimizations

Fixes:
- Fixed an issue where IP FWMark rules were erroneously being deleted when editing or deleting a policy.
- Fixed an issue with executing the kill function to kill Domain VPN Routing processes, this was also happeneing in update mode.
- Fixed grammatical error on Main Menu for queryasn.
- Fixed error when editing a policy and getting an error for no NEWASININTERFACE variable.
- Fixed an erroroneous file being created under /jffs/configs/domain_vpn_routing/policy_all_domainlist ***It is safe to delete this file***
- Various minor fixes

v3.0.0 - 10/14/2024
Enhancements:
- Added functionality to support wildcards for subdomains.  Example: *.example.com ***Requires DNS Logging to be enabled***
- Added DNS Overrides for VPN Client interfaces, when a policy is configured with a specific interface it will use the system default DNS Server unless a DNS override is configured for that specific interface in the configuration menu.
- Domain queries will now utilize dig if it is installed and will bypass use of nslookup.
- If dig is installed, a policy can be configured to allow CNAMES of domains to be added to the policy domain list automatically during query execution.  This is disabled by default for existing policies and can be enabled using the editpolicy function.
- IP Version will now be displayed under System Information located in the Configuration menu.

Fixes:
- Reduced names of IPSets to allow policy names to have a max length of 24 characters.
- Fixed issue that caused RT-AC68U and DSL-AC68U to lock up on execution due to limitation of 2 OpenVPN Client slots.
- Domain VPN Routing will now check the IP version and operate in a compability mode for older versions.  If an optional binary is installed Domain VPN Routing will test and use the newer version of the ip binary between the system and optional binary.
- Fixed an issue with beta update channel.
- Fixed an issue where ip rules were not being deleted when an unreachable rule was being created to block traffic for a VPN interface being down.
- Fixed minor issues with IPv6 routing rules.

v2.1.3 - 02/26/2024
Enhancements:
- Added restore policy mode that will recreate objects for policies to function without performing an active query.  This will increase the time of restoration of policies during reboot or WAN failover events, restore policy mode is also called at the beginning of query policy mode.
- Simplified policy selection in menu interface where only a number has to be selected to select a policy instead of manually typing it.
- Optional configuration item added to add restorepolicy command during firewall restart events.

Fixes:
- System binaries will now be used over optional binaries installed from repos such as Entware.

v2.1.2 - 10/14/2023
Enhancements:
- The wgclient-start start up script for WireGuard clients will now be created if it doesn't exist and will call Domain VPN Routing.
- The Reverse Path Filter will now be set to Loose Filtering if set to Strict Filtering and FWMarks are being used for a policy.

Fixes:
- Fixed integration with Wireguard clients configured with IPv6.
- Fixed issue where IPv4 ipsets were not being saved under some conditions.
- Fixed issue where IPv6 addresses were not being deleted from ipsets.
- Fixed an issue that caused Domain VPN Routing to be stuck in a loop if a WireGuard Client DNS Option was null.
- Fixed integration issues with amtm.
- Fixed an issue where a failed DNS query returned 0.0.0.0 as a queried IP Address for a policy, this entry will be excluded.

v2.1.1 - 10/09/2023
Enhancements:
- Integration with amtm

v2.1.0 - 10/06/2023
Enhancements:
- DNSMasq log is now utilized if enabled to query for domain records to route.  The log path will be captured from the DNSMasq Configuration.
- IPSets, IPTables Rules, and IP Rules using FWMarks have been implemented to reduce the amount of routes / rules that are created for policies.
- Added Check Interval configuration options to Configuration Menu to modify the cron job schedule between 1 - 59 minutes.  Default: 15 minutes
- The current interface for a Policy will be displayed when in the Edit Policy configuration menu.
- Added default FWMark and Mask values for OpenVPN and WireGuard clients that can be changed in the configuration menu.  Reboot required for changes.
- Log priority values added (Critical, Error, Warning, Notice, Informational, Debug)
- Additional logging messages have been added.
- Added Boot Delay Timer configuration setting to delay execution to wait and allow VPN tunnels to initalize during start up before querying for policies. Default: 0 Seconds
- Added Reset Default Configuration to Configuration Menu, additionally the command argument resetconfig can be used.

Fixes:
- Fixed an issue where adding a domain with the same partial name as an existing in a policy prevented it from being added.
- Fixed an issue that causes the update function to hang when complete as well as when terminating Domain VPN Routing.
- Fixed an issue preventing installation where Domain VPN Routing was trying to access the global configuration before it was created.
- Fixed an issue where the alias "domain_vpn_routing" was not being deleted during uninstallation.
- Fixed an issue where changing the Check Interval causes the Domain VPN Routing to hang on Query Policy screen instead of returning to Configuration Menu.
- Fixed an issue when editing a policy and changing the interface would cause a parameter not set error.
- Fixed an issue that wouldn't allow FWMark and Mask settings in the configuration to be null.
- Fixed an issue that caused uninstallation to prompt multiple times for confirmation during uninstall process.
- Fixed an issue that prevented the menu from loading when Domain VPN Routing was not installed.

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
