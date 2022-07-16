#!/bin/sh

# Domain Name based VPN routing for ASUS Routers using Merlin Firmware v386.7
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 07/15/2022
# Version: v1.3-beta

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/domain_vpn_routing.sh"
VERSION="v1.3-beta"
CONFIGFILE="/jffs/configs/domain_vpn_routing/domain_vpn_routing.conf"
POLICYDIR="/jffs/configs/domain_vpn_routing"
SYSTEMLOG="/tmp/syslog.log"
LOCKFILE="/var/lock/domain_vpn_routing.lock"
NOCOLOR="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;94m"
WHITE="\033[0;37m"

# Set Script Mode
if [ "$#" == "0" ] >/dev/null;then
  echo -e "${RED}${0##*/} - Executed without a Run Mode Selected!!!${NOCOLOR}"
  echo -e "${WHITE}Use one of the following run modes...${NOCOLOR}"
  echo -e "${BLUE}$0 install${WHITE} - This will install Domain VPN Routing and the configuration files necessary for it to run.${NOCOLOR}"
  echo -e "${GREEN}$0 createpolicy${WHITE} - This will create a new policy.${NOCOLOR}"
  echo -e "${GREEN}$0 showpolicy${WHITE} - This will show the policy specified or all policies.${NOCOLOR}"
  echo -e "${GREEN}$0 querypolicy${WHITE} - This will query domains from a policy or all policies and create IP Routes necessary.${NOCOLOR}"
  echo -e "${GREEN}$0 adddomain${WHITE} - This will add a domain to the policy specified.${NOCOLOR}"
  echo -e "${YELLOW}$0 editpolicy${WHITE} - This will modify an existing policy.${NOCOLOR}"
  echo -e "${YELLOW}$0 update${WHITE} - This will download and update to the latest version.${NOCOLOR}"
  echo -e "${YELLOW}$0 cron${WHITE} - This will create the Cron Jobs to automate Query Policy functionality.${NOCOLOR}"
  echo -e "${RED}$0 deletedomain${WHITE} - This will delete a specified domain from a selected policy.${NOCOLOR}"
  echo -e "${RED}$0 deletepolicy${WHITE} - This will delete a specified policy or all policies.${NOCOLOR}"
  echo -e "${RED}$0 deleteip${WHITE} - This will delete a queried IP from a policy.${NOCOLOR}"
  echo -e "${RED}$0 kill${WHITE} - This will kill any running instances of the script.${NOCOLOR}"
  echo -e "${RED}$0 uninstall${WHITE} - This will uninstall the configuration files necessary to stop the script from running.${NOCOLOR}"
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
if [ ! -f "$CONFIGFILE" ] >/dev/null;then
  echo -e "${RED}${0##*/} - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  exit
