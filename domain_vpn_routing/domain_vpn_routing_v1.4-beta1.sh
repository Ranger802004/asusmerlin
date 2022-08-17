#!/bin/sh

# Domain Name based VPN routing for ASUS Routers using Merlin Firmware v386.7
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 08/17/2022
# Version: v1.4-beta1

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/domain_vpn_routing.sh"
VERSION="v1.4-beta1"
CONFIGFILE="/jffs/configs/domain_vpn_routing/domain_vpn_routing.conf"
POLICYDIR="/jffs/configs/domain_vpn_routing"
SYSTEMLOG="/tmp/syslog.log"
LOCKFILE="/var/lock/domain_vpn_routing.lock"
NOCOLOR="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[94m"
WHITE="\033[37m"

# Set Script Mode
if [ "$#" == "0" ] >/dev/null;then
  echo -e "${RED}${0##*/} - Executed without a Run Mode Selected!!!${NOCOLOR}"
  echo -e "${WHITE}Use one of the following run modes...${NOCOLOR}"
  echo -e "${BLUE}$0 install${WHITE} - Install Domain VPN Routing and the configuration files necessary for it to run.${NOCOLOR}"
  echo -e "${GREEN}$0 createpolicy${WHITE} - Create a new policy.${NOCOLOR}"
  echo -e "${GREEN}$0 showpolicy${WHITE} - Show the policy specified or all policies.${NOCOLOR}"
  echo -e "${GREEN}$0 querypolicy${WHITE} - Query domains from a policy or all policies and create IP Routes necessary.${NOCOLOR}"
  echo -e "${GREEN}$0 adddomain${WHITE} - Add a domain to the policy specified.${NOCOLOR}"
  echo -e "${YELLOW}$0 editpolicy${WHITE} - Modify an existing policy.${NOCOLOR}"
  echo -e "${YELLOW}$0 update${WHITE} - Download and update to the latest version.${NOCOLOR}"
  echo -e "${YELLOW}$0 cron${WHITE} - Create the Cron Jobs to automate Query Policy functionality.${NOCOLOR}"
  echo -e "${RED}$0 deletedomain${WHITE} - Delete a specified domain from a selected policy.${NOCOLOR}"
  echo -e "${RED}$0 deletepolicy${WHITE} - Delete a specified policy or all policies.${NOCOLOR}"
  echo -e "${RED}$0 deleteip${WHITE} - Delete a queried IP from a policy.${NOCOLOR}"
  echo -e "${RED}$0 kill${WHITE} - Kill any instances of the script.${NOCOLOR}"
  echo -e "${RED}$0 uninstall${WHITE} - Uninstall the configuration files necessary to stop the script from running.${NOCOLOR}"
  if [ ! -f "$CONFIGFILE" ] >/dev/null;then
    echo -e "${RED}${0##*/} - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  fi
  break && exit
