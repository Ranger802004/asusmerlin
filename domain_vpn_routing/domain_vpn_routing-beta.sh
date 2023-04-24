#!/bin/sh

# Domain VPN Routing for ASUS Routers using Merlin Firmware v386.7 or newer
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 4/24/2023
# Version: v2.0.0-beta1

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
ALIAS="domain_vpn_routing"
VERSION="v2.0.0-beta1"
REPO="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/"
GLOBALCONFIGFILE="/jffs/configs/domain_vpn_routing/global.conf"
CONFIGFILE="/jffs/configs/domain_vpn_routing/domain_vpn_routing.conf"
POLICYDIR="/jffs/configs/domain_vpn_routing"
SYSTEMLOG="/tmp/syslog.log"
LOCKFILE="/var/lock/domain_vpn_routing.lock"

# Checksum
if [[ -f "/usr/sbin/openssl" ]] &>/dev/null;then
  CHECKSUM="$(/usr/sbin/openssl sha256 "$0" | awk -F " " '{print $2}')"
elif [[ -f "/usr/bin/md5sum" ]] &>/dev/null;then
  CHECKSUM="$(/usr/bin/md5sum "$0" | awk -F " " '{print $1}')"
fi

# Color Codes
NOCOLOR="\033[0m"
BOLD="\033[1m"
FAINT="\033[2m"
UNDERLINE="\033[4m"
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
LIGHTGRAY="\033[37m"
GRAY="\033[90m"
LIGHTRED="\033[91m"
LIGHTGREEN="\033[92m"
LIGHTYELLOW="\033[93m"
LIGHTBLUE="\033[94m"
LIGHTMAGENTA="\033[95m"
LIGHTCYAN="\033[96m"
WHITE="\033[97m"

if [[ "$(dirname "$0")" == "." ]] &>/dev/null;then
  if [ -n "$(cat /jffs/configs/profile.add | grep -w "# domain_vpn_routing")" ]] &>/dev/null;then
    echo -e ""${BOLD}"${RED}***WARNING*** Execute using Alias: ${LIGHTBLUE}$ALIAS${RED}${NOCOLOR}.${NOCOLOR}"
  else
    SCRIPTPATH="/jffs/scripts/"${0##*/}""
    echo -e ""${BOLD}"${RED}***WARNING*** Execute using full script path ${LIGHTBLUE}"$SCRIPTPATH"${NOCOLOR}.${NOCOLOR}"
  fi
  exit
fi

# Set Script Mode
if [[ "$#" == "0" ]] &>/dev/null;then
  # Default to Menu Mode if no argument specified
  [[ -z "${mode+x}" ]] &>/dev/null && mode="menu"
elif [[ "$#" -gt "1" ]] &>/dev/null;then
  mode="$1"
  arg2="$2"
else
  mode="$1"
  arg2=""
fi
scriptmode ()
{
if [[ "${mode}" == "menu" ]] &>/dev/null;then
  if tty &>/dev/null;then
    trap 'return' EXIT HUP INT QUIT TERM
    menu || return
  else
    return
  fi
elif [[ "${mode}" == "install" ]] &>/dev/null;then
  install
elif [[ "${mode}" == "createpolicy" ]] &>/dev/null;then 
  createpolicy
elif [[ "${mode}" == "showpolicy" ]] &>/dev/null;then
  if [[ -z "$arg2" ]] &>/dev/null;then
    POLICY=all
    showpolicy
  else
    POLICY="$arg2"
    showpolicy
  fi
elif [[ "${mode}" == "editpolicy" ]] &>/dev/null;then 
  POLICY="$arg2"
  editpolicy
elif [[ "${mode}" == "deletepolicy" ]] &>/dev/null;then 
  POLICY="$arg2"
  deletepolicy
elif [[ "${mode}" == "querypolicy" ]] &>/dev/null;then 
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} - Query Policy already running...${NOCOLOR}" && exit ;}
  trap 'cleanup' EXIT HUP INT QUIT TERM
  POLICY="$arg2"
  querypolicy
elif [[ "${mode}" == "adddomain" ]] &>/dev/null;then 
  DOMAIN="$arg2"
  adddomain
elif [[ "${mode}" == "deletedomain" ]] &>/dev/null;then 
  DOMAIN="$arg2"
  deletedomain
elif [[ "${mode}" == "deleteip" ]] &>/dev/null;then 
  IP="$arg2"
  deleteip
elif [[ "${mode}" == "kill" ]] &>/dev/null;then 
  killscript
elif [[ "${mode}" == "uninstall" ]] &>/dev/null;then 
  uninstall
elif [[ "${mode}" == "cron" ]] &>/dev/null;then 
  cronjob
elif [[ "${mode}" == "update" ]] &>/dev/null;then 
  update
elif [[ "${mode}" == "config" ]] &>/dev/null;then 
  config
fi
exit
}

# Cleanup
cleanup ()
{
# Remove Lock File
logger -p 6 -t "$ALIAS" "Debug - Checking for Lock File: $LOCKFILE"
if [[ -f "$LOCKFILE" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting $LOCKFILE"
  rm -f $LOCKFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted $LOCKFILE" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete $LOCKFILE"
fi

return
}

# Menu
menu ()
{
        # Set Mode back to Menu if Changed
        [[ "$mode" != "menu" ]] &>/dev/null && mode="menu"

	clear
        # Buffer Menu
        output="$(
	sed -n '3,6p' "${0}"		# Display Banner
        printf "\n"
        printf "  ${BOLD}Information:${NOCOLOR}\n"
   	printf "  (1)  readme            View Domain VPN Routing Readme\n"
        printf "  (2)  showpolicy        View existing policies\n"
        printf "\n"
        printf "  ${BOLD}Installation/Configuration:${NOCOLOR}\n"
	printf "  (3)  install           Install Domain VPN Routing\n"
	printf "  (4)  uninstall         Uninstall Domain VPN Routing\n"
	printf "  (5)  config            Global Configuration Settings\n"
	printf "  (6)  update            Check for updates for Domain VPN Routing\n"
        printf "\n"
        printf "  ${BOLD}Operations:${NOCOLOR}\n"
   	printf "  (7)  cron              Schedule Cron Job to automate Query Policy for all policies\n"
        printf "  (8)  querypolicy       Perform a manual query of an existing policy\n"
        printf "  (9)  kill              Kill any running instances of Domain VPN Routing\n"
        printf "\n"
        printf "  ${BOLD}Policy Configuration:${NOCOLOR}\n"
        printf "  (10) createpolicy      Create Policy\n"
	printf "  (11) editpolicy        Edit Policy\n"
	printf "  (12) deletepolicy      Delete Policy\n"
	printf "  (13) adddomain         Add Domain to an existing Policy\n"
	printf "  (14) deletedomain      Delete Domain from an existing Policy\n"
	printf "  (15) deleteip          Delete IP from an existing Policy\n"
        printf "\n"
	printf "  (e)  exit              Exit Domain VPN Routing Menu\n"
	printf "\nMake a selection: "
        )"
        # Display Menu
        echo "$output" && unset output
	read -r input
	case "${input}" in
		'')
                        return
		;;
		'1')    # readme
                        README=""$REPO"readme.txt"
                        clear
                        /usr/sbin/curl --connect-timeout 30 --max-time 30 --url $README --ssl-reqd 2>/dev/null || echo -e "${RED}***Unable to access Readme***${NOCOLOR}"
		;;
		'2')    # showpolicy
			mode="showpolicy"
                        POLICY=all
                        showpolicy
			while true &>/dev/null;do  
                          read -p "Select the Policy You Want to View: " value
                          case $value in
                            * ) POLICY=$value; break;;
                          esac
                        done
                        showpolicy
                        unset value
		;;
		'3')    # install
			mode="install"
			install
		;;
		'4')    # uninstall
			mode="uninstall"
			uninstall
		;;
		'5')    # config
			mode="config"
                        config
		;;
		'6')    # update
			mode="update"
                        update
		;;
		'7')    # cron
			mode="cron"
                        cronjob
		;;
		'8')    # querypolicy
			mode="querypolicy"
                        POLICY=all
                        showpolicy
			while true &>/dev/null;do  
                          read -p "Select the Policy You Want to Query: " value
                          case $value in
                            * ) POLICY=$value; break;;
                          esac
                        done
                        querypolicy $value
                        unset value
                ;;
		'9')    # kill
			mode="kill"
                        killscript
		;;
		'10')    # createpolicy
			mode="createpolicy"
                        createpolicy
		;;
		'11')   # editpolicy
			mode="editpolicy"
                        POLICY=all
                        showpolicy
			while true &>/dev/null;do  
                          read -p "Select the Policy You Want to Edit: " value
                          case $value in
                            * ) POLICY=$value; break;;
                          esac
                        done
                        editpolicy $value
                        unset value
		;;
		'12')   # deletepolicy
			mode="deletepolicy"
                        POLICY=all
                        showpolicy
			while true &>/dev/null;do  
                          read -p "Select the Policy You Want to Delete: " value
                          case $value in
                            * ) POLICY=$value; break;;
                          esac
                        done
                        deletepolicy $value
                        unset value
		;;
		'13')   # adddomain
			mode="adddomain"
			while true &>/dev/null;do  
                          read -p "Select a domain to add to a policy: " value
                          case $value in
                            * ) DOMAIN=$value; break;;
                          esac
                        done
                        adddomain $DOMAIN
                        unset value
                        unset DOMAIN
		;;
		'14')   # deletedomain
			mode="deletedomain"
			while true &>/dev/null;do  
                          read -p "Select a domain to delete from a policy: " value
                          case $value in
                            * ) DOMAIN=$value; break;;
                          esac
                        done
                        deletedomain $DOMAIN
                        unset value
                        unset DOMAIN
		;;
		'15')   # deleteip
			mode="deleteip"
			while true &>/dev/null;do  
                          read -p "Select an IP Address to delete from a policy: " value
                          case $value in
                            * ) IP=$value; break;;
                          esac
                        done
                        deleteip $IP
                        unset value
                        unset IP
		;;
		'e'|'E'|'exit')
			exit 0
		;;
		*)
                echo -e "${RED}***Invalid Selection***${NOCOLOR}"
		;;
	esac
	PressEnter
	menu

}