fi
exit
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
  if [ ! -z "$(cat /jffs/scripts/openvpn-event | grep -e "# domain_vpn_routing")" ] >/dev/null;then 
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
  if [ ! -z "$(cat /jffs/scripts/openvpn-event | grep -e "# domain_vpn_routing_queryall")" ] >/dev/null;then 
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
  cronjob

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
  if [ ! -z "$(cru l | grep -w "setup_domain_vpn_routing")" ] >/dev/null; then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing Cron Job"
    cru d setup_domain_vpn_routing
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed Cron Job"
  else
    echo -e "${GREEN}${0##*/} - Uninstall: Cron Job doesn't exist.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Cron Job doesn't exist"
  fi

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
logger -p 6 -st "${0##*/}" "Debug - Routing Director Interface: $INTERFACE"

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
  echo -e "VPN Interfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "$INTERFACE"
  done
  # User Input for VPN Interface
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

  echo -e "\nVPN Interfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "$INTERFACE"
  done

  # User Input for VPN Interface
  while true;do  
    read -p "Select an Interface for this Policy: " EDITPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [ "$EDITPOLICYINTERFACE" == "${INTERFACE}" ] >/dev/null;then
        NEWPOLICYINTERFACE=$EDITPOLICYINTERFACE
        break 2
      elif [ ! -z "$(echo "${INTERFACES}" | grep -w "$EDITPOLICYINTERFACE")" ] >/dev/null;then
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
          echo -e "${YELLOW}Deleting route for $IPV6 dev $OLDINTERFACE...${NOCOLOR}"
          logger -t "${0##*/}" "Edit Policy - "Deleting route for $IPV6 dev $OLDINTERFACE"
          $(ip -6 route del $IPV6 dev $OLDINTERFACE)
          echo "${GREEN}Route deleted for $IPV6 dev $OLDINTERFACE.${NOCOLOR}"
          logger -t "${0##*/}" "Edit Policy - "Route deleted for $IPV6 dev $OLDINTERFACE"
        fi
        if [ -z "$(ip -6 route list $IPV6 dev $NEWPOLICYINTERFACE)" ] >/dev/null;then
          echo -e "${YELLOW}Adding route for "$IPV6" dev "$NEWPOLICYINTERFACE"...${NOCOLOR}"
          logger -t "${0##*/}" "Edit Policy - Adding route for "$IPV6" dev "$EDITPOLICYINTERFACE""
          ip -6 route add $IPV6 dev $NEWPOLICYINTERFACE
          echo -e "${GREEN}Route added for "$IPV6" dev "$NEWPOLICYINTERFACE".${NOCOLOR}"
          logger -t "${0##*/}" "Edit Policy - Route added for "$IPV6" dev "$NEWPOLICYINTERFACE""
        fi
      done

      # Recreate IPv4 Routes and IP Rules
      for IPV4 in ${IPV4S}; do
        if [[ "$OLDRGW" == "0" ]] >/dev/null;then
          if [ ! -z "$(ip route list $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE)" ] >/dev/null;then
            echo -e "${YELLOW}Deleting route for $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE...${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - "Deleting route for $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE"
            $(ip route del $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE)
            echo -e "${GREEN}Route deleted for $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE.${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - "Route deleted for $IPV4 dev $OLDINTERFACE table $OLDROUTETABLE"
          fi
        elif [[ "$OLDRGW" != "0" ]] >/dev/null;then
          if [ ! -z "$(ip rule list from all to $IPV4 lookup $OLDROUTETABLE priority "$OLDPRIORITY")" ] >/dev/null;then
            echo -e "${YELLOW}Deleting IP Rule for "$IPV4" table "$OLDROUTETABLE" priority "$OLDPRIORITY"...${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - Deleting IP Rule for "$IPV4" table "$OLDROUTETABLE" priority "$OLDPRIORITY""
            $(ip rule del from all to $IPV4 table $OLDROUTETABLE priority $OLDPRIORITY)
            echo -e "${GREEN}IP Rule deleted for "$IPV4" table "$OLDROUTETABLE" priority "$OLDPRIORITY".${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - Deleted IP Rule for "$IPV4" table "$OLDROUTETABLE" priority "$OLDPRIORITY""
          fi
        fi
        if [[ "$NEWRGW" == "0" ]] >/dev/null;then
          if [ -z "$(ip route list $IPV4 dev $NEWPOLICYINTERFACE table $NEWROUTETABLE)" ] >/dev/null;then
            echo -e "${YELLOW}Adding route for "$IPV4" dev "$NEWPOLICYINTERFACE" table "$NEWROUTETABLE"...${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - Adding route for "$IPV4" dev "$NEWPOLICYINTERFACE" table "$NEWROUTETABLE""
            ip route add $IPV4 dev $NEWPOLICYINTERFACE table $NEWROUTETABLE
            echo -e "${GREEN}Route added for "$IPV4" dev "$NEWPOLICYINTERFACE" table "$NEWROUTETABLE".${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - Route added for "$IPV4" dev "$NEWPOLICYINTERFACE" table "$NEWROUTETABLE""
          fi
        elif [[ "$NEWRGW" != "0" ]] >/dev/null;then
          if [ -z "$(ip rule list from all to $IPV4 lookup $NEWROUTETABLE priority "$NEWPRIORITY")" ] >/dev/null;then
            echo -e "${YELLOW}Adding IP Rule for "$IPV4" table "$NEWROUTETABLE" priority "$NEWPRIORITY"...${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - Adding IP Rule for "$IPV4" table "$NEWROUTETABLE" priority "$NEWPRIORITY""
            $(ip rule add from all to $IPV4 table $NEWROUTETABLE priority $NEWPRIORITY)
            echo -e "${GREEN}IP Rule added for "$IPV4" table "$NEWROUTETABLE" priority "$NEWPRIORITY".${NOCOLOR}"
            logger -t "${0##*/}" "Edit Policy - Added IP Rule for "$IPV4" table "$NEWROUTETABLE" priority "$NEWPRIORITY""
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
        echo -e "${YELLOW}Deleting route for $IPV6 dev $INTERFACE...${NOCOLOR}"
        logger -t "${0##*/}" "Delete Policy - "Deleting route for $IPV6 dev $INTERFACE"
        $(ip -6 route del $IPV6 dev $INTERFACE)
        echo "${GREEN}Route deleted for $IPV6 dev $INTERFACE.${NOCOLOR}"
        logger -t "${0##*/}" "Delete Policy - "Route deleted for $IPV6 dev $INTERFACE"
      fi
    done

    # Delete IPv4 Routes and IP Rules
    for IPV4 in ${IPV4S};do
      if [[ "$RGW" == "0" ]] >/dev/null;then
        if [ ! -z "$(ip route list $IPV4 dev $INTERFACE table $ROUTETABLE)" ] >/dev/null;then
          echo -e "${YELLOW}Deleting route for $IPV4 dev $INTERFACE table $ROUTETABLE...${NOCOLOR}"
          logger -t "${0##*/}" "Delete Policy - "Deleting route for $IPV4 dev $INTERFACE table $ROUTETABLE"
          $(ip route del $IPV4 dev $INTERFACE table $ROUTETABLE)
          echo -e "${GREEN}Route deleted for $IPV4 dev $INTERFACE table $ROUTETABLE.${NOCOLOR}"
          logger -t "${0##*/}" "Delete Policy - "Route deleted for $IPV4 dev $INTERFACE table $ROUTETABLE"
        fi
      elif [[ "$RGW" != "0" ]] >/dev/null;then
        if [ ! -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority "$PRIORITY")" ] >/dev/null;then
          echo -e "${YELLOW}Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY"...${NOCOLOR}"
          logger -t "${0##*/}" "Delete Policy - Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
          $(ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY)
          echo -e "${GREEN}IP Rule deleted for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY".${NOCOLOR}"
          logger -t "${0##*/}" "Delete Policy - Deleted IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
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
# Select Policy for New Domain
POLICIES="$(cat $CONFIGFILE | awk -F"|" '{print $1}')"
echo -e "Select a Policy for the new Domain: \r\n"$POLICIES""
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

if [ ! -z "$DOMAIN" ] >/dev/null;then
  if [ -z "$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')" | grep -w "$DOMAIN")" ] >/dev/null;then
    echo -e "${YELLOW}Add Domain - Adding "$DOMAIN" to Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Add Domain - Adding "$DOMAIN" to "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
    echo -e "$DOMAIN" >> "$(cat $CONFIGFILE | grep -w "$POLICY" | awk -F"|" '{print $2}')"
    echo -e "${GREEN}Add Domain - Added "$DOMAIN" to Policy: "$POLICY"${NOCOLOR}"
    logger -t "${0##*/}" "Add Domain - Added "$DOMAIN" to "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
  else
    echo -e "${RED}***Domain already added to $POLICY***${NOCOLOR}"
  fi
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
        echo -e "${YELLOW}Deleting route for $IPV6 dev $INTERFACE...${NOCOLOR}"
        logger -st "${0##*/}" "Delete IP - Deleting route for $IPV6 dev $INTERFACE"
        $(ip -6 route del $IPV6 dev $INTERFACE)
        echo -e "${GREEN}Route deleted for $IPV6 dev $INTERFACE.${NOCOLOR}"
        logger -st "${0##*/}" "Delete IP - Route deleted for $IPV6 dev $INTERFACE"
      fi
    done

    if [[ "$RGW" == "0" ]] >/dev/null;then
      # Delete IPv4 Routes
      for IPV4 in ${IPV4S}; do
        if [ ! -z "$(ip route list $IPV4 dev $INTERFACE table $ROUTETABLE)" ] >/dev/null;then
          echo -e "${YELLOW}Deleting route for $IPV4 dev $INTERFACE table $ROUTETABLE...${NOCOLOR}"
          logger -st "${0##*/}" "Delete IP - Deleting route for $IPV4 dev $INTERFACE table $ROUTETABLE"
          $(ip route del $IPV4 dev $INTERFACE table $ROUTETABLE)
          echo -e "${GREEN}Route deleted for $IPV4 dev $INTERFACE table $ROUTETABLE.${NOCOLOR}"
          logger -st "${0##*/}" "Delete IP - Route deleted for $IPV4 dev $INTERFACE table $ROUTETABLE"
        fi
      done
    elif [[ "$RGW" != "0" ]] >/dev/null;then
      # Delete IPv4 IP Rules
      for IPV4 in ${IPV4S};do
        if [ ! -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority "$PRIORITY")" ] >/dev/null;then
          echo -e "${YELLOW}Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY"...${NOCOLOR}"
          logger -st "${0##*/}" "Delete IP - Deleting IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
          ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY
          echo -e "${GREEN}IP Rule deleted for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY".${NOCOLOR}"
          logger -st "${0##*/}" "Delete IP - Deleted IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
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
  # Query Domains for IP Addresses
  DOMAINS="$(cat "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $2}')")"
  for DOMAIN in ${DOMAINS};do
    if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
      logger -st "${0##*/}" "Query Policy - Policy: $QUERYPOLICY Querying "$DOMAIN""
    fi
    if tty >/dev/null 2>&1;then
      printf '\033[K'
      printf '%b\r' ""${YELLOW}"Query Policy: $QUERYPOLICY Querying "$DOMAIN"..."${NOCOLOR}""
    fi
    for IP in $(nslookup $DOMAIN | awk '(NR>2) && /^Address/ {print $3}' | sort); do
      if [ -z "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" ] >/dev/null;then
        echo $DOMAIN'>>'$IP >> "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
      elif [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=1" ]] >/dev/null;then
        echo $DOMAIN'>>'$IP >> "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
      elif [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=0" ]] \
      && [ -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ] >/dev/null;then
        echo $DOMAIN'>>'$IP >> "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
      elif [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=0" ]] \
      && [ ! -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ] >/dev/null;then
        if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
          logger -st "${0##*/}" "Query Policy - Domain: "$DOMAIN" queried "$IP" ***Excluded because Private IPs are disabled for Policy: "$QUERYPOLICY"***"
        fi
        if tty >/dev/null 2>&1;then
          printf '\033[K'
          printf '%b\r' ""${RED}"Query Policy: Domain: "$DOMAIN" queried "$IP" ***Excluded because Private IPs are disabled for Policy: "$QUERYPOLICY"***"${NOCOLOR}""
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
      printf '\033[K'
      printf '%b\r' ""${GREEN}"Query Policy: No new IP Addresses detected for $QUERYPOLICY"${NOCOLOR}""
    fi
  fi

  # Determine Interface and Route Table for IP Routes.
  INTERFACE="$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $4}')"
  routingdirector || return

  # Create IPv4 and IPv6 Arrays from Policy File. 
  IPV6S="$(cat "/tmp/policy_"$QUERYPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
  IPV4S="$(cat "/tmp/policy_"$QUERYPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"
  
    if tty >/dev/null 2>&1;then
      printf '\033[K'
      printf '%b\r' ""${YELLOW}"Query Policy: Updating IP Routes and IP Rules"${NOCOLOR}""
    fi

    # Create IPv6 Routes
    for IPV6 in ${IPV6S};do
      if [ -z "$(ip -6 route list $IPV6 dev $INTERFACE)" ] >/dev/null;then
        echo -e "${YELLOW}Adding route for "$IPV6" dev "$INTERFACE"...${NOCOLOR}"
        if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
        logger -st "${0##*/}" "Query Policy - Adding route for "$IPV6" dev "$INTERFACE""
        fi
        ip -6 route add $IPV6 dev $INTERFACE
        echo -e "${GREEN}Route added for "$IPV6" dev "$INTERFACE".${NOCOLOR}"
        if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
          logger -st "${0##*/}" "Query Policy - Route added for "$IPV6" dev "$INTERFACE""
        fi
      fi
    done

  if [[ "$RGW" == "0" ]] >/dev/null;then
    # Create IPv4 Routes
    for IPV4 in ${IPV4S};do
      if [ -z "$(ip route list $IPV4 dev $INTERFACE table $ROUTETABLE)" ] >/dev/null;then
        echo -e "${YELLOW}Adding route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE"...${NOCOLOR}"
        if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
          logger -st "${0##*/}" "Query Policy - Adding route for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
        fi
        ip route add $IPV4 dev $INTERFACE table $ROUTETABLE
        echo -e "${GREEN}Route added for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE".${NOCOLOR}"
        if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
          logger -st "${0##*/}" "Query Policy - Route added for "$IPV4" dev "$INTERFACE" table "$ROUTETABLE""
        fi
      fi
    done
  elif [[ "$RGW" != "0" ]] >/dev/null;then
    # Create IPv4 Rules
    for IPV4 in ${IPV4S}; do
      if [ -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority "$PRIORITY")" ] >/dev/null;then
        echo -e "${YELLOW}Adding IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY"...${NOCOLOR}"
        if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
          logger -st "${0##*/}" "Query Policy - Adding IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
        fi
        ip rule add from all to $IPV4 table $ROUTETABLE priority $PRIORITY
        echo -e "${GREEN}IP Rule added for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY".${NOCOLOR}"
        if [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] >/dev/null;then
          logger -st "${0##*/}" "Query Policy - Added IP Rule for "$IPV4" table "$ROUTETABLE" priority "$PRIORITY""
        fi
      fi
    done
  fi
done
if tty >/dev/null 2>&1;then
  printf '\033[K'
fi
exit
}

# Cronjob
cronjob ()
{
if [ -z "$(cru l | grep -w "$0")" ] >/dev/null; then
  echo -e "${BLUE}Creating cron jobs...${NOCOLOR}"
  logger -t "${0##*/}" "Cron - Creating cron job"
  cru a setup_domain_vpn_routing "*/15 * * * *" $0 querypolicy all
  echo -e "${GREEN}Completed creating cron job.${NOCOLOR}"
  logger -t "${0##*/}" "Cron - Completed creating cron job"
fi
exit
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
