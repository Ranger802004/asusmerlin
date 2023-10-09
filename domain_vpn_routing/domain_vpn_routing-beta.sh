#!/bin/sh

# Domain VPN Routing for ASUS Routers using Merlin Firmware v386.7 or newer
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 10/09/2023
# Version: v2.1.1

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
ALIAS="domain_vpn_routing"
VERSION="v2.1.1"
REPO="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/"
GLOBALCONFIGFILE="/jffs/configs/domain_vpn_routing/global.conf"
CONFIGFILE="/jffs/configs/domain_vpn_routing/domain_vpn_routing.conf"
POLICYDIR="/jffs/configs/domain_vpn_routing"
SYSTEMLOG="/tmp/syslog.log"
LOCKFILE="/var/lock/domain_vpn_routing.lock"
DNSMASQCONFIGFILE="/etc/dnsmasq.conf"

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
  if [[ -n "$(grep -w "# domain_vpn_routing" /jffs/configs/profile.add)" ]] &>/dev/null;then
    echo -e "${BOLD}${RED}***WARNING*** Execute using Alias: ${LIGHTBLUE}${ALIAS}${RED}${NOCOLOR}.${NOCOLOR}"
  else
    SCRIPTPATH="/jffs/scripts/${0##*/}"
    echo -e "${BOLD}${RED}***WARNING*** Execute using full script path ${LIGHTBLUE}${SCRIPTPATH}${NOCOLOR}.${NOCOLOR}"
  fi
  exit
fi

# Set Script Mode
if [[ "$#" == "0" ]] &>/dev/null;then
  # Default to Menu Mode if no argument specified
  [[ -z "${mode+x}" ]] &>/dev/null && mode="menu"
elif [[ "$#" == "2" ]] &>/dev/null;then
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
  flock -x -n 100 || { echo -e "${LIGHTRED}***Query Policy already running***${NOCOLOR}" && return ;}
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
elif [[ "${mode}" == "resetconfig" ]] &>/dev/null;then 
  resetconfig
fi
return
}

# Cleanup
cleanup ()
{
# Remove Lock File
logger -p 6 -t "$ALIAS" "Debug - Checking for Lock File: ${LOCKFILE}"
if [[ -f "$LOCKFILE" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting ${LOCKFILE}"
  rm -f $LOCKFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted ${LOCKFILE}" \
  || logger -p 2 -st "$ALIAS" "Cleanup - ***Error*** Failed to delete ${LOCKFILE}"
fi

return
}

# Menu
menu ()
{
        # Load Global Configuration
        if [[ -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
          setglobalconfig
        fi

        # Set Mode back to Menu if Changed
        [[ "$mode" != "menu" ]] &>/dev/null && mode="menu"

        # Override Process Priority back to Normal if changed for other functions
        if [[ -n "${PROCESSPRIORITY+x}" ]] &>/dev/null;then
          renice -n 0 $$
        fi

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
                        # Determine if readme source is prod or beta
                        if [[ "$DEVMODE" == "1" ]] &>/dev/null;then
                          README="${REPO}readme-beta.txt"
                        else
                          README="${REPO}readme.txt"
                        fi
                        clear
                        /usr/sbin/curl --connect-timeout 30 --max-time 30 --url ${README} --ssl-reqd 2>/dev/null || echo -e "${RED}***Unable to access Readme***${NOCOLOR}"
		;;
		'2')    # showpolicy
			mode="showpolicy"
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do  
                          read -r -p "Select the Policy You Want to View: " value
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
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do  
                          read -r -p "Select the Policy You Want to Query: " value
                          case $value in
                            * ) POLICY=$value; break;;
                          esac
                        done
                        querypolicy "$value"
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
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do  
                          read -r -p "Select the Policy You Want to Edit: " value
                          case $value in
                            * ) POLICY=$value; break;;
                          esac
                        done
                        editpolicy "$value"
                        unset value
		;;
		'12')   # deletepolicy
			mode="deletepolicy"
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do  
                          read -r -p "Select the Policy You Want to Delete: " value
                          case $value in
                            * ) POLICY=$value; break;;
                          esac
                        done
                        deletepolicy "$value"
                        unset value
		;;
		'13')   # adddomain
			mode="adddomain"
			while true &>/dev/null;do  
                          read -r -p "Select a domain to add to a policy: " value
                          case $value in
                            * ) DOMAIN=$value; break;;
                          esac
                        done
                        adddomain "${DOMAIN}"
                        unset value DOMAIN
		;;
		'14')   # deletedomain
			mode="deletedomain"
			while true &>/dev/null;do  
                          read -r -p "Select a domain to delete from a policy: " value
                          case $value in
                            * ) DOMAIN=$value; break;;
                          esac
                        done
                        deletedomain "${DOMAIN}"
                        unset value DOMAIN
		;;
		'15')   # deleteip
			mode="deleteip"
			while true &>/dev/null;do  
                          read -r -p "Select an IP Address to delete from a policy: " value
                          case $value in
                            * ) IP=$value; break;;
                          esac
                        done
                        deleteip "$IP"
                        unset value IP
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
        getsystemparameters || return
        [[ "$mode" != "menu" ]] &>/dev/null && mode="menu"
	return 0
}


