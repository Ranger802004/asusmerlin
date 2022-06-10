# Domain VPN Routing for ASUS Routers using Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 06/10/2022
# Version: v0.9-beta

Domain VPN Routing allows you to create policies to add domains and select which VPN interface you want them routed to, the script will query the Domains via cronjob and add the queried IPs to a Policy File that will create the routes necessary.

Requirements:
- ASUS Merlin Firmware v386.5.2
- JFFS custom scripts and configs Enabled
- OpenVPN

Installation Command:
/usr/sbin/curl -s "https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/domain_vpn_routing.sh" -o "/jffs/scripts/domain_vpn_routing.sh" && chmod 755 /jffs/scripts/domain_vpn_routing.sh && sh /jffs/scripts/domain_vpn_routing.sh install

Update Command:
/jffs/scripts/domain_vpn_routing.sh update

Uninstallation Command:
/jffs/scripts/domain_vpn_routing.sh uninstall

Run Modes:
- install - This will install Domain VPN Routing and the configuration files necessary for it to run.
- createpolicy - This will create a new policy.
- showpolicy - This will show the policy specified or all policies.
- querypolicy - This will query domains from a policy or all policies and create IP Routes necessary.
- addomain - This will add a domain to the policy specified.
- update - This will download and update to the latest version.
- cron - This will create the Cron Jobs to automate Query Policy functionality.
- deletedomain - This will delete a specified domain from a selected policy.
- deletepolicy - This will delete a specified policy or all policies.
- kill - This will kill any running instances of the script.
- uninstall - This will uninstall the configuration files necessary to stop the script from running.

Creating a Policy:
Step 1: Create a policy by running the following command: /jffs/scripts/domain_vpn_routing.sh createpolicy

Step 2: Select a name for the Policy (Case Sensitive).
	Example: Google

Step 3: Select an existing OpenVPN Interface.  Type the name of the interface as displayed.

Step 4: Policy is created, proceed to Section: Adding a Domain.

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
v0.9-beta - 06/10/2022
- Initial Beta Release