fi
mode="${1#}"
if [ $# -gt "1" ] >/dev/null;then
  arg2=$2
else
  arg2=""
fi
scriptmode ()
{
if [[ "${mode}" == "install" ]] >/dev/null;then
  echo -e "${BLUE}${0##*/} - Installation${NOCOLOR}"
  install
elif [[ "${mode}" == "createpolicy" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Create Policy${NOCOLOR}"
  createpolicy
elif [[ "${mode}" == "showpolicy" ]] >/dev/null;then
  if [ -z "$arg2" ] >/dev/null;then
    POLICY=all
    showpolicy
  else
    POLICY="$arg2"
    showpolicy
  fi
elif [[ "${mode}" == "editpolicy" ]] >/dev/null;then 
  POLICY="$arg2"
  editpolicy
elif [[ "${mode}" == "deletepolicy" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Delete Policy${NOCOLOR}"
  POLICY="$arg2"
  deletepolicy
elif [[ "${mode}" == "querypolicy" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Query Policy${NOCOLOR}"
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} - Query Policy already running...${NOCOLOR}" && exit ;}
  trap 'rm -f "$LOCKFILE"' EXIT
  POLICY="$arg2"
  querypolicy
elif [[ "${mode}" == "adddomain" ]] >/dev/null;then 
  DOMAIN="$arg2"
  adddomain
elif [[ "${mode}" == "deletedomain" ]] >/dev/null;then 
  DOMAIN="$arg2"
  deletedomain
elif [[ "${mode}" == "deleteip" ]] >/dev/null;then 
  IP="$arg2"
  deleteip
elif [[ "${mode}" == "kill" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Kill Mode${NOCOLOR}"
  killscript
elif [[ "${mode}" == "uninstall" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Uninstallation${NOCOLOR}"
  uninstall
elif [[ "${mode}" == "cron" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Cron Job${NOCOLOR}"
  cronjob
elif [[ "${mode}" == "update" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Update Mode${NOCOLOR}"
  update
fi
exit
}

# Check Alias
checkalias ()
{
logger -p 6 -t "${0##*/}" "Debug - Checking Alias in /jffs/configs/profile.add"
if [ ! -f "/jffs/configs/profile.add" ] >/dev/null;then
  logger -p 5 -st "${0##*/}" "Alias Check - Creating /jffs/configs/profile.add"
  touch -a /jffs/configs/profile.add \
  && chmod 666 /jffs/configs/profile.add \
  && logger -p 4 -st "${0##*/}" "Alias Check - Created /jffs/configs/profile.add" \
  || logger -p 2 -st "${0##*/}" "Alias Check - ***Error*** Unable to create /jffs/configs/profile.add"
fi
if [ -z "$(cat /jffs/configs/profile.add | grep -w "# domain_vpn_routing")" ] >/dev/null;then
  logger -p 5 -st "${0##*/}" "Alias Check - Creating Alias for "$0" as domain_vpn_routing"
  echo -e "alias domain_vpn_routing=\"sh $0\" # domain_vpn_routing" >> /jffs/configs/profile.add \
  && source /jffs/configs/profile.add \
  && logger -p 4 -st "${0##*/}" "Alias Check - Created Alias for "$0" as domain_vpn_routing" \
  || logger -p 2 -st "${0##*/}" "Alias Check - ***Error*** Unable to create Alias for "$0" as domain_vpn_routing"
  . /jffs/configs/profile.add
fi
}

# Install
install ()
{
if [[ "${mode}" == "install" ]] >/dev/null;then
  read -n 1 -s -r -p "Press any key to continue to install..."
  # Create Policy Directory
  echo -e "${BLUE}${0##*/} - Install: Creating "$POLICYDIR"...${NOCOLOR}"
  logger -t "${0##*/}" "Install - Creating "$POLICYDIR""
  if [ ! -d "$POLICYDIR" ] >/dev/null;then
    mkdir -m 666 -p "$POLICYDIR"
    echo -e "${GREEN}${0##*/} - Install: "$POLICYDIR" created.${NOCOLOR}"
    logger -t "${0##*/}" "Install - "$POLICYDIR" created"
  else
    echo -e "${YELLOW}${0##*/} - Install: "$POLICYDIR" already exists...${NOCOLOR}"
    logger -t "${0##*/}" "Install - "$POLICYDIR" already exists"
  fi

  # Create Configuration File.
  echo -e "${BLUE}${0##*/} - Install: Creating "$CONFIGFILE"...${NOCOLOR}"
  logger -t "${0##*/}" "Install - Creating "$CONFIGFILE""
  if [ ! -f "$CONFIGFILE" ] >/dev/null;then
    touch -a "$CONFIGFILE"
    chmod 666 "$CONFIGFILE"
    echo -e "${GREEN}${0##*/} - Install: "$CONFIGFILE" created.${NOCOLOR}"
    logger -t "${0##*/}" "Install - "$CONFIGFILE" created"
  else
    echo -e "${YELLOW}${0##*/} - Install: "$CONFIGFILE" already exists...${NOCOLOR}"
    logger -t "${0##*/}" "Install - "$CONFIGFILE" already exists"
  fi

  # Create openvpn-event if it doesn't exist
  echo -e "${BLUE}Creating openvpn-event script...${NOCOLOR}"
  logger -t "${0##*/}" "Install - Creating openvpn-event script"
    if [ ! -f "/jffs/scripts/openvpn-event" ] >/dev/null;then
      touch -a /jffs/scripts/openvpn-event
      chmod 755 /jffs/scripts/openvpn-event
      echo "#!/bin/sh" >> /jffs/scripts/openvpn-event
      echo -e "${GREEN}openvpn-event script has been created.${NOCOLOR}"
    logger -t "${0##*/}" "Install - openvpn-event script has been created"
    else
      echo -e "${YELLOW}openvpn-event script already exists...${NOCOLOR}"
      logger -t "${0##*/}" "Install - openvpn-event script already exists"
    fi

  # Add Script to Openvpn-event
  if [ ! -z "$(cat /jffs/scripts/openvpn-event | grep -w "# domain_vpn_routing")" ] >/dev/null;then 
    echo -e "${YELLOW}${0##*/} already added to Openvpn-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Install - ${0##*/} already added to Openvpn-Event"
  else
    cmdline="sh $0 cron"
    echo -e "${BLUE}Adding ${0##*/} to Openvpn-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Install - Adding ${0##*/} to Openvpn-Event"
    echo -e "\r\n$cmdline # domain_vpn_routing" >> /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} added to Openvpn-event.${NOCOLOR}"
    logger -t "${0##*/}" "Install - ${0##*/} added to Openvpn-Event"
  fi
  if [ ! -z "$(cat /jffs/scripts/openvpn-event | grep -w "# domain_vpn_routing_queryall")" ] >/dev/null;then 
    echo -e "${YELLOW}${0##*/} already added to Openvpn-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Install - ${0##*/} already added to Openvpn-Event"
  else
    cmdline="sh $0 querypolicy all"
    echo -e "${BLUE}Adding ${0##*/} to Openvpn-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Install - Adding ${0##*/} to Openvpn-Event"
    echo -e "\r\n$cmdline # domain_vpn_routing_queryall" >> /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} added to Openvpn-event.${NOCOLOR}"
    logger -t "${0##*/}" "Install - ${0##*/} added to Openvpn-Event"
  fi

  # Create Initial Cron Jobs
  cronjob || return

  # Check Alias
  checkalias || return

fi
exit
}

# Uninstall
uninstall ()
{
if [[ "${mode}" == "uninstall" ]] >/dev/null;then
  read -n 1 -s -r -p "Press any key to continue to uninstall..."
  if [ ! -d "$POLICYDIR" ] >/dev/null;then
    echo -e "${RED}${0##*/} - Uninstall: "${0##*/}" not installed...${NOCOLOR}"
    exit
  fi

  # Remove Cron Job
  cronjob || return

  # Remove Script from Openvpn-event
  cmdline="sh $0 cron"
  if [ ! -z "$(cat /jffs/scripts/openvpn-event | grep -e "^$cmdline")" ] >/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Openvpn-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing Cron Job from Openvpn-Event"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Openvpn-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed Cron Job from Openvpn-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Openvpn-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Cron Job doesn't exist in Openvpn-Event"
  fi
  cmdline="sh $0 querypolicy all"
  if [ ! -z "$(cat /jffs/scripts/openvpn-event | grep -e "^$cmdline")" ] >/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Openvpn-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing Cron Job from Openvpn-Event"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Openvpn-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed Cron Job from Openvpn-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Openvpn-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Cron Job doesn't exist in Openvpn-Event"
  fi

  # Delete Policies
  $0 deletepolicy all
  # Delete Policy Directory
  if [ -d "$POLICYDIR" ] >/dev/null;then
    echo -e "${BLUE}${0##*/} - Uninstall: Deleting "$POLICYDIR"...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Creating "$POLICYDIR""
    rm -rf "$POLICYDIR"
    echo -e "${GREEN}${0##*/} - Uninstall: "$POLICYDIR" deleted.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - "$POLICYDIR" deleted"
  fi
  # Remove Lock File
  if [ -f "$LOCKFILE" ] >/dev/null;then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing "$LOCKFILE"...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing "$LOCKFILE""
    rm -f "$LOCKFILE" 
    echo -e "${GREEN}${0##*/} - Uninstall: Removed "$LOCKFILE"...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed "$LOCKFILE""
  fi
fi
exit
}

routingdirector ()
{
logger -p 6 -t "${0##*/}" "Debug - Routing Director Interface: $INTERFACE"

if [[ "$INTERFACE" == "tun11" ]] >/dev/null;then
  RGW=$(nvram get vpn_client1_rgw)
  ROUTETABLE=ovpnc1
  PRIORITY="1000"
elif [[ "$INTERFACE" == "tun12" ]] >/dev/null;then
  RGW=$(nvram get vpn_client2_rgw)
  ROUTETABLE=ovpnc2
  PRIORITY="2000"
elif [[ "$INTERFACE" == "tun13" ]] >/dev/null;then
  RGW=$(nvram get vpn_client3_rgw)
  ROUTETABLE=ovpnc3
  PRIORITY="3000"
elif [[ "$INTERFACE" == "tun14" ]] >/dev/null;then
  RGW=$(nvram get vpn_client4_rgw)
  ROUTETABLE=ovpnc4
  PRIORITY="4000"
elif [[ "$INTERFACE" == "tun15" ]] >/dev/null;then
  RGW=$(nvram get vpn_client5_rgw)
  ROUTETABLE=ovpnc5
  PRIORITY="5000"
elif [[ "$INTERFACE" == "tun21" ]] >/dev/null;then
  ROUTETABLE=main
  RGW="0"
  PRIORITY="0"
elif [[ "$INTERFACE" == "tun22" ]] >/dev/null;then
  ROUTETABLE=main
  RGW="0"
  PRIORITY="0"
elif [[ "$INTERFACE" == "$(nvram get wan_gw_ifname)" ]] && [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null;then
  ROUTETABLE=main
  RGW="2"
  PRIORITY="150"
elif [[ "$INTERFACE" == "$(nvram get wan0_gw_ifname)" ]] && [[ "$(nvram get wans_dualwan | awk '{print $2}')" != "none" ]] >/dev/null;then
  ROUTETABLE=100
  RGW="2"
  PRIORITY="150"
  logger -p 6 -t "${0##*/}" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
  if [ -z "$(ip route list default table 100 | grep -w "$(nvram get wan0_gw_ifname)")" ] >/dev/null;then
    logger -p 5 -t "${0##*/}" "Routing Director - Adding default route for WAN0 Routing Table via "$(nvram get wan0_gateway)" dev "$(nvram get wan0_gw_ifname)""
    ip route add default via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) table 100 \
    && logger -p 4 -t "${0##*/}" "Routing Director - Added default route for WAN0 Routing Table via "$(nvram get wan0_gateway)" dev "$(nvram get wan0_gw_ifname)"" \
    || logger -p 2 -st "${0##*/}" "Routing Director - ***Error*** Unable to add default route for WAN0 Routing Table via "$(nvram get wan0_gateway)" dev "$(nvram get wan0_gw_ifname)""
  fi
elif [[ "$INTERFACE" == "$(nvram get wan1_gw_ifname)" ]] && [[ "$(nvram get wans_dualwan | awk '{print $2}')" != "none" ]] >/dev/null;then
  ROUTETABLE=200
  RGW="2"
  PRIORITY="150"
  if [ -z "$(ip route list default table 200 | grep -w "$(nvram get wan1_gw_ifname)")" ] >/dev/null;then
    logger -p 5 -t "${0##*/}" "Routing Director - Adding default route for WAN1 Routing Table via "$(nvram get wan1_gateway)" dev "$(nvram get wan1_gw_ifname)""
    ip route add default via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) table 200 \
    && logger -p 4 -t "${0##*/}" "Routing Director - Added default route for WAN1 Routing Table via "$(nvram get wan1_gateway)" dev "$(nvram get wan1_gw_ifname)"" \
    || logger -p 2 -st "${0##*/}" "Routing Director - ***Error*** Unable to add default route for WAN1 Routing Table via "$(nvram get wan1_gateway)" dev "$(nvram get wan1_gw_ifname)""
  fi

else
  echo -e "${RED}Policy: Unable to query Interface${NOCOLOR}"
  exit
fi
return
}

# Create Policy
createpolicy ()
{
if [[ "${mode}" == "createpolicy" ]] >/dev/null;then
  # User Input for Policy Name
  while true;do  
    read -p "Policy Name: " NEWPOLICYNAME
      case "$NEWPOLICYNAME" in
         [abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_-]* ) CREATEPOLICYNAME=$NEWPOLICYNAME; break;;
        * ) echo -e "${RED}***Enter a valid Policy Name*** Use the following characters: A-Z, a-z, 0-9,-_${NOCOLOR}"
      esac
  done

# Select Interface for Policy
OVPNCONFIGFILES='
/etc/openvpn/client1/config.ovpn
/etc/openvpn/client2/config.ovpn
/etc/openvpn/client3/config.ovpn
/etc/openvpn/client4/config.ovpn
/etc/openvpn/client5/config.ovpn
/etc/openvpn/server1/config.ovpn
/etc/openvpn/server2/config.ovpn
'

INTERFACES=""  
  for OVPNCONFIGFILE in ${OVPNCONFIGFILES};do
    if [ -f "$OVPNCONFIGFILE" ] >/dev/null;then
      INTERFACE="$(cat ${OVPNCONFIGFILE} | grep -e dev -m 1 | awk '{print $2}')"
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done

  if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null;then
    INTERFACES="${INTERFACES} $(nvram get wan_gw_ifname)"
  elif [[ "$(nvram get wans_dualwan | awk '{print $2}')" != "none" ]] >/dev/null;then
    INTERFACES="${INTERFACES} $(nvram get wan0_gw_ifname)"
    INTERFACES="${INTERFACES} $(nvram get wan1_gw_ifname)"
  fi

  echo -e "Interfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "$INTERFACE"
  done
  # User Input for Interface
  while true;do  
    read -p "Select an Interface for this Policy: " NEWPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [ "$NEWPOLICYINTERFACE" == "${INTERFACE}" ] >/dev/null;then
        CREATEPOLICYINTERFACE=$NEWPOLICYINTERFACE
        break 2
      elif [ ! -z "$(echo "${INTERFACES}" | grep -w "$NEWPOLICYINTERFACE")" ] >/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid VPN Interface***${NOCOLOR}"
        echo -e "Interfaces: \r\n"$INTERFACES""
        break 1
      fi
    done
  done

  # Enable Verbose Logging
  while true;do  
    read -p "Enable verbose logging for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETVERBOSELOGGING="VERBOSELOGGING=1"; break;;
        [Nn]* ) SETVERBOSELOGGING="VERBOSELOGGING=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Enable Private IP Addresses
  while true;do  
    read -p "Enable Private IP Addresses for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETPRIVATEIPS="PRIVATEIPS=1"; break;;
        [Nn]* ) SETPRIVATEIPS="PRIVATEIPS=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Create Policy Files
    if [ ! -f $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist' ] >/dev/null;then
      echo -e "${BLUE}${0##*/} - Create Policy: Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist...${NOCOLOR}"
      logger -t "${0##*/}" "Create Policy - Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist"
      touch -a $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist'
      chmod 666 $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist'
      echo -e "${GREEN}${0##*/} - Create Policy: "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist created.${NOCOLOR}"
      logger -t "${0##*/}" "Create Policy - "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist created"
    fi
    if [ ! -f $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP' ] >/dev/null;then
      echo -e "${BLUE}${0##*/} - Create Policy: Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP...${NOCOLOR}"
      logger -t "${0##*/}" "Create Policy - Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP"
      touch -a $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP'
      chmod 666 $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP'
      echo -e "${GREEN}${0##*/} - Create Policy: "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP created.${NOCOLOR}"
      logger -t "${0##*/}" "Create Policy - "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP created"
    fi
  # Adding Policy to Config File
  echo -e "${BLUE}Create Policy - Adding "$CREATEPOLICYNAME" to "$CONFIGFILE"...${NOCOLOR}"
  logger -t "${0##*/}" "Create Policy - Adding "$CREATEPOLICYNAME" to "$CONFIGFILE""
    if [ -z "$(cat $CONFIGFILE | grep -w "$(echo $CREATEPOLICYNAME | awk -F"|" '{print $1}')")" ] >/dev/null;then
      echo -e ""$CREATEPOLICYNAME"|"$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist|"$POLICYDIR"/policy_"$CREATEPOLICYNAME"_"domaintoIP"|"$CREATEPOLICYINTERFACE"|"$SETVERBOSELOGGING"|"$SETPRIVATEIPS"" >> $CONFIGFILE
      echo -e "${GREEN}Create Policy - Added "$CREATEPOLICYNAME" to "$CONFIGFILE"...${NOCOLOR}"
      logger -t "${0##*/}" "Create Policy - Added "$CREATEPOLICYNAME" to "$CONFIGFILE""
    else
      echo -e "${YELLOW}"$CREATEPOLICYNAME" already exists in "$CONFIGFILE"...${NOCOLOR}"
      logger -t "${0##*/}" "Create Policy - "$CREATEPOLICYNAME" already exists in $CONFIGFILE"
    fi
fi
}

# Show Policy
showpolicy ()
{
if [ "$POLICY" == "all" ] >/dev/null;then
  echo -e "Policies: \n$(cat "$CONFIGFILE" | awk -F"|" '{print $1}')"
  exit
elif [ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ] >/dev/null;then
  echo "Policy Name: "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")""
  echo "Interface: "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $4}')""
  if [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
    echo "Verbose Logging: Enabled"
  elif [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=0" ]] >/dev/null;then
    echo "Verbose Logging: Disabled"
  elif [ -z "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $5}')" ] >/dev/null;then
    echo "Verbose Logging: Not Configured"
  fi
  if [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=1" ]] >/dev/null;then
    echo "Private IP Addresses: Enabled"
  elif [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=0" ]] >/dev/null;then
    echo "Private IP Addresses: Disabled"
  elif [ -z "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $6}')" ] >/dev/null;then
    echo "Private IP Addresses: Not Configured"
  fi
  DOMAINS="$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')")"
  echo -e "Domains:"
  for DOMAIN in ${DOMAINS};do
    echo -e "${DOMAIN}"
  done
  exit
else
  echo -e "${RED}Policy: "$POLICY" not found${NOCOLOR}"
  exit
fi
exit
}

# Edit Policy
editpolicy ()
{
if [[ "${mode}" == "editpolicy" ]] >/dev/null;then
  if [ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ] >/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to edit Policy: $POLICY"
    EDITPOLICY=$POLICY
  else
    echo -e "${RED}Policy: "$POLICY" not found${NOCOLOR}"
    exit
  fi
# Select VPN Interface for Policy
OVPNCONFIGFILES='
/etc/openvpn/client1/config.ovpn
/etc/openvpn/client2/config.ovpn
/etc/openvpn/client3/config.ovpn
/etc/openvpn/client4/config.ovpn
/etc/openvpn/client5/config.ovpn
/etc/openvpn/server1/config.ovpn
/etc/openvpn/server2/config.ovpn
'
INTERFACES=""  
  for OVPNCONFIGFILE in ${OVPNCONFIGFILES};do
    if [ -f "$OVPNCONFIGFILE" ] >/dev/null;then
      INTERFACE="$(cat ${OVPNCONFIGFILE} | grep -e dev -m 1 | awk '{print $2}')"
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done

  if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null;then
    INTERFACES="${INTERFACES} $(nvram get wan_gw_ifname)"
  elif [[ "$(nvram get wans_dualwan | awk '{print $2}')" != "none" ]] >/dev/null;then
    INTERFACES="${INTERFACES} $(nvram get wan0_gw_ifname)"
    INTERFACES="${INTERFACES} $(nvram get wan1_gw_ifname)"
  fi

  echo -e "\nInterfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "$INTERFACE"
  done

  # User Input for Interface
  while true;do  
    read -p "Select an Interface for this Policy: " EDITPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [ "$EDITPOLICYINTERFACE" == "${INTERFACE}" ] >/dev/null;then
        NEWPOLICYINTERFACE=$EDITPOLICYINTERFACE
        break 2
      elif [ ! -z "$(echo "${INTERFACES}" | grep -w "$EDITPOLICYINTERFACE")" ] >/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Interface***${NOCOLOR}"
        echo -e "Interfaces: \r\n"$INTERFACES""
        break 1
      fi
    done
  done

  # Enable Verbose Logging
  while true;do  
    read -p "Enable verbose logging for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETVERBOSELOGGING="VERBOSELOGGING=1"; break;;
        [Nn]* ) SETVERBOSELOGGING="VERBOSELOGGING=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Enable Private IP Addresses
  while true;do  
    read -p "Enable Private IP Addresses for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETPRIVATEIPS="PRIVATEIPS=1"; break;;
        [Nn]* ) SETPRIVATEIPS="PRIVATEIPS=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Editing Policy in Config File
  echo -e "${BLUE}Edit Policy - Modifying "$EDITPOLICY" in "$CONFIGFILE"...${NOCOLOR}"
  logger -t "${0##*/}" "Edit Policy - Modifying "$EDITPOLICY" in "$CONFIGFILE""
  if [ ! -z "$(cat $CONFIGFILE | grep -w "$(echo $EDITPOLICY | awk -F"|" '{print $1}')")" ] >/dev/null;then
    OLDINTERFACE="$(cat "$CONFIGFILE" | grep -w "$EDITPOLICY" | awk -F"|" '{print $4}')"
    sed -i "\:"$EDITPOLICY":d" "$CONFIGFILE"
    echo -e ""$EDITPOLICY"|"$POLICYDIR"/policy_"$EDITPOLICY"_domainlist|"$POLICYDIR"/policy_"$EDITPOLICY"_"domaintoIP"|"$NEWPOLICYINTERFACE"|"$SETVERBOSELOGGING"|"$SETPRIVATEIPS"" >> $CONFIGFILE
    echo -e "${GREEN}Edit Policy - Modified "$EDITPOLICY" in "$CONFIGFILE"...${NOCOLOR}"
    logger -t "${0##*/}" "Edit Policy - Modified "$EDITPOLICY" in "$CONFIGFILE""
  else
    echo -e "${YELLOW}"$EDITPOLICY" not found in "$CONFIGFILE"...${NOCOLOR}"
    logger -t "${0##*/}" "Edit Policy - "$EDITPOLICY" not found in $CONFIGFILE"
  fi
  
  # Check if Routes need to be modified
  if [[ "$NEWPOLICYINTERFACE" != "$OLDINTERFACE" ]] >/dev/null;then

INTERFACES='
'$OLDINTERFACE'
'$NEWPOLICYINTERFACE'
'

    for INTERFACE in ${INTERFACES};do
      routingdirector || return
      if [[ "$INTERFACE" == "$OLDINTERFACE" ]] >/dev/null;then
        OLDROUTETABLE=$ROUTETABLE
        OLDRGW=$RGW
        OLDPRIORITY=$PRIORITY
      elif [[ "$INTERFACE" == "$NEWPOLICYINTERFACE" ]] >/dev/null;then
        NEWROUTETABLE=$ROUTETABLE
        NEWRGW=$RGW
        NEWPRIORITY=$PRIORITY
      fi
    done

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(cat "$POLICYDIR/policy_"$EDITPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
    IPV4S="$(cat "$POLICYDIR/policy_"$EDITPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"

    # Recreate IPv6 Routes
      for IPV6 in ${IPV6S}; do
        if [ ! -z "$(ip -6 route list $IPV6 dev $OLDINTERFACE)" ] >/dev/null;then
          logger -t "${0##*/}" "Edit Policy - Deleting route for "$IPV6" dev "$OLDINTERFACE""
          $(ip -6 route del $IPV6 dev $OLDINTERFACE) \
          && logger -t "${0##*/}" "Edit Policy - Route deleted for "$IPV6" dev "$OLDINTERFACE"" \
          || logger -st "${0##*/}" "Edit Policy - ***Error*** Unable to delete route for "$IPV6" dev "$OLDINTERFACE""
        fi
        if [ -z "$(ip -6 route list $IPV6 dev $NEWPOLICYINTERFACE)" ] >/dev/null;then
          logger -t "${0##*/}" "Edit Policy - Adding route for "$IPV6" dev "$EDITPOLICYINTERFACE""
          ip -6 route add $IPV6 dev $NEWPOLICYINTERFACE \
          && logger -t "${0##*/}" "Edit Policy - Route added for "$IPV6" dev "$NEWPOLICYINTERFACE"" \
          || logger -st "${0##*/}" "Edit Policy - ***Error*** Unable to add route for "$IPV6" dev "$NEWPOLICYINTERFACE""
        fi
      done

      # Recreate IPv4 Routes and IP Rules
      for IPV4 in ${IPV4S}; do
        if [[ "$OLDRGW" == "0" ]] >/dev/null;then
          if [ ! -z "$(ip route list $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE)" ] >/dev/null;then
            logger -t "${0##*/}" "Edit Policy - Deleting route for "$IPV4" dev "$OLDINTERFACE" table "$OLDROUTETABLE""
            $(ip route del $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE) \
            && logger -t "${0##*/}" "Edit Policy - Route deleted for "$IPV4" dev "$OLDINTERFACE" table "$OLDROUTETABLE"" \
            || logger -st "${0##*/}" "Edit Policy - ***Error*** Unable to delete route for "$IPV4" dev "$OLDINTERFACE" table "$OLDROUTETABLE""
          fi
        elif [[ "$OLDRGW" != "0" ]] >/dev/null;then
          if [ ! -z "$(ip rule list from all to $IPV4 lookup $OLDROUTETABLE priority "$OLDPRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Edit Policy - Deleting IP Rule for "$IPV4" table "$OLDROUTETABLE" priority "$OLDPRIORITY""
            $(ip rule del from all to $IPV4 table $OLDROUTETABLE priority $OLDPRIORITY) \
            && logger -t "${0##*/}" "Edit Policy - Deleted IP Rule for "$IPV4" table "$OLDROUTETABLE" priority "$OLDPRIORITY"" \
            || logger -st "${0##*/}" "Edit Policy - ***Error*** Unable to delete IP Rule for "$IPV4" table "$OLDROUTETABLE" priority "$OLDPRIORITY""
          fi
        fi
        if [[ "$NEWRGW" == "0" ]] >/dev/null;then
          if [ -z "$(ip route list $IPV4 dev $NEWPOLICYINTERFACE table $NEWROUTETABLE)" ] >/dev/null;then
            logger -t "${0##*/}" "Edit Policy - Adding route for "$IPV4" dev "$NEWPOLICYINTERFACE" table "$NEWROUTETABLE""
            ip route add $IPV4 dev $NEWPOLICYINTERFACE table $NEWROUTETABLE \
            && logger -t "${0##*/}" "Edit Policy - Route added for "$IPV4" dev "$NEWPOLICYINTERFACE" table "$NEWROUTETABLE"" \
            || logger -st "${0##*/}" "Edit Policy - ***Error*** Unable to add route for "$IPV4" dev "$NEWPOLICYINTERFACE" table "$NEWROUTETABLE""
          fi
        elif [[ "$NEWRGW" != "0" ]] >/dev/null;then
          if [ -z "$(ip rule list from all to $IPV4 lookup $NEWROUTETABLE priority "$NEWPRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Edit Policy - Adding IP Rule for "$IPV4" table "$NEWROUTETABLE" priority "$NEWPRIORITY""
            $(ip rule add from all to $IPV4 table $NEWROUTETABLE priority $NEWPRIORITY) \
            && logger -t "${0##*/}" "Edit Policy - Added IP Rule for "$IPV4" table "$NEWROUTETABLE" priority "$NEWPRIORITY"" \
            || logger -st "${0##*/}" "Edit Policy - ***Error*** Unable to add IP Rule for "$IPV4" table "$NEWROUTETABLE" priority "$NEWPRIORITY""
          fi
        fi
      done
  fi
fi
}

# Delete Policy
deletepolicy ()
{
if [[ "${mode}" == "deletepolicy" ]] >/dev/null;then
  if [ "$POLICY" == "all" ] >/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to delete all policies"
    DELETEPOLICIES="$(cat "$CONFIGFILE" | awk -F"|" '{print $1}')"
  elif [ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ] >/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to delete Policy: $POLICY"
    DELETEPOLICIES=$POLICY
  else
    echo -e "${RED}Policy: "$POLICY" not found${NOCOLOR}"
    exit
  fi
  for DELETEPOLICY in ${DELETEPOLICIES};do
    # Determine Interface and Route Table for IP Routes to delete.
    INTERFACE="$(cat "$CONFIGFILE" | grep -w "$DELETEPOLICY" | awk -F"|" '{print $4}')"
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(cat "$POLICYDIR/policy_"$DELETEPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
    IPV4S="$(cat "$POLICYDIR/policy_"$DELETEPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"
 
    # Delete IPv6 Routes
    for IPV6 in ${IPV6S};do
      if [ ! -z "$(ip -6 route list $IPV6 dev $INTERFACE)" ] >/dev/null;then
        logger -t "${0##*/}" "Delete Policy - Deleting route for "$IPV6" dev "$INTERFACE""
        $(ip -6 route del $IPV6 dev $INTERFACE) \
        && logger -t "${0##*/}" "Delete Policy - Route deleted for "$IPV6" dev "$INTERFACE"" \
        || logger -st "${0##*/}" "Delete Policy - ***Error*** Unable to delete route for "$IPV6" dev "$INTERFACE""
      fi
    done

    # Delete IPv4 Routes and IP Rules
    for IPV4 in ${IPV4S};do
      if [[ "$RGW" == "0" ]] >/dev/null;then
        if [ ! -z "$(ip route list $IPV4 dev $INTERFACE table $ROUTETABLE)" ] >/dev/null;then
          logger -t "${0##*/}" "Delete Policy - Deleting route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
          $(ip route del $IPV4 dev $INTERFACE table $ROUTETABLE) \
          && logger -t "${0##*/}" "Delete Policy - Route deleted for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE"" \
          || logger -st "${0##*/}" "Delete Policy - ***Error*** Unable to delete route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
        fi
      elif [[ "$RGW" != "0" ]] >/dev/null;then
        if [ ! -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority "$PRIORITY")" ] >/dev/null;then
          logger -t "${0##*/}" "Delete Policy - Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
          $(ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY) \
          && logger -t "${0##*/}" "Delete Policy - Deleted IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY"" \
          || logger -st "${0##*/}" "Delete Policy - ***Error*** Unable to delete IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
        fi
      fi
    done

    # Removing Policy Files
    if [ -f ""$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist" ] >/dev/null;then
      echo -e "${BLUE}${0##*/} - Delete Policy: Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist...${NOCOLOR}"
      logger -t "${0##*/}" "Delete Policy - Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist"
      rm -f "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist
      echo -e "${GREEN}${0##*/} - Delete Policy: "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist deleted.${NOCOLOR}"
      logger -t "${0##*/}" "Delete Policy - "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist deleted"
    fi
    if [ -f ""$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP" ] >/dev/null;then
      echo -e "${BLUE}${0##*/} - Delete Policy: Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP...${NOCOLOR}"
      logger -t "${0##*/}" "Delete Policy - Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP"
      rm -f "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP
      echo -e "${GREEN}${0##*/} - Delete Policy: "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP deleted.${NOCOLOR}"
      logger -t "${0##*/}" "Delete Policy - "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP deleted"
    fi
    # Removing Policy from Config File
    if [ ! -z "$(cat "$CONFIGFILE" | grep -w "$(echo "$DELETEPOLICY" | awk -F"|" '{print $1}')")" ] >/dev/null;then
      echo -e "${BLUE}Delete Policy - Deleting "$DELETEPOLICY" from "$CONFIGFILE"...${NOCOLOR}"
      logger -t "${0##*/}" "Delete Policy - Deleting "$DELETEPOLICY" to "$CONFIGFILE""
      POLICYTODELETE="$(cat "$CONFIGFILE" | grep -w "$DELETEPOLICY")"
      sed -i "\:"$POLICYTODELETE":d" "$CONFIGFILE"
      echo -e "${GREEN}Delete Policy - Deleted "$POLICY" from "$CONFIGFILE"...${NOCOLOR}"
      logger -t "${0##*/}" "Delete Policy - Deleted "$POLICY" from "$CONFIGFILE""
    fi
  done
fi
exit
}

# Add Domain to Policy
adddomain ()
{
if [ ! -z "$DOMAIN" ] >/dev/null;then
  # Select Policy for New Domain
  POLICIES="$(cat $CONFIGFILE | awk -F"|" '{print $1}')"
  echo -e "${BLUE}Select a Policy for the new Domain:${NOCOLOR} \r\n"$POLICIES""
  # User Input for Policy for New Domain
  while true;do  
    read -p "Policy: " NEWDOMAINPOLICY
    for POLICY in ${POLICIES};do
      if [ "$NEWDOMAINPOLICY" == "${POLICY}" ] >/dev/null;then
        POLICY=$NEWDOMAINPOLICY
        break 2
      elif [ ! -z "$(echo "${POLICIES}" | grep -w "$NEWDOMAINPOLICY")" ] >/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a Valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n"${POLICIES}""
        break 1
      fi
    done
  done

  if [ -z "$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')" | grep -w "$DOMAIN")" ] >/dev/null;then
    echo -e "${YELLOW}Add Domain - Adding "$DOMAIN" to Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Add Domain - Adding "$DOMAIN" to "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
    echo -e "$DOMAIN" >> "$(cat $CONFIGFILE | grep -w "$POLICY" | awk -F"|" '{print $2}')"
    echo -e "${GREEN}Add Domain - Added "$DOMAIN" to Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Add Domain - Added "$DOMAIN" to "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
  else
    echo -e "${RED}***Domain already added to $POLICY***${NOCOLOR}"
  fi
elif [ -z "$DOMAIN" ] >/dev/null;then
  echo -e "${RED}***No Domain Specified***${NOCOLOR}"
fi
exit
}

# Delete Domain from Policy
deletedomain ()
{
# Select Policy for Domain to Delete
POLICIES="$(cat $CONFIGFILE | awk -F"|" '{print $1}')"
echo -e "Select a Policy to delete $DOMAIN: \r\n"$POLICIES""
  # User Input for Policy for Deleting Domain
  while true;do  
    read -p "Policy: " DELETEDOMAINPOLICY
    for POLICY in ${POLICIES};do
      if [ "$DELETEDOMAINPOLICY" == "${POLICY}" ] >/dev/null;then
        POLICY=$DELETEDOMAINPOLICY
        break 2
      elif [ ! -z "$(echo "${POLICIES}" | grep -w "$DELETEDOMAINPOLICY")" ] >/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n"${POLICIES}""
        break 1
      fi
    done
  done

if [ ! -z "$DOMAIN" ] >/dev/null;then
  if [ ! -z "$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')" | grep -w "$DOMAIN")" ] >/dev/null;then
    # Determine Interface and Route Table for IP Routes to delete.
    INTERFACE="$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $4}')"
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -w "$DOMAIN" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
    IPV4S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -w "$DOMAIN" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"
 
    # Delete IPv6 Routes
    for IPV6 in ${IPV6S};do
      if [ ! -z "$(ip -6 route list $IPV6 dev $INTERFACE)" ] >/dev/null;then
        echo -e "${YELLOW}Deleting route for $IPV6 dev $INTERFACE...${NOCOLOR}"
        logger -t "${0##*/}" "Delete Domain - Deleting route for $IPV6 dev $INTERFACE"
        $(ip -6 route del $IPV6 dev $INTERFACE)
        echo -e "${GREEN}Route deleted for $IPV6 dev $INTERFACE.${NOCOLOR}"
        logger -t "${0##*/}" "Delete Domain - Route deleted for $IPV6 dev $INTERFACE"
      fi
    done

  if [[ "$RGW" == "0" ]] >/dev/null;then
    # Delete IPv4 Routes
    for IPV4 in ${IPV4S};do
      if [ ! -z "$(ip route list $IPV4 dev $INTERFACE table $ROUTETABLE)" ] >/dev/null;then
        echo -e "${YELLOW}Deleting route for $IPV4 dev $INTERFACE table $ROUTETABLE...${NOCOLOR}"
        logger -t "${0##*/}" "Delete Domain - Deleting route for $IPV4 dev $INTERFACE table $ROUTETABLE"
        $(ip route del $IPV4 dev $INTERFACE table $ROUTETABLE)
        echo -e "${GREEN}Route deleted for $IPV4 dev $INTERFACE table $ROUTETABLE.${NOCOLOR}"
        logger -t "${0##*/}" "Delete Domain - Route deleted for $IPV4 dev $INTERFACE table $ROUTETABLE"
      fi
    done

  elif [[ "$RGW" != "0" ]] >/dev/null;then
    # Delete IPv4 IP Rules
    for IPV4 in ${IPV4S};do
      if [ ! -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority "$PRIORITY")" ] >/dev/null;then
        echo -e "${YELLOW}Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY"...${NOCOLOR}"
        logger -t "${0##*/}" "Delete Domain - Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
        ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY
        echo -e "${GREEN}IP Rule deleted for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY".${NOCOLOR}"
        logger -t "${0##*/}" "Delete Domain - Deleted IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
      fi
    done
  fi

    # Delete Domain from Policy
    echo -e "${YELLOW}Delete Domain - Deleting "$DOMAIN" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Delete Domain - Deleting "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
    logger -t "${0##*/}" "Delete Domain - Deleting "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
    sed -i "\:"$DOMAIN":d" "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')"
    sed -i "\:"^$DOMAIN":d" "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')"
    echo -e "${GREEN}Delete Domain - Deleted "$DOMAIN" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Delete Domain - Deleted "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
    logger -t "${0##*/}" "Delete Domain - Deleted "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
  else
    echo -e "${RED}***Domain not added to Policy: $POLICY***${NOCOLOR}"
  fi
fi
exit
}

# Delete IP from Policy
deleteip ()
{
# Select Policy for Domain to Delete
POLICIES="$(cat $CONFIGFILE | awk -F"|" '{print $1}')"
echo -e "Select a Policy to delete $IP: \r\n"$POLICIES""
  # User Input for Policy for Deleting IP
  while true;do  
    read -p "Policy: " DELETEIPPOLICY
    for POLICY in ${POLICIES};do
      if [ "$DELETEIPPOLICY" == "${POLICY}" ] >/dev/null;then
        POLICY=$DELETEIPPOLICY
        break 2
      elif [ ! -z "$(echo "${POLICIES}" | grep -w "$DELETEIPPOLICY")" ] >/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n"${POLICIES}""
        break 1
      fi
    done
  done

if [ ! -z "$IP" ] >/dev/null;then
  if [ ! -z "$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')" | grep -w "$IP")" ] >/dev/null;then
    # Determine Interface and Route Table for IP Routes to delete.
    INTERFACE="$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $4}')"
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -m 1 -w "$IP" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
    IPV4S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -m 1 -w "$IP" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"
 
    # Delete IPv6 Routes
    for IPV6 in ${IPV6S}; do
      if [ ! -z "$(ip -6 route list $IPV6 dev $INTERFACE)" ] >/dev/null;then
        logger -t "${0##*/}" "Delete IP - Deleting route for "$IPV6" dev "$INTERFACE""
        $(ip -6 route del $IPV6 dev $INTERFACE) \
        && logger -t "${0##*/}" "Delete IP - Route deleted for "$IPV6" dev "$INTERFACE"" \
        || logger -st "${0##*/}" "Delete IP - ***Error*** Unable to delete route for "$IPV6" dev "$INTERFACE""

      fi
    done

    if [[ "$RGW" == "0" ]] >/dev/null;then
      # Delete IPv4 Routes
      for IPV4 in ${IPV4S}; do
        if [ ! -z "$(ip route list $IPV4 dev $INTERFACE table $ROUTETABLE)" ] >/dev/null;then
          logger -t "${0##*/}" "Delete IP - Deleting route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
          $(ip route del $IPV4 dev $INTERFACE table $ROUTETABLE) \
          && logger -t "${0##*/}" "Delete IP - Route deleted for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE"" \
          || logger -st "${0##*/}" "Delete IP - ***Error*** Unable to delete route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
        fi
      done
    elif [[ "$RGW" != "0" ]] >/dev/null;then
      # Delete IPv4 IP Rules
      for IPV4 in ${IPV4S};do
        if [ ! -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority "$PRIORITY")" ] >/dev/null;then
          logger -t "${0##*/}" "Delete IP - Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
          ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY \
          && logger -st "${0##*/}" "Delete IP - Deleted IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY"" \
          || logger -st "${0##*/}" "Delete IP - ***Error*** Unable to delete IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
        fi
      done
    fi

    # Delete IP from Policy
    echo -e "${YELLOW}Delete IP - Deleting "$IP" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Delete IP - Deleting "$IP" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
    DELETEDOMAINTOIPS="$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')" | grep -w "$IP")"
    for DELETEDOMAINTOIP in ${DELETEDOMAINTOIPS}; do
    sed -i "\:"^${DELETEDOMAINTOIP}":d" "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')"
    done
    echo -e "${GREEN}Delete IP - Deleted "$IP" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Delete IP - Deleted "$IP" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
  else
    echo -e "${RED}***IP not added to Policy: $POLICY***${NOCOLOR}"
  fi
fi
exit

}

# Query Policies for New IP Addresses
querypolicy ()
{
checkalias || return

if [ "$POLICY" == "all" ] >/dev/null;then
  QUERYPOLICIES="$(cat "$CONFIGFILE" | awk -F"|" '{print $1}')"
  if [ -z "$QUERYPOLICIES" ] >/dev/null;then
    echo -e "${RED}***No Policies Detected***${NOCOLOR}"
    logger -t "${0##*/}" "Query Policy - ***No Policies Detected***"
    exit
  fi
elif [ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ] >/dev/null;then
  QUERYPOLICIES=$POLICY
else
  echo -e "${RED}Policy: "$POLICY" not found${NOCOLOR}"
  exit
fi
for QUERYPOLICY in ${QUERYPOLICIES};do
  # Create Temporary File for Sync
  if [ ! -f "/tmp/policy_"$QUERYPOLICY"_domaintoIP" ] >/dev/null;then
    touch -a "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
  fi

  # Compare Policy File to Temporary File
  if ! diff "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP" "/tmp/policy_"$QUERYPOLICY"_domaintoIP" >/dev/null;then
    cp "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP" "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
  fi

  # Check if Verbose Logging is Enabled
  [ -z "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" ] && VERBOSELOGGING=1
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=0" ]] && VERBOSELOGGING=0
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] && VERBOSELOGGING=1

  # Check if Private IPs are Enabled
  [ -z "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" ] && PRIVATEIPS=0
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=0" ]] && PRIVATEIPS=0
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=1" ]] && PRIVATEIPS=1

  # Query Domains for IP Addresses
  DOMAINS="$(cat "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $2}')")"
  for DOMAIN in ${DOMAINS};do
    [[ "$VERBOSELOGGING" == "1" ]] && logger -t "${0##*/}" "Query Policy - Policy: $QUERYPOLICY Querying "$DOMAIN""
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' ""${YELLOW}"Query Policy: $QUERYPOLICY Querying "$DOMAIN"..."${NOCOLOR}""
    fi
    for IP in $(nslookup $DOMAIN | awk '(NR>2) && /^Address/ {print $3}' | sort); do
      if [[ "$PRIVATEIPS" == "1" ]] >/dev/null;then
        echo $DOMAIN'>>'$IP >> "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
      elif [[ "$PRIVATEIPS" == "0" ]] >/dev/null;then
        if [ -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ] >/dev/null;then
          echo $DOMAIN'>>'$IP >> "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
        elif [ ! -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ] >/dev/null;then
          [[ "$VERBOSELOGGING" == "1" ]] && logger -st "${0##*/}" "Query Policy - Domain: "$DOMAIN" queried "$IP" ***Excluded because Private IPs are disabled for Policy: "$QUERYPOLICY"***"
          if tty >/dev/null 2>&1;then
            printf '\033[K%b\r' ""${RED}"Query Policy: Domain: "$DOMAIN" queried "$IP" ***Excluded because Private IPs are disabled for Policy: "$QUERYPOLICY"***"${NOCOLOR}""
          fi
        fi
      fi
    done
  done

  # Remove duplicates from Temporary File
  sort -u "/tmp/policy_"$QUERYPOLICY"_domaintoIP" -o "/tmp/policy_"$QUERYPOLICY"_domaintoIP"

  # Compare Temporary File to Policy File
  if ! diff "/tmp/policy_"$QUERYPOLICY"_domaintoIP" "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP" >/dev/null;then
    echo -e "${YELLOW}Policy: New IP Addresses detected for $QUERYPOLICY${NOCOLOR}"
    echo -e "${YELLOW}Updating Policy: "$QUERYPOLICY"${NOCOLOR}"
    logger -st "${0##*/}" "Query Policy - Updating Policy: "$QUERYPOLICY""
    cp "/tmp/policy_"$QUERYPOLICY"_domaintoIP" "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP"
    echo -e "${GREEN}Updated Policy: "$QUERYPOLICY"${NOCOLOR}"
    logger -st "${0##*/}" "Query Policy - Updated Policy: "$QUERYPOLICY""
  else
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' ""${GREEN}"Query Policy: No new IP Addresses detected for $QUERYPOLICY"${NOCOLOR}""
    fi
  fi

  # Determine Interface and Route Table for IP Routes.
  INTERFACE="$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $4}')"
  routingdirector || return

  # Create IPv4 and IPv6 Arrays from Policy File. 
  IPV6S="$(cat "/tmp/policy_"$QUERYPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
  IPV4S="$(cat "/tmp/policy_"$QUERYPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"
  
  if tty >/dev/null 2>&1;then
    printf '\033[K%b\r' ""${YELLOW}"Query Policy: Updating IP Routes and IP Rules"${NOCOLOR}""
  fi

  # Create IPv6 Routes
  for IPV6 in ${IPV6S};do
    if [ -z "$(ip -6 route list $IPV6 dev $INTERFACE)" ] >/dev/null;then
      [[ "$VERBOSELOGGING" == "1" ]] && logger -t "${0##*/}" "Query Policy - Adding route for "$IPV6" dev "$INTERFACE""
      ip -6 route add $IPV6 dev $INTERFACE \
      && { [[ "$VERBOSELOGGING" == "1" ]] && logger -t "${0##*/}" "Query Policy - Route added for "$IPV6" dev "$INTERFACE"" ;} \
      || logger -st "${0##*/}" "Query Policy - ***Error*** Unable to add route for "$IPV6" dev "$INTERFACE""
    fi
  done

  if [[ "$RGW" == "0" ]] >/dev/null;then
    # Create IPv4 Routes
    for IPV4 in ${IPV4S};do
      if [ -z "$(ip route list $IPV4 dev $INTERFACE table $ROUTETABLE)" ] >/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] && logger -t "${0##*/}" "Query Policy - Adding route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
        ip route add $IPV4 dev $INTERFACE table $ROUTETABLE \
        && { [[ "$VERBOSELOGGING" == "1" ]] && logger -t "${0##*/}" "Query Policy - Route added for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE"" ;} \
        || logger -st "${0##*/}" "Query Policy - ***Error*** Unable to add route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
      fi
    done
  elif [[ "$RGW" != "0" ]] >/dev/null;then
    # Create IPv4 Rules
    for IPV4 in ${IPV4S}; do
      if [ -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority "$PRIORITY")" ] >/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] && logger -st "${0##*/}" "Query Policy - Adding IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
        ip rule add from all to $IPV4 table $ROUTETABLE priority $PRIORITY \
        && { [[ "$VERBOSELOGGING" == "1" ]] && logger -t "${0##*/}" "Query Policy - Added IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY"" ;} \
        || logger -st "${0##*/}" "Query Policy - ***Error*** Unable to add IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
      fi
    done
  fi

  # Clear Parameters
  VERBOSELOGGING=""
  PRIVATEIPS=""
  INTERFACE=""
  IPV6S=""
  IPV4S=""
  RGW=""
  PRIORITY=""
  ROUTETABLE=""
done
if tty >/dev/null 2>&1;then
  printf '\033[K'
fi
exit
}

# Cronjob
cronjob ()
{
# Create Cron Job
if [[ "${mode}" != "uninstall" ]] >/dev/null;then
  if [ -z "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ] >/dev/null;then
    logger -p 5 -st "${0##*/}" "Cron - Creating Cron Job"
    $(cru a setup_domain_vpn_routing "*/15 * * * *" $0 querypolicy all) \
    && logger -p 4 -st "${0##*/}" "Cron - Created Cron Job" \
    || logger -p 2 -st "${0##*/}" "Cron - ***Error*** Unable to create Cron Job"
  fi

  # Execute Query Policy All if System Uptime is less than 15 minutes
  [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "900" ]] && $0 querypolicy all

# Remove Cron Job
elif [[ "${mode}" == "uninstall" ]] >/dev/null;then
  if [ ! -z "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ] >/dev/null;then
    logger -p 3 -st "${0##*/}" "Cron - Removing Cron Job"
    $(cru d setup_domain_vpn_routing "*/15 * * * *" $0 querypolicy all) \
    && logger -p 3 -st "${0##*/}" "Cron - Removed Cron Job" \
    || logger -p 2 -st "${0##*/}" "Cron - ***Error*** Unable to remove Cron Job"
  fi
  return
fi
return
}

# Kill Script
killscript ()
{
echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
logger -t "${0##*/}" "Kill - Killing ${0##*/}"
if [ -f "$LOCKFILE" ] >/dev/null;then
  rm -f "$LOCKFILE"
fi
sleep 3 && killall ${0##*/}
exit
}

# Update Script
update ()
{
REMOTEVERSION="$(echo $(curl "$DOWNLOADPATH" | grep -v "grep" | grep -e "# Version:" | awk '{print $3}'))"
if [ -z "$REMOTEVERSION" ] >/dev/null; then
  echo -e "${RED}Current Version: $VERSION - Update server not available...${NOCOLOR}"
  exit
fi
if [[ ! -z "$(echo "$VERSION" | grep -e "beta")" ]] >/dev/null; then
  echo -e "${YELLOW}Current Version: $VERSION - Script is a beta version and must be manually upgraded or replaced for a production version.${NOCOLOR}"
  while true;do  
    read -p "Do you want to update to the latest production version? "$REMOTEVERSION" ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done
fi
if [[ "$VERSION" != "$REMOTEVERSION" ]] >/dev/null; then
  echo -e "${YELLOW}Script is out of date - Current Version: "$VERSION" Available Version: "$REMOTEVERSION"${NOCOLOR}"
  read -n 1 -s -r -p "Press any key to continue to update..."
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" && chmod 755 $0 & kill
  echo -e "${GREEN}Script has been updated...${NOCOLOR}"
elif [[ "$VERSION" == "$REMOTEVERSION" ]] >/dev/null; then
  echo -e "${GREEN}Script is up to date - Version: "$VERSION"${NOCOLOR}"
fi
}
scriptmode