# Check Alias
checkalias ()
{
# Create alias if it doesn't exist
if [[ "${mode}" != "uninstall" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking Alias in /jffs/configs/profile.add"
  if [[ ! -f "/jffs/configs/profile.add" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Alias Check - Creating /jffs/configs/profile.add"
    touch -a /jffs/configs/profile.add \
    && chmod 666 /jffs/configs/profile.add \
    && logger -p 4 -st "$ALIAS" "Alias Check - Created /jffs/configs/profile.add" \
    || logger -p 2 -st "$ALIAS" "Alias Check - ***Error*** Failed to create /jffs/configs/profile.add"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/configs/profile.add)" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Alias Check - Creating Alias for $0 as ${ALIAS}"
    echo -e "alias ${ALIAS}=\"sh $0\" # domain_vpn_routing" >> /jffs/configs/profile.add \
    && source /jffs/configs/profile.add \
    && logger -p 4 -st "$ALIAS" "Alias Check - Created Alias for $0 as ${ALIAS}" \
    || logger -p 2 -st "$ALIAS" "Alias Check - ***Error*** Failed to create Alias for $0 as ${ALIAS}"
    . /jffs/configs/profile.add
  fi
# Remove alias if it does exist during uninstall
elif [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  # Remove Alias
  cmdline="sh $0 cron"
  if [[ -n "$(grep -e "alias ${ALIAS}=\"sh $0\" # domain_vpn_routing" /jffs/configs/profile.add)" ]] &>/dev/null;then 
    logger -p 5 -st "$ALIAS" "Uninstall - Removing Alias for $0 from /jffs/configs/profile.add"
    sed -i '\~# domain_vpn_routing~d' /jffs/configs/profile.add \
    && logger -p 4 -st "$ALIAS" "Uninstall - Removed Alias from /jffs/configs/profile.add" \
    || logger -p 2 -st "$ALIAS" "Uninstall - ***Error*** Failed to remove Alias from /jffs/configs/profile.add"
  fi
fi
return
}

# Install
install ()
{
if [[ "${mode}" == "install" ]] &>/dev/null;then
  # Create Policy Directory
  if [[ ! -d "${POLICYDIR}" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Install - Creating ${POLICYDIR}"
    mkdir -m 666 -p "${POLICYDIR}" \
    && logger -p 4 -st "$ALIAS" "Install - ${POLICYDIR} created" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to create ${POLICYDIR}"
  fi

  # Create Global Configuration File.
  if [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Install - Creating ${GLOBALCONFIGFILE}"
    touch -a "${GLOBALCONFIGFILE}" \
    && chmod 666 "${GLOBALCONFIGFILE}" \
    && { globalconfigsync="0" && setglobalconfig ;} \
    && logger -p 4 -st "$ALIAS" "Install - ${GLOBALCONFIGFILE} created" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to create ${GLOBALCONFIGFILE}"
  fi

  # Create Configuration File.
  if [[ ! -f "${CONFIGFILE}" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Install - Creating ${CONFIGFILE}"
    touch -a "${CONFIGFILE}" \
    && chmod 666 "${CONFIGFILE}" \
    && logger -p 4 -st "$ALIAS" "Install - ${CONFIGFILE} created" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to create ${CONFIGFILE}"
  fi

  # Create wan-event if it does not exist
    if [[ ! -f "/jffs/scripts/wan-event" ]] &>/dev/null;then
      logger -p 5 -st "$ALIAS" "Install - Creating wan-event script"
      touch -a /jffs/scripts/wan-event \
      && chmod 755 /jffs/scripts/wan-event \
      && echo "#!/bin/sh" >> /jffs/scripts/wan-event \
      && logger -p 4 -st "$ALIAS" "Install - wan-event script has been created" \
      || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to create wan-event script"
    fi

  # Add Script to wan-event
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh $0 cron"
    logger -p 5 -st "$ALIAS" "Install - Adding ${ALIAS} cron job to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "$ALIAS" "Install - ${ALIAS} cron job added to wan-event" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to add ${ALIAS} cron job to wan-event"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh $0 querypolicy all"
    logger -t "$ALIAS" "Install - Adding ${ALIAS} to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing_queryall" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "$ALIAS" "Install - ${ALIAS} added to wan-event" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to add ${ALIAS} to wan-event"
  fi

  # Create openvpn-event if it does not exist
  if [[ ! -f "/jffs/scripts/openvpn-event" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Install - Creating openvpn-event"
    touch -a /jffs/scripts/openvpn-event \
    && chmod 755 /jffs/scripts/openvpn-event \
    && echo "#!/bin/sh" >> /jffs/scripts/openvpn-event \
    && logger -p 4 -st "$ALIAS" "Install - openvpn-event has been created" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to create openvpn-event"
  fi

  # Add Script to Openvpn-event
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    cmdline="sh $0 cron"
    logger -p 5 -st "$ALIAS" "Install - Adding ${ALIAS} cron job to openvpn-event"
    echo -e "\r\n$cmdline # domain_vpn_routing" >> /jffs/scripts/openvpn-event \
    && logger -p 4 -st "$ALIAS" "Install - ${ALIAS} cron job added to openvpn-event" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to add ${ALIAS} cron job to openvpn-event"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    cmdline="sh $0 querypolicy all"
    logger -p 5 -st "$ALIAS" "Install - Adding ${ALIAS} to openvpn-event"
    echo -e "\r\n$cmdline # domain_vpn_routing_queryall" >> /jffs/scripts/openvpn-event \
    && logger -p 4 -st "$ALIAS" "Install - ${ALIAS} added to openvpn-event" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to add ${ALIAS} to openvpn-event"
  fi

  # Check Alias
  checkalias || return

  # Create Initial Cron Jobs
  cronjob || return

fi
return
}

# Uninstall
uninstall ()
{
# Prompt for confirmation
if [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  # Verify uninstallation prompt
  while true &>/dev/null;do
    read -p "Are you sure you want to uninstall ${ALIAS}? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done

  if [[ ! -d "${POLICYDIR}" ]] &>/dev/null;then
    echo -e "${RED}${ALIAS} - Uninstall: ${ALIAS} not installed...${NOCOLOR}"
    return
  fi

  # Remove Cron Job
  cronjob || return

  # Remove Script from wan-event
  cmdline="sh $0 cron"
  if [[ -n "$(grep -e "^$cmdline" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    logger -p 5 -st "$ALIAS" "Uninstall - Removing Cron Job from wan-event"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/wan-event \
    && logger -p 4 -st "$ALIAS" "Uninstall - Removed Cron Job from wan-event" \
    || logger -p 2 -st "$ALIAS" "Uninstall - ***Error*** Failed to remove Cron Job from wan-event"
  fi
  cmdline="sh $0 querypolicy all"
  if [[ -n "$(grep -e "^$cmdline" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    logger -p 5 -st "$ALIAS" "Uninstall - Removing Query Policy All from wan-event"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/wan-event \
    && logger -p 4 -st "$ALIAS" "Uninstall - Removed Query Policy All from wan-event" \
    || logger -p 2 -st "$ALIAS" "Uninstall - ***Error*** Failed to remove Query Policy All from wan-event"
  fi

  # Remove Script from Openvpn-event
  cmdline="sh $0 cron"
  if [[ -n "$(grep -e "^$cmdline" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    logger -p 5 -st "$ALIAS" "Uninstall - Removing Cron Job from Openvpn-Event"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/openvpn-event \
    && logger -p 4 -st "$ALIAS" "Uninstall - Removed Cron Job from Openvpn-Event" \
    || logger -p 2 -st "$ALIAS" "Uninstall - ***Error*** Failed to remove Cron Job from Openvpn-Event"
  fi
  cmdline="sh $0 querypolicy all"
  if [[ -n "$(grep -e "^$cmdline" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    logger -p 5 -st "$ALIAS" "Uninstall - Removing Query Policy All from Openvpn-Event"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/openvpn-event \
    && logger -p 4 -st "$ALIAS" "Uninstall - Removed Query Policy All from Openvpn-Event" \
    || logger -p 2 -st "$ALIAS" "Uninstall - ***Error*** Failed to remove Query Policy All from Openvpn-Event"
  fi

  # Delete Policies
  POLICY="all"
  deletepolicy

  # Delete Policy Directory
  if [[ -d "${POLICYDIR}" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Uninstall - Deleting ${POLICYDIR}"
    rm -rf "${POLICYDIR}" \
    && logger -p 4 -st "$ALIAS" "Uninstall - ${POLICYDIR} deleted" \
    || logger -p 2 -st "$ALIAS" "Uninstall - ***Error*** Failed to delete ${POLICYDIR}"
  fi
  # Remove Lock File
  if [[ -f "$LOCKFILE" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Uninstall - Removing ${LOCKFILE}"
    rm -f "${LOCKFILE}" \
    && logger -p 4 -st "$ALIAS" "Uninstall - Removed ${LOCKFILE}" \
    || logger -p 2 -st "$ALIAS" "Uninstall - ***Error*** Failed to remove ${LOCKFILE}"
  fi

  # Remove Alias
  checkalias

  # Check for Script File
  if [[ -f $0 ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Uninstall - Deleting $0"
    rm -f $0 \
    && logger -p 4 -st "$ALIAS" "Uninstall - $0 deleted" \
    || logger -p 2 -st "$ALIAS" "Uninstall - $0 failed to delete"
  fi

fi
return
}

# Set Global Configuration
setglobalconfig ()
{
# Return if mode is Install Mode
if [[ "${mode}" == "install" ]] &>/dev/null && [[ -z "${globalconfigsync+x}" ]] &>/dev/null;then
  return
# Check Configuration File for Missing Settings and Set Default if Missing
elif [[ -z "${globalconfigsync+x}" ]] &>/dev/null;then
  globalconfigsync="0"
fi
if [[ "$globalconfigsync" == "0" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking for missing global configuration options"

  # DEVMODE
  if [[ -z "$(sed -n '/\bDEVMODE=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating DEVMODE Default: Disabled"
    echo -e "DEVMODE=0" >> ${GLOBALCONFIGFILE}
  fi

  # CHECKNVRAM
  if [[ -z "$(sed -n '/\bCHECKNVRAM=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating CHECKNVRAM Default: Disabled"
    echo -e "CHECKNVRAM=0" >> ${GLOBALCONFIGFILE}
  fi

  # PROCESSPRIORITY
  if [[ -z "$(sed -n '/\bPROCESSPRIORITY\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating PROCESSPRIORITY Default: Normal"
    echo -e "PROCESSPRIORITY=0" >> ${GLOBALCONFIGFILE}
  fi

  # CHECKINTERVAL
  if [[ -z "$(sed -n '/\bCHECKINTERVAL\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating CHECKINTERVAL Default: 15 minutes"
    echo -e "CHECKINTERVAL=15" >> ${GLOBALCONFIGFILE}
  fi

  # BOOTDELAYTIMER
  if [[ -z "$(sed -n '/\bBOOTDELAYTIMER\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating BOOTDELAYTIMER Default: 0 seconds"
    echo -e "BOOTDELAYTIMER=0" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC1FWMARK
  if [[ -z "$(sed -n '/\bOVPNC1FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC1FWMARK Default: 0x1000"
    echo -e "OVPNC1FWMARK=0x1000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC1MASK
  if [[ -z "$(sed -n '/\bOVPNC1MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC1MASK Default: 0xf000"
    echo -e "OVPNC1MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC2FWMARK
  if [[ -z "$(sed -n '/\bOVPNC2FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC2FWMARK Default: 0x2000"
    echo -e "OVPNC2FWMARK=0x2000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC2MASK
  if [[ -z "$(sed -n '/\bOVPNC2MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC2MASK Default: 0xf000"
    echo -e "OVPNC2MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC3FWMARK
  if [[ -z "$(sed -n '/\bOVPNC3FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC3FWMARK Default: 0x4000"
    echo -e "OVPNC3FWMARK=0x4000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC3MASK
  if [[ -z "$(sed -n '/\bOVPNC3MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC3MASK Default: 0xf000"
    echo -e "OVPNC3MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC4FWMARK
  if [[ -z "$(sed -n '/\bOVPNC4FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC4FWMARK Default: 0x7000"
    echo -e "OVPNC4FWMARK=0x7000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC4MASK
  if [[ -z "$(sed -n '/\bOVPNC4MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC4MASK Default: 0xf000"
    echo -e "OVPNC4MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC5FWMARK
  if [[ -z "$(sed -n '/\bOVPNC5FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC5FWMARK Default: 0x3000"
    echo -e "OVPNC5FWMARK=0x3000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC5MASK
  if [[ -z "$(sed -n '/\bOVPNC5MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating OVPNC5MASK Default: 0xf000"
    echo -e "OVPNC5MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC1FWMARK
  if [[ -z "$(sed -n '/\bWGC1FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC1FWMARK Default: 0xa000"
    echo -e "WGC1FWMARK=0xa000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC1MASK
  if [[ -z "$(sed -n '/\bWGC1MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC1MASK Default: 0xf000"
    echo -e "WGC1MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC2FWMARK
  if [[ -z "$(sed -n '/\bWGC2FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC2FWMARK Default: 0xb000"
    echo -e "WGC2FWMARK=0xb000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC2MASK
  if [[ -z "$(sed -n '/\bWGC2MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC2MASK Default: 0xf000"
    echo -e "WGC2MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC3FWMARK
  if [[ -z "$(sed -n '/\bWGC3FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC3FWMARK Default: 0xc000"
    echo -e "WGC3FWMARK=0xc000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC3MASK
  if [[ -z "$(sed -n '/\bWGC3MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC3MASK Default: 0xf000"
    echo -e "WGC3MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC4FWMARK
  if [[ -z "$(sed -n '/\bWGC4FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC4FWMARK Default: 0xd000"
    echo -e "WGC4FWMARK=0xd000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC4MASK
  if [[ -z "$(sed -n '/\bWGC4MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC4MASK Default: 0xf000"
    echo -e "WGC4MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC5FWMARK
  if [[ -z "$(sed -n '/\bWGC5FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC5FWMARK Default: 0xe000"
    echo -e "WGC5FWMARK=0xe000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC5MASK
  if [[ -z "$(sed -n '/\bWGC5MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating WGC5MASK Default: 0xf000"
    echo -e "WGC5MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi

  # Reading updated Global Configuration
  logger -p 6 -t "$ALIAS" "Debug - Reading ${GLOBALCONFIGFILE}"
  . ${GLOBALCONFIGFILE}

  # Set flag for Global Config Sync to 1
  [[ "${globalconfigsync}" == "0" ]] &>/dev/null && globalconfigsync="1"
fi

# Read Configuration File if Global Config Sync flag is 1
if [[ "${globalconfigsync}" == "1" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Reading ${GLOBALCONFIGFILE}"
  . ${GLOBALCONFIGFILE}
fi

return
}

# Reset Global Config
resetconfig ()
{
if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  logger -p 3 -t "$ALIAS" "Reset Config - Resetting Global Configuration"
  > ${GLOBALCONFIGFILE} \
  && { globalconfigsync="0" && setglobalconfig && logger -p 4 -st "$ALIAS" "Reset Config - Reset Global Configuration" ;} \
  || logger -p 2 -st "$ALIAS" "Reset Config - ***Error*** Failed to reset Global Configuration"
fi

return
}

# Update Configuration from Pre-Version 2
updateconfigprev2 ()
{
# Check if config file exists and global config file is missing and then update from prev2 configuration
if [[ -f "${CONFIGFILE}" ]] &>/dev/null && [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  # Back up Policy Configuration File
  /bin/cp -rf ${CONFIGFILE} ${CONFIGFILE}-"$(date +"%F-%T-%Z")".bak \
  && logger -p 4 -st "$ALIAS" "Install - Successfully backed up policy configuration" \
  || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to back up policy configuration"

  # Create Global Configuration File
  if [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Install - Creating ${GLOBALCONFIGFILE}"
    touch -a "${GLOBALCONFIGFILE}" \
    && chmod 666 "${GLOBALCONFIGFILE}" \
    && setglobalconfig \
    && logger -p 4 -st "$ALIAS" "Install - ${GLOBALCONFIGFILE} created" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to create ${GLOBALCONFIGFILE}"
  fi

  # Create wan-event if it does not exist
  if [[ ! -f "/jffs/scripts/wan-event" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Install - Creating wan-event script"
    touch -a /jffs/scripts/wan-event \
    && chmod 755 /jffs/scripts/wan-event \
    && echo "#!/bin/sh" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "$ALIAS" "Install - wan-event script has been created" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to create wan-event script"
  fi

  # Add Script to wan-event
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh $0 cron"
    logger -p 5 -st "$ALIAS" "Install - Adding ${ALIAS} Cron Job to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "$ALIAS" "Install - ${ALIAS} Cron Job added to wan-event" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to add ${ALIAS} Cron Job to wan-event"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh $0 querypolicy all"
    logger -p 5 -st "$ALIAS" "Install - Adding ${ALIAS} Query Policy All to wan-event"
    echo -e "\r\n$cmdline # domain_vpn_routing_queryall" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "$ALIAS" "Install - ${ALIAS} Query Policy All added to wan-event" \
    || logger -p 2 -st "$ALIAS" "Install - ***Error*** Failed to add ${ALIAS} Query Policy All to wan-event"
  fi

  # Read Configuration File for Policies
  Lines="$(cat $CONFIGFILE)"

  # Identify OpenVPN Tunnel Interfaces
  c1="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  c2="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client2/config.ovpn 2>/dev/null)"
  c3="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client3/config.ovpn 2>/dev/null)"
  c4="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client4/config.ovpn 2>/dev/null)"
  c5="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client5/config.ovpn 2>/dev/null)"
  s1="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server1/config.ovpn 2>/dev/null)"
  s2="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server2/config.ovpn 2>/dev/null)"

  # Update Interfaces
  for Line in $Lines;do
    if [[ -n "$(echo $Line | grep -e "$c1\|$c2\|$c3\|$c4\|$c5\|$s1\|$s2\|$WAN0GWIFNAME\|$WAN1GWIFNAME")" ]] &>/dev/null;then
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
      elif [[ "$fixpolicyinterface" == "$WAN0GWIFNAME" ]] &>/dev/null;then
        fixpolicyinterface="wan0"
      elif [[ "$fixpolicyinterface" == "$WAN1GWIFNAME" ]] &>/dev/null;then
        fixpolicyinterface="wan1"
      fi
      sed -i "\:"$Line":d" "$CONFIGFILE"
      echo -e "${fixpolicy}|${fixpolicydomainlist}|${fixpolicydomainiplist}|${fixpolicyinterface}|${fixpolicyverboselog}|${fixpolicyprivateips}" >> $CONFIGFILE
    else
      continue
    fi
  done

  unset Lines fixpolicy fixpolicydomainlist fixpolicydomainiplist fixpolicyinterface fixpolicyverboselog fixpolicyprivateips c1 c2 c3 c4 c5 s1 s2
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
  echo -e "${RED}Domain VPN Routing currently has no configuration file present${NOCOLOR}"
elif [[ -f "$GLOBALCONFIGFILE" ]] &>/dev/null;then
  setglobalconfig || return
fi

# Load Config Menu
clear
printf "\n  ${BOLD}Global Settings:${NOCOLOR}\n"
printf "  (1)  Configure Dev Mode              Dev Mode: " && { [[ "$DEVMODE" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (2)  Configure NVRAM Checks          NVRAM Checks: " && { [[ "$CHECKNVRAM" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (3)  Configure Process Priority      Process Priority: " && { { [[ "$PROCESSPRIORITY" == "0" ]] &>/dev/null && printf "${LIGHTBLUE}Normal${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "-20" ]] &>/dev/null && printf "${LIGHTCYAN}Real Time${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "-10" ]] &>/dev/null && printf "${LIGHTMAGENTA}High${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "10" ]] &>/dev/null && printf "${LIGHTYELLOW}Low${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "20" ]] &>/dev/null && printf "${LIGHTRED}Lowest${NOCOLOR}" ;} || printf "${LIGHTGRAY}$PROCESSPRIORITY${NOCOLOR}" ;} && printf "\n"
printf "  (4)  Configure Check Interval        Check Interval: ${LIGHTBLUE}${CHECKINTERVAL} Minutes${NOCOLOR}\n"
printf "  (5)  Configure Boot Delay Timer      Boot Delay Timer: ${LIGHTBLUE}${BOOTDELAYTIMER} Seconds${NOCOLOR}\n"

printf "\n  ${BOLD}Advanced Settings:${NOCOLOR}  ${LIGHTRED}***Recommended to leave default unless necessary to change***${NOCOLOR}\n"
printf "  (6)  OpenVPN Client 1 FWMark         OpenVPN Client 1 FWMark:   ${LIGHTBLUE}${OVPNC1FWMARK}${NOCOLOR}\n"
printf "  (7)  OpenVPN Client 1 Mask           OpenVPN Client 1 Mask:     ${LIGHTBLUE}${OVPNC1MASK}${NOCOLOR}\n"
printf "  (8)  OpenVPN Client 2 FWMark         OpenVPN Client 2 FWMark:   ${LIGHTBLUE}${OVPNC2FWMARK}${NOCOLOR}\n"
printf "  (9)  OpenVPN Client 2 Mask           OpenVPN Client 2 Mask:     ${LIGHTBLUE}${OVPNC2MASK}${NOCOLOR}\n"
printf "  (10) OpenVPN Client 3 FWMark         OpenVPN Client 3 FWMark:   ${LIGHTBLUE}${OVPNC3FWMARK}${NOCOLOR}\n"
printf "  (12) OpenVPN Client 3 Mask           OpenVPN Client 3 Mask:     ${LIGHTBLUE}${OVPNC3MASK}${NOCOLOR}\n"
printf "  (12) OpenVPN Client 4 FWMark         OpenVPN Client 4 FWMark:   ${LIGHTBLUE}${OVPNC4FWMARK}${NOCOLOR}\n"
printf "  (13) OpenVPN Client 4 Mask           OpenVPN Client 4 Mask:     ${LIGHTBLUE}${OVPNC4MASK}${NOCOLOR}\n"
printf "  (14) OpenVPN Client 5 FWMark         OpenVPN Client 5 FWMark:   ${LIGHTBLUE}${OVPNC5FWMARK}${NOCOLOR}\n"
printf "  (15) OpenVPN Client 5 Mask           OpenVPN Client 5 Mask:     ${LIGHTBLUE}${OVPNC5MASK}${NOCOLOR}\n"
printf "  (16) Wireguard Client 1 FWMark       Wireguard Client 1 FWMark: ${LIGHTBLUE}${WGC1FWMARK}${NOCOLOR}\n"
printf "  (17) Wireguard Client 1 Mask         Wireguard Client 1 Mask:   ${LIGHTBLUE}${WGC1MASK}${NOCOLOR}\n"
printf "  (18) Wireguard Client 2 FWMark       Wireguard Client 2 FWMark: ${LIGHTBLUE}${WGC2FWMARK}${NOCOLOR}\n"
printf "  (19) Wireguard Client 2 Mask         Wireguard Client 2 Mask:   ${LIGHTBLUE}${WGC2MASK}${NOCOLOR}\n"
printf "  (20) Wireguard Client 3 FWMark       Wireguard Client 3 FWMark: ${LIGHTBLUE}${WGC3FWMARK}${NOCOLOR}\n"
printf "  (21) Wireguard Client 3 Mask         Wireguard Client 3 Mask:   ${LIGHTBLUE}${WGC3MASK}${NOCOLOR}\n"
printf "  (22) Wireguard Client 4 FWMark       Wireguard Client 4 FWMark: ${LIGHTBLUE}${WGC4FWMARK}${NOCOLOR}\n"
printf "  (23) Wireguard Client 4 Mask         Wireguard Client 4 Mask:   ${LIGHTBLUE}${WGC4MASK}${NOCOLOR}\n"
printf "  (24) Wireguard Client 5 FWMark       Wireguard Client 5 FWMark: ${LIGHTBLUE}${WGC5FWMARK}${NOCOLOR}\n"
printf "  (25) Wireguard Client 5 Mask         Wireguard Client 5 Mask:   ${LIGHTBLUE}${WGC5MASK}${NOCOLOR}\n"

printf "\n  ${BOLD}System Information:${NOCOLOR}\n"
printf "   DNS Logging Status                  Status:      " && { [[ "$DNSLOGGINGENABLED" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "   DNS Log Path                        Log Path:    ${LIGHTBLUE}${DNSLOGPATH}${NOCOLOR}\n"
if [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
  printf "   WAN0 FWMark                         WAN0 FWMark: ${LIGHTBLUE}${WAN0FWMARK}${NOCOLOR}\n"
  printf "   WAN0 Mask                           WAN0 Mask:   ${LIGHTBLUE}${WAN0MASK}${NOCOLOR}\n"
  printf "   WAN1 FWMark                         WAN1 FWMark: ${LIGHTBLUE}${WAN1FWMARK}${NOCOLOR}\n"
  printf "   WAN1 Mask                           WAN1 Mask:   ${LIGHTBLUE}${WAN1MASK}${NOCOLOR}\n"
else
  printf "   WAN FWMark                          WAN FWMark: ${LIGHTBLUE}${WAN0FWMARK}${NOCOLOR}\n"
  printf "   WAN Mask                            WAN Mask:   ${LIGHTBLUE}${WAN0MASK}${NOCOLOR}\n"
fi


if [[ "$mode" == "menu" ]] &>/dev/null;then
  printf "\n  (r)  return    Return to Main Menu"
  printf "\n  (x)  reset     Reset to Default Configuration"
  printf "\n  (e)  exit      Exit" 
else
  printf "\n  (x)  reset     Reset to Default Configuration"
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
    read -r -p "Do you want to enable Developer Mode? This defines if the Script is set to Developer Mode where updates will apply beta releases: ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETDEVMODE=1; break;;
      [Nn]* ) SETDEVMODE=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} DEVMODE=|$SETDEVMODE"
  ;;
  '2')      # CHECKNVRAM
  while true &>/dev/null;do
    read -p "Do you want to enable NVRAM Checks? This defines if the Script is set to perform NVRAM checks before peforming key functions: ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETCHECKNVRAM="1"; break;;
      [Nn]* ) SETCHECKNVRAM="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} CHECKNVRAM=|$SETCHECKNVRAM"
  ;;
  '3')      # PROCESSPRIORITY
  while true &>/dev/null;do  
    read -p "Configure Process Priority - 4 for Real Time Priority, 3 for High Priority, 2 for Low Priority, 1 for Lowest Priority, 0 for Normal Priority: " value
    case $value in
      4 ) SETPROCESSPRIORITY="-20"; break;;
      3 ) SETPROCESSPRIORITY="-10"; break;;
      2 ) SETPROCESSPRIORITY="10"; break;;
      1 ) SETPROCESSPRIORITY="20"; break;;
      0 ) SETPROCESSPRIORITY="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Select a Value between 4 and 0***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} PROCESSPRIORITY=|$SETPROCESSPRIORITY"
  ;;
  '4')      # CHECKINTERVAL
  while true &>/dev/null;do  
    read -p "Configure Check Interval for how frequent ${ALIAS} checks policies - Valid range is 1 - 59 minutes: " value
    case $value in
      ''|*[!0-9]* ) echo -e "${RED}Invalid Selection!!! ***Select a Value between 1 and 59***${NOCOLOR}";;
      * )
        if [[ "${value}" -le "0" ]] &>/dev/null || [[ "${value}" -ge "60" ]] &>/dev/null;then
          echo -e "${RED}Invalid Selection!!! ***Select a Value between 1 and 59***${NOCOLOR}"
        else
          SETCHECKINTERVAL="${value}"
          break
        fi
      ;;
      [0123456789] ) SETCHECKINTERVAL="${value}"; break;;
    esac
  done
  zCHECKINTERVAL="${CHECKINTERVAL}"
  NEWVARIABLES="${NEWVARIABLES} CHECKINTERVAL=|$SETCHECKINTERVAL"
  ;;
  '5')      # BOOTDELAYTIMER
  while true &>/dev/null;do
    read -p "Configure Boot Delay Timer - This will delay execution until System Uptime reaches this time (seconds): " value
    case $value in
      [0123456789]* ) SETBOOTDELAYTIMER="$value"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} BOOTDELAYTIMER=|$SETBOOTDELAYTIMER"
  ;;
  '6')      # OVPNC1FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC1 FWMark - This defines the OVPNC1 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC1FWMARK="$value"; break;;
        "" ) SETOVPNC1FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC1FWMARK=|$SETOVPNC1FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '7')      # OVPNC1MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC1 Mask - This defines the OVPNC1 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC1MASK="$value"; break;;
        "" ) SETOVPNC1MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC1MASK=|$SETOVPNC1MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '8')      # OVPNC2FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC2 FWMark - This defines the OVPNC2 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC2FWMARK="$value"; break;;
        "" ) SETOVPNC2FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC2FWMARK=|$SETOVPNC2FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '9')      # OVPNC2MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC2 Mask - This defines the OVPNC2 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC2MASK="$value"; break;;
        "" ) SETOVPNC2MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC2MASK=|$SETOVPNC2MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '10')      # OVPNC3FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC3 FWMark - This defines the OVPNC3 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC3FWMARK="$value"; break;;
        "" ) SETOVPNC3FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC3FWMARK=|$SETOVPNC3FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '11')      # OVPNC3MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC3 Mask - This defines the OVPNC3 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC3MASK="$value"; break;;
        "" ) SETOVPNC3MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC3MASK=|$SETOVPNC3MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '12')      # OVPNC4FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC4 FWMark - This defines the OVPNC4 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC4FWMARK="$value"; break;;
        "" ) SETOVPNC4FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC4FWMARK=|$SETOVPNC4FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '13')      # OVPNC4MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC4 Mask - This defines the OVPNC4 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC4MASK="$value"; break;;
        "" ) SETOVPNC4MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC4MASK=|$SETOVPNC4MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '14')      # OVPNC5FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC5 FWMark - This defines the OVPNC5 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC5FWMARK="$value"; break;;
        "" ) SETOVPNC5FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC5FWMARK=|$SETOVPNC5FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '15')      # OVPNC5MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC5 Mask - This defines the OVPNC5 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETOVPNC5MASK="$value"; break;;
        "" ) SETOVPNC5MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC5MASK=|$SETOVPNC5MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '16')      # WGC1FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC1 FWMark - This defines the WGC1 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC1FWMARK="$value"; break;;
        "" ) SETWGC1FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC1FWMARK=|$SETWGC1FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '17')      # WGC1MASK
  while true &>/dev/null;do
    read -p "Configure WGC1 Mask - This defines the WGC1 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC1MASK="$value"; break;;
        "" ) SETWGC1MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC1MASK=|$SETWGC1MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '18')      # WGC2FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC2 FWMark - This defines the WGC2 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC2FWMARK="$value"; break;;
        "" ) SETWGC2FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC2FWMARK=|$SETWGC2FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '19')      # WGC2MASK
  while true &>/dev/null;do
    read -p "Configure WGC2 Mask - This defines the WGC2 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC2MASK="$value"; break;;
        "" ) SETWGC2MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC2MASK=|$SETWGC2MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '20')      # WGC3FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC3 FWMark - This defines the WGC3 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC3FWMARK="$value"; break;;
        "" ) SETWGC3FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC3FWMARK=|$SETWGC3FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '21')      # WGC3MASK
  while true &>/dev/null;do
    read -p "Configure WGC3 Mask - This defines the WGC3 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC3MASK="$value"; break;;
        "" ) SETWGC3MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC3MASK=|$SETWGC3MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '22')      # WGC4FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC4 FWMark - This defines the WGC4 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC4FWMARK="$value"; break;;
        "" ) SETWGC4FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi  done
  NEWVARIABLES="${NEWVARIABLES} WGC4FWMARK=|$SETWGC4FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '23')      # WGC4MASK
  while true &>/dev/null;do
    read -p "Configure WGC4 Mask - This defines the WGC4 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC4MASK="$value"; break;;
        "" ) SETWGC4MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi  done
  NEWVARIABLES="${NEWVARIABLES} WGC4MASK=|$SETWGC4MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '24')      # WGC5FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC5 FWMark - This defines the WGC5 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC5FWMARK="$value"; break;;
        "" ) SETWGC5FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC5FWMARK=|$SETWGC5FWMARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '25')      # WGC5MASK
  while true &>/dev/null;do
    read -p "Configure WGC5 Mask - This defines the WGC5 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case $value in
        0[xX][[:xdigit:]]* ) SETWGC5MASK="$value"; break;;
        "" ) SETWGC5MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC5MASK=|$SETWGC5MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;

  'r'|'R'|'menu'|'return'|'Return' )
  clear
  menu
  break
  ;;
  'x'|'X'|'reset'|'Reset'|'default' )
  while true &>/dev/null;do
    read -p "Are you sure you want to reset back to default configuration? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    case $yn in
      [Yy]* ) resetconfig && break;;
      [Nn]* ) break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
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
    if [[ -z "$(grep -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" ${GLOBALCONFIGFILE})" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      echo -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" >> ${GLOBALCONFIGFILE}
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F "|" '{print $2}')"/" ${GLOBALCONFIGFILE}
    elif [[ -n "$(grep -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" ${GLOBALCONFIGFILE})" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F "|" '{print $2}')"/" ${GLOBALCONFIGFILE}
    elif [[ "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" == "CUSTOMLOGPATH=" ]] &>/dev/null;then
      [[ -n "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$GLOBALCONFIGFILE")" ]] &>/dev/null && sed -i '/CUSTOMLOGPATH=/d' ${GLOBALCONFIGFILE}
      echo -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')$(echo ${NEWVARIABLE} | awk -F "|" '{print $2}')" >> ${GLOBALCONFIGFILE}
    fi
  done

  # Check if cron job needs to be updated
  if [[ -n "${zCHECKINTERVAL+x}" ]] &>/dev/null;then
    setglobalconfig || return
    cronjob || return
    unset zCHECKINTERVAL
  fi
fi

# Check for Restart Flag
if [[ "$RESTARTREQUIRED" == "1" ]] &>/dev/null;then
  echo -e "${LIGHTRED}***Changes are pending that require a reboot***${NOCOLOR}"
  # Prompt for Reboot
  while true &>/dev/null;do
    read -p "Do you want to reboot now? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) reboot; break;;
      [Nn]* ) break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  PressEnter
  config
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

# Set default values to null
GATEWAY=""
IFNAME=""
IPV6VPNGW=""
RGW=""
ROUTETABLE=""
IPV6ROUTETABLE=""
PRIORITY=""
FWMARK=""
MASK=""
PRIMARY=""
STATE=""

# Set paramaeters based on interface
if [[ "$INTERFACE" == "ovpnc1" ]] &>/dev/null;then
  IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  RGW="$OVPNC1RGW"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="1000"
  FWMARK="$OVPNC1FWMARK"
  MASK="$OVPNC1MASK"
  STATE="$OVPNC1STATE"
elif [[ "$INTERFACE" == "ovpnc2" ]] &>/dev/null;then
  IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client2/config.ovpn 2>/dev/null)"
  IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  RGW="$OVPNC2RGW"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="2000"
  FWMARK="$OVPNC2FWMARK"
  MASK="$OVPNC2MASK"
  STATE="$OVPNC2STATE"
elif [[ "$INTERFACE" == "ovpnc3" ]] &>/dev/null;then
  IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client3/config.ovpn 2>/dev/null)"
  IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  RGW="$OVPNC3RGW"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="3000"
  FWMARK="$OVPNC3FWMARK"
  MASK="$OVPNC3MASK"
  STATE="$OVPNC3STATE"
elif [[ "$INTERFACE" == "ovpnc4" ]] &>/dev/null;then
  IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client4/config.ovpn 2>/dev/null)"
  IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  RGW="$OVPNC4RGW"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="4000"
  FWMARK="$OVPNC4FWMARK"
  MASK="$OVPNC4MASK"
  STATE="$OVPNC4STATE"
elif [[ "$INTERFACE" == "ovpnc5" ]] &>/dev/null;then
  IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client5/config.ovpn 2>/dev/null)"
  IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  RGW="$OVPNC5RGW"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="5000"
  FWMARK="$OVPNC5FWMARK"
  MASK="$OVPNC5MASK"
  STATE="$OVPNC5STATE"
elif [[ "$INTERFACE" == "ovpns1" ]] &>/dev/null;then
  IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server1/config.ovpn 2>/dev/null)"
  ROUTETABLE="main"
  IPV6ROUTETABLE="main"
  RGW="0"
  PRIORITY="0"
elif [[ "$INTERFACE" == "ovpns2" ]] &>/dev/null;then
  IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server2/config.ovpn 2>/dev/null)"
  ROUTETABLE="main"
  IPV6ROUTETABLE="main"
  RGW="0"
  PRIORITY="0"
elif [[ "$INTERFACE" == "wgc1" ]] &>/dev/null;then
  IFNAME="$INTERFACE"
  RGW="2"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="6000"
  FWMARK="$WGC1FWMARK"
  MASK="$WGC1MASK"
  STATE="$WGC1STATE"
elif [[ "$INTERFACE" == "wgc2" ]] &>/dev/null;then
  IFNAME="$INTERFACE"
  RGW="2"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="7000"
  FWMARK="$WGC2FWMARK"
  MASK="$WGC2MASK"
  STATE="$WGC2STATE"
elif [[ "$INTERFACE" == "wgc3" ]] &>/dev/null;then
  IFNAME="$INTERFACE"
  RGW="2"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="8000"
  FWMARK="$WGC3FWMARK"
  MASK="$WGC3MASK"
  STATE="$WGC3STATE"
elif [[ "$INTERFACE" == "wgc4" ]] &>/dev/null;then
  IFNAME="$INTERFACE"
  RGW="2"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="9000"
  FWMARK="$WGC4FWMARK"
  MASK="$WGC4MASK"
  STATE="$WGC4STATE"
elif [[ "$INTERFACE" == "wgc5" ]] &>/dev/null;then
  IFNAME="$INTERFACE"
  RGW="2"
  ROUTETABLE="$INTERFACE"
  IPV6ROUTETABLE="$INTERFACE"
  PRIORITY="10000"
  FWMARK="$WGC5FWMARK"
  MASK="$WGC5MASK"
  STATE="$WGC5STATE"
elif [[ "$INTERFACE" == "wan" ]] &>/dev/null;then
  if [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null;then
    STATE="$WAN0STATE"
    PRIMARY="$WAN0PRIMARY"
    GATEWAY="$WAN0GATEWAY"
    OLDGATEWAY="$WAN1GATEWAY"
    IFNAME="$WAN0GWIFNAME"
    OLDIFNAME="$WAN1GWIFNAME"
    FWMARK="$WAN0FWMARK"
    MASK="$WAN0MASK"
    OLDFWMARK="$WAN1FWMARK"
    OLDMASK="$WAN1MASK"
    OLDSTATE="$WAN1STATE"
  elif [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null;then
    STATE="$WAN1STATE"
    PRIMARY="$WAN1PRIMARY"
    GATEWAY="$WAN1GATEWAY"
    OLDGATEWAY="$WAN0GATEWAY"
    IFNAME="$WAN1GWIFNAME"
    OLDIFNAME="$WAN0GWIFNAME"
    FWMARK="$WAN1FWMARK"
    MASK="$WAN1MASK"
    OLDFWMARK="$WAN0FWMARK"
    OLDMASK="$WAN0MASK"
    OLDSTATE="$WAN0STATE"
  fi
  ROUTETABLE="main"
  IPV6ROUTETABLE="main"
  RGW="2"
  PRIORITY="150"
elif [[ "$INTERFACE" == "wan0" ]] &>/dev/null;then
  STATE="$WAN0STATE"
  ROUTETABLE="wan0"
  IPV6ROUTETABLE="main"
  RGW="2"
  PRIORITY="150"
  GATEWAY="$WAN0GATEWAY"
  IFNAME="$WAN0GWIFNAME"
  FWMARK="$WAN0FWMARK"
  MASK="$WAN0MASK"
  PRIMARY="$WAN0PRIMARY"
elif [[ "$INTERFACE" == "wan1" ]] &>/dev/null;then
  STATE="$WAN1STATE"
  ROUTETABLE="wan1"
  IPV6ROUTETABLE="main"
  RGW="2"
  PRIORITY="150"
  GATEWAY="$WAN1GATEWAY"
  IFNAME="$WAN1GWIFNAME"
  FWMARK="$WAN1FWMARK"
  MASK="$WAN1MASK"
  PRIMARY="$WAN1PRIMARY"
else
  echo -e "${RED}Policy: Unable to query Interface${NOCOLOR}"
  return
fi

# Set State to 0 if Null
if [[ -z "${STATE}" ]] &>/dev/null;then
  STATE="0"
fi

# Create Default Route for WAN Interface Routing Tables
if [[ -n "${GATEWAY}" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking ${INTERFACE} for Default Route in Routing Table ${ROUTETABLE}"
  if [[ -z "$(ip route list default table $ROUTETABLE | grep -w "${IFNAME}")" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Routing Director - Adding default route for ${INTERFACE} Routing Table via ${GATEWAY} dev ${IFNAME}"
    ip route add default via ${GATEWAY} dev ${IFNAME} table ${ROUTETABLE} \
    && logger -p 4 -t "$ALIAS" "Routing Director - Added default route for ${INTERFACE} Routing Table via ${GATEWAY} dev ${IFNAME}" \
    || logger -p 2 -st "$ALIAS" "Routing Director - ***Error*** Failed to add default route for ${INTERFACE} Routing Table via ${GATEWAY} dev ${IFNAME}"
  fi
fi

# Create IPv6 Default Route for VPN Client Interface Routing Tables
if [[ -n "${IPV6VPNGW}" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking ${INTERFACE} for Default IPv6 Route in Routing Table ${ROUTETABLE}"
  if [[ -z "$(ip -6 route list default table ${ROUTETABLE})" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Routing Director - Adding default IPv6 route for ${INTERFACE} IPv6 Routing Table via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE}"
    ip -6 route add default via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
    && logger -p 4 -t "$ALIAS" "Routing Director - Added default route for ${INTERFACE} IPv6 Routing Table via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE}" \
    || logger -p 2 -st "$ALIAS" "Routing Director - ***Error*** Failed to add default route for ${INTERFACE} IPv6 Routing Table via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE}"
  fi
fi

return
}

# Create Policy
createpolicy ()
{
if [[ "${mode}" == "createpolicy" ]] &>/dev/null;then
  # User Input for Policy Name
  while true;do  
    read -r -p "Policy Name: " NEWPOLICYNAME
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

WGFILES='
/etc/wg/wgc1_status
/etc/wg/wgc2_status
/etc/wg/wgc3_status
/etc/wg/wgc4_status
/etc/wg/wgc5_status
'

INTERFACES=""
  # Check if OpenVPN Interfaces are Active
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

  # Check if Wireguard Interfaces are Active
  for WGFILE in ${WGFILES};do
    if [[ -f "$WGFILE" ]] &>/dev/null && [[ -s "$WGFILE" ]] &>/dev/null;then
      INTERFACE="wgc"$(echo $WGFILE | grep -o '[0-9]')""
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done

  # Check if WAN is configured in Single or Dual WAN
  if [[ "$WANSDUALWANENABLE" == "0" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
  elif [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
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
    read -r -p "Select an Interface for this Policy: " NEWPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [[ "$NEWPOLICYINTERFACE" == "${INTERFACE}" ]] &>/dev/null;then
        CREATEPOLICYINTERFACE="$NEWPOLICYINTERFACE"
        break 2
      elif [[ -n "$(echo "${INTERFACES}" | grep -w "$NEWPOLICYINTERFACE")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid VPN Interface***${NOCOLOR}"
        break 1
      fi
    done
  done

  # Enable Verbose Logging
  while true;do  
    read -r -p "Enable verbose logging for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETVERBOSELOGGING="VERBOSELOGGING=1"; break;;
        [Nn]* ) SETVERBOSELOGGING="VERBOSELOGGING=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Enable Private IP Addresses
  while true;do  
    read -r -p "Enable Private IP Addresses for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETPRIVATEIPS="PRIVATEIPS=1"; break;;
        [Nn]* ) SETPRIVATEIPS="PRIVATEIPS=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Create Policy Files
  if [[ ! -f $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist' ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Create Policy - Creating ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist"
    touch -a $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist' \
    && chmod 666 $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domainlist' \
    && logger -p 4 -st "$ALIAS" "Create Policy - ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist created" \
    || logger -p 2 -st "$ALIAS" "Create Policy - ***Error*** Failed to create ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist"
  fi
  if [[ ! -f $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP' ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Create Policy - Creating ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP"
    touch -a $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP' \
    && chmod 666 $POLICYDIR/'policy_'$CREATEPOLICYNAME'_domaintoIP' \
    && logger -p 4 -st "$ALIAS" "Create Policy - ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP created" \
    || logger -p 2 -st "$ALIAS" "Create Policy - ***Error*** Failed to create ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP"
  fi
  # Adding Policy to Config File
  if [[ -z "$(awk -F "|" '/^'${CREATEPOLICYNAME}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Create Policy - Adding ${CREATEPOLICYNAME} to ${CONFIGFILE}"
    echo -e "${CREATEPOLICYNAME}|${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist|${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP|${CREATEPOLICYINTERFACE}|${SETVERBOSELOGGING}|${SETPRIVATEIPS}" >> ${CONFIGFILE} \
    && logger -p 4 -st "$ALIAS" "Create Policy - Added ${CREATEPOLICYNAME} to ${CONFIGFILE}" \
    || logger -p 2 -st "$ALIAS" "Create Policy - ***Error*** Failed to add ${CREATEPOLICYNAME} to ${CONFIGFILE}"
  fi
fi
return
}

# Show Policy
showpolicy ()
{
if [[ "$POLICY" == "all" ]] &>/dev/null;then
  echo -e "Policies: \n$(awk -F "|" '{print $1}' ${CONFIGFILE})"
  return
elif [[ "$POLICY" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
  echo "Policy Name: $(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})"
  echo "Interface: $(awk -F "|" '/^'${POLICY}'/ {print $4}' ${CONFIGFILE})"
  if [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=1" ]] &>/dev/null;then
    echo "Verbose Logging: Enabled"
  elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=0" ]] &>/dev/null;then
    echo "Verbose Logging: Disabled"
  elif [[ -z "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" ]] &>/dev/null;then
    echo "Verbose Logging: Not Configured"
  fi
  if [[ "$(awk -F "|" '/^'${POLICY}'/ {print $6}' ${CONFIGFILE})" == "PRIVATEIPS=1" ]] &>/dev/null;then
    echo "Private IP Addresses: Enabled"
  elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $6}' ${CONFIGFILE})" == "PRIVATEIPS=0" ]] &>/dev/null;then
    echo "Private IP Addresses: Disabled"
  elif [[ -z "$(awk -F "|" '/^'${POLICY}'/ {print $6}' ${CONFIGFILE})" ]] &>/dev/null;then
    echo "Private IP Addresses: Not Configured"
  fi
  DOMAINS="$(cat ${POLICYDIR}/policy_${POLICY}_domainlist | sort -u)"


  echo -e "Domains:"
  for DOMAIN in ${DOMAINS};do
    echo -e "${DOMAIN}"
  done
  return
else
  echo -e "${RED}Policy: $POLICY not found${NOCOLOR}"
  return
fi
return
}

# Edit Policy
editpolicy ()
{
# Prompt for confirmation to edit policy
if [[ "${mode}" == "editpolicy" ]] &>/dev/null;then
  if [[ "$POLICY" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to edit Policy: $POLICY"
    EDITPOLICY="$POLICY"
  else
    echo -e "${RED}Policy: $POLICY not found${NOCOLOR}"
    return
  fi

# Select VPN Interface for Policy
# Array of OVPN Files
OVPNCONFIGFILES='
/etc/openvpn/client1/config.ovpn
/etc/openvpn/client2/config.ovpn
/etc/openvpn/client3/config.ovpn
/etc/openvpn/client4/config.ovpn
/etc/openvpn/client5/config.ovpn
/etc/openvpn/server1/config.ovpn
/etc/openvpn/server2/config.ovpn
'
# Array of WireGuard Files
WGFILES='
/etc/wg/wgc1_status
/etc/wg/wgc2_status
/etc/wg/wgc3_status
/etc/wg/wgc4_status
/etc/wg/wgc5_status
'

  # Generate List of available interfaces
  # Generate available OVPN interfaces
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


  # Generate available WireGuard interfaces
  for WGFILE in ${WGFILES};do
    if [[ -f "$WGFILE" ]] &>/dev/null && [[ -s "$WGFILE" ]] &>/dev/null;then
      INTERFACE="wgc"$(echo $WGFILE | grep -o '[0-9]')""
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done

  # Generate available WAN interfaces
  if [[ "$WANSDUALWANENABLE" == "0" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
  elif [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
    INTERFACES="${INTERFACES} wan0"
    INTERFACES="${INTERFACES} wan1"
  fi

  # Display available interfaces
  echo -e "\nInterfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "$INTERFACE"
  done

  # User input to select an interface
  while true;do  
    echo -e "Current Interface: $(awk -F "|" '/^'${EDITPOLICY}'/ {print $4}' ${CONFIGFILE})"
    read -r -p "Select an Interface for this Policy: " EDITPOLICYINTERFACE
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
    read -r -p "Enable verbose logging for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETVERBOSELOGGING="VERBOSELOGGING=1"; break;;
        [Nn]* ) SETVERBOSELOGGING="VERBOSELOGGING=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Enable Private IP Addresses
  while true;do  
    read -r -p "Enable Private IP Addresses for this policy? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETPRIVATEIPS="PRIVATEIPS=1"; break;;
        [Nn]* ) SETPRIVATEIPS="PRIVATEIPS=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Set process priority
  if [[ -n "${PROCESSPRIORITY+x}" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting Process Priority to ${PROCESSPRIORITY}"
    renice -n ${PROCESSPRIORITY} $$ \
    && logger -p 4 -t "$ALIAS" "Edit Policy - Set Process Priority to ${PROCESSPRIORITY}" \
    || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to set Process Priority to ${PROCESSPRIORITY}"
  fi

  # Editing Policy in Config File
  if [[ -n "$(awk -F "|" '/^'${EDITPOLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Edit Policy - Modifying $EDITPOLICY in $CONFIGFILE"
    OLDINTERFACE="$(awk -F "|" '/^'${EDITPOLICY}'/ {print $4}' ${CONFIGFILE})"
    sed -i "\:"$EDITPOLICY":d" "$CONFIGFILE"
    echo -e "${EDITPOLICY}|${POLICYDIR}/policy_${EDITPOLICY}_domainlist|${POLICYDIR}/policy_${EDITPOLICY}_domaintoIP|${NEWPOLICYINTERFACE}|${SETVERBOSELOGGING}|${SETPRIVATEIPS}" >> $CONFIGFILE \
    && logger -p 4 -st "$ALIAS" "Edit Policy - Modified ${EDITPOLICY} in ${CONFIGFILE}" \
    || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to modify ${EDITPOLICY} in ${CONFIGFILE}"
  else
    echo -e "${YELLOW}${EDITPOLICY} not found in ${CONFIGFILE}...${NOCOLOR}"
    logger -p 3 -t "$ALIAS" "Edit Policy - ${EDITPOLICY} not found in ${CONFIGFILE}"
  fi
  
  # Check if routes need to be modified
  if [[ "$NEWPOLICYINTERFACE" != "$OLDINTERFACE" ]] &>/dev/null;then

    # Check if old interface is no longer being used by a policy
    if [[ -z "$(awk -F "|" '$4 == "'${OLDINTERFACE}'" {print $4}' "${CONFIGFILE}" | sort -u)" ]] &>/dev/null;then
      ifnotinuse="1"
    else
      ifnotinuse="0"
    fi

# Array for old and new interfaces
INTERFACES='
'$OLDINTERFACE'
'$NEWPOLICYINTERFACE'
'

    # Generate old and new values for each interface
    for INTERFACE in ${INTERFACES};do
      routingdirector || return
      if [[ "$INTERFACE" == "$OLDINTERFACE" ]] &>/dev/null;then
        OLDROUTETABLE="$ROUTETABLE"
        OLDRGW="$RGW"
        OLDPRIORITY="$PRIORITY"
        OLDIFNAME="$IFNAME"
        OLDFWMARK="$FWMARK"
        OLDMASK="$MASK"
        OLDIPV6VPNGW="$IPV6VPNGW"
        OLDIPV6ROUTETABLE="$IPV6ROUTETABLE"
        OLDSTATE="$STATE"
      elif [[ "$INTERFACE" == "$NEWPOLICYINTERFACE" ]] &>/dev/null;then
        NEWROUTETABLE="$ROUTETABLE"
        NEWRGW="$RGW"
        NEWPRIORITY="$PRIORITY"
        NEWIFNAME="$IFNAME"
        NEWFWMARK="$FWMARK"
        NEWMASK="$MASK"
        NEWIPV6VPNGW="$IPV6VPNGW"
        NEWIPV6ROUTETABLE="$IPV6ROUTETABLE"
        NEWSTATE="$STATE"
      fi
    done

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "${POLICYDIR}/policy_${EDITPOLICY}_domaintoIP" | sort -u)"
    IPV4S="$(grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" "${POLICYDIR}/policy_${EDITPOLICY}_domaintoIP" | sort -u)"

    # Create IPv6 IPSET
    if [[ -z "$(ipset list DomainVPNRouting-${EDITPOLICY}-ipv6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Creating IPv6 IPSET for ${EDITPOLICY}"
      ipset create DomainVPNRouting-${EDITPOLICY}-ipv6 hash:ip family inet6 comment \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Created IPv6 IPSET for ${EDITPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to create IPv6 IPSET for ${EDITPOLICY}"
    fi
    # Create IPv4 IPSET
    if [[ -z "$(ipset list DomainVPNRouting-${EDITPOLICY}-ipv4 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Creating IPv4 IPSET for ${EDITPOLICY}"
      ipset create DomainVPNRouting-${EDITPOLICY}-ipv4 hash:ip family inet comment \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Created IPv4 IPSET for ${EDITPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to create IPv4 IPSET for ${EDITPOLICY}"
    fi

    # Recreate IPv6
    if [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null;then
      # Recreate FWMark IPv6 Rule
      if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -n "$(ip -6 route show default dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null && [[ -z "$(ip -6 rule list from all fwmark ${NEWFWMARK}/${NEWMASK} table ${NEWIPV6ROUTETABLE} priority ${NEWPRIORITY})" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Checking for IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
        ip -6 rule add from all fwmark ${NEWFWMARK}/${NEWMASK} table ${NEWIPV6ROUTETABLE} priority ${NEWPRIORITY} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Added IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
      elif [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && { [[ -z "$(ip -6 route show default dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null || [[ "$PRIMARY" == "0" ]] &>/dev/null ;} && [[ -z "$(ip -6 rule list from all fwmark ${NEWFWMARK}/${NEWMASK} priority ${NEWPRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Checking for Unreachable IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
        ip -6 rule add unreachable from all fwmark ${NEWFWMARK}/${NEWMASK} priority ${NEWPRIORITY} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Added Unreachable IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add Unreachable IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
      fi
      # Recreate IPv6 IP6Tables OUTPUT Rule
      if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${EDITPOLICY}'-ipv6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Adding IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${NEWFWMARK}"
        ip6tables -t mangle -A OUTPUT -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Added IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${NEWFWMARK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${NEWFWMARK}"
      fi
      # Recreate IPv6 IP6Tables PREROUTING Rule
      if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${EDITPOLICY}'-ipv6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Adding IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${NEWFWMARK}"
        ip6tables -t mangle -A PREROUTING -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Added IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${NEWFWMARK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${NEWFWMARK}"
      fi
      # Recreate IPv6 IP6Tables POSTROUTING Rule
      if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${NEWIFNAME}'" && $10 == "DomainVPNRouting-'${EDITPOLICY}'-ipv6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Adding IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 Interface: ${NEWIFNAME} FWMark: ${NEWFWMARK}"
        ip6tables -t mangle -A POSTROUTING -o ${NEWIFNAME} -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Added IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 Interface: ${NEWIFNAME} FWMark: ${NEWFWMARK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 Interface: ${NEWIFNAME} FWMark: ${NEWFWMARK}"
      fi
      # Delete Old FWMark IPv6 Rule
      if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip -6 rule list from all fwmark ${OLDFWMARK}/${OLDMASK} table ${OLDIPV6ROUTETABLE} priority ${OLDPRIORITY})" ]] &>/dev/null && [[ "$ifnotinuse" == "1" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Checking for IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
        ip -6 rule del from all fwmark ${OLDFWMARK}/${OLDMASK} table ${OLDIPV6ROUTETABLE} priority ${OLDPRIORITY} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
      fi
      # Delete Old FWMark IPv6 Unreachable Rule
      if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip -6 rule list from all fwmark ${OLDFWMARK}/${OLDMASK} priority ${OLDPRIORITY} | grep -w "unreachable")" ]] &>/dev/null && [[ "$ifnotinuse" == "1" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Checking for Unreachable IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
        ip -6 rule del unreachable from all fwmark ${OLDFWMARK}/${OLDMASK} priority ${OLDPRIORITY} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Added Unreachable IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add Unreachable IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
      fi
      # Delete Old IPv6 IP6Tables OUTPUT Rule
      if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${EDITPOLICY}'-ipv6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Deleting IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${OLDFWMARK}"
        ip6tables -t mangle -D OUTPUT -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${OLDFWMARK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${OLDFWMARK}"
      fi
      # Delete Old IPv6 IP6Tables PREROUTING Rule
      if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${EDITPOLICY}'-ipv6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Deleting IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${OLDFWMARK}"
        ip6tables -t mangle -D PREROUTING -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${OLDFWMARK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 FWMark: ${OLDFWMARK}"
      fi
      # Delete Old IPv6 IP6Tables POSTROUTING Rule
      if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${OLDIFNAME}'" && $10 == "DomainVPNRouting-'${EDITPOLICY}'-ipv6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Deleting IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 Interface: ${OLDIFNAME} FWMark: ${OLDFWMARK}"
        ip6tables -t mangle -D POSTROUTING -o ${OLDIFNAME} -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 Interface: ${OLDIFNAME} FWMark: ${OLDFWMARK}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv6 Interface: ${OLDIFNAME} FWMark: ${OLDFWMARK}"
      fi

      # Recreate IPv6 Routes
      for IPV6 in ${IPV6S}; do
        # Delete old IPv6 Route
        if [[ -n "$(ip -6 route list ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" "Edit Policy - Deleting route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
          ip -6 route del ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
          && logger -p 4 -st "$ALIAS" "Edit Policy - Route deleted for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
          || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
        fi
        # Create IPv6 Routes if necessary due to lack of FWMark Rules
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -z "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip -6 route show default dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null;then
          # Check for IPv6 prefix error and create new IPv6 routes
          if [[ -n "$(ip -6 route list ${IPV6} 2>&1 | grep -w "Error: inet6 prefix is expected rather than \"${IPV6}\"." )" ]] &>/dev/null;then
            if [[ -z "$(ip -6 route list ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null;then
              logger -p 5 -t "$ALIAS" "Edit Policy - Adding route for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              ip -6 route add ${IPV6}:: dev ${IFNAME} table ${NEWIPV6ROUTETABLE} &>/dev/null \
              || rc="$?" \
              && { rc="$?" && logger -p 4 -t "$ALIAS" "Edit Policy - Route added for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}" ;}
              # Generate Error Log
              if [[ "${rc+x}" ]] &>/dev/null;then
                continue
              elif [[ "$rc" == "2" ]] &>/dev/null;then
                logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Route already exists for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              elif [[ "$rc" != "0" ]] &>/dev/null;then
                logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Unable to add route for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              fi
            fi
          else
            if [[ -z "$(ip -6 route list ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null;then
              logger -p 5 -t "$ALIAS" "Edit Policy - Adding route for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              ip -6 route add ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE} &>/dev/null \
              || rc="$?" \
              && { rc="$?" && logger -p 4 -t "$ALIAS" "Edit Policy - Route added for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}" ;}
              # Generate Error Log
              if [[ "${rc+x}" ]] &>/dev/null;then
                continue
              elif [[ "$rc" == "2" ]] &>/dev/null;then
                logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Route already exists for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              elif [[ "$rc" != "0" ]] &>/dev/null;then
                logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Unable to add route for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              fi
            fi
          fi
        fi
      done

      # Save IPv6 IPSET if save file does not exist
      if [[ ! -f "${POLICYDIR}/policy_${EDITPOLICY}-ipv6.ipset" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Edit Policy - Saving IPv6 IPSET for ${EDITPOLICY}"
        ipset save DomainVPNRouting-${EDITPOLICY}-ipv6 -file ${POLICYDIR}/policy_${EDITPOLICY}-ipv6.ipset \
        && logger -p 4 -st "$ALIAS" "Edit Policy - Save IPv6 IPSET for ${EDITPOLICY}" \
        || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to save IPv6 IPSET for ${EDITPOLICY}"
      fi
    fi

    # Recreate IPv4
    # Recreate FWMark IPv4 Rule
    if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -n "$(ip route show default table ${NEWROUTETABLE})" ]] &>/dev/null && [[ -z "$(ip rule list from all fwmark ${NEWFWMARK}/${NEWMASK} table ${NEWROUTETABLE} priority ${NEWPRIORITY})" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Checking for IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
      ip rule add from all fwmark ${NEWFWMARK}/${NEWMASK} table ${NEWROUTETABLE} priority ${NEWPRIORITY} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Added IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
    elif [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip route show default table ${NEWROUTETABLE})" ]] &>/dev/null && [[ -z "$(ip rule list from all fwmark ${NEWFWMARK}/${NEWMASK} priority ${NEWPRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Checking for Unreachable IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
      ip rule add unreachable from all fwmark ${NEWFWMARK}/${NEWMASK} priority ${NEWPRIORITY} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Added Unreachable IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add Unreachable IP Rule for Interface: ${NEWPOLICYINTERFACE} using FWMark: ${NEWFWMARK}/${NEWMASK}"
    fi
    # Recreate IPv4 IPTables OUTPUT Rule
    if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${EDITPOLICY}'-ipv4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Adding IPTables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${NEWFWMARK}"
      iptables -t mangle -A OUTPUT -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Added IPTables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${NEWFWMARK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${NEWFWMARK}"
    fi
    # Recreate IPv4 IPTables PREROUTING Rule
    if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${EDITPOLICY}'-ipv4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Adding IPTables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${NEWFWMARK}"
      iptables -t mangle -A PREROUTING -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Added IPTables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${NEWFWMARK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${NEWFWMARK}"
    fi
    # Recreate IPv4 IPTables POSTROUTING Rule
    if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${NEWIFNAME}'" && $11 == "DomainVPNRouting-'${EDITPOLICY}'-ipv4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Adding IPTables rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 Interface: ${NEWIFNAME} FWMark: ${NEWFWMARK}"
      iptables -t mangle -A POSTROUTING -o ${NEWIFNAME} -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Added IPTables rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 Interface: ${NEWIFNAME} FWMark: ${NEWFWMARK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IPTables rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 Interface: ${NEWIFNAME} FWMark: ${NEWFWMARK}"
    fi
    # Delete Old FWMark IPv4 Rule
    if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip rule list from all fwmark ${OLDFWMARK}/${OLDMASK} table ${OLDROUTETABLE} priority ${OLDPRIORITY})" ]] &>/dev/null && [[ "$ifnotinuse" == "1" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Checking for IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
      ip rule del from all fwmark ${OLDFWMARK}/${OLDMASK} table ${OLDROUTETABLE} priority ${OLDPRIORITY} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
    fi
    # Delete Old FWMark IPv4 Unreachable Rule
    if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip rule list from all fwmark ${OLDFWMARK}/${OLDMASK} priority ${OLDPRIORITY} | grep -w "unreachable")" ]] &>/dev/null && [[ "$ifnotinuse" == "1" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Checking for Unreachable IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
      ip rule del unreachable from all fwmark ${OLDFWMARK}/${OLDMASK} priority ${OLDPRIORITY} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Added Unreachable IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add Unreachable IP Rule for Interface: ${OLDINTERFACE} using FWMark: ${OLDFWMARK}/${OLDMASK}"
    fi
    # Delete Old IPv4 IPTables OUTPUT Rule
    if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${EDITPOLICY}'-ipv4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Deleting IPTables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${OLDFWMARK}"
      iptables -t mangle -D OUTPUT -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IPTables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${OLDFWMARK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IPTables OUTPUT rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${OLDFWMARK}"
    fi
    # Delete Old IPv4 IPTables PREROUTING Rule
    if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${EDITPOLICY}'-ipv4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Deleting IPTables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${OLDFWMARK}"
      iptables -t mangle -D PREROUTING -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IPTables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${OLDFWMARK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IPTables PREROUTING rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 FWMark: ${OLDFWMARK}"
    fi
    # Delete Old IPv4 IPTables POSTROUTING Rule
    if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${OLDIFNAME}'" && $11 == "DomainVPNRouting-'${EDITPOLICY}'-ipv4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Deleting IPTables rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 Interface: ${OLDIFNAME} FWMark: ${OLDFWMARK}"
      iptables -t mangle -D POSTROUTING -o ${OLDIFNAME} -m set --match-set DomainVPNRouting-${EDITPOLICY}-ipv4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Deleted IPTables rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 Interface: ${OLDIFNAME} FWMark: ${OLDFWMARK}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IPTables rule for IPSET: DomainVPNRouting-${EDITPOLICY}-ipv4 Interface: ${OLDIFNAME} FWMark: ${OLDFWMARK}"
    fi

    # Recreate IPv4 Routes and IPv4 Rules
    for IPV4 in ${IPV4S}; do
      if [[ "$OLDRGW" == "0" ]] &>/dev/null;then
        # Delete old IPv4 routes
        if [[ -n "$(ip route list $IPV4 dev ${OLDIFNAME} table ${OLDROUTETABLE})" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" "Edit Policy - Deleting route for $IPV4 dev ${OLDIFNAME} table ${OLDROUTETABLE}"
          ip route del ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE} &>/dev/null \
          && logger -p 4 -t "$ALIAS" "Edit Policy - Route deleted for ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE}" \
          || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete route for ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE}"
        fi
      # Delete old IPv4 rules
      elif [[ "$OLDRGW" != "0" ]] &>/dev/null;then
        if [[ -n "$(ip rule list from all to ${IPV4} lookup ${OLDROUTETABLE} priority ${OLDPRIORITY})" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" "Edit Policy - Deleting IP Rule for ${IPV4} table ${OLDROUTETABLE} priority ${OLDPRIORITY}"
          ip rule del from all to ${IPV4} table ${OLDROUTETABLE} priority ${OLDPRIORITY} &>/dev/null \
          && logger -p 4 -t "$ALIAS" "Edit Policy - Deleted IP Rule for ${IPV4} table ${OLDROUTETABLE} priority ${OLDPRIORITY}" \
          || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to delete IP Rule for ${IPV4} table $OLDROUTETABLE priority ${OLDPRIORITY}"
        fi
      fi
      # Create new IPv4 routes and IPv4 rules if necessary
      if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -z "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip route show default table ${NEWROUTETABLE})" ]] &>/dev/null;then
        # Create new IPv4 routes
        if [[ "$NEWRGW" == "0" ]] &>/dev/null;then
          if [[ -z "$(ip route list ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE})" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Edit Policy - Adding route for ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE}"
            ip route add ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE} &>/dev/null \
            && logger -p 4 -t "$ALIAS" "Edit Policy - Route added for ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE}" \
            || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add route for ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE}"
          fi
        # Create new IPv4 rules
        elif [[ "$NEWRGW" != "0" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from all to ${IPV4} lookup ${NEWROUTETABLE} priority ${NEWPRIORITY})" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Edit Policy - Adding IP Rule for ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY}"
            ip rule add from all to ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY} &>/dev/null \
            && logger -p 4 -t "$ALIAS" "Edit Policy - Added IP Rule for ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY}" \
            || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to add IP Rule for ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY}"
          fi
        fi
      fi
    done
    # Save IPv4 IPSET if save file does not exist
    if [[ ! -f "${POLICYDIR}/policy_${EDITPOLICY}-ipv4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Edit Policy - Saving IPv4 IPSET for ${EDITPOLICY}"
      ipset save DomainVPNRouting-${EDITPOLICY}-ipv4 -file ${POLICYDIR}/policy_${EDITPOLICY}-ipv4.ipset \
      && logger -p 4 -st "$ALIAS" "Edit Policy - Save IPv4 IPSET for ${EDITPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Edit Policy - ***Error*** Failed to save IPv4 IPSET for ${EDITPOLICY}"
    fi
  fi
fi
# Reset ifnotinuse flag
[[ -n "${ifnotinuse+x}" ]] &>/dev/null && unset ifnotinuse
return
}

# Delete Policy
deletepolicy ()
{
# Prompt for confirmation
if [[ "${mode}" == "deletepolicy" ]] &>/dev/null || [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  if [[ "$POLICY" == "all" ]] &>/dev/null;then
    [[ "${mode}" != "uninstall" ]] &>/dev/null && read -n 1 -s -r -p "Press any key to continue to delete all policies"
    DELETEPOLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
  elif [[ "$POLICY" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to delete Policy: ${POLICY}"
    DELETEPOLICIES=${POLICY}
  else
    echo -e "${RED}Policy: ${POLICY} not found${NOCOLOR}"
    return
  fi
  for DELETEPOLICY in ${DELETEPOLICIES};do
    # Determine Interface and Route Table for IP Routes to delete.
    INTERFACE="$(awk -F "|" '/^'${DELETEPOLICY}'/ {print $4}' ${CONFIGFILE})"
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP" | sort -u)"
    IPV4S="$(grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" "${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP" | sort -u)"

    # Delete IPv6
    # Delete FWMark IPv6 Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip -6 rule list from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Checking for IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ip -6 rule del from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
    # Delete Old FWMark IPv6 Unreachable Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Checking for Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ip -6 rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Added Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to add Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
    # Delete IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${DELETEPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D OUTPUT -m set --match-set DomainVPNRouting-${DELETEPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${DELETEPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D PREROUTING -m set --match-set DomainVPNRouting-${DELETEPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "DomainVPNRouting-'${DELETEPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set DomainVPNRouting-${DELETEPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IPSET
    if [[ -n "$(ipset list DomainVPNRouting-${DELETEPOLICY}-ipv6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IPv6 IPSET for ${DELETEPOLICY}"
      ipset destroy DomainVPNRouting-${DELETEPOLICY}-ipv6 \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPv6 IPSET for ${DELETEPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPv6 IPSET for ${DELETEPOLICY}"
    fi
    # Delete saved IPv6 IPSET
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}-ipv6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IPv6 IPSET saved file for ${DELETEPOLICY}"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}-ipv6.ipset \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPv6 IPSET saved file for ${DELETEPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPv6 IPSET saved file for ${DELETEPOLICY}"
    fi
    # Delete IPv6 Routes
    for IPV6 in ${IPV6S};do
      if [[ -n "$(ip -6 route list ${IPV6} dev $IFNAME table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Delete Policy - Deleting route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && logger -p 4 -t "$ALIAS" "Delete Policy - Route deleted for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" \
        || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi
    done

    # Delete IPv4
    # Delete FWMark IPv4 Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Checking for IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ip rule del from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
    # Delete Old FWMark IPv4 Unreachable Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Checking for Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ip rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Added Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to add Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
    # Delete IPv4 IPTables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${DELETEPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IPTables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 FWMark: ${FWMARK}"
      iptables -t mangle -D OUTPUT -m set --match-set DomainVPNRouting-${DELETEPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPTables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPTables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${DELETEPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IPTables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 FWMark: ${FWMARK}"
      iptables -t mangle -D PREROUTING -m set --match-set DomainVPNRouting-${DELETEPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPTables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPTables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "DomainVPNRouting-'${DELETEPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IPTables rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}"
      iptables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set DomainVPNRouting-${DELETEPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPTables rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPTables rule for IPSET: DomainVPNRouting-${DELETEPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPSET
    if [[ -n "$(ipset list DomainVPNRouting-${DELETEPOLICY}-ipv4 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Creating IPv4 IPSET for ${DELETEPOLICY}"
      ipset destroy DomainVPNRouting-${DELETEPOLICY}-ipv4 \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPv4 IPSET for ${DELETEPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPv4 IPSET for ${DELETEPOLICY}"
    fi
    # Delete saved IPv4 IPSET
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}-ipv4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IPv4 IPSET saved file for ${DELETEPOLICY}"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}-ipv4.ipset \
      && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IPv4 IPSET saved file for ${DELETEPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IPv4 IPSET saved file for ${DELETEPOLICY}"
    fi

    # Delete IPv4 routes and IP rules
    for IPV4 in ${IPV4S};do
      if [[ "$RGW" == "0" ]] &>/dev/null;then
        if [[ -n "$(ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" "Delete Policy - Deleting route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
          ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} \
          && logger -p 4 -t "$ALIAS" "Delete Policy - Route deleted for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" \
          || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
        fi
      elif [[ "$RGW" != "0" ]] &>/dev/null;then
        if [[ -n "$(ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" "Delete Policy - Deleting IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
          ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} \
          && logger -p 4 -t "$ALIAS" "Delete Policy - Deleted IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
          || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
        fi
      fi
    done

    # Removing policy files
    # Removing domain list
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}_domainlist" ]] &>/dev/null;then
      logger -p 5 -st "$ALIAS" "Delete Policy - Deleting ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist \
      && logger -p 4 -st "$ALIAS" "Delete Policy - ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist deleted" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist"
    fi
    # Removing domain to IP list
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP" ]] &>/dev/null;then
      logger -p 5 -st "$ALIAS" "Delete Policy - Deleting ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP \
      && logger -p 4 -st "$ALIAS" "Delete Policy - ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP deleted" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP"
    fi
    # Removing Policy from Config File
    if [[ -n "$(awk -F "|" '/^'${DELETEPOLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
      logger -p 5 -st "$ALIAS" "Delete Policy - Deleting ${DELETEPOLICY} to ${CONFIGFILE}"
      POLICYTODELETE="$(grep -w "$DELETEPOLICY" ${CONFIGFILE})"
      sed -i "\:"$POLICYTODELETE":d" "${CONFIGFILE}" \
      && logger -p 4 -st "$ALIAS" "Delete Policy - Deleted $POLICY from ${CONFIGFILE}" \
      || logger -p 2 -st "$ALIAS" "Delete Policy - ***Error*** Failed to delete $POLICY from ${CONFIGFILE}"
    fi
  done
fi
return
}

# Add Domain to Policy
adddomain ()
{
# Prompt for policy to select
if [[ -n "${DOMAIN}" ]] &>/dev/null;then
  # Select Policy for New Domain
  POLICIES="$(awk -F "|" '{print $1}' ${CONFIGFILE})"
  echo -e "${LIGHTCYAN}Select a Policy for the new Domain:${NOCOLOR} \r\n$POLICIES"
  # User Input for Policy for New Domain
  while true;do  
    read -r -p "Policy: " NEWDOMAINPOLICY
    for POLICY in ${POLICIES};do
      if [[ "$NEWDOMAINPOLICY" == "${POLICY}" ]] &>/dev/null;then
        POLICY=$NEWDOMAINPOLICY
        break 2
      elif [[ -n "$(echo "${POLICIES}" | grep -w "$NEWDOMAINPOLICY")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a Valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n${POLICIES}"
        break 1
      fi
    done
  done

  # Check if Domain is already added to policy and if not add it
  if [[ -z "$(awk '$0 == "'${DOMAIN}'" {print}' "${POLICYDIR}/policy_${POLICY}_domainlist")" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Add Domain - Adding ${DOMAIN} to ${POLICY}"
    echo -e "$DOMAIN" >> "${POLICYDIR}/policy_${POLICY}_domainlist" \
    && logger -p 4 -st "$ALIAS" "Add Domain - Added ${DOMAIN} to ${POLICY}" \
    || logger -p 2 -st "$ALIAS" "Add Domain - ***Error*** Failed to add ${DOMAIN} to ${POLICY}"
  else
    echo -e "${RED}***Domain already added to ${POLICY}***${NOCOLOR}"
  fi
elif [[ -z "$DOMAIN" ]] &>/dev/null;then
  echo -e "${RED}***No Domain Specified***${NOCOLOR}"
fi
return
}

# Delete domain from policy
deletedomain ()
{
# Select Policy for Domain to Delete
POLICIES="$(awk -F "|" '{print $1}' ${CONFIGFILE})"
echo -e "Select a Policy to delete ${DOMAIN}: \r\n${POLICIES}"
  # User Input for Policy for Deleting Domain
  while true;do  
    read -r -p "Policy: " DELETEDOMAINPOLICY
    for POLICY in ${POLICIES};do
      if [[ "$DELETEDOMAINPOLICY" == "${POLICY}" ]] &>/dev/null;then
        POLICY=${DELETEDOMAINPOLICY}
        break 2
      elif [[ -n "$(echo "${POLICIES}" | grep -w "$DELETEDOMAINPOLICY")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n${POLICIES}"
        break 1
      fi
    done
  done

# Set process priority
if [[ -n "${PROCESSPRIORITY+x}" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Setting Process Priority to ${PROCESSPRIORITY}"
  renice -n ${PROCESSPRIORITY} $$ \
  && logger -p 4 -t "$ALIAS" "Delete Domain - Set Process Priority to ${PROCESSPRIORITY}" \
  || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to set Process Priority to ${PROCESSPRIORITY}"
fi

# Check if Domain is null and delete from policy
if [[ -n "$DOMAIN" ]] &>/dev/null;then
  if [[ -n "$(awk '$0 == "'${DOMAIN}'" {print}' "${POLICYDIR}/policy_${POLICY}_domainlist")" ]] &>/dev/null;then
    # Determine Domain Policy Files and Interface and Route Table for IP Routes to delete.
    DOMAINLIST="$(awk -F "|" '/^'${POLICY}'/ {print $2}' ${CONFIGFILE})"
    DOMAINIPLIST="$(awk -F "|" '/^'${POLICY}'/ {print $3}' ${CONFIGFILE})"
    INTERFACE="$(awk -F "|" '/^'${POLICY}'/ {print $4}' ${CONFIGFILE})"
    # Check if Verbose Logging is Enabled
    if [[ -z "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" ]] &>/dev/null;then
      VERBOSELOGGING="1"
    elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=0" ]] &>/dev/null;then
      VERBOSELOGGING="0"
    elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=1" ]] &>/dev/null;then
      VERBOSELOGGING="1"
    fi
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(grep -w "$DOMAIN" ${DOMAINIPLIST} | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" | sort -u)"
    IPV4S="$(grep -w "$DOMAIN" ${DOMAINIPLIST} | grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | sort -u)"
 
    # Delete IPv6
    for IPV6 in ${IPV6S};do

      # Delete from IPv6 IPSET with prefix fixed
      if [[ -n "$(ipset list DomainVPNRouting-${POLICY}-ipv6 | grep -wo "${IPV6}:: 2>/dev/null")" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete Domain - Deleting ${IPV6}:: to IPSET: DomainVPNRouting-${POLICY}-ipv6"
        ipset del DomainVPNRouting-${POLICY}-ipv6 ${IPV6}:: \
        || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete ${IPV6}:: to IPSET: DomainVPNRouting-${POLICY}-ipv6" \
        && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete Domain - Deleting ${IPV6}:: to IPSET: DomainVPNRouting-${POLICY}-ipv6" ;}
      fi

      # Delete IPv6 Route with prefix fixed
      if [[ -n "$(ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete Domain - Deleting route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ip -6 route del ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete Domain - Route deleted for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi

      # Delete from IPv6 IPSET
      if [[ -n "$(ipset list DomainVPNRouting-${POLICY}-ipv6 | grep -wo "${IPV6} 2>/dev/null")" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete Domain - Deleting ${IPV6} to IPSET: DomainVPNRouting-${POLICY}-ipv6"
        ipset del DomainVPNRouting-${POLICY}-ipv6 ${IPV6} \
        || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete ${IPV6} to IPSET: DomainVPNRouting-${POLICY}-ipv6" \
        && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete Domain - Deleting ${IPV6} to IPSET: DomainVPNRouting-${POLICY}-ipv6" ;}
      fi

      # Delete IPv6 Route
      if [[ -n "$(ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete Domain - Deleting route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete Domain - Route deleted for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** ***Error*** Failed to delete route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi
    done

    # Save IPv6 IPSET if modified or does not exist
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if [[ "${saveipv6ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-ipv6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Domain - Saving IPv6 IPSET for ${POLICY}"
      ipset save DomainVPNRouting-${POLICY}-ipv6 -file ${POLICYDIR}/policy_${POLICY}-ipv6.ipset \
      && logger -p 4 -t "$ALIAS" "Delete Domain - Saved IPv6 IPSET for ${POLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to save IPv6 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset


    # Delete IPv4
    for IPV4 in ${IPV4S};do

      # Delete from IPv4 IPSET
      if [[ -n "$(ipset list DomainVPNRouting-${POLICY}-ipv4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete Domain - Deleting ${IPV4} to IPSET: DomainVPNRouting-${POLICY}-ipv4"
        ipset del DomainVPNRouting-${POLICY}-ipv4 ${IPV4} \
        || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete ${IPV4} to IPSET: DomainVPNRouting-${POLICY}-ipv4" \
        && { saveipv4ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete Domain - Deleted ${IPV4} to IPSET: DomainVPNRouting-${POLICY}-ipv4" ;}
      fi

      # Delete IPv4 IP Rule
      if [[ -n "$(ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete Domain - Deleting IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
        ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} \
        && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete Domain - Deleted IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" ;} \
        || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
      fi

      # Delete IPv4 Route
      if [[ -n "$(ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete Domain - Deleting route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
        ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} \
        && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete Domain - Route deleted for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;} \
        || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete Route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
      fi
    done

    # Save IPv4 IPSET if modified or does not exist
    [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
    if [[ "${saveipv4ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-ipv4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete Domain - Saving IPv4 IPSET for ${POLICY}"
      ipset save DomainVPNRouting-${POLICY}-ipv4 -file ${POLICYDIR}/policy_${POLICY}-ipv4.ipset \
      && logger -p 4 -t "$ALIAS" "Delete Domain - Saved IPv4 IPSET for ${POLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to save IPv4 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset

    # Delete domain from policy files
    logger -p 5 -st "$ALIAS" "Delete Domain - Deleting ${DOMAIN} from Policy: ${POLICY}"
    domaindeleted="0"
    logger -p 5 -st "$ALIAS" "Delete Domain - Deleting ${DOMAIN} from ${DOMAINLIST}"
    sed -i "\:"$DOMAIN":d" $DOMAINLIST \
    && { domaindeleted="1" ; logger -p 4 -st "$ALIAS" "Delete Domain - Deleted ${DOMAIN} from ${DOMAINLIST}" ;} \
    || { domaindeleted="0" ; logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete ${DOMAIN} from ${DOMAINLIST}" ;}
    logger -p 5 -st "$ALIAS" "Delete Domain - Deleting ${DOMAIN} from ${DOMAINIPLIST}"
    sed -i "\:"^$DOMAIN":d" $DOMAINIPLIST \
    && { domaindeleted="1" ; logger -p 4 -st "$ALIAS" "Delete Domain - Deleted ${DOMAIN} from ${DOMAINIPLIST}" ;} \
    || { domaindeleted="0" ; logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete ${DOMAIN} from ${DOMAINIPLIST}" ;}
    if [[ "$domaindeleted" == "1" ]] &>/dev/null;then
      logger -p 4 -st "$ALIAS" "Delete Domain - Deleted ${DOMAIN} from Policy: ${POLICY}"
    else
      logger -p 2 -st "$ALIAS" "Delete Domain - ***Error*** Failed to delete ${DOMAIN} from Policy: ${POLICY}"
    fi
    unset domaindeleted
  else
    echo -e "${RED}***Domain not added to Policy: ${POLICY}***${NOCOLOR}"
  fi
fi
return
}

# Delete IP from Policy
deleteip ()
{
#Select IP if null
if [[ -z "${IP}" ]] &>/dev/null;then
  while true &>/dev/null;do
    read -r -p "Select an IP Address to delete from a policy: " value
    case $value in
      * ) IP=$value; break;;
    esac
  done
fi

# Select Policy to delete IP
POLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
echo -e "Select a Policy to delete $IP: \r\n$POLICIES"
  # User Input for Policy for Deleting IP
  while true;do  
    read -r -p "Policy: " DELETEIPPOLICY
    for POLICY in ${POLICIES};do
      if [[ "$DELETEIPPOLICY" == "${POLICY}" ]] &>/dev/null;then
        POLICY=$DELETEIPPOLICY
        break 2
      elif [[ -n "$(echo "${POLICIES}" | grep -w "$DELETEIPPOLICY")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Policy***${NOCOLOR}"
        echo -e "Policies: \r\n${POLICIES}"
        break 1
      fi
    done
  done

# Set process priority
if [[ -n "${PROCESSPRIORITY+x}" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Setting Process Priority to ${PROCESSPRIORITY}"
  renice -n ${PROCESSPRIORITY} $$ \
  && logger -p 4 -t "$ALIAS" "Delete IP - Set Process Priority to ${PROCESSPRIORITY}" \
  || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to set Process Priority to ${PROCESSPRIORITY}"
fi

# Check if IP is null and delete from policy
if [[ -n "$IP" ]] &>/dev/null;then
  if [[ -n "$(grep -w "$IP" "${POLICYDIR}/policy_${POLICY}_domaintoIP" | grep oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))")" ]] &>/dev/null;then
    # Determine Domain Policy Files and Interface and Route Table for IP Routes to delete.
    DOMAINIPLIST="$(awk -F"|" '/^'${POLICY}'/ {print $3}' ${CONFIGFILE})"
    INTERFACE="$(awk -F"|" '/^'${POLICY}'/ {print $4}' ${CONFIGFILE})"
    # Check if Verbose Logging is Enabled
    if [[ -z "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" ]] &>/dev/null;then
      VERBOSELOGGING="1"
    elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=0" ]] &>/dev/null;then
      VERBOSELOGGING="0"
    elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=1" ]] &>/dev/null;then
      VERBOSELOGGING="1"
    fi
    routingdirector || return

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(grep -m 1 -w "$IP" ${DOMAINIPLIST} | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" | sort -u)"
    IPV4S="$(grep -m 1 -w "$IP" ${DOMAINIPLIST} | grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | sort -u)"

    # Delete IPv6
    for IPV6 in ${IPV6S};do

      # Delete from IPv6 IPSET with prefix fixed
      if [[ -n "$(ipset list DomainVPNRouting-${POLICY}-ipv6 | grep -wo "${IPV6}:: 2>/dev/null")" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete IP - Deleting ${IPV6}:: to IPSET: DomainVPNRouting-${POLICY}-ipv6"
        ipset del DomainVPNRouting-${POLICY}-ipv6 ${IPV6}:: \
        || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete ${IPV6}:: to IPSET: DomainVPNRouting-${POLICY}-ipv6" \
        && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete IP - Deleting ${IPV6}:: to IPSET: DomainVPNRouting-${POLICY}-ipv6" ;}
      fi

      # Delete IPv6 Route with prefix fixed
      if [[ -n "$(ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete IP - Deleting route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ip -6 route del ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete IP - Route deleted for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete Route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi

      # Delete from IPv6 IPSET
      if [[ -n "$(ipset list DomainVPNRouting-${POLICY}-ipv6 | grep -wo "${IPV6}" 2>/dev/null)" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete IP - Deleting ${IPV6} to IPSET: DomainVPNRouting-${POLICY}-ipv6"
        ipset del DomainVPNRouting-${POLICY}-ipv6 ${IPV6} \
        || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete ${IPV6} to IPSET: DomainVPNRouting-${POLICY}-ipv6" \
        && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete IP - Deleting ${IPV6} to IPSET: DomainVPNRouting-${POLICY}-ipv6" ;}
      fi

      # Delete IPv6 Route
      if [[ -n "$(ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete IP - Deleting route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete IP - Route deleted for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete Route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi

    done

    # Save IPv6 IPSET if modified or does not exist
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if [[ "${saveipv6ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-ipv6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete IP - Saving IPv6 IPSET for ${POLICY}"
      ipset save DomainVPNRouting-${POLICY}-ipv6 -file ${POLICYDIR}/policy_${POLICY}-ipv6.ipset \
      && logger -p 4 -t "$ALIAS" "Delete IP - Saved IPv6 IPSET for ${POLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to save IPv6 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset


    # Delete IPv4
    for IPV4 in ${IPV4S};do

      # Delete from IPv4 IPSET
      if [[ -n "$(ipset list DomainVPNRouting-${POLICY}-ipv4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete IP - Deleting ${IPV4} to IPSET: DomainVPNRouting-${POLICY}-ipv4"
        ipset del DomainVPNRouting-${POLICY}-ipv4 ${IPV4} \
        || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete ${IPV4} to IPSET: DomainVPNRouting-${POLICY}-ipv4" \
        && { saveipv4ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete IP - Deleted ${IPV4} to IPSET: DomainVPNRouting-${POLICY}-ipv4" ;}
      fi

      # Delete IPv4 IPv4 Rule
      if [[ -n "$(ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete IP - Deleting IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
        ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} \
        && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete IP - Deleted IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
        || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
      fi

      # Delete IPv4 Route
      if [[ -n "$(ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Delete IP - Deleting route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
        ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} \
        && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Delete IP - Route deleted for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;} \
        || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete Route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
      fi
    done

    # Save IPv4 IPSET if modified or does not exist
    [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
    if [[ "${saveipv4ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-ipv4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Delete IP - Saving IPv4 IPSET for ${POLICY}"
      ipset save DomainVPNRouting-${POLICY}-ipv4 -file ${POLICYDIR}/policy_${POLICY}-ipv4.ipset \
      && logger -p 4 -t "$ALIAS" "Delete IP - Saved IPv4 IPSET for ${POLICY}" \
      || logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to save IPv4 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset

    # Delete IPv4 from policy
    logger -p 5 -st "$ALIAS" "Delete IP - Deleting ${IP} from Policy: ${POLICY}"
    DELETEDOMAINTOIPS="$(grep -w "$IP" ${DOMAINIPLIST})"
    for DELETEDOMAINTOIP in ${DELETEDOMAINTOIPS}; do
      sed -i "\:"^${DELETEDOMAINTOIP}":d" $DOMAINIPLIST \
      && { ipdeleted="1" ; logger -p 4 -st "$ALIAS" "Delete IP - Deleted ${IP} from ${DOMAINIPLIST}" ;} \
      || { ipdeleted="0" ; logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete ${IP} from ${DOMAINIPLIST}" ;}
    done
    if [[ "$ipdeleted" == "1" ]] &>/dev/null;then
      logger -p 4 -st "$ALIAS" "Delete IP - Deleted ${IP} from Policy: ${POLICY}"
    else
      logger -p 2 -st "$ALIAS" "Delete IP - ***Error*** Failed to delete ${IP} from Policy: ${POLICY}"
    fi
    unset ipdeleted
  else
    echo -e "${RED}***IP not added to Policy: ${POLICY}***${NOCOLOR}"
  fi
fi
return
}

# Query Policies for New IP Addresses
querypolicy ()
{
checkalias || return

# Boot Delay Timer
if [[ -n "${BOOTDELAYTIMER+x}" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - System Uptime: $(awk -F "." '{print $1}' "/proc/uptime") Seconds"
  logger -p 6 -t "$ALIAS" "Debug - Boot Delay Timer: ${BOOTDELAYTIMER} Seconds"
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "${BOOTDELAYTIMER}" ]] &>/dev/null;then
    logger -p 4 -st "$ALIAS" "Boot Delay - Waiting for System Uptime to reach ${BOOTDELAYTIMER} seconds"
    while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "${BOOTDELAYTIMER}" ]] &>/dev/null;do
      sleep $((($(awk -F "." '{print $1}' "/proc/uptime")-${BOOTDELAYTIMER})*-1))
    done
    logger -p 5 -st "$ALIAS" "Boot Delay - System Uptime is $(awk -F "." '{print $1}' "/proc/uptime") seconds"
  fi
fi

# Set process priority
if [[ -n "${PROCESSPRIORITY+x}" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Setting Process Priority to ${PROCESSPRIORITY}"
  renice -n ${PROCESSPRIORITY} $$ \
  && logger -p 4 -t "$ALIAS" "Query Policy - Set Process Priority to ${PROCESSPRIORITY}" \
  || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to set Process Priority to ${PROCESSPRIORITY}"
fi

# Query Policies
if [[ "${POLICY}" == "all" ]] &>/dev/null;then
  QUERYPOLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
  if [[ -z "${QUERYPOLICIES}" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Query Policy - ***No Policies Detected***"
    return
  fi
elif [[ "${POLICY}" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
  QUERYPOLICIES="${POLICY}"
else
  echo -e "${RED}Policy: ${POLICY} not found${NOCOLOR}"
  return
fi
for QUERYPOLICY in ${QUERYPOLICIES};do
  # Check if IPv6 IP Addresses are in policy file if IPv6 is Disabled and delete them
  if [[ "$IPV6SERVICE" == "disabled" ]] &>/dev/null && [[ -n "$(grep -m1 -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP")" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Query Policy - Removing IPv6 IP Addresses from Policy: ${QUERYPOLICY}***"
    sed -i '/:/d' "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP" \
    && logger -p 4 -t "$ALIAS" "Query Policy - Removed IPv6 IP Addresses from Policy: ${QUERYPOLICY}***" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to remove IPv6 IP Addresses from Policy: ${QUERYPOLICY}***"
  fi

  # Create Temporary File for Sync
  if [[ ! -f "/tmp/policy_${QUERYPOLICY}_domaintoIP" ]] &>/dev/null;then
    touch -a "/tmp/policy_${QUERYPOLICY}_domaintoIP"
  fi

  # Compare Policy File to Temporary File
  if ! diff "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP" "/tmp/policy_${QUERYPOLICY}_domaintoIP" &>/dev/null;then
    cp "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP" "/tmp/policy_${QUERYPOLICY}_domaintoIP"
  fi

  # Check if Verbose Logging is Enabled
  if [[ -z "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $5}' ${CONFIGFILE})" ]] &>/dev/null;then
    VERBOSELOGGING="1"
  elif [[ "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=0" ]] &>/dev/null;then
    VERBOSELOGGING="0"
  elif [[ "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=1" ]] &>/dev/null;then
    VERBOSELOGGING="1"
  fi

  # Check if Private IPs are Enabled
  if [[ -z "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $6}' ${CONFIGFILE})" ]] &>/dev/null;then
    PRIVATEIPS="0"
  elif [[ "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $6}' ${CONFIGFILE})" == "PRIVATEIPS=0" ]] &>/dev/null;then
    PRIVATEIPS="0"
  elif [[ "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $6}' ${CONFIGFILE})" == "PRIVATEIPS=1" ]] &>/dev/null;then
    PRIVATEIPS="1"
  fi

  # Display Query Policy
  if tty >/dev/null 2>&1;then
    printf '\033[K%b\r' "${BOLD}${UNDERLINE}Query Policy: ${QUERYPOLICY}${NOCOLOR}\n"
  fi

  # Query Domains for IP Addresses
  DOMAINS="$(cat ${POLICYDIR}/policy_${QUERYPOLICY}_domainlist)"
  for DOMAIN in ${DOMAINS};do
    [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -st "$ALIAS" "Query Policy - Policy: ${QUERYPOLICY} Querying ${DOMAIN}"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' "${LIGHTCYAN}Querying ${DOMAIN}...${NOCOLOR}"
    fi
    # Determine to query for IPv6 and IPv4 IP Addresses or only IPv4 Addresses
    if [[ "$IPV6SERVICE" == "disabled" ]] &>/dev/null;then
      # Query dnsmasq log if enabled for IPv4
      if [[ "${DNSLOGGINGENABLED}" == "1" ]] &>/dev/null && [[ -n "${DNSLOGPATH}" ]] &>/dev/null;then
        for IP in $(awk '($5 == "reply" || $5 == "cached") && ($6 ~ /.'${DOMAIN}'/ || $6 == "'${DOMAIN}'") && $8 ~ /((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/ {print $8}' "${DNSLOGPATH}" | sort -u); do
          if [[ "$PRIVATEIPS" == "1" ]] &>/dev/null;then
            echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "$PRIVATEIPS" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -st "$ALIAS" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      fi
      # Perform nslookup if nslookup is installed for IPv4
      if [[ -L "/usr/bin/nslookup" ]] &>/dev/null;then
        for IP in $(/usr/bin/nslookup ${DOMAIN} 2>/dev/null | awk '(NR>2)' | grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))"); do
          if [[ "$PRIVATEIPS" == "1" ]] &>/dev/null;then
            echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "$PRIVATEIPS" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: $DOMAIN queried $IP ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      fi
    else
      # Query dnsmasq log if enabled for IPv6 and IPv4
      if [[ "${DNSLOGGINGENABLED}" == "1" ]] &>/dev/null && [[ -n "${DNSLOGPATH}" ]] &>/dev/null;then
        for IP in $(awk '($5 == "reply" || $5 == "cached") && ($6 ~ /.'${DOMAIN}'/ || $6 == "'${DOMAIN}'") && $8 ~ /(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/ {print $8}' "${DNSLOGPATH}" | sort -u); do
          if [[ "$PRIVATEIPS" == "1" ]] &>/dev/null;then
            echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "$PRIVATEIPS" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried $IP ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      fi
      # Perform nslookup if nslookup is installed for IPv6 and IPv4
      if [[ -L "/usr/bin/nslookup" ]] &>/dev/null;then
        for IP in $(/usr/bin/nslookup ${DOMAIN} 2>/dev/null | awk '(NR>2)' | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))"); do
          if [[ "$PRIVATEIPS" == "1" ]] &>/dev/null;then
            echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "$PRIVATEIPS" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo $DOMAIN'>>'$IP >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo $IP | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      fi
    fi
    if tty >/dev/null 2>&1;then
      printf '\033[K'
    fi
  done

  # Remove duplicates from Temporary File
  sort -u "/tmp/policy_${QUERYPOLICY}_domaintoIP" -o "/tmp/policy_${QUERYPOLICY}_domaintoIP"

  # Compare Temporary File to Policy File
  if ! diff "/tmp/policy_${QUERYPOLICY}_domaintoIP" "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP" &>/dev/null;then
    echo -e "${LIGHTMAGENTA}***New IP Addresses detected for ${QUERYPOLICY}***${NOCOLOR}"
    echo -e "${LIGHTCYAN}Updating Policy: ${QUERYPOLICY}${NOCOLOR}"
    logger -p 5 -t "$ALIAS" "Query Policy - Updating Policy: ${QUERYPOLICY}"
    cp "/tmp/policy_${QUERYPOLICY}_domaintoIP" "$POLICYDIR/policy_${QUERYPOLICY}_domaintoIP" \
    && { echo -e "${GREEN}Updated Policy: ${QUERYPOLICY}${NOCOLOR}" ; logger -p 4 -t "$ALIAS" "Query Policy - Updated Policy: ${QUERYPOLICY}" ;} \
    || { echo -e "${RED}Failed to update Policy: ${QUERYPOLICY}${NOCOLOR}" ; logger -p 2 -t "$ALIAS" "Query Policy - ***Error*** Failed to update Policy: ${QUERYPOLICY}" ;}
  else
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' "${LIGHTCYAN}Query Policy: No new IP Addresses detected for ${QUERYPOLICY}${NOCOLOR}"
    fi
  fi

  # Determine Domain Policy Files and Interface and Route Table for IP Routes to delete.
  DOMAINIPLIST="$(grep -w "$QUERYPOLICY" "$CONFIGFILE" | awk -F"|" '{print $3}')"
  INTERFACE="$(grep -w "$QUERYPOLICY" "$CONFIGFILE" | awk -F"|" '{print $4}')"
  routingdirector || return

  # Check if Interface State is Up or Down
  if [[ "$STATE" == "0" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Query Policy - Interface ${INTERFACE} for ${QUERYPOLICY} is down"
    continue
  fi

  # Create IPv6 IPSET
  # Check for saved IPSET
  if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv6 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${QUERYPOLICY}-ipv6.ipset" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Restoring IPv6 IPSET for ${QUERYPOLICY}"
    ipset restore -! <"${POLICYDIR}/policy_${QUERYPOLICY}-ipv6.ipset" \
    && logger -p 4 -t "$ALIAS" "Query Policy - Restored IPv6 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to restore IPv6 IPSET for ${QUERYPOLICY}"
  # Create saved IPv6 IPSET file if IPSET exists
  elif [[ -n "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv6 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-ipv6.ipset" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Saving IPv6 IPSET for ${QUERYPOLICY}"
    ipset save DomainVPNRouting-${QUERYPOLICY}-ipv6 -file ${POLICYDIR}/policy_${QUERYPOLICY}-ipv6.ipset \
    && logger -p 4 -t "$ALIAS" "Query Policy - Saved IPv6 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to save IPv6 IPSET for ${QUERYPOLICY}"
  # Create new IPv6 IPSET if it does not exist
  elif [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv6 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Creating IPv6 IPSET for ${QUERYPOLICY}"
    ipset create DomainVPNRouting-${QUERYPOLICY}-ipv6 hash:ip family inet6 comment \
    && { saveipv6ipset="1" && logger -p 4 -t "$ALIAS" "Query Policy - Created IPv6 IPSET for ${QUERYPOLICY}" ;} \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to create IPv6 IPSET for ${QUERYPOLICY}"
  fi
  # Create IPv4 IPSET
  # Check for saved IPv4 IPSET
  if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv4 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${QUERYPOLICY}-ipv4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Restoring IPv4 IPSET for ${QUERYPOLICY}"
    ipset restore -! <"${POLICYDIR}/policy_${QUERYPOLICY}-ipv4.ipset" \
    && logger -p 4 -t "$ALIAS" "Query Policy - Restored IPv4 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to restore IPv4 IPSET for ${QUERYPOLICY}"
  # Create saved IPv4 IPSET file if IPSET exists
  elif [[ -n "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv4 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-ipv4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Saving IPv4 IPSET for ${QUERYPOLICY}"
    ipset save DomainVPNRouting-${QUERYPOLICY}-ipv4 -file ${POLICYDIR}/policy_${QUERYPOLICY}-ipv4.ipset \
    && logger -p 4 -t "$ALIAS" "Query Policy - Saved IPv4 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to save IPv4 IPSET for ${QUERYPOLICY}"
  # Create new IPv4 IPSET if it does not exist
  elif [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv4 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Creating IPv4 IPSET for ${QUERYPOLICY}"
    ipset create DomainVPNRouting-${QUERYPOLICY}-ipv4 hash:ip family inet comment \
    && { saveipv4ipset="1" && logger -p 4 -t "$ALIAS" "Query Policy - Created IPv4 IPSET for ${QUERYPOLICY}" ;} \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to create IPv4 IPSET for ${QUERYPOLICY}"
  fi

  # Create IPv4 and IPv6 Arrays from Policy File. 
  IPV6S="$(grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "$DOMAINIPLIST" | sort -u)"
  IPV4S="$(grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" "$DOMAINIPLIST" | sort -u)"
  
  # Show visual status for updating routes and rules
  if tty >/dev/null 2>&1;then
    printf '\033[K%b\r' "${LIGHTCYAN}Query Policy: Updating IP Routes and IP Rules${NOCOLOR}"
  fi

  # IPv6
  if [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null;then
    # Create FWMark IPv6 Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip -6 route show default dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null && [[ -z "$(ip -6 rule list from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Checking for IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ip -6 rule add from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} \
      && logger -p 4 -t "$ALIAS" "Query Policy - Added IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - Failed to add IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      # Remove FWMark Unreachable IPv6 Rule if it exists
      if [[ -n "$(ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Query Policy - Checking for Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
        ip -6 rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
        && logger -p 4 -t "$ALIAS" "Query Policy - Added Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
        || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      fi
    # Create FWMark Unreachable IPv6 Rule
    elif [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip -6 route show default dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null && [[ -z "$(ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Checking for Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ip -6 rule add unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -t "$ALIAS" "Query Policy - Added Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi

    # Create IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${QUERYPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Adding IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A OUTPUT -m set --match-set DomainVPNRouting-${QUERYPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Query Policy - Added IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${QUERYPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Adding IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A PREROUTING -m set --match-set DomainVPNRouting-${QUERYPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Query Policy - Added IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "DomainVPNRouting-'${QUERYPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Adding IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set DomainVPNRouting-${QUERYPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "$ALIAS" "Query Policy - Added IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi

    # Add IPv6s to IPSET or create IPv6 Routes
    if [[ -n "${FWMARK}" ]] &>/dev/null;then
      for IPV6 in ${IPV6S};do
        # Check IPv6 for prefix error
        if [[ -n "$(ip -6 route list ${IPV6} 2>&1 | grep -e "Error: inet6 prefix is expected rather than" )" ]] &>/dev/null;then
          # Add to IPv6 IPSET with prefix fixed
          if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv6 | grep -wo "${IPV6}::")" ]] &>/dev/null;then
            comment="$(awk -F ">>" '$2 == "'${IPV6}'::" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding ${IPV6}:: to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6"
            ipset add DomainVPNRouting-${QUERYPOLICY}-ipv6 ${IPV6}:: comment "${comment}" \
            || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add ${IPV6}:: to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" \
            && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Added ${IPV6}:: to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" ;}
            unset comment
          fi
          # Remove IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Removing route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ip -6 route del ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route removed for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "$rc" == "2" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Route does not exist for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "$rc" != "0" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to remove route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
          # Remove IPv6 Route for WAN Failover
          if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ -n "${OLDIPV6ROUTETABLE+x}" ]] &>/dev/null && [[ "$INTERFACE" == "wan" ]] &>/dev/null;then
            if [[ -n "$(ip route list ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
              [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Deleting route for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
              ip route del ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
              || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to delete route for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
              && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route deleted for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" ;}
            fi
          fi
        else
          # Add to IPv6 IPSET
          if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv6 | grep -wo "${IPV6}")" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding ${IPV6} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            ipset add DomainVPNRouting-${QUERYPOLICY}-ipv6 ${IPV6} comment "${comment}" \
            || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add ${IPV6} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" \
            && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Added ${IPV6} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" ;}
            unset comment
          fi
          # Remove IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Removing route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route removed for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "$rc" == "2" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Route does not exist for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "$rc" != "0" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to remove route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
          # Remove IPv6 Route for WAN Failover
          if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ -n "${OLDIPV6ROUTETABLE+x}" ]] &>/dev/null && [[ "$INTERFACE" == "wan" ]] &>/dev/null;then
            if [[ -n "$(ip route list ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
              [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Deleting route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
              ip route del ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
              || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to delete route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
              && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route deleted for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" ;}
            fi
          fi
        fi
      done
    elif [[ -z "${FWMARK}" ]] &>/dev/null;then
      for IPV6 in ${IPV6S};do
        # Check IPv6 for prefix error
        if [[ -n "$(ip -6 route list ${IPV6} 2>&1 | grep -e "Error: inet6 prefix is expected rather than" )" ]] &>/dev/null;then
          # Add to IPv6 IPSET with prefix fixed
          if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv6 | grep -w "${IPV6}::")" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding ${IPV6}:: to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'::" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            ipset add DomainVPNRouting-${QUERYPOLICY}-ipv6 ${IPV6}:: comment "${comment}" \
            || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add ${IPV6}:: to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" \
            && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Added ${IPV6}:: to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" ;}
            unset comment
          fi
          # Add IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ip -6 route add ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route added for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "$rc" == "2" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Route already exists for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "$rc" != "0" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
        else
          # Add to IPv6 IPSET
          if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv6 | grep -wo "${IPV6}")" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding ${IPV6} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            ipset add DomainVPNRouting-${QUERYPOLICY}-ipv6 ${IPV6} comment "${comment}" \
            || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add ${IPV6} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" \
            && { saveipv6ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Added ${IPV6} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv6" ;}
          fi
          # Add IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ip -6 route add ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route added for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "$rc" == "2" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Route already exists for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "$rc" != "0" ]] &>/dev/null;then
              logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
        fi
      done
    fi

    # Save IPv6 IPSET if modified or does not exist
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if [[ "${saveipv6ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-ipv6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Saving IPv6 IPSET for ${QUERYPOLICY}"
      ipset save DomainVPNRouting-${QUERYPOLICY}-ipv6 -file ${POLICYDIR}/policy_${QUERYPOLICY}-ipv6.ipset \
      && logger -p 4 -t "$ALIAS" "Query Policy - Save IPv6 IPSET for ${QUERYPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to save IPv6 IPSET for ${QUERYPOLICY}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset
  fi

  # IPv4
  # Create FWMark IPv4 Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip route show default table ${ROUTETABLE})" ]] &>/dev/null && [[ -z "$(ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Checking for IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ip rule add from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} \
    && logger -p 4 -t "$ALIAS" "Query Policy - Added IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    # Remove FWMark Unreachable IPv4 Rule if it exists
    if [[ -n "$(ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Checking for Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ip rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -t "$ALIAS" "Query Policy - Added Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
  # Create FWMark Unreachable IPv4 Rule
  elif [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip route show default table ${ROUTETABLE})" ]] &>/dev/null && [[ -z "$(ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Checking for Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ip rule add unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
    && logger -p 4 -t "$ALIAS" "Query Policy - Added Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
  fi

  # Create IPv4 IPTables OUTPUT Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${QUERYPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Adding IPTables OUTPUT rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 FWMark: ${FWMARK}"
    iptables -t mangle -A OUTPUT -m set --match-set DomainVPNRouting-${QUERYPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "$ALIAS" "Query Policy - Added IPTables OUTPUT rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables PREROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${QUERYPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Adding IPTables PREROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 FWMark: ${FWMARK}"
    iptables -t mangle -A PREROUTING -m set --match-set DomainVPNRouting-${QUERYPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "$ALIAS" "Query Policy - Added IPTables PREROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables POSTROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "DomainVPNRouting-'${QUERYPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Query Policy - Adding IPTables rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    iptables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set DomainVPNRouting-${QUERYPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "$ALIAS" "Query Policy - Added IPTables rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
    || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IPTables rule for IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}"
  fi

  # Add IPv4s to IPSET or create IPv4 Routes or rules and remove old IPv4 Routes or Rules
  if [[ -n "${FWMARK}" ]] &>/dev/null && { [[ -n "$(ip rule list from all fwmark ${FWMARK} table ${ROUTETABLE} priority ${PRIORITY})" ]] &>/dev/null || [[ -n "$(ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null ;};then
    for IPV4 in ${IPV4S};do
      # Add to IPv4 IPSET
      if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding ${IPV4} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4"
        comment="$(awk -F ">>" '$2 == "'${IPV4}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
        ipset add DomainVPNRouting-${QUERYPOLICY}-ipv4 ${IPV4} comment "${comment}" \
        || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add ${IPV4} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4" \
        && { saveipv4ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Added ${IPV4} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4" ;}
        unset comment
      fi
      # Remove IPv4 Routes
      if [[ "$RGW" == "0" ]] &>/dev/null;then
        if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(ip route list $IPV4 dev $IFNAME table $ROUTETABLE)" ]] &>/dev/null;then
          [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Removing route for $IPV4 dev $IFNAME table $ROUTETABLE"
          ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
          || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to remove route for $IPV4 dev $IFNAME table $ROUTETABLE" \
          && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route removed for $IPV4 dev $IFNAME table $ROUTETABLE" ;}
        fi
        if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ "$INTERFACE" == "wan" ]] &>/dev/null;then
          if [[ -n "$(ip route list $IPV4 dev $OLDIFNAME table $ROUTETABLE)" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Deleting route for $IPV4 dev $OLDIFNAME table $ROUTETABLE"
            ip route del ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE} &>/dev/null \
            || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to delete route for $IPV4 dev $OLDIFNAME table $ROUTETABLE" \
            && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route deleted for $IPV4 dev $OLDIFNAME table $ROUTETABLE" ;}
          fi
        fi
      elif [[ "$RGW" != "0" ]] &>/dev/null;then
        # Remove IPv4 Rules
        if [[ -n "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority $PRIORITY)" ]] &>/dev/null;then
          [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Removing IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
          ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} &>/dev/null \
          || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to remove IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY" \
          && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Removed IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY" ;}
        fi
      fi
    done
  elif [[ -z "${FWMARK}" ]] &>/dev/null || [[ -z "$(ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} | grep -w "unreachable")" ]] &>/dev/null;then
    for IPV4 in ${IPV4S};do
      # Add to IPv4 IPSET
      if [[ -z "$(ipset list DomainVPNRouting-${QUERYPOLICY}-ipv4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding ${IPV4} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4"
        comment="$(awk -F ">>" '$2 == "'${IPV4}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
        ipset add DomainVPNRouting-${QUERYPOLICY}-ipv4 ${IPV4} comment "${comment}" \
        || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add ${IPV4} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4" \
        && { saveipv4ipset="1" && [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Added ${IPV4} to IPSET: DomainVPNRouting-${QUERYPOLICY}-ipv4" ;}
        unset comment
      fi
      # Create IPv4 Routes
      if [[ "$RGW" == "0" ]] &>/dev/null;then
        if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(ip route list $IPV4 dev $IFNAME table $ROUTETABLE)" ]] &>/dev/null;then
          [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding route for $IPV4 dev $IFNAME table $ROUTETABLE"
          ip route add ${IPV4} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
          || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add route for $IPV4 dev $IFNAME table $ROUTETABLE" \
          && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route added for $IPV4 dev $IFNAME table $ROUTETABLE" ;}
        fi
        if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ "$INTERFACE" == "wan" ]] &>/dev/null;then
          if [[ -n "$(ip route list $IPV4 dev $OLDIFNAME table $ROUTETABLE)" ]] &>/dev/null;then
            [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Deleting route for $IPV4 dev $OLDIFNAME table $ROUTETABLE"
            ip route del ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE} &>/dev/null \
            || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to delete route for $IPV4 dev $OLDIFNAME table $ROUTETABLE" \
            && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Route deleted for $IPV4 dev $OLDIFNAME table $ROUTETABLE" ;}
          fi
        fi
      elif [[ "$RGW" != "0" ]] &>/dev/null;then
        # Create IPv4 Rules
        if [[ -z "$(ip rule list from all to $IPV4 lookup $ROUTETABLE priority $PRIORITY)" ]] &>/dev/null;then
          [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 5 -t "$ALIAS" "Query Policy - Adding IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY"
          ip rule add from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} &>/dev/null \
          || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to add IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY" \
          && { [[ "$VERBOSELOGGING" == "1" ]] &>/dev/null && logger -p 4 -t "$ALIAS" "Query Policy - Added IP Rule for $IPV4 table $ROUTETABLE priority $PRIORITY" ;}
        fi
      fi
    done
    # Save IPv4 IPSET if modified or does not exist
    [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
    if [[ "${saveipv4ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-ipv4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Query Policy - Saving IPv4 IPSET for ${QUERYPOLICY}"
      ipset save DomainVPNRouting-${QUERYPOLICY}-ipv4 -file ${POLICYDIR}/policy_${QUERYPOLICY}-ipv4.ipset \
      && logger -p 4 -t "$ALIAS" "Query Policy - Save IPv4 IPSET for ${QUERYPOLICY}" \
      || logger -p 2 -st "$ALIAS" "Query Policy - ***Error*** Failed to save IPv4 IPSET for ${QUERYPOLICY}"
    fi
    [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset
  fi

done
# Clear Parameters
unset VERBOSELOGGING PRIVATEIPS INTERFACE IFNAME OLDIFNAME IPV6S IPV4S RGW PRIORITY ROUTETABLE DOMAIN IP FWMARK MASK IPV6ROUTETABLE OLDIPV6ROUTETABLE

if tty >/dev/null 2>&1;then
  printf '\033[K'
fi
return
}

# Cronjob
cronjob ()
{
# Check CHECKINTERVAL Setting for valid range and if not default to 15
if [[ "${CHECKINTERVAL}" -ge "1" ]] &>/dev/null && [[ "${CHECKINTERVAL}" -le "59" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - CHECKINTERVAL is within valid range: ${CHECKINTERVAL}"
else
  logger -p 6 -t "$ALIAS" "Debug - CHECKINTERVAL is out of valid range: ${CHECKINTERVAL}"
  CHECKINTERVAL="15"
  logger -p 6 -t "$ALIAS" "Debug - CHECKINTERVAL using default value: ${CHECKINTERVAL} Minutes"
fi

# Create Cron Job
if [[ "${mode}" != "uninstall" ]] &>/dev/null;then
  logger -p 6 -st "$ALIAS" "Cron - Checking if Cron Job is Scheduled"

  # Delete old cron job if flag is set by configuration menu
  if [[ -n "${zCHECKINTERVAL+x}" ]] &>/dev/null && [[ -n "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Cron - Removing old Cron Job"
    cru d setup_domain_vpn_routing "*/${zCHECKINTERVAL} * * * *" $0 querypolicy all \
    && logger -p 3 -st "$ALIAS" "Cron - Removed old Cron Job" \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Failed to remove old Cron Job"
  fi
  # Create cron job if it does not exist
  if [[ -z "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Cron - Creating Cron Job"
    cru a setup_domain_vpn_routing "*/${CHECKINTERVAL} * * * *" $0 querypolicy all \
    && { logger -p 4 -st "$ALIAS" "Cron - Created Cron Job" ; echo -e "${GREEN}Created Cron Job${NOCOLOR}" ;} \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Failed to create Cron Job"
    # Execute initial query policy if interval was changed in configuration
    [[ -n "${zCHECKINTERVAL+x}" ]] &>/dev/null && $0 querypolicy all &>/dev/null &
  elif [[ -n "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    if tty &>/dev/null;then
      echo -e "${GREEN}Cron Job already exists${NOCOLOR}"
    fi
  fi

# Remove Cron Job
elif [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  if [[ -n "$(cru l | grep -w "$0" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Cron - Removing Cron Job"
    cru d setup_domain_vpn_routing "*/${CHECKINTERVAL} * * * *" $0 querypolicy all \
    && logger -p 3 -st "$ALIAS" "Cron - Removed Cron Job" \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Failed to remove Cron Job"
  fi
  return
fi
return
}

# Kill Script
killscript ()
{
# Prompt for Confirmation
while [[ "${mode}" == "kill" ]] &>/dev/null;do
  read -p "Are you sure you want to kill Domain VPN Routing? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) return;;
    * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
  esac
done

# Determine PIDs to kill
logger -p 6 -t "$ALIAS" "Debug - Selecting PIDs to kill"

# Determine binary to use for detecting PIDs
if [[ -f "/usr/bin/pstree" ]] &>/dev/null;then
  PIDS="$(pstree -s "$0" | grep -v "grep" | grep -w "$0" | grep -o '[0-9]*' | grep -v "$$")" || PIDS=""
else
  PIDS="$(ps | grep -v "grep" | grep -w "$0" | awk '{print $1}' | grep -v "$$")"
fi

logger -p 6 -t "$ALIAS" "Debug - ***Checking if PIDs array is null*** Process ID: ${PIDS}"
if [[ -n "${PIDS+x}" ]] &>/dev/null && [[ -n "${PIDS}" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Killing Process ID: ${PIDS}"
  # Kill PIDs
  until [[ -z "$PIDS" ]] &>/dev/null;do
    if [[ -z "$(echo "$PIDS" | grep -o '[0-9]*')" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - ***PIDs array is null***"
      break
    fi
    if [[ -f "/usr/bin/pstree" ]] &>/dev/null;then
      for PID in ${PIDS};do
        if [[ "${PID}" == "$$" ]] &>/dev/null;then
          PIDS="${PIDS//[${PID}$'\t\r\n']/}" && continue
        fi
        [[ -n "$(pstree -s "$0" | grep -v "grep" | grep -w "$0" | grep -o '[0-9]*' | grep -o "${PID}")" ]] \
        && logger -p 1 -st "$ALIAS" "Restart - Killing ${ALIAS} Process ID: ${PID}" \
          && { kill -9 ${PID} \
          && { PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 1 -st "$ALIAS" "Restart - Killed $ALIAS Process ID: ${PID}" && continue ;} \
          || { [[ -z "$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*' | grep -o "${PID}")" ]] &>/dev/null && PIDS=${PIDS//[${PID}$'\t\r\n']/} && continue || PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 2 -st "$ALIAS" "Restart - ***Error*** Failed to kill ${ALIAS} Process ID: ${PID}" ;} ;} \
        || PIDS="${PIDS//[${PID}$'\t\r\n']/}" && continue
      done
    else
      for PID in ${PIDS};do
        if [[ "${PID}" == "$$" ]] &>/dev/null;then
          PIDS="${PIDS//[${PID}$'\t\r\n']/}" && continue
        fi
        [[ -n "$(ps | grep -v "grep" | grep -w "$0" | awk '{print $1}' | grep -o "${PID}")" ]] \
        && logger -p 1 -st "$ALIAS" "Restart - Killing ${ALIAS} Process ID: ${PID}" \
          && { kill -9 ${PID} \
          && { PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 1 -st "$ALIAS" "Restart - Killed $ALIAS Process ID: ${PID}" && continue ;} \
          || { [[ -z "$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}' | grep -o "${PID}")" ]] &>/dev/null && PIDS=${PIDS//[${PID}$'\t\r\n']/} && continue || PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 2 -st "$ALIAS" "Restart - ***Error*** Failed to kill ${ALIAS} Process ID: ${PID}" ;} ;} \
        || PIDS="${PIDS//[${PID}$'\t\r\n']/}" && continue
      done
    fi
  done
elif [[ -z "${PIDS+x}" ]] &>/dev/null || [[ -z "$PIDS" ]] &>/dev/null;then
  # Log no PIDs found and return
  logger -p 2 -st "$ALIAS" "Restart - ***${ALIAS} is not running*** No Process ID Detected"
  if tty &>/dev/null;then
    printf '\033[K%b\r\a' "${BOLD}${RED}***${ALIAS} is not running*** No Process ID Detected${NOCOLOR}"
    sleep 3
    printf '\033[K'
  fi
fi
[[ -n "${PIDS+x}" ]] &>/dev/null && unset PIDS

return
}

# Update Script
update ()
{

# Read Global Config File
if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  setglobalconfig || return
fi

# Determine Production or Beta Update Channel
if [[ -z "${DEVMODE+x}" ]] &>/dev/null;then
  echo -e "Dev Mode not configured in Global Configuration"
elif [[ "$DEVMODE" == "0" ]] &>/dev/null;then
  DOWNLOADPATH="${REPO}domain_vpn_routing.sh"
elif [[ "$DEVMODE" == "1" ]] &>/dev/null;then
  DOWNLOADPATH="${REPO}domain_vpn_routing-beta.sh"
fi

# Determine if newer version is available
REMOTEVERSION="$(echo "$(/usr/sbin/curl "$DOWNLOADPATH" 2>/dev/null | grep -v "grep" | grep -w "# Version:" | awk '{print $3}')")"

# Remote Checksum
if [[ -f "/usr/sbin/openssl" ]] &>/dev/null;then
  REMOTECHECKSUM="$(/usr/sbin/curl -s "$DOWNLOADPATH" | /usr/sbin/openssl sha256 | awk -F " " '{print $2}')"
elif [[ -f "/usr/bin/md5sum" ]] &>/dev/null;then
  REMOTECHECKSUM="$(echo "$(/usr/sbin/curl -s "$DOWNLOADPATH" 2>/dev/null | /usr/bin/md5sum | awk -F " " '{print $1}')")"
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
  logger -p 3 -t "$ALIAS" "$ALIAS is out of date - Current Version: $VERSION Available Version: $REMOTEVERSION"
  [[ "$DEVMODE" == "1" ]] &>/dev/null && echo -e "${RED}***Dev Mode is Enabled***${NOCOLOR}"
  echo -e "${YELLOW}${ALIAS} is out of date - Current Version: ${LIGHTBLUE}${VERSION}${YELLOW} Available Version: ${LIGHTCYAN}${REMOTEVERSION}${NOCOLOR}${NOCOLOR}"
  while true &>/dev/null;do
    if [[ "$DEVMODE" == "0" ]] &>/dev/null;then
      read -r -p "Do you want to update to the latest production version? $REMOTEVERSION ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    elif [[ "$DEVMODE" == "1" ]] &>/dev/null;then
      read -r -p "Do you want to update to the latest beta version? $REMOTEVERSION ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    fi
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) unset passiveupdate && return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" 2>/dev/null && chmod 755 $0 \
  && { logger -p 4 -st "$ALIAS" "Update - $ALIAS has been updated to version: $REMOTEVERSION" && killscript ;} \
  || logger -p 2 -st "$ALIAS" "Update - ***Error*** Failed to update $ALIAS to version: $REMOTEVERSION"
elif [[ "$version" == "$remoteversion" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" "$ALIAS is up to date - Version: $VERSION"
  if [[ "$CHECKSUM" != "$REMOTECHECKSUM" ]] &>/dev/null;then
    logger -p 2 -st "$ALIAS" "***${ALIAS} failed Checksum Check*** Current Checksum: $CHECKSUM  Valid Checksum: $REMOTECHECKSUM"
    echo -e "${RED}***Checksum Failed***${NOCOLOR}"
    echo -e "${LIGHTGRAY}Current Checksum: ${LIGHTRED}${CHECKSUM}  ${LIGHTGRAY}Valid Checksum: ${GREEN}${REMOTECHECKSUM}${NOCOLOR}"
  fi
  while true &>/dev/null;do  
    read -r -p "$ALIAS is up to date. Do you want to reinstall $ALIAS Version: ${VERSION}? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) unset passiveupdate && return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" 2>/dev/null && chmod 755 $0 \
  && { logger -p 4 -st "$ALIAS" "Update - ${ALIAS} has reinstalled version: ${VERSION}" && killscript ;} \
  || logger -p 2 -st "$ALIAS" "Update - ***Error*** Failed to reinstall ${ALIAS} with version: ${VERSION}"
elif [[ "$version" -gt "$remoteversion" ]] &>/dev/null;then
  echo -e "${LIGHTMAGENTA}${ALIAS} is newer than Available Version: ${REMOTEVERSION} ${NOCOLOR}- ${LIGHTCYAN}Current Version: ${VERSION}${NOCOLOR}"
fi

return
}

# Get System Parameters
getsystemparameters ()
{
# Get Global System Parameters
while [[ -z "${systemparameterssync+x}" ]] &>/dev/null || [[ "$systemparameterssync" == "0" ]] &>/dev/null;do
  if [[ -z "${systemparameterssync+x}" ]] &>/dev/null;then
    systemparameterssync="0"
  elif [[ "$systemparameterssync" == "1" ]] &>/dev/null;then
    break
  else
    sleep 1
  fi

  # WANSDUALWANENABLE
  if [[ -z "${WANSDUALWANENABLE+x}" ]] &>/dev/null;then
    wansdualwanenable="$(nvram get wans_dualwan & nvramcheck)"
    [[ -n "$(echo "$wansdualwanenable" | awk '{if ($0 != "" && $2 != "none") {print $2}}')" ]] &>/dev/null && WANSDUALWANENABLE="1" || WANSDUALWANENABLE="0"
    [[ -n "$WANSDUALWANENABLE" ]] &>/dev/null && unset wansdualwanenable || { logger -p 6 -t "$ALIAS" "Debug - failed to set WANSDUALWANENABLE" && unset WANSDUALWANENABLE && continue ;}
  fi

  # IPV6SERVICE
  if [[ -z "${IPV6SERVICE+x}" ]] &>/dev/null;then
    IPV6SERVICE="$(nvram get ipv6_service & nvramcheck)"
    [[ -n "$IPV6SERVICE" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - IPv6 Service: ${IPV6SERVICE}" || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPV6SERVICE" && unset IPV6SERVICE && continue ;}
  fi

  # IPV6IPADDR
  if [[ -z "${IPV6IPADDR+x}" ]] &>/dev/null;then
    IPV6IPADDR="$(nvram get ipv6_wan_addr & nvramcheck)"
    { [[ -n "$IPV6IPADDR" ]] &>/dev/null || [[ "$IPV6SERVICE" == "disabled" ]] &>/dev/null || [[ -z "$(nvram get ipv6_wan_addr & nvramcheck)" ]] &>/dev/null ;} \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPV6IPADDR" && unset IPV6IPADDR && continue ;}
  fi

  # WAN0STATE
  if [[ -z "${WAN0STATE+x}" ]] &>/dev/null;then
    WAN0STATE="$(nvram get wan0_state_t & nvramcheck)"
    [[ -n "$WAN0STATE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0STATE" && unset WAN0STATE && continue ;}
  fi

  # WAN0GWIFNAME
  if [[ -z "${WAN0GWIFNAME+x}" ]] &>/dev/null;then
    WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
    [[ -n "$WAN0GWIFNAME" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0GWIFNAME" && unset WAN0GWIFNAME && continue ;}
  fi

  # WAN0GATEWAY
  if [[ -z "${WAN0GATEWAY+x}" ]] &>/dev/null;then
    WAN0GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
    [[ -n "$WAN0GATEWAY" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0GATEWAY" && unset WAN0GATEWAY && continue ;}
  fi

  # WAN0PRIMARY
  if [[ -z "${WAN0PRIMARY+x}" ]] &>/dev/null;then
    WAN0PRIMARY="$(nvram get wan0_primary & nvramcheck)"
    if [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
      [[ -n "$WAN0PRIMARY" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0PRIMARY" && unset WAN0PRIMARY && continue ;}
    fi
  fi

  # WAN0FWMARK
  if [[ -z "${WAN0FWMARK+x}" ]] &>/dev/null;then
    WAN0FWMARK="0x8000"
  fi

  # WAN0MASK
  if [[ -z "${WAN0MASK+x}" ]] &>/dev/null;then
    WAN0MASK="0xf000"
  fi

  # WAN1STATE
  if [[ -z "${WAN1STATE+x}" ]] &>/dev/null;then
    WAN1STATE="$(nvram get wan1_state_t & nvramcheck)"
    { [[ -n "$WAN1STATE" ]] &>/dev/null || [[ "$WANSDUALWANENABLE" == "0" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1STATE" && unset WAN1STATE && continue ;}
  fi

  # WAN1GWIFNAME
  if [[ -z "${WAN1GWIFNAME+x}" ]] &>/dev/null;then
    WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
    if [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
      [[ -n "$WAN1GWIFNAME" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1GWIFNAME" && unset WAN1GWIFNAME && continue ;}
    fi
  fi

  # WAN1GATEWAY
  if [[ -z "${WAN1GATEWAY+x}" ]] &>/dev/null;then
    WAN1GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
    if [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
      [[ -n "$WAN1GATEWAY" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1GATEWAY" && unset WAN1GATEWAY && continue ;}
    fi
  fi

  # WAN1PRIMARY
  if [[ -z "${WAN1PRIMARY+x}" ]] &>/dev/null;then
    WAN1PRIMARY="$(nvram get wan1_primary & nvramcheck)"
    if [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
      [[ -n "$WAN1PRIMARY" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1PRIMARY" && unset WAN1PRIMARY && continue ;}
    fi
  fi

  # WAN1FWMARK
  if [[ -z "${WAN1FWMARK+x}" ]] &>/dev/null;then
    WAN1FWMARK="0x9000"
  fi

  # WAN1MASK
  if [[ -z "${WAN1MASK+x}" ]] &>/dev/null;then
    WAN1MASK="0xf000"
  fi

  # OVPNC1STATE
  if [[ -z "${OVPNC1STATE+x}" ]] &>/dev/null;then
    OVPNC1STATE="$(nvram get vpn_client1_state & nvramcheck)"
    { [[ -n "$OVPNC1STATE" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client1" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC1STATE" && unset OVPNC1STATE && continue ;}
  fi

  # OVPNC1RGW
  if [[ -z "${OVPNC1RGW+x}" ]] &>/dev/null;then
    OVPNC1RGW="$(nvram get vpn_client1_rgw & nvramcheck)"
    [[ -n "$OVPNC1RGW" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC1RGW" && unset OVPNC1RGW && continue ;}
  fi

  # OVPNC2STATE
  if [[ -z "${OVPNC2STATE+x}" ]] &>/dev/null;then
    OVPNC2STATE="$(nvram get vpn_client2_state & nvramcheck)"
    { [[ -n "$OVPNC2STATE" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client2" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC2STATE" && unset OVPNC2STATE && continue ;}
  fi

  # OVPNC2RGW
  if [[ -z "${OVPNC2RGW+x}" ]] &>/dev/null;then
    OVPNC2RGW="$(nvram get vpn_client2_rgw & nvramcheck)"
    [[ -n "$OVPNC2RGW" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC2RGW" && unset OVPNC2RGW && continue ;}
  fi

  # OVPNC3STATE
  if [[ -z "${OVPNC3STATE+x}" ]] &>/dev/null;then
    OVPNC3STATE="$(nvram get vpn_client3_state & nvramcheck)"
    { [[ -n "$OVPNC3STATE" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client3" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC3STATE" && unset OVPNC3STATE && continue ;}
  fi

  # OVPNC3RGW
  if [[ -z "${OVPNC3RGW+x}" ]] &>/dev/null;then
    OVPNC3RGW="$(nvram get vpn_client3_rgw & nvramcheck)"
    [[ -n "$OVPNC3RGW" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC3RGW" && unset OVPNC3RGW && continue ;}
  fi

  # OVPNC4STATE
  if [[ -z "${OVPNC4STATE+x}" ]] &>/dev/null;then
    OVPNC4STATE="$(nvram get vpn_client4_state & nvramcheck)"
    { [[ -n "$OVPNC4STATE" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client4" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC4STATE" && unset OVPNC4STATE && continue ;}
  fi

  # OVPNC4RGW
  if [[ -z "${OVPNC4RGW+x}" ]] &>/dev/null;then
    OVPNC4RGW="$(nvram get vpn_client4_rgw & nvramcheck)"
    [[ -n "$OVPNC4RGW" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC4RGW" && unset OVPNC4RGW && continue ;}
  fi

  # OVPNC5STATE
  if [[ -z "${OVPNC5STATE+x}" ]] &>/dev/null;then
    OVPNC5STATE="$(nvram get vpn_client5_state & nvramcheck)"
    { [[ -n "$OVPNC5STATE" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client5" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC5STATE" && unset OVPNC5STATE && continue ;}
  fi

  # OVPNC5RGW
  if [[ -z "${OVPNC5RGW+x}" ]] &>/dev/null;then
    OVPNC5RGW="$(nvram get vpn_client5_rgw & nvramcheck)"
    [[ -n "$OVPNC5RGW" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNC5RGW" && unset OVPNC5RGW && continue ;}
  fi

  # WGC1STATE
  if [[ -z "${WGC1STATE+x}" ]] &>/dev/null;then
    WGC1STATE="$(nvram get wgc1_enable & nvramcheck)"
    { [[ -n "$WGC1STATE" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc1_status" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set WGC1STATE" && unset WGC1STATE && continue ;}
  fi

  # WGC2STATE
  if [[ -z "${WGC2STATE+x}" ]] &>/dev/null;then
    WGC2STATE="$(nvram get wgc2_enable & nvramcheck)"
    { [[ -n "$WGC2STATE" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc2_status" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set WGC2STATE" && unset WGC2STATE && continue ;}
  fi

  # WGC3STATE
  if [[ -z "${WGC3STATE+x}" ]] &>/dev/null;then
    WGC3STATE="$(nvram get wgc3_enable & nvramcheck)"
    { [[ -n "$WGC3STATE" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc3_status" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set WGC3STATE" && unset WGC3STATE && continue ;}
  fi

  # WGC4STATE
  if [[ -z "${WGC4STATE+x}" ]] &>/dev/null;then
    WGC4STATE="$(nvram get wgc4_enable & nvramcheck)"
    { [[ -n "$WGC4STATE" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc4_status" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set WGC4STATE" && unset WGC4STATE && continue ;}
  fi

  # WGC5STATE
  if [[ -z "${WGC5STATE+x}" ]] &>/dev/null;then
    WGC5STATE="$(nvram get wgc5_enable & nvramcheck)"
    { [[ -n "$WGC5STATE" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc5_status" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set WGC5STATE" && unset WGC5STATE && continue ;}
  fi

  # DNSLOGGINGENABLED
  if [[ -n "$(awk '$0 == "log-queries" {print}' "${DNSMASQCONFIGFILE}")" ]] &>/dev/null;then
    DNSLOGGINGENABLED="1"
  else
    DNSLOGGINGENABLED="0"
  fi

  # DNSLOGPATH
  if [[ -n "$(awk -F "=" '$1 == "log-facility" {print $2}' "${DNSMASQCONFIGFILE}")" ]] &>/dev/null;then
    DNSLOGPATH="$(awk -F "=" '$1 == "log-facility" {print $2}' "${DNSMASQCONFIGFILE}")"
  else
    DNSLOGPATH=""
  fi

 systemparameterssync="1"
done

unset systemparameterssync

return
}

# Check if NVRAM Background Process is Stuck if CHECKNVRAM is Enabled
nvramcheck ()
{
# Return if CHECKNVRAM is Disabled
if [[ -z "${CHECKNVRAM+x}" ]] &>/dev/null || [[ "$CHECKNVRAM" == "0" ]] &>/dev/null;then
  return
# Check if Background Process for NVRAM Call is still running
else
  lastpid="$!"
  # Return if last PID is null
  if [[ -z "$(ps | awk '$1 == "'${lastpid}'" {print}')" ]] &>/dev/null;then
    unset lastpid
    return
  # Kill PID if stuck process
  elif [[ -n "$(ps | awk '$1 == "'${lastpid}'" {print}')" ]] &>/dev/null;then
    kill -9 $lastpid &>/dev/null \
    && logger -p 2 -t "$ALIAS" "NVRAM Check - ***NVRAM Check Failure Detected***"
    unset lastpid
    return
  fi
fi

return
}

# Get System Parameters
getsystemparameters || return
# Perform PreV2 Config Update
if [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  updateconfigprev2 || return
# Get Global Configuration
elif [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  setglobalconfig || return
fi
# Check Alias
if [[ -d "${POLICYDIR}" ]] &>/dev/null && [[ "${mode}" != "uninstall" ]] &>/dev/null;then
  checkalias || return
fi
# Set Mode and Execute
scriptmode