PressEnter()
{
	printf "\n"
	while true &>/dev/null; do
		printf "Press Enter to continue..."
		read -r "key"
		case "${key}" in
			*)
				break
			;;
		esac
	done
        [[ "$mode" != "menu" ]] &>/dev/null && mode="menu"
	return 0
}


# Check Alias
checkalias ()
{
logger -p 6 -t "$ALIAS" "Debug - Checking Alias in /jffs/configs/profile.add"
if [[ ! -f "/jffs/configs/profile.add" ]] &>/dev/null;then
  logger -p 5 -st "$ALIAS" "Alias Check - Creating /jffs/configs/profile.add"
  touch -a /jffs/configs/profile.add \
  && chmod 666 /jffs/configs/profile.add \
  && logger -p 4 -st "$ALIAS" "Alias Check - Created /jffs/configs/profile.add" \
  || logger -p 2 -st "$ALIAS" "Alias Check - ***Error*** Unable to create /jffs/configs/profile.add"
fi
if [[ -z "$(cat /jffs/configs/profile.add | grep -w "# domain_vpn_routing")" ]] &>/dev/null;then
  logger -p 5 -st "$ALIAS" "Alias Check - Creating Alias for "$0" as domain_vpn_routing"
  echo -e "alias domain_vpn_routing=\"sh $0\" # domain_vpn_routing" >> /jffs/configs/profile.add \
  && source /jffs/configs/profile.add \
  && logger -p 4 -st "$ALIAS" "Alias Check - Created Alias for "$0" as domain_vpn_routing" \
  || logger -p 2 -st "$ALIAS" "Alias Check - ***Error*** Unable to create Alias for "$0" as domain_vpn_routing"
  . /jffs/configs/profile.add
fi
}

# Install
install ()
{
if [[ "${mode}" == "install" ]] &>/dev/null;then
  read -n 1 -s -r -p "Press any key to continue to install..."
  # Create Policy Directory
  echo -e "${BLUE}${0##*/} - Install: Creating "$POLICYDIR"...${NOCOLOR}"
  logger -t "$ALIAS" "Install - Creating "$POLICYDIR""
  if [[ ! -d "$POLICYDIR" ]] &>/dev/null;then
    mkdir -m 666 -p "$POLICYDIR"
    echo -e "${GREEN}${0##*/} - Install: "$POLICYDIR" created.${NOCOLOR}"
    logger -t "$ALIAS" "Install - "$POLICYDIR" created"
  else
    echo -e "${YELLOW}${0##*/} - Install: "$POLICYDIR" already exists...${NOCOLOR}"
    logger -t "$ALIAS" "Install - "$POLICYDIR" already exists"
  fi

  # Create Global Configuration File.
  echo -e "${BLUE}${0##*/} - Install: Creating "$GLOBALCONFIGFILE"...${NOCOLOR}"
  logger -t "$ALIAS" "Install - Creating "$GLOBALCONFIGFILE""
  if [[ ! -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
    touch -a "$GLOBALCONFIGFILE"
    chmod 666 "$GLOBALCONFIGFILE"
    setglobalconfig
    echo -e "${GREEN}${0##*/} - Install: "$GLOBALCONFIGFILE" created.${NOCOLOR}"
    logger -t "$ALIAS" "Install - "$GLOBALCONFIGFILE" created"
  else
    echo -e "${YELLOW}${0##*/} - Install: "$GLOBALCONFIGFILE" already exists...${NOCOLOR}"
    logger -t "$ALIAS" "Install - "$GLOBALCONFIGFILE" already exists"
  fi

  # Create Configuration File.
  echo -e "${BLUE}${0##*/} - Install: Creating "$CONFIGFILE"...${NOCOLOR}"
  logger -t "$ALIAS" "Install - Creating "$CONFIGFILE""
  if [[ ! -f "$CONFIGFILE" ]] &>/dev/null;then
    touch -a "$CONFIGFILE"
    chmod 666 "$CONFIGFILE"
    echo -e "${GREEN}${0##*/} - Install: "$CONFIGFILE" created.${NOCOLOR}"
    logger -t "$ALIAS" "Install - "$CONFIGFILE" created"
  else
    echo -e "${YELLOW}${0##*/} - Install: "$CONFIGFILE" already exists...${NOCOLOR}"
    logger -t "$ALIAS" "Install - "$CONFIGFILE" already exists"
  fi

  # Create wan-event if it doesn't exist
  echo -e "${BLUE}Creating wan-event script...${NOCOLOR}"
  logger -t "$ALIAS" "Install - Creating wan-event script"
    if [[ ! -f "/jffs/scripts/wan-event" ]] &>/dev/null;then
      touch -a /jffs/scripts/wan-event
      chmod 755 /jffs/scripts/wan-event
      echo "#!/bin/sh" >> /jffs/scripts/wan-event
      echo -e "${GREEN}wan-event script has been created.${NOCOLOR}"
      logger -t "$ALIAS" "Install - wan-event script has been created"
    else
      echo -e "${YELLOW}wan-event script already exists...${NOCOLOR}"
      logger -t "$ALIAS" "Install - wan-event script already exists"
    fi

  # Add Script to wan-event
  if [[ -n "$(cat /jffs/scripts/wan-event | grep -w "# domain_vpn_routing")" ]] &>/dev/null;then 
    echo -e "${YELLOW}${0##*/} already added to wan-Event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} already added to wan-Event"
  else
    cmdline="sh $0 cron"
    echo -e "${BLUE}Adding ${0##*/} to wan-event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - Adding ${0##*/} to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing" >> /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} added to wan-event.${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} added to wan-event"
  fi
  if [[ -n "$(cat /jffs/scripts/wan-event | grep -w "# domain_vpn_routing_queryall")" ]] &>/dev/null;then 
    echo -e "${YELLOW}${0##*/} already added to wan-event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} already added to wan-event"
  else
    cmdline="sh $0 querypolicy all"
    echo -e "${BLUE}Adding ${0##*/} to wan-event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - Adding ${0##*/} to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing_queryall" >> /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} added to wan-event.${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} added to wan-event"
  fi

  # Create openvpn-event if it doesn't exist
  echo -e "${BLUE}Creating openvpn-event script...${NOCOLOR}"
  logger -t "$ALIAS" "Install - Creating openvpn-event script"
    if [[ ! -f "/jffs/scripts/openvpn-event" ]] &>/dev/null;then
      touch -a /jffs/scripts/openvpn-event
      chmod 755 /jffs/scripts/openvpn-event
      echo "#!/bin/sh" >> /jffs/scripts/openvpn-event
      echo -e "${GREEN}openvpn-event script has been created.${NOCOLOR}"
      logger -t "$ALIAS" "Install - openvpn-event script has been created"
    else
      echo -e "${YELLOW}openvpn-event script already exists...${NOCOLOR}"
      logger -t "$ALIAS" "Install - openvpn-event script already exists"
    fi

  # Add Script to Openvpn-event
  if [[ -n "$(cat /jffs/scripts/openvpn-event | grep -w "# domain_vpn_routing")" ]] &>/dev/null;then 
    echo -e "${YELLOW}${0##*/} already added to Openvpn-Event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} already added to Openvpn-Event"
  else
    cmdline="sh $0 cron"
    echo -e "${BLUE}Adding ${0##*/} to Openvpn-Event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - Adding ${0##*/} to Openvpn-Event"
    echo -e "\r\n$cmdline # domain_vpn_routing" >> /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} added to Openvpn-event.${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} added to Openvpn-Event"
  fi
  if [[ -n "$(cat /jffs/scripts/openvpn-event | grep -w "# domain_vpn_routing_queryall")" ]] &>/dev/null;then 
    echo -e "${YELLOW}${0##*/} already added to Openvpn-Event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} already added to Openvpn-Event"
  else
    cmdline="sh $0 querypolicy all"
    echo -e "${BLUE}Adding ${0##*/} to Openvpn-Event...${NOCOLOR}"
    logger -t "$ALIAS" "Install - Adding ${0##*/} to Openvpn-Event"
    echo -e "\r\n$cmdline # domain_vpn_routing_queryall" >> /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} added to Openvpn-event.${NOCOLOR}"
    logger -t "$ALIAS" "Install - ${0##*/} added to Openvpn-Event"
  fi

  # Create Initial Cron Jobs
  cronjob || return

  # Check Alias
  checkalias || return

fi
return
}

# Uninstall
uninstall ()
{
if [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  read -n 1 -s -r -p "Press any key to continue to uninstall..."
  if [[ ! -d "$POLICYDIR" ]] &>/dev/null;then
    echo -e "${RED}${0##*/} - Uninstall: "${0##*/}" not installed...${NOCOLOR}"
    return
  fi

  # Remove Cron Job
  cronjob || return

  # Remove Script from wan-event
  cmdline="sh $0 cron"
  if [[ -n "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ]] &>/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from wan-event...${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removing Cron Job from wan-event"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from wan-event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removed Cron Job from wan-event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in wan-event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Cron Job doesn't exist in wan-event"
  fi
  cmdline="sh $0 querypolicy all"
  if [[ -n "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ]] &>/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from wan-event...${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removing Cron Job from wan-event"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from wan-event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removed Cron Job from wan-event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in wan-event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Cron Job doesn't exist in wan-event"
  fi

  # Remove Script from Openvpn-event
  cmdline="sh $0 cron"
  if [[ -n "$(cat /jffs/scripts/openvpn-event | grep -e "^$cmdline")" ]] &>/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Openvpn-Event...${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removing Cron Job from Openvpn-Event"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Openvpn-Event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removed Cron Job from Openvpn-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Openvpn-Event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Cron Job doesn't exist in Openvpn-Event"
  fi
  cmdline="sh $0 querypolicy all"
  if [[ -n "$(cat /jffs/scripts/openvpn-event | grep -e "^$cmdline")" ]] &>/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Openvpn-Event...${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removing Cron Job from Openvpn-Event"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/openvpn-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Openvpn-Event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removed Cron Job from Openvpn-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Openvpn-Event.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Cron Job doesn't exist in Openvpn-Event"
  fi

  # Delete Policies
  $0 deletepolicy all
  # Delete Policy Directory
  if [[ -d "$POLICYDIR" ]] &>/dev/null;then
    echo -e "${BLUE}${0##*/} - Uninstall: Deleting "$POLICYDIR"...${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Creating "$POLICYDIR""
    rm -rf "$POLICYDIR"
    echo -e "${GREEN}${0##*/} - Uninstall: "$POLICYDIR" deleted.${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - "$POLICYDIR" deleted"
  fi
  # Remove Lock File
  if [[ -f "$LOCKFILE" ]] &>/dev/null;then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing "$LOCKFILE"...${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removing "$LOCKFILE""
    rm -f "$LOCKFILE" 
    echo -e "${GREEN}${0##*/} - Uninstall: Removed "$LOCKFILE"...${NOCOLOR}"
    logger -t "$ALIAS" "Uninstall - Removed "$LOCKFILE""
  fi
fi
return
}

# Set Global Configuration
setglobalconfig ()
{
logger -p 6 -t "$ALIAS" "Debug - Reading "$GLOBALCONFIGFILE""
. $GLOBALCONFIGFILE

# Check Configuration File for Missing Settings and Set Default if Missing
[[ -z "${globalconfigsync+x}" ]] &>/dev/null && globalconfigsync="0"

if [[ "$globalconfigsync" == "0" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking for missing global configuration options"
  if [[ -z "$(sed -n '/\bDEVMODE=\b/p' "$GLOBALCONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating DEVMODE Default: Disabled"
    echo -e "DEVMODE=0" >> $GLOBALCONFIGFILE
  fi
  [[ "$globalconfigsync" == "0" ]] &>/dev/null && globalconfigsync="1"
fi

logger -p 6 -t "$ALIAS" "Debug - Reading "$GLOBALCONFIGFILE""
. $GLOBALCONFIGFILE

return
}

# Update Configuration from Pre-Version 2
updateconfigprev2 ()
{
# Create Global Configuration File.
if [[ -f "$CONFIGFILE" ]] &>/dev/null && [[ ! -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
  logger -t "$ALIAS" "Install - Creating "$GLOBALCONFIGFILE""
  if [[ ! -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
    touch -a "$GLOBALCONFIGFILE"
    chmod 666 "$GLOBALCONFIGFILE"
    setglobalconfig
    logger -t "$ALIAS" "Install - "$GLOBALCONFIGFILE" created"
  fi

  # Create wan-event if it doesn't exist
  if [[ ! -f "/jffs/scripts/wan-event" ]] &>/dev/null;then
    logger -t "$ALIAS" "Install - Creating wan-event script"
    touch -a /jffs/scripts/wan-event
    chmod 755 /jffs/scripts/wan-event
    echo "#!/bin/sh" >> /jffs/scripts/wan-event
    logger -t "$ALIAS" "Install - wan-event script has been created"
  fi

  # Add Script to wan-event
  if [[ -z "$(cat /jffs/scripts/wan-event | grep -w "# domain_vpn_routing")" ]] &>/dev/null;then 
    cmdline="sh $0 cron"
    logger -t "$ALIAS" "Install - Adding ${0##*/} to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing" >> /jffs/scripts/wan-event
    logger -t "$ALIAS" "Install - ${0##*/} added to wan-event"
  fi
  if [[ -z "$(cat /jffs/scripts/wan-event | grep -w "# domain_vpn_routing_queryall")" ]] &>/dev/null;then 
    cmdline="sh $0 querypolicy all"
    logger -t "$ALIAS" "Install - Adding ${0##*/} to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing_queryall" >> /jffs/scripts/wan-event
    logger -t "$ALIAS" "Install - ${0##*/} added to wan-event"
  fi
fi

if [[ -f "$CONFIGFILE" ]] &>/dev/null;then
  Lines="$(cat $CONFIGFILE)"
  c1="$(cat /etc/openvpn/client1/config.ovpn 2>/dev/null | grep -e dev -m 1 | awk '{print $2}')"
  c2="$(cat /etc/openvpn/client2/config.ovpn 2>/dev/null | grep -e dev -m 1 | awk '{print $2}')"
  c3="$(cat /etc/openvpn/client3/config.ovpn 2>/dev/null | grep -e dev -m 1 | awk '{print $2}')"
  c4="$(cat /etc/openvpn/client4/config.ovpn 2>/dev/null | grep -e dev -m 1 | awk '{print $2}')"
  c5="$(cat /etc/openvpn/client5/config.ovpn 2>/dev/null | grep -e dev -m 1 | awk '{print $2}')"
  s1="$(cat /etc/openvpn/server1/config.ovpn 2>/dev/null | grep -e dev -m 1 | awk '{print $2}')"
  s2="$(cat /etc/openvpn/server2/config.ovpn 2>/dev/null | grep -e dev -m 1 | awk '{print $2}')"

  for Line in $Lines;do
    if [[ -n "$(echo $Line | grep -e "$c1\|$c2\|$c3\|$c4\|$c5\|$s1\|$s2\|$(nvram get wan0_gw_ifname & nvramcheck)\|$(nvram get wan1_gw_ifname & nvramcheck)")" ]] &>/dev/null;then
      fixpolicy="$(echo "$Line" | awk -F "|" '{print $1}')"
      fixpolicydomainlist="$(echo "$Line" | awk -F "|" '{print $2}')"
      fixpolicydomainiplist="$(echo "$Line" | awk -F "|" '{print $3}')"
      fixpolicyinterface="$(echo "$Line" | awk -F "|" '{print $4}')"
      fixpolicyverboselog="$(echo "$Line" | awk -F "|" '{print $5}')"
      fixpolicyprivateips="$(echo "$Line" | awk -F "|" '{print $6}')"
      if [[ "$fixpolicyinterface" == "$c1" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc1"
      elif [[ "$fixpolicyinterface" == "$c2" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc2"
      elif [[ "$fixpolicyinterface" == "$c3" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc3"
      elif [[ "$fixpolicyinterface" == "$c4" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc4"
      elif [[ "$fixpolicyinterface" == "$c5" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc5"
      elif [[ "$fixpolicyinterface" == "$s1" ]] &>/dev/null;then
        fixpolicyinterface="ovpns1"
      elif [[ "$fixpolicyinterface" == "$s2" ]] &>/dev/null;then
        fixpolicyinterface="ovpns2"
      elif [[ "$fixpolicyinterface" == "$(nvram get wan0_gw_ifname & nvramcheck)" ]] &>/dev/null;then
        fixpolicyinterface="wan0"
      elif [[ "$fixpolicyinterface" == "$(nvram get wan1_gw_ifname & nvramcheck)" ]] &>/dev/null;then
        fixpolicyinterface="wan1"
      fi
      sed -i "\:"$Line":d" "$CONFIGFILE"
      echo -e "${fixpolicy}|${fixpolicydomainlist}|${fixpolicydomainiplist}|${fixpolicyinterface}|${fixpolicyverboselog}|${fixpolicyprivateips}" >> $CONFIGFILE
    else
      continue
    fi
  done

  unset Lines fixpolicy fixpolicydomainlist fixpolicydomainiplist fixpolicyinterface fixpolicyverboselog fixpolicyprivateips c1 c2 c3 c4 c5 s1 s2
elif [[ -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
  setglobalconfig
fi

return
}

# Configuration Menu
config ()
{
# Check for configuration and load configuration
if [[ -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
  setglobalconfig || return
else
  printf "${RED}***Domain VPN Routing is not Installed***${NOCOLOR}\n"
  if [[ "$mode" == "menu" ]] &>/dev/null;then
    printf "\n  (r)  return    Return to Main Menu"
    printf "\n  (e)  exit      Exit" 
  else
    printf "\n  (e)  exit      Exit" 
  fi
  printf "\nMake a selection: "

  read -r input
  case $input in
    'r'|'R'|'menu'|'return'|'Return' )
    clear
    menu
    break
    ;;

    'e'|'E'|'exit' )
    clear
    if [[ "$mode" == "menu" ]] &>/dev/null;then
      exit
    else
      return
    fi
    break
    ;;
    * ) continue;;
  esac
fi

# Check for configuration and load configuration
if [[ ! -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
  echo -e "${RED}Domain VPN Routing currently has no configuration file present{$NOCOLOR}"
elif [[ -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
  setglobalconfig || return
fi

# Load Config Menu
clear
printf "\n  ${BOLD}Global Settings:${NOCOLOR}\n"
printf "  (1) Configure Dev Mode              Dev Mode: " && { [[ "$DEVMODE" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "Disabled" ;} && printf "\n"

if [[ "$mode" == "menu" ]] &>/dev/null;then
  printf "\n  (r)  return    Return to Main Menu"
  printf "\n  (e)  exit      Exit" 
else
  printf "\n  (e)  exit      Exit" 
fi
printf "\nMake a selection: "

# Set Variables for Configuration Menu
[[ -z "${NEWVARIABLES+x}" ]] &>/dev/null && NEWVARIABLES=""
[[ -z "${RESTARTREQUIRED+x}" ]] &>/dev/null && RESTARTREQUIRED="0"
read -r configinput
case "${configinput}" in
  '1')      # DEVMODE
  while true &>/dev/null;do
    read -p "Do you want to enable Developer Mode? This defines if the Script is set to Developer Mode where updates will apply beta releases: ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETDEVMODE=1; break;;
      [Nn]* ) SETDEVMODE=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} DEVMODE=|$SETDEVMODE"
  ;;
  'e'|'E'|'exit')
  clear
  if [[ "$mode" == "menu" ]] &>/dev/null;then
    exit
  else
    return
  fi
  break
  ;;
esac

# Configure Changed Setting in Configuration File
if [[ -n "$NEWVARIABLES" ]] &>/dev/null;then
  for NEWVARIABLE in ${NEWVARIABLES};do
    if [[ -z "$(cat $GLOBALCONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $GLOBALCONFIGFILE
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $GLOBALCONFIGFILE
    elif [[ -n "$(cat $GLOBALCONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $GLOBALCONFIGFILE
    elif [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" == "CUSTOMLOGPATH=" ]] &>/dev/null;then
      [[ -n "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$GLOBALCONFIGFILE")" ]] &>/dev/null && sed -i '/CUSTOMLOGPATH=/d' $GLOBALCONFIGFILE
      echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')" >> $GLOBALCONFIGFILE
    fi
  done
  if [[ "$RESTARTREQUIRED" == "1" ]] &>/dev/null;then
    echo -e "${RED}***This change will require Domain VPN Routing to restart to take effect***${NOCOLOR}"
    PressEnter
    config
  fi
fi

# Unset Variables
[[ -n "${NEWVARIABLES+x}" ]] &>/dev/null && unset NEWVARIABLES
[[ -n "${configinput+x}" ]] &>/dev/null && unset configinput
[[ -n "${value+x}" ]] &>/dev/null && unset value
[[ -n "${RESTARTREQUIRED+x}" ]] &>/dev/null && unset RESTARTREQUIRED

# Return to Config Menu
config
}


routingdirector ()
{
logger -p 6 -t "$ALIAS" "Debug - Routing Director Interface: $INTERFACE"

if [[ "$INTERFACE" == "ovpnc1" ]] &>/dev/null;then
  IFNAME="$(cat /etc/openvpn/client1/config.ovpn | grep -e dev -m 1 | awk '{print $2}')"
  RGW=$(nvram get vpn_client1_rgw & nvramcheck)
  ROUTETABLE=ovpnc1
  PRIORITY="1000"
elif [[ "$INTERFACE" == "ovpnc2" ]] &>/dev/null;then
  IFNAME="$(cat /etc/openvpn/client2/config.ovpn | grep -e dev -m 1 | awk '{print $2}')"
  RGW=$(nvram get vpn_client2_rgw & nvramcheck)
  ROUTETABLE=ovpnc2
  PRIORITY="2000"
elif [[ "$INTERFACE" == "ovpnc3" ]] &>/dev/null;then
  IFNAME="$(cat /etc/openvpn/client3/config.ovpn | grep -e dev -m 1 | awk '{print $2}')"
  RGW=$(nvram get vpn_client3_rgw & nvramcheck)
  ROUTETABLE=ovpnc3
  PRIORITY="3000"
elif [[ "$INTERFACE" == "ovpnc4" ]] &>/dev/null;then
  IFNAME="$(cat /etc/openvpn/client4/config.ovpn | grep -e dev -m 1 | awk '{print $2}')"
  RGW=$(nvram get vpn_client4_rgw & nvramcheck)
  ROUTETABLE=ovpnc4
  PRIORITY="4000"
elif [[ "$INTERFACE" == "ovpnc5" ]] &>/dev/null;then
  IFNAME="$(cat /etc/openvpn/client5/config.ovpn | grep -e dev -m 1 | awk '{print $2}')"
  RGW=$(nvram get vpn_client5_rgw & nvramcheck)
  ROUTETABLE=ovpnc5
  PRIORITY="5000"
elif [[ "$INTERFACE" == "ovpns1" ]] &>/dev/null;then
  IFNAME="$(cat /etc/openvpn/server1/config.ovpn | grep -e dev -m 1 | awk '{print $2}')"
  ROUTETABLE=main
  RGW="0"
  PRIORITY="0"
elif [[ "$INTERFACE" == "ovpns2" ]] &>/dev/null;then
  IFNAME="$(cat /etc/openvpn/server2/config.ovpn | grep -e dev -m 1 | awk '{print $2}')"
  ROUTETABLE=main
  RGW="0"
  PRIORITY="0"
elif [[ "$INTERFACE" == "wan" ]] &>/dev/null;then
  if [[ "$(nvram get wan0_primary & nvramcheck)" == "1" ]] &>/dev/null;then
    IFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
    OLDIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
  elif [[ "$(nvram get wan1_primary & nvramcheck)" == "1" ]] &>/dev/null;then
    IFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
    OLDIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
  fi
  ROUTETABLE=main
  RGW="2"
  PRIORITY="150"
elif [[ "$INTERFACE" == "wan0" ]] &>/dev/null;then
  ROUTETABLE=100
  RGW="2"
  PRIORITY="150"
  IFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
  logger -p 6 -t "$ALIAS" "Debug - Checking WAN0 for Default Route in Routing Table 100"
  if [[ -z "$(ip route list default table 100 | grep -w "$(nvram get wan0_gw_ifname & nvramcheck)")" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Routing Director - Adding default route for WAN0 Routing Table via "$(nvram get wan0_gateway & nvramcheck)" dev "$(nvram get wan0_gw_ifname & nvramcheck)""
    ip route add default via $(nvram get wan0_gateway & nvramcheck) dev $(nvram get wan0_gw_ifname & nvramcheck) table 100 \
    && logger -p 4 -t "$ALIAS" "Routing Director - Added default route for WAN0 Routing Table via "$(nvram get wan0_gateway & nvramcheck)" dev "$(nvram get wan0_gw_ifname & nvramcheck)"" \
    || logger -p 2 -st "$ALIAS" "Routing Director - ***Error*** Unable to add default route for WAN0 Routing Table via "$(nvram get wan0_gateway & nvramcheck)" dev "$(nvram get wan0_gw_ifname & nvramcheck)""
  fi
elif [[ "$INTERFACE" == "wan1" ]] &>/dev/null;then
  ROUTETABLE=200
  RGW="2"
  PRIORITY="150"
  IFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
  logger -p 6 -t "$ALIAS" "Debug - Checking WAN1 for Default Route in Routing Table 200"
  if [[ -z "$(ip route list default table 200 | grep -w "$(nvram get wan1_gw_ifname & nvramcheck)")" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Routing Director - Adding default route for WAN1 Routing Table via "$(nvram get wan1_gateway & nvramcheck)" dev "$(nvram get wan1_gw_ifname & nvramcheck)""
    ip route add default via $(nvram get wan1_gateway & nvramcheck) dev $(nvram get wan1_gw_ifname & nvramcheck) table 200 \
    && logger -p 4 -t "$ALIAS" "Routing Director - Added default route for WAN1 Routing Table via "$(nvram get wan1_gateway & nvramcheck)" dev "$(nvram get wan1_gw_ifname & nvramcheck)"" \
    || logger -p 2 -st "$ALIAS" "Routing Director - ***Error*** Unable to add default route for WAN1 Routing Table via "$(nvram get wan1_gateway & nvramcheck)" dev "$(nvram get wan1_gw_ifname & nvramcheck)""
  fi

else
  echo -e "${RED}Policy: Unable to query Interface${NOCOLOR}"
  return
fi
return
}

# Create Policy
createpolicy ()
{
if [[ "${mode}" == "createpolicy" ]] &>/dev/null;then
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
    if [[ -f "$OVPNCONFIGFILE" ]] &>/dev/null;then
      if [[ -n "$(echo $OVPNCONFIGFILE | grep -e "client")" ]] &>/dev/null;then
        INTERFACE="ovpnc"$(echo $OVPNCONFIGFILE | grep -o '[0-9]')""
      elif [[ -n "$(echo $OVPNCONFIGFILE | grep -e "server")" ]] &>/dev/null;then
        INTERFACE="ovpns"$(echo $OVPNCONFIGFILE | grep -o '[0-9]')""
      fi
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done

  if [[ "$(nvram get wans_dualwan & nvramcheck | awk '{print $2}')" == "none" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
  elif [[ "$(nvram get wans_dualwan & nvramcheck | awk '{print $2}')" != "none" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
    INTERFACES="${INTERFACES} wan0"
    INTERFACES="${INTERFACES} wan1"
  fi

  echo -e "Interfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "$INTERFACE"
  done
  # User Input for Interface
  while true;do  
    read -p "Select an Interface for this Policy: " NEWPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [[ "$NEWPOLICYINTERFACE" == "${INTERFACE}" ]] &>/dev/null;then
        CREATEPOLICYINTERFACE=$NEWPOLICYINTERFACE
        break 2
      elif [[ -n "$(echo "${INTERFACES}" | grep -w "$NEWPOLICYINTERFACE")" ]] &>/dev/null;then
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
    if [[ ! -f $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist' ]] &>/dev/null;then
      echo -e "${BLUE}${0##*/} - Create Policy: Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist...${NOCOLOR}"
      logger -t "$ALIAS" "Create Policy - Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist"
      touch -a $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist'
      chmod 666 $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist'
      echo -e "${GREEN}${0##*/} - Create Policy: "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist created.${NOCOLOR}"
      logger -t "$ALIAS" "Create Policy - "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist created"
    fi
    if [[ ! -f $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP' ]] &>/dev/null;then
      echo -e "${BLUE}${0##*/} - Create Policy: Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP...${NOCOLOR}"
      logger -t "$ALIAS" "Create Policy - Creating "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP"
      touch -a $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP'
      chmod 666 $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP'
      echo -e "${GREEN}${0##*/} - Create Policy: "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP created.${NOCOLOR}"
      logger -t "$ALIAS" "Create Policy - "$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domaintoIP created"
    fi
  # Adding Policy to Config File
  echo -e "${BLUE}Create Policy - Adding "$CREATEPOLICYNAME" to "$CONFIGFILE"...${NOCOLOR}"
  logger -t "$ALIAS" "Create Policy - Adding "$CREATEPOLICYNAME" to "$CONFIGFILE""
    if [[ -z "$(cat $CONFIGFILE | grep -w "$(echo $CREATEPOLICYNAME | awk -F"|" '{print $1}')")" ]] &>/dev/null;then
      echo -e ""$CREATEPOLICYNAME"|"$POLICYDIR"/policy_"$CREATEPOLICYNAME"_domainlist|"$POLICYDIR"/policy_"$CREATEPOLICYNAME"_"domaintoIP"|"$CREATEPOLICYINTERFACE"|"$SETVERBOSELOGGING"|"$SETPRIVATEIPS"" >> $CONFIGFILE
      echo -e "${GREEN}Create Policy - Added "$CREATEPOLICYNAME" to "$CONFIGFILE"...${NOCOLOR}"
      logger -t "$ALIAS" "Create Policy - Added "$CREATEPOLICYNAME" to "$CONFIGFILE""
    else
      echo -e "${YELLOW}"$CREATEPOLICYNAME" already exists in "$CONFIGFILE"...${NOCOLOR}"
      logger -t "$ALIAS" "Create Policy - "$CREATEPOLICYNAME" already exists in $CONFIGFILE"
    fi
fi
}

# Show Policy
showpolicy ()
{
if [[ "$POLICY" == "all" ]] &>/dev/null;then
  echo -e "Policies: \n$(cat "$CONFIGFILE" | awk -F"|" '{print $1}')"
  return
elif [[ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ]] &>/dev/null;then
  echo "Policy Name: "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")""
  echo "Interface: "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $4}')""
  if [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] &>/dev/null;then
    echo "Verbose Logging: Enabled"
  elif [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=0" ]] &>/dev/null;then
    echo "Verbose Logging: Disabled"
  elif [[ -z "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $5}')" ]] &>/dev/null;then
    echo "Verbose Logging: Not Configured"
  fi
  if [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=1" ]] &>/dev/null;then
    echo "Private IP Addresses: Enabled"
  elif [[ "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=0" ]] &>/dev/null;then
    echo "Private IP Addresses: Disabled"
  elif [[ -z "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $6}')" ]] &>/dev/null;then
    echo "Private IP Addresses: Not Configured"
  fi
  DOMAINS="$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')")"
  echo -e "Domains:"
  for DOMAIN in ${DOMAINS};do
    echo -e "${DOMAIN}"
  done
  return
else
  echo -e "${RED}Policy: "$POLICY" not found${NOCOLOR}"
  return
fi
return
}

# Edit Policy
editpolicy ()
{
if [[ "${mode}" == "editpolicy" ]] &>/dev/null;then
  if [[ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ]] &>/dev/null;then
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
    if [[ -f "$OVPNCONFIGFILE" ]] &>/dev/null;then
      if [[ -n "$(echo $OVPNCONFIGFILE | grep -e "client")" ]] &>/dev/null;then
        INTERFACE="ovpnc"$(echo $OVPNCONFIGFILE | grep -o '[0-9]')""
      elif [[ -n "$(echo $OVPNCONFIGFILE | grep -e "server")" ]] &>/dev/null;then
        INTERFACE="ovpns"$(echo $OVPNCONFIGFILE | grep -o '[0-9]')""
      fi
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done

  if [[ "$(nvram get wans_dualwan & nvramcheck | awk '{print $2}')" == "none" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
  elif [[ "$(nvram get wans_dualwan & nvramcheck | awk '{print $2}')" != "none" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
    INTERFACES="${INTERFACES} wan0"
    INTERFACES="${INTERFACES} wan1"
  fi

  echo -e "\nInterfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "$INTERFACE"
  done

  # User Input for Interface
  while true;do  
    read -p "Select an Interface for this Policy: " EDITPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [[ "$EDITPOLICYINTERFACE" == "${INTERFACE}" ]] &>/dev/null;then
        NEWPOLICYINTERFACE=$EDITPOLICYINTERFACE
        break 2
      elif [[ -n "$(echo "${INTERFACES}" | grep -w "$EDITPOLICYINTERFACE")" ]] &>/dev/null;then
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
  logger -t "$ALIAS" "Edit Policy - Modifying "$EDITPOLICY" in "$CONFIGFILE""
  if [[ -n "$(cat $CONFIGFILE | grep -w "$(echo $EDITPOLICY | awk -F"|" '{print $1}')")" ]] &>/dev/null;then
    OLDINTERFACE="$(cat "$CONFIGFILE" | grep -w "$EDITPOLICY" | awk -F"|" '{print $4}')"
    sed -i "\:"$EDITPOLICY":d" "$CONFIGFILE"
    echo -e ""$EDITPOLICY"|"$POLICYDIR"/policy_"$EDITPOLICY"_domainlist|"$POLICYDIR"/policy_"$EDITPOLICY"_"domaintoIP"|"$NEWPOLICYINTERFACE"|"$SETVERBOSELOGGING"|"$SETPRIVATEIPS"" >> $CONFIGFILE
    echo -e "${GREEN}Edit Policy - Modified "$EDITPOLICY" in "$CONFIGFILE"...${NOCOLOR}"
    logger -t "$ALIAS" "Edit Policy - Modified "$EDITPOLICY" in "$CONFIGFILE""
  else
    echo -e "${YELLOW}"$EDITPOLICY" not found in "$CONFIGFILE"...${NOCOLOR}"
    logger -t "$ALIAS" "Edit Policy - "$EDITPOLICY" not found in $CONFIGFILE"
  fi
  
  # Check if Routes need to be modified
  if [[ "$NEWPOLICYINTERFACE" != "$OLDINTERFACE" ]] &>/dev/null;then

INTERFACES='
'$OLDINTERFACE'
'$NEWPOLICYINTERFACE'
'

    for INTERFACE in ${INTERFACES};do
      routingdirector || return
      if [[ "$INTERFACE" == "$OLDINTERFACE" ]] &>/dev/null;then
        OLDROUTETABLE=$ROUTETABLE
        OLDRGW=$RGW
        OLDPRIORITY=$PRIORITY
        OLDIFNAME=$IFNAME
      elif [[ "$INTERFACE" == "$NEWPOLICYINTERFACE" ]] &>/dev/null;then
        NEWROUTETABLE=$ROUTETABLE
        NEWRGW=$RGW
        NEWPRIORITY=$PRIORITY
        NEWIFNAME=$IFNAME
      fi
    done

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(cat "$POLICYDIR/policy_"$EDITPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
    IPV4S="$(cat "$POLICYDIR/policy_"$EDITPOLICY"_domaintoIP" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"

    # Recreate IPv6 Routes
      for IPV6 in ${IPV6S}; do
        if [[ -n "$(ip -6 route list $IPV6 dev $OLDIFNAME)" ]] &>/dev/null;then
          logger -t "$ALIAS" "Edit Policy - Deleting route for $IPV6 dev $OLDIFNAME"
          $(ip -6 route del $IPV6 dev $OLDIFNAME) \
          && logger -t "$ALIAS" "Edit Policy - Route deleted for $IPV6 dev $OLDIFNAME" \
          || logger -st "$ALIAS" "Edit Policy - ***Error*** Unable to delete route for $IPV6 dev $OLDIFNAME"
        fi
        if [[ -z "$(ip -6 route list $IPV6 dev $NEWPOLICYIFNAME)" ]] &>/dev/null;then
          logger -t "$ALIAS" "Edit Policy - Adding route for $IPV6 dev $EDITPOLICYIFNAME"
          ip -6 route add $IPV6 dev $NEWIFNAME \
          && logger -t "$ALIAS" "Edit Policy - Route added for $IPV6 dev $NEWIFNAME" \
          || logger -st "$ALIAS" "Edit Policy - ***Error*** Unable to add route for $IPV6 dev $NEWIFNAME"
        fi
      done

      # Recreate IPv4 Routes and IP Rules
      for IPV4 in ${IPV4S}; do
        if [[ "$OLDRGW" == "0" ]] &>/dev/null;then
          if [[ -n "$(ip route list $IPV4 dev $OLDIFNAME table $OLDROUTETABLE)" ]] &>/dev/null;then
            logger -t "$ALIAS" "Edit Policy - Deleting route for $IPV4 dev $OLDIFNAME table $OLDROUTETABLE"
            $(ip route del $IPV4 dev $OLDIFNAME table $OLDROUTETABLE) \
            && logger -t "$ALIAS" "Edit Policy - Route deleted for $IPV4 dev $OLDIFNAME table $OLDROUTETABLE" \
            || logger -st "$ALIAS" "Edit Policy - ***Error*** Unable to delete route for $IPV4 dev $OLDIFNAME table $OLDROUTETABLE"
          fi
        elif [[ "$OLDRGW" != "0" ]] &>/dev/null;then
          if [[ -n "$(ip rule list from all to $IPV4 lookup $OLDROUTETABLE priority $OLDPRIORITY)" ]] &>/dev/null;then
            logger -t "$ALIAS" "Edit Policy - Deleting IP Rule for $IPV4 table $OLDROUTETABLE priority $OLDPRIORITY"
            $(ip rule del from all to $IPV4 table $OLDROUTETABLE priority $OLDPRIORITY) \
            && logger -t "$ALIAS" "Edit Policy - Deleted IP Rule for $IPV4 table $OLDROUTETABLE priority $OLDPRIORITY" \
            || logger -st "$ALIAS" "Edit Policy - ***Error*** Unable to delete IP Rule for $IPV4 table $OLDROUTETABLE priority $OLDPRIORITY"
          fi
        fi
        if [[ "$NEWRGW" == "0" ]] &>/dev/null;then
          if [[ -z "$(ip route list $IPV4 dev $NEWIFNAME table $NEWROUTETABLE)" ]] &>/dev/null;then
            logger -t "$ALIAS" "Edit Policy - Adding route for $IPV4 dev $NEWIFNAME table $NEWROUTETABLE"
            ip route add $IPV4 dev $NEWIFNAME table $NEWROUTETABLE \
            && logger -t "$ALIAS" "Edit Policy - Route added for $IPV4 dev $NEWIFNAME table $NEWROUTETABLE" \
            || logger -st "$ALIAS" "Edit Policy - ***Error*** Unable to add route for $IPV4 dev $NEWIFNAME table $NEWROUTETABLE"
          fi
        elif [[ "$NEWRGW" != "0" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from all to $IPV4 lookup $NEWROUTETABLE priority $NEWPRIORITY)" ]] &>/dev/null;then
            logger -t "$ALIAS" "Edit Policy - Adding IP Rule for $IPV4 table $NEWROUTETABLE priority $NEWPRIORITY"
            $(ip rule add from all to $IPV4 table $NEWROUTETABLE priority $NEWPRIORITY) \
            && logger -t "$ALIAS" "Edit Policy - Added IP Rule for $IPV4 table $NEWROUTETABLE priority $NEWPRIORITY" \
            || logger -st "$ALIAS" "Edit Policy - ***Error*** Unable to add IP Rule for $IPV4 table $NEWROUTETABLE priority $NEWPRIORITY"
          fi
        fi
      done
  fi
fi
}

# Delete Policy
deletepolicy ()
{
if [[ "${mode}" == "deletepolicy" ]] &>/dev/null;then
  if [[ "$POLICY" == "all" ]] &>/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to delete all policies"
    DELETEPOLICIES="$(cat "$CONFIGFILE" | awk -F"|" '{print $1}')"
  elif [[ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ]] &>/dev/null;then
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
      if [[ -n "$(ip -6 route list $IPV6 dev $IFNAME)" ]] &>/dev/null;then
        logger -t "$ALIAS" "Delete Policy - Deleting route for $IPV6 dev $IFNAME"
        $(ip -6 route del $IPV6 dev $IFNAME) \
        && logger -t "$ALIAS" "Delete Policy - Route deleted for $IPV6 dev $IFNAME" \
        || logger -st "$ALIAS" "Delete Policy - ***Error*** Unable to delete route for $IPV6 dev $IFNAME"
      fi
    done

    # Delete IPv4 Routes and IP Rules
    for IPV4 in ${IPV4S};do
      if [[ "$RGW" == "0" ]] &>/dev/null;then
        if [[ -n "$(ip route list $IPV4 dev $IFNAME table $ROUTETABLE)" ]] &>/dev/null;then
          logger -t "$ALIAS" "Delete Policy - Deleting route for $IPV4 dev $IFNAME table $ROUTETABLE"
          $(ip route del $IPV4 dev $IFNAME table $ROUTETABLE) \
          && logger -t "$ALIAS" "Delete Policy - Route deleted for $IPV4 dev $IFNAME table $ROUTETABLE" \
          || logger -st "$ALIAS" "Delete Policy - ***Error*** Unable to delete route for $IPV4 dev $IFNAME table $ROUTETABLE"
        fi
      elif [[ "$RGW" != "0" ]] &>/dev/null;then
        if [[ -n "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority $PRIORITY)" ]] &>/dev/null;then
          logger -t "$ALIAS" "Delete Policy - Deleting IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
          $(ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY) \
          && logger -t "$ALIAS" "Delete Policy - Deleted IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY" \
          || logger -st "$ALIAS" "Delete Policy - ***Error*** Unable to delete IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
        fi
      fi
    done

    # Removing Policy Files
    if [[ -f ""$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist" ]] &>/dev/null;then
      echo -e "${BLUE}${0##*/} - Delete Policy: Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist...${NOCOLOR}"
      logger -t "$ALIAS" "Delete Policy - Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist"
      rm -f "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist
      echo -e "${GREEN}${0##*/} - Delete Policy: "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist deleted.${NOCOLOR}"
      logger -t "$ALIAS" "Delete Policy - "$POLICYDIR"/policy_"$DELETEPOLICY"_domainlist deleted"
    fi
    if [[ -f ""$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP" ]] &>/dev/null;then
      echo -e "${BLUE}${0##*/} - Delete Policy: Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP...${NOCOLOR}"
      logger -t "$ALIAS" "Delete Policy - Deleting "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP"
      rm -f "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP
      echo -e "${GREEN}${0##*/} - Delete Policy: "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP deleted.${NOCOLOR}"
      logger -t "$ALIAS" "Delete Policy - "$POLICYDIR"/policy_"$DELETEPOLICY"_domaintoIP deleted"
    fi
    # Removing Policy from Config File
    if [[ -n "$(cat "$CONFIGFILE" | grep -w "$(echo "$DELETEPOLICY" | awk -F"|" '{print $1}')")" ]] &>/dev/null;then
      echo -e "${BLUE}Delete Policy - Deleting "$DELETEPOLICY" from "$CONFIGFILE"...${NOCOLOR}"
      logger -t "$ALIAS" "Delete Policy - Deleting "$DELETEPOLICY" to "$CONFIGFILE""
      POLICYTODELETE="$(cat "$CONFIGFILE" | grep -w "$DELETEPOLICY")"
      sed -i "\:"$POLICYTODELETE":d" "$CONFIGFILE"
      echo -e "${GREEN}Delete Policy - Deleted "$POLICY" from "$CONFIGFILE"...${NOCOLOR}"
      logger -t "$ALIAS" "Delete Policy - Deleted "$POLICY" from "$CONFIGFILE""
    fi
  done
fi
exit
}

# Add Domain to Policy
adddomain ()
{
if [[ -n "$DOMAIN" ]] &>/dev/null;then
  # Select Policy for New Domain
  POLICIES="$(cat $CONFIGFILE | awk -F"|" '{print $1}')"
  echo -e "${BLUE}Select a Policy for the new Domain:${NOCOLOR} \r\n"$POLICIES""
  # User Input for Policy for New Domain
  while true;do  
    read -p "Policy: " NEWDOMAINPOLICY
    for POLICY in ${POLICIES};do
      if [[ "$NEWDOMAINPOLICY" == "${POLICY}" ]] &>/dev/null;then
        POLICY=$NEWDOMAINPOLICY
        break 2
      elif [[ -n "$(echo "${POLICIES}" | grep -w "$NEWDOMAINPOLICY")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a Valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n"${POLICIES}""
        break 1
      fi
    done
  done

  if [[ -z "$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')" | grep -w "$DOMAIN")" ]] &>/dev/null;then
    echo -e "${YELLOW}Add Domain - Adding "$DOMAIN" to Policy: "$POLICY"${NOCOLOR}"
    logger -t "$ALIAS" "Add Domain - Adding "$DOMAIN" to "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
    echo -e "$DOMAIN" >> "$(cat $CONFIGFILE | grep -w "$POLICY" | awk -F"|" '{print $2}')"
    echo -e "${GREEN}Add Domain - Added "$DOMAIN" to Policy: "$POLICY"${NOCOLOR}"
    logger -t "$ALIAS" "Add Domain - Added "$DOMAIN" to "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
  else
    echo -e "${RED}***Domain already added to $POLICY***${NOCOLOR}"
  fi
elif [[ -z "$DOMAIN" ]] &>/dev/null;then
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
      if [[ "$DELETEDOMAINPOLICY" == "${POLICY}" ]] &>/dev/null;then
        POLICY=$DELETEDOMAINPOLICY
        break 2
      elif [[ -n "$(echo "${POLICIES}" | grep -w "$DELETEDOMAINPOLICY")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n"${POLICIES}""
        break 1
      fi
    done
  done

if [[ -n "$DOMAIN" ]] &>/dev/null;then
  if [[ -n "$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')" | grep -w "$DOMAIN")" ]] &>/dev/null;then
    # Determine Interface and Route Table for IP Routes to delete.
    INTERFACE="$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $4}')"
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -w "$DOMAIN" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
    IPV4S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -w "$DOMAIN" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"
 
    # Delete IPv6 Routes
    for IPV6 in ${IPV6S};do
      if [[ -n "$(ip -6 route list $IPV6 dev $IFNAME)" ]] &>/dev/null;then
        echo -e "${YELLOW}Deleting route for $IPV6 dev $IFNAME...${NOCOLOR}"
        logger -t "$ALIAS" "Delete Domain - Deleting route for $IPV6 dev $IFNAME"
        $(ip -6 route del $IPV6 dev $IFNAME)
        echo -e "${GREEN}Route deleted for $IPV6 dev $IFNAME.${NOCOLOR}"
        logger -t "$ALIAS" "Delete Domain - Route deleted for $IPV6 dev $IFNAME"
      fi
    done

  if [[ "$RGW" == "0" ]] &>/dev/null;then
    # Delete IPv4 Routes
    for IPV4 in ${IPV4S};do
      if [[ -n "$(ip route list $IPV4 dev $IFNAME table $ROUTETABLE)" ]] &>/dev/null;then
        echo -e "${YELLOW}Deleting route for $IPV4 dev $IFNAME table $ROUTETABLE...${NOCOLOR}"
        logger -t "$ALIAS" "Delete Domain - Deleting route for $IPV4 dev $IFNAME table $ROUTETABLE"
        $(ip route del $IPV4 dev $IFNAME table $ROUTETABLE)
        echo -e "${GREEN}Route deleted for $IPV4 dev $IFNAME table $ROUTETABLE.${NOCOLOR}"
        logger -t "$ALIAS" "Delete Domain - Route deleted for $IPV4 dev $IFNAME table $ROUTETABLE"
      fi
    done

  elif [[ "$RGW" != "0" ]] &>/dev/null;then
    # Delete IPv4 IP Rules
    for IPV4 in ${IPV4S};do
      if [[ -n "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority $PRIORITY)" ]] &>/dev/null;then
        echo -e "${YELLOW}Deleting IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY...${NOCOLOR}"
        logger -t "$ALIAS" "Delete Domain - Deleting IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
        ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY
        echo -e "${GREEN}IP Rule deleted for $IPV4 table $ROUTETABLE priority $PRIORITY.${NOCOLOR}"
        logger -t "$ALIAS" "Delete Domain - Deleted IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
      fi
    done
  fi

    # Delete Domain from Policy
    echo -e "${YELLOW}Delete Domain - Deleting "$DOMAIN" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "$ALIAS" "Delete Domain - Deleting "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
    logger -t "$ALIAS" "Delete Domain - Deleting "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
    sed -i "\:"$DOMAIN":d" "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')"
    sed -i "\:"^$DOMAIN":d" "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')"
    echo -e "${GREEN}Delete Domain - Deleted "$DOMAIN" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "$ALIAS" "Delete Domain - Deleted "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $2}')""
    logger -t "$ALIAS" "Delete Domain - Deleted "$DOMAIN" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
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
      if [[ "$DELETEIPPOLICY" == "${POLICY}" ]] &>/dev/null;then
        POLICY=$DELETEIPPOLICY
        break 2
      elif [[ -n "$(echo "${POLICIES}" | grep -w "$DELETEIPPOLICY")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n"${POLICIES}""
        break 1
      fi
    done
  done

if [[ -n "$IP" ]] &>/dev/null;then
  if [[ -n "$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')" | grep -w "$IP")" ]] &>/dev/null;then
    # Determine Interface and Route Table for IP Routes to delete.
    INTERFACE="$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $4}')"
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -m 1 -w "$IP" | awk -F'>>' '{print $2}' | awk '/:/' | sort -u)"
    IPV4S="$(cat "$POLICYDIR/policy_"$POLICY"_domaintoIP" | grep -m 1 -w "$IP" | awk -F'>>' '{print $2}' | awk '!/:/' | sort -u)"
 
    # Delete IPv6 Routes
    for IPV6 in ${IPV6S}; do
      if [[ -n "$(ip -6 route list $IPV6 dev $IFNAME)" ]] &>/dev/null;then
        logger -t "$ALIAS" "Delete IP - Deleting route for $IPV6 dev $IFNAME"
        $(ip -6 route del $IPV6 dev $IFNAME) \
        && logger -t "$ALIAS" "Delete IP - Route deleted for $IPV6 dev $IFNAME" \
        || logger -st "$ALIAS" "Delete IP - ***Error*** Unable to delete route for $IPV6 dev $IFNAME"

      fi
    done

    if [[ "$RGW" == "0" ]] &>/dev/null;then
      # Delete IPv4 Routes
      for IPV4 in ${IPV4S}; do
        if [[ -n "$(ip route list $IPV4 dev $IFNAME table $ROUTETABLE)" ]] &>/dev/null;then
          logger -t "$ALIAS" "Delete IP - Deleting route for $IPV4 dev $IFNAME table $ROUTETABLE"
          $(ip route del $IPV4 dev $IFNAME table $ROUTETABLE) \
          && logger -t "$ALIAS" "Delete IP - Route deleted for $IPV4 dev $IFNAME table $ROUTETABLE" \
          || logger -st "$ALIAS" "Delete IP - ***Error*** Unable to delete route for $IPV4 dev $IFNAME table $ROUTETABLE"
        fi
      done
    elif [[ "$RGW" != "0" ]] &>/dev/null;then
      # Delete IPv4 IP Rules
      for IPV4 in ${IPV4S};do
        if [[ -n "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority $PRIORITY)" ]] &>/dev/null;then
          logger -t "$ALIAS" "Delete IP - Deleting IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
          ip rule del from all to $IPV4 table $ROUTETABLE priority $PRIORITY \
          && logger -st "$ALIAS" "Delete IP - Deleted IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY" \
          || logger -st "$ALIAS" "Delete IP - ***Error*** Unable to delete IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
        fi
      done
    fi

    # Delete IP from Policy
    echo -e "${YELLOW}Delete IP - Deleting "$IP" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "$ALIAS" "Delete IP - Deleting "$IP" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
    DELETEDOMAINTOIPS="$(cat "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')" | grep -w "$IP")"
    for DELETEDOMAINTOIP in ${DELETEDOMAINTOIPS}; do
    sed -i "\:"^${DELETEDOMAINTOIP}":d" "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')"
    done
    echo -e "${GREEN}Delete IP - Deleted "$IP" from Policy: "$POLICY"${NOCOLOR}"
    logger -t "$ALIAS" "Delete IP - Deleted "$IP" from "$(cat "$CONFIGFILE" | grep -w "$POLICY" | awk -F"|" '{print $3}')""
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

renice -n 20 $$

if [[ "$POLICY" == "all" ]] &>/dev/null;then
  QUERYPOLICIES="$(cat "$CONFIGFILE" | awk -F"|" '{print $1}')"
  if [[ -z "$QUERYPOLICIES" ]] &>/dev/null;then
    echo -e "${RED}***No Policies Detected***${NOCOLOR}"
    logger -t "$ALIAS" "Query Policy - ***No Policies Detected***"
    exit
  fi
elif [[ "$POLICY" == "$(cat "$CONFIGFILE" | awk -F"|" '{print $1}' | grep -w "$POLICY")" ]] &>/dev/null;then
  QUERYPOLICIES=$POLICY
else
  echo -e "${RED}Policy: "$POLICY" not found${NOCOLOR}"
  exit
fi
for QUERYPOLICY in ${QUERYPOLICIES};do
  # Create Temporary File for Sync
  if [[ ! -f "/tmp/policy_"$QUERYPOLICY"_domaintoIP" ]] &>/dev/null;then
    touch -a "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
  fi

  # Compare Policy File to Temporary File
  if ! diff "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP" "/tmp/policy_"$QUERYPOLICY"_domaintoIP" &>/dev/null;then
    cp "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP" "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
  fi

  # Check if Verbose Logging is Enabled
  [[ -z "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" ]] && VERBOSELOGGING=1
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=0" ]] && VERBOSELOGGING=0
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $5}')" == "VERBOSELOGGING=1" ]] && VERBOSELOGGING=1

  # Check if Private IPs are Enabled
  [[ -z "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" ]] && PRIVATEIPS=0
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=0" ]] && PRIVATEIPS=0
  [[ "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $6}')" == "PRIVATEIPS=1" ]] && PRIVATEIPS=1

  # Query Domains for IP Addresses
  DOMAINS="$(cat "$(cat "$CONFIGFILE" | grep -w "$QUERYPOLICY" | awk -F"|" '{print $2}')")"
  for DOMAIN in ${DOMAINS};do
    [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Policy: $QUERYPOLICY Querying "$DOMAIN""
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' ""${YELLOW}"Query Policy: $QUERYPOLICY Querying "$DOMAIN"..."${NOCOLOR}""
    fi
    for IP in $(nslookup $DOMAIN 2>/dev/null | awk '(NR>2) && /^Address/ {print $3}' | sort); do
      if [[ "$PRIVATEIPS" == "1" ]] &>/dev/null;then
        echo $DOMAIN'>>'$IP >> "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
      elif [[ "$PRIVATEIPS" == "0" ]] &>/dev/null;then
        if [[ -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
          echo $DOMAIN'>>'$IP >> "/tmp/policy_"$QUERYPOLICY"_domaintoIP"
        elif [[ -n "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
          [[ "$VERBOSELOGGING" == "1" ]] && logger -st "$ALIAS" "Query Policy - Domain: "$DOMAIN" queried "$IP" ***Excluded because Private IPs are disabled for Policy: "$QUERYPOLICY"***"
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
  if ! diff "/tmp/policy_"$QUERYPOLICY"_domaintoIP" "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP" &>/dev/null;then
    echo -e "${YELLOW}Policy: New IP Addresses detected for $QUERYPOLICY${NOCOLOR}"
    echo -e "${YELLOW}Updating Policy: "$QUERYPOLICY"${NOCOLOR}"
    logger -st "$ALIAS" "Query Policy - Updating Policy: "$QUERYPOLICY""
    cp "/tmp/policy_"$QUERYPOLICY"_domaintoIP" "$POLICYDIR/policy_"$QUERYPOLICY"_domaintoIP"
    echo -e "${GREEN}Updated Policy: "$QUERYPOLICY"${NOCOLOR}"
    logger -st "$ALIAS" "Query Policy - Updated Policy: "$QUERYPOLICY""
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
    if [[ -z "$(ip -6 route list $IPV6 dev $IFNAME)" ]] &>/dev/null;then
      [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Adding route for $IPV6 dev $IFNAME"
      ip -6 route add $IPV6 dev $IFNAME \
      && { [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Route added for $IPV6 dev $IFNAME" ;} \
      || logger -st "$ALIAS" "Query Policy - ***Error*** Unable to add route for $IPV6 dev $IFNAME"
    fi
  done

  if [[ "$RGW" == "0" ]] &>/dev/null;then
    # Create IPv4 Routes
    for IPV4 in ${IPV4S};do
      if [[ -z "$(ip route list $IPV4 dev $IFNAME table $ROUTETABLE)" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Adding route for $IPV4 dev $IFNAME table $ROUTETABLE"
        ip route add $IPV4 dev $IFNAME table $ROUTETABLE \
        && { [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Route added for $IPV4 dev $IFNAME table $ROUTETABLE" ;} \
        || logger -st "$ALIAS" "Query Policy - ***Error*** Unable to add route for $IPV4 dev $IFNAME table $ROUTETABLE"
      fi
      if [[ "$INTERFACE" == "wan" ]] &>/dev/null;then
        if [[ -n "$(ip route list $IPV$ dev $OLDIFNAME table $ROUTETABLE)" ]] &>/dev/null;then
          [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Deleting route for $IPV4 dev $OLDIFNAME table $ROUTETABLE"
          ip route del $IPV4 dev $OLDIFNAME table $ROUTETABLE \
          && { [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Route deleted for $IPV4 dev $OLDIFNAME table $ROUTETABLE" ;} \
          || logger -st "$ALIAS" "Query Policy - ***Error*** Unable to delete route for $IPV4 dev $OLDIFNAME table $ROUTETABLE"
        fi
      fi
    done
  elif [[ "$RGW" != "0" ]] &>/dev/null;then
    # Create IPv4 Rules
    for IPV4 in ${IPV4S}; do
      if [[ -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority $PRIORITY)" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] && logger -st "$ALIAS" "Query Policy - Adding IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
        ip rule add from all to $IPV4 table $ROUTETABLE priority $PRIORITY \
        && { [[ "$VERBOSELOGGING" == "1" ]] && logger -t "$ALIAS" "Query Policy - Added IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY" ;} \
        || logger -st "$ALIAS" "Query Policy - ***Error*** Unable to add IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
      fi
    done
  fi

  # Clear Parameters
  unset VERBOSELOGGING PRIVATEIPS INTERFACE IFNAME OLDIFNAME IPV6S IPV4S RGW PRIORITY ROUTETABLE
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
if [[ "${mode}" != "uninstall" ]] &>/dev/null;then
  if tty &>/dev/null;then
    echo -e "${BLUE}Checking if Cron Job is Scheduled...${NOCOLOR}"
  fi
  if [[ -z "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    if tty &>/dev/null;then
      echo -e "${BLUE}Creating Cron Job...${NOCOLOR}"
    fi
    logger -p 5 -st "$ALIAS" "Cron - Creating Cron Job"
    $(cru a setup_domain_vpn_routing "*/15 * * * *" $0 querypolicy all) \
    && { logger -p 4 -st "$ALIAS" "Cron - Created Cron Job" ; echo -e "${GREEN}Created Cron Job${NOCOLOR}" ;} \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Unable to create Cron Job"
  elif [[ -n "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    if tty &>/dev/null;then
      echo -e "${GREEN}Cron Job already exists${NOCOLOR}"
    fi
  fi

  # Execute Query Policy All if System Uptime is less than 15 minutes
  [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "900" ]] && $0 querypolicy all

# Remove Cron Job
elif [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  if [[ -n "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Cron - Removing Cron Job"
    $(cru d setup_domain_vpn_routing "*/15 * * * *" $0 querypolicy all) \
    && logger -p 3 -st "$ALIAS" "Cron - Removed Cron Job" \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Unable to remove Cron Job"
  fi
  return
fi
return
}

# Kill Script
killscript ()
{
echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
logger -t "$ALIAS" "Kill - Killing ${0##*/}"
sleep 3 && killall ${0##*/} 2>/dev/null
exit
}

# Update Script
update ()
{

# Read Global Config File
if [[ -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
  . $GLOBALCONFIGFILE
fi

# Determine Production or Beta Update Channel
if [[ -z "${DEVMODE+x}" ]] &>/dev/null;then
  echo -e "Dev Mode not configured in Global Configuration"
elif [[ "$DEVMODE" == "0" ]] &>/dev/null;then
  DOWNLOADPATH=""$REPO"domain_vpn_routing.sh"
elif [[ "$DEVMODE" == "1" ]] &>/dev/null;then
  DOWNLOADPATH=""$REPO"domain_vpn_routing-beta.sh"
fi

# Determine if newer version is available
REMOTEVERSION="$(echo $(/usr/sbin/curl "$DOWNLOADPATH" 2>/dev/null | grep -v "grep" | grep -w "# Version:" | awk '{print $3}'))"

# Remote Checksum
if [[ -f "/usr/sbin/openssl" ]] &>/dev/null;then
  REMOTECHECKSUM="$(/usr/sbin/curl -s "$DOWNLOADPATH" | /usr/sbin/openssl sha256 | awk -F " " '{print $2}')"
elif [[ -f "/usr/bin/md5sum" ]] &>/dev/null;then
  REMOTECHECKSUM="$(echo $(/usr/sbin/curl -s "$DOWNLOADPATH" 2>/dev/null | /usr/bin/md5sum | awk -F " " '{print $1}'))"
fi

# Convert versions in numbers for evaluation
if [[ "$DEVMODE" == "0" ]] &>/dev/null;then
  version="$(echo $VERSION | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && version=${version//[$'\t\r\n']/}
  remoteversion="$(echo $REMOTEVERSION | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && remoteversion=${remoteversion//[$'\t\r\n']/}
elif [[ "$DEVMODE" == "1" ]] &>/dev/null;then
  if [[ -n "$(echo $REMOTEVERSION | grep -e "beta")" ]] &>/dev/null;then
    version="$(echo $VERSION | grep -o '[0-9]*')" && version=${version//[$'\t\r\n']/}
    remoteversion="$(echo $REMOTEVERSION | grep -o '[0-9]*')" && remoteversion=${remoteversion//[$'\t\r\n']/}
  elif [[ -z "$(echo $REMOTEVERSION | grep -e "beta")" ]] &>/dev/null;then
    version="$(echo $VERSION | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && version=${version//[$'\t\r\n']/}
    remoteversion="$(echo $REMOTEVERSION | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && remoteversion=${remoteversion//[$'\t\r\n']/}
  fi
fi

if [[ "$version" -lt "$remoteversion" ]] &>/dev/null;then
  logger -p 3 -t "$ALIAS" ""$ALIAS" is out of date - Current Version: "$VERSION" Available Version: "$REMOTEVERSION""
  [[ "$DEVMODE" == "1" ]] &>/dev/null && echo -e "${RED}***Dev Mode is Enabled***${NOCOLOR}"
  echo -e "${YELLOW}"$ALIAS" is out of date - Current Version: ${LIGHTBLUE}"$VERSION"${YELLOW} Available Version: ${LIGHTBLUE}"$REMOTEVERSION"${NOCOLOR}${NOCOLOR}"
  while true &>/dev/null;do
    if [[ "$DEVMODE" == "0" ]] &>/dev/null;then
      read -p "Do you want to update to the latest production version? "$REMOTEVERSION" ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    elif [[ "$DEVMODE" == "1" ]] &>/dev/null;then
      read -p "Do you want to update to the latest beta version? "$REMOTEVERSION" ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    fi
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) unset passiveupdate && return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" 2>/dev/null && chmod 755 $0 \
  && { logger -p 4 -st "$ALIAS" "Update - "$ALIAS" has been updated to version: "$REMOTEVERSION"" && killscript ;} \
  || logger -p 2 -st "$ALIAS" "Update - ***Error*** Unable to update "$ALIAS" to version: "$REMOTEVERSION""
elif [[ "$version" == "$remoteversion" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" ""$ALIAS" is up to date - Version: "$VERSION""
  if [[ "$CHECKSUM" != "$REMOTECHECKSUM" ]] &>/dev/null;then
    logger -p 2 -t "$ALIAS" "***"$ALIAS" failed Checksum Check*** Current Checksum: "$CHECKSUM"  Valid Checksum: "$REMOTECHECKSUM""
    echo -e "${RED}***Checksum Failed***${NOCOLOR}"
    echo -e "${LIGHTGRAY}Current Checksum: ${LIGHTRED}"$CHECKSUM"  ${LIGHTGRAY}Valid Checksum: ${GREEN}"$REMOTECHECKSUM"${NOCOLOR}"
  fi
  while true &>/dev/null;do  
    read -p ""$ALIAS" is up to date. Do you want to reinstall "$ALIAS" Version: "$VERSION"? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) unset passiveupdate && return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" 2>/dev/null && chmod 755 $0 \
  && { logger -p 4 -st "$ALIAS" "Update - "$ALIAS" has reinstalled version: "$VERSION"" && killscript ;} \
  || logger -p 2 -st "$ALIAS" "Update - ***Error*** Unable to reinstall "$ALIAS" with version: "$VERSION""
elif [[ "$version" -gt "$remoteversion" ]] &>/dev/null;then
  echo -e "${LIGHTMAGENTA}"$ALIAS" is newer than Available Version: "$REMOTEVERSION" ${NOCOLOR}- ${LIGHTCYAN}Current Version: "$VERSION"${NOCOLOR}"
fi

return
}

# Check if NVRAM Background Process is Stuck if CHECKNVRAM is Enabled
nvramcheck ()
{
# Check if Background Process for NVRAM Call is still running
lastpid="$!"
if [[ -z "$(ps | grep -v "grep" | awk '{print $1}' | grep -o "$lastpid")" ]] &>/dev/null;then
  unset lastpid
  return
elif [[ -n "$(ps | grep -v "grep" | awk '{print $1}' | grep -o "$lastpid")" ]] &>/dev/null;then
  kill -9 $lastpid 2>/dev/null \
  && logger -p 2 -t "$ALIAS" "NVRAM Check - ***NVRAM Check Failure Detected***"
  unset lastpid
  return
fi

return
}

updateconfigprev2 || return
scriptmode
