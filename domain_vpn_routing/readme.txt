# Domain VPN Routing for ASUS Routers using Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 07/24/2022
# Version: v1.3

Domain VPN Routing allows you to create policies to add domains and select which VPN interface you want them routed to, the script will query the Domains via cronjob and add the queried IPs to a Policy File that will create the routes necessary.

Requirements:
- ASUS Merlin Firmware v386.7
- JFFS custom scripts and configs Enabled
- OpenVPN

Installation Command:
/usr/sbin/curl -s "https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/domain_vpn_routing.sh" -o "/jffs/scripts/domain_vpn_routing.sh" && chmod 755 /jffs/scripts/domain_vpn_routing.sh && sh /jffs/scripts/domain_vpn_routing.sh install

Update Command:
/jffs/scripts/domain_vpn_routing.sh update

Uninstallation Command:
/jffs/scripts/domain_vpn_routing.sh uninstall

Run Modes:
- install - Install Domain VPN Routing and the configuration files necessary for it to run.
- createpolicy - Create a new policy.
- showpolicy - Show the policy specified or all policies. Use all as 2nd argument for All Policies.
- querypolicy - Query domains from a policy or all policies and create IP Routes necessary. Use all as 2nd argument for All Policies.
- adddomain - Add a domain to the policy specified.
- editpolicy - Modify an existing policy.
- update - Download and update to the latest version.
- cron - Create the Cron Jobs to automate Query Policy functionality.
- deletedomain - Delete a specified domain from a selected policy.
- deletepolicy - Delete a specified policy or all policies. Use all as 2nd argument for All Policies.
- deleteip - Delete a queried IP from a policy.
- kill - Kill any instances of the script.
- uninstall - Uninstall the configuration files necessary to stop the script from running.

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
