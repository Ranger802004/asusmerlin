#!/bin/sh

# Domain VPN Routing for ASUS Routers using Merlin Firmware v386.7 or newer
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 04/12/2025
# Version: v3.1.1-beta1

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
ALIAS="domain_vpn_routing"
FRIENDLYNAME="Domain VPN Routing"
VERSION="v3.1.1-beta1"
MAJORVERSION="${VERSION:0:1}"
REPO="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/domain_vpn_routing/"
GLOBALCONFIGFILE="/jffs/configs/domain_vpn_routing/global.conf"
CONFIGFILE="/jffs/configs/domain_vpn_routing/domain_vpn_routing.conf"
ASNFILE="/jffs/configs/domain_vpn_routing/asn.conf"
ADGUARDHOMELOGFILE="/opt/etc/AdGuardHome/data/querylog.json"
ADGUARDHOMELOGCHECKPOINT="/jffs/configs/domain_vpn_routing/adguardhomelog.checkpoint"
POLICYDIR="/jffs/configs/domain_vpn_routing"
BACKUPPATH="/jffs/configs/domain_vpn_routing.tar.gz"
SYSTEMLOG="/tmp/syslog.log"
LOCKFILE="/var/lock/domain_vpn_routing.lock"
DNSMASQCONFIGFILE="/etc/dnsmasq.conf"
RTTABLESFILE="/etc/iproute2/rt_tables"
IPSETPREFIX="DVR"
POLICYNAMEMAXLENGTH="24"
IPSETMAXCOMMENTLENGTH="255"
ENTWAREMOUNTCHECKS="30"

# Checksum
if [[ -f "/usr/sbin/openssl" ]] &>/dev/null;then
  CHECKSUM="$(/usr/sbin/openssl sha256 "${0}" | awk -F " " '{print $2}')"
elif [[ -f "/usr/bin/md5sum" ]] &>/dev/null;then
  CHECKSUM="$(/usr/bin/md5sum "${0}" | awk -F " " '{print $1}')"
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

if [[ "$(dirname "${0}")" == "." ]] &>/dev/null;then
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
  mode="${1}"
  arg2="${2}"
else
  mode="${1}"
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
  if [[ -z "${arg2}" ]] &>/dev/null;then
    POLICY=all
    showpolicy
  else
    POLICY="${arg2}"
    showpolicy
  fi
elif [[ "${mode}" == "showasn" ]] &>/dev/null;then
  if [[ -z "${arg2}" ]] &>/dev/null;then
    ASN=all
    showasn
  else
    ASN="${arg2}"
    showasn
  fi
elif [[ "${mode}" == "editpolicy" ]] &>/dev/null;then 
  POLICY="${arg2}"
  editpolicy
elif [[ "${mode}" == "editasn" ]] &>/dev/null;then 
  ASN="${arg2}"
  editasn
elif [[ "${mode}" == "deletepolicy" ]] &>/dev/null;then 
  POLICY="${arg2}"
  deletepolicy
elif [[ "${mode}" == "deleteasn" ]] &>/dev/null;then 
  ASN="${arg2}"
  deleteasn
elif [[ "${mode}" == "querypolicy" ]] &>/dev/null;then 
  exec 100>"${LOCKFILE}" || exit
  flock -x -n 100 || { echo -e "${LIGHTRED}***Query Policy already running***${NOCOLOR}" && return ;}
  trap 'cleanup' EXIT HUP INT QUIT TERM
  POLICY="${arg2}"
  # Set ASN to all if POLICY is all
  if [[ "${POLICY}" == "all" ]] &>/dev/null;then
    ASN="all"
  fi
  # Query Policy
  querypolicy
  # Query ASNs if ASN is set
  if [[ -n "${ASN+x}" ]] &>/dev/null;then
    queryasn
  fi
elif [[ "${mode}" == "queryasn" ]] &>/dev/null;then 
  exec 100>"${LOCKFILE}" || exit
  flock -x -n 100 || { echo -e "${LIGHTRED}***Query ASN already running***${NOCOLOR}" && return ;}
  trap 'cleanup' EXIT HUP INT QUIT TERM
  ASN="${arg2}"
  queryasn
elif [[ "${mode}" == "restorepolicy" ]] &>/dev/null;then 
  POLICY="${arg2}"
  restorepolicy
elif [[ "${mode}" == "restoreasncache" ]] &>/dev/null;then 
  restoreasncache
elif [[ "${mode}" == "adddomain" ]] &>/dev/null;then 
  DOMAIN="${arg2}"
  adddomain
elif [[ "${mode}" == "addasn" ]] &>/dev/null;then 
  ASN="${arg2}"
  addasn
elif [[ "${mode}" == "deletedomain" ]] &>/dev/null;then 
  DOMAIN="${arg2}"
  deletedomain
elif [[ "${mode}" == "deleteip" ]] &>/dev/null;then 
  IP="${arg2}"
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

# Set Script to use System Binaries
systembinaries ()
{
  # Check System Binaries Path
  if [[ "$(echo ${PATH} | awk -F ":" '{print $1":"$2":"$3":"$4":"}')" != "/sbin:/bin:/usr/sbin:/usr/bin:" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting System Binaries Path"
    export PATH=/sbin:/bin:/usr/sbin:/usr/bin:${PATH}
    logger -p 6 -t "${ALIAS}" "Debug - PATH: ${PATH}"
  fi
  return
}

# Cleanup
cleanup ()
{
# Remove Lock File
logger -p 6 -t "${ALIAS}" "Debug - Checking for Lock File: ${LOCKFILE}"
if [[ -f "${LOCKFILE}" ]] &>/dev/null;then
  logger -p 5 -t "${ALIAS}" "Cleanup - Deleting ${LOCKFILE}"
  rm -f ${LOCKFILE} \
  && logger -p 4 -t "${ALIAS}" "Cleanup - Deleted ${LOCKFILE}" \
  || logger -p 2 -st "${ALIAS}" "Cleanup - ***Error*** Failed to delete ${LOCKFILE}"
fi

return
}

# Menu
menu ()
{
        # Load Global Configuration
        if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
          setglobalconfig
        fi

        # Set Mode back to Menu if Changed
        [[ "${mode}" != "menu" ]] &>/dev/null && mode="menu"

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
   	printf "  (1)  readme            View ${FRIENDLYNAME} Readme\n"
     printf "  (2)  showpolicy        View existing policies\n"
     printf "  (3)  showasn           View existing ASNs\n"
     printf "\n"
     printf "  ${BOLD}Installation/Configuration:${NOCOLOR}\n"
	printf "  (4)  install           Install ${FRIENDLYNAME}\n"
	printf "  (5)  uninstall         Uninstall ${FRIENDLYNAME}\n"
	printf "  (6)  config            Global Configuration Settings\n"
	printf "  (7)  update            Check for updates for ${FRIENDLYNAME}\n"
     printf "\n"
     printf "  ${BOLD}Operations:${NOCOLOR}\n"
   	printf "  (8)  cron              Schedule Cron Job to automate Query Policy for all policies\n"
     printf "  (9)  querypolicy       Perform a manual query of an existing policy\n"
     printf "  (10) queryasn          Perform a manual query of an existing configured ASN\n"
     printf "  (11) restorepolicy     Perform a restore of an existing policy\n"
     printf "  (12) restoreasncache   Perform a restore of the ASN Cache\n"
     printf "  (13) kill              Kill any running instances of ${FRIENDLYNAME}\n"
     printf "\n"
     printf "  ${BOLD}Policy Configuration:${NOCOLOR}\n"
     printf "  (14) createpolicy      Create Policy\n"
	 printf "  (15) addasn            Add ASN\n"
	printf "  (16) editpolicy        Edit Policy\n"
	printf "  (17) editasn           Edit ASN\n"
	printf "  (18) deletepolicy      Delete Policy\n"
	printf "  (19) deleteasn         Delete ASN\n"
	printf "  (20) adddomain         Add Domain to an existing Policy\n"
	printf "  (21) deletedomain      Delete Domain from an existing Policy\n"
	printf "  (22) deleteip          Delete IP from an existing Policy\n"
     printf "\n"
	printf "  (e)  exit              Exit ${FRIENDLYNAME} Menu\n"
	printf "\nMake a selection: "
        )"
        # Display Menu
        echo "${output}" && unset output
	read -r input
	case "${input}" in
		'')
                        return
		;;
		'1')    # readme
                        # Determine if readme source is prod or beta
                        if [[ "${DEVMODE}" == "1" ]] &>/dev/null;then
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
                        clear
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy You Want to View: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        printf "\n"
                        showpolicy ${POLICY}
                        unset value policysel
		;;
		'3')    # showasn
			mode="showasn"
                        ASN="all"
                        clear
                        showasn
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the ASN You Want to View: " value
                          for asnsel in ${asnsnum};do
                            if [[ "${value}" == "$(echo ${asnsel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              ASN="$(echo ${asnsel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${asnsnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        printf "\n"
                        showasn ${ASN}
                        unset value asnsel
		;;
		'4')    # install
			mode="install"
			install
		;;
		'5')    # uninstall
			mode="uninstall"
			uninstall
		;;
		'6')    # config
                        config
		;;
		'7')    # update
			mode="update"
                        update
		;;
		'8')    # cron
			mode="cron"
                        cronjob
		;;
		'9')    # querypolicy
			mode="querypolicy"
            exec 100>"${LOCKFILE}" || return
            flock -x -n 100 || { echo -e "${LIGHTRED}***Query Policy already running***${NOCOLOR}" && PressEnter && menu ;}
            trap 'cleanup' EXIT HUP INT QUIT TERM
                        POLICY="all"
                        clear
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy You Want to Query: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        querypolicy ${POLICY}
                        unset value policysel
                        cleanup && trap '' EXIT HUP INT QUIT TERM
        ;;
		'10')    # queryasn
			mode="queryasn"
            exec 100>"${LOCKFILE}" || return
            flock -x -n 100 || { echo -e "${LIGHTRED}***Query ASN already running***${NOCOLOR}" && PressEnter && menu ;}
            trap 'cleanup' EXIT HUP INT QUIT TERM
                        ASN="all"
                        clear
                        showasn
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the ASN You Want to Query: " value
                          for asnsel in ${asnsnum};do
                            if [[ "${value}" == "$(echo ${asnsel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              ASN="$(echo ${asnsel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${asnsnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        queryasn ${ASN}
                        unset value asnsel
                        cleanup && trap '' EXIT HUP INT QUIT TERM
        ;;
		'11')    # restorepolicy
			mode="restorepolicy"
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy You Want to Restore: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        restorepolicy ${POLICY}
                        unset value policysel
        ;;
		'12')    # restoreasncache
			mode="restoreasncache"
                        restoreasncache
        ;;
		'13')    # kill
			mode="kill"
                        killscript
		;;
		'14')    # createpolicy
			mode="createpolicy"
                        createpolicy
		;;
		'15')    # addasn
			mode="addasn"
			while true &>/dev/null;do  
                          read -r -p "Select an ASN to add: " value
                          case ${value} in
                            * ) ASN=${value}; break;;
                          esac
                        done
                        addasn
		;;
		'16')   # editpolicy
			mode="editpolicy"
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy You Want to Edit: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        editpolicy ${POLICY}
                        unset value policysel
		;;
		'17')   # editasn
			mode="editasn"
                        ASN="all"
                        showasn
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the ASN You Want to Edit: " value
                          for asnsel in ${asnsnum};do
                            if [[ "${value}" == "$(echo ${asnsel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              ASN="$(echo ${asnsel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${asnsnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        editasn ${ASN}
                        unset value asnsel
		;;
		'18')   # deletepolicy
			mode="deletepolicy"
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy You Want to Delete: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        deletepolicy ${POLICY}
                        unset value policysel
		;;
		'19')   # deleteasn
			mode="deleteasn"
                        ASN="all"
                        showasn
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the ASN You Want to Delete: " value
                          for asnsel in ${asnsnum};do
                            if [[ "${value}" == "$(echo ${asnsel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              ASN="$(echo ${asnsel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${asnsnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        deleteasn ${ASN}
                        unset value asnsel
		;;
		'20')   # adddomain
			mode="adddomain"
			while true &>/dev/null;do  
                          read -r -p "Select a domain to add to a policy: " value
                          case ${value} in
                            * ) DOMAIN=${value}; break;;
                          esac
                        done
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy where you want to add ${DOMAIN}: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        adddomain ${DOMAIN}
                        unset value DOMAIN policysel
		;;
		'21')   # deletedomain
			mode="deletedomain"
			while true &>/dev/null;do  
                          read -r -p "Select a domain to delete from a policy: " value
                          case ${value} in
                            * ) DOMAIN=${value}; break;;
                          esac
                        done
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy where you want to delete ${DOMAIN}: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        deletedomain ${DOMAIN}
                        unset value DOMAIN policysel
		;;
		'22')   # deleteip
			mode="deleteip"
			while true &>/dev/null;do  
                          read -r -p "Select an IP Address to delete from a policy: " value
                          case ${value} in
                            * ) IP=${value}; break;;
                          esac
                        done
                        POLICY="all"
                        showpolicy
			while true &>/dev/null;do
                          printf "\n"
                          read -r -p "Select the Policy where you want to delete ${IP}: " value
                          for policysel in ${policiesnum};do
                            if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
                              POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
                              break 2
                            elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
                              echo -e "${RED}***Select a valid number***${NOCOLOR}"
                              break 1
                            else
                              continue
                            fi
                          done
                        done
                        deleteip ${IP}
                        unset value IP policysel
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
        [[ "${mode}" != "menu" ]] &>/dev/null && mode="menu"
	return 0
}


# Check Alias
checkalias ()
{
# Create alias if it doesn't exist
if [[ "${mode}" != "uninstall" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Checking Alias in /jffs/configs/profile.add"
  if [[ ! -f "/jffs/configs/profile.add" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Alias Check - Creating /jffs/configs/profile.add"
    touch -a /jffs/configs/profile.add \
    && chmod 666 /jffs/configs/profile.add \
    && logger -p 4 -st "${ALIAS}" "Alias Check - Created /jffs/configs/profile.add" \
    || logger -p 2 -st "${ALIAS}" "Alias Check - ***Error*** Failed to create /jffs/configs/profile.add"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/configs/profile.add)" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Alias Check - Creating Alias for ${0} as ${ALIAS}"
    echo -e "alias ${ALIAS}=\"sh ${0}\" # domain_vpn_routing" >> /jffs/configs/profile.add \
    && source /jffs/configs/profile.add \
    && logger -p 4 -st "${ALIAS}" "Alias Check - Created Alias for ${0} as ${ALIAS}" \
    || logger -p 2 -st "${ALIAS}" "Alias Check - ***Error*** Failed to create Alias for ${0} as ${ALIAS}"
    . /jffs/configs/profile.add
  fi
# Remove alias if it does exist during uninstall
elif [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  # Remove Alias
  cmdline="sh ${0} cron"
  if [[ -n "$(grep -e "alias ${ALIAS}=\"sh ${0}\" # domain_vpn_routing" /jffs/configs/profile.add)" ]] &>/dev/null;then 
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing Alias for ${0} from /jffs/configs/profile.add"
    sed -i '\~# domain_vpn_routing~d' /jffs/configs/profile.add \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed Alias from /jffs/configs/profile.add" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove Alias from /jffs/configs/profile.add"
  fi
fi
return
}

# Install
install ()
{
if [[ "${mode}" == "install" ]] &>/dev/null;then
  # Check to see if already installed
  if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null && [[ -f "${CONFIGFILE}" ]] &>/dev/null;then
    mode="menu"
    menu
  fi
  
  # Check if Backup exists
  if [[ -f "${BACKUPPATH}" ]] &>/dev/null;then
    # Prompt for restore of configuration
    while true &>/dev/null;do
      read -p "Do you want to restore configuration of ${FRIENDLYNAME}? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
      case ${yn} in
        [Yy]* ) restoreconfig="1";break;;
        [Nn]* ) restoreconfig="0";return;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
    done
  else
    restoreconfig="0"
  fi

  # Restore Configuration from Backup
  if [[ "${restoreconfig}" == "1" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Restoring configuration from ${BACKUPPATH}"
    /bin/tar zxf ${BACKUPPATH} -C / \
    && logger -p 4 -st "${ALIAS}" "Install - Restored configuration from ${BACKUPPATH}" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to restore configuration from ${BACKUPPATH}"
  fi

  # Create Policy Directory
  if [[ ! -d "${POLICYDIR}" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating ${POLICYDIR}"
    mkdir -m 666 -p "${POLICYDIR}" \
    && logger -p 4 -st "${ALIAS}" "Install - ${POLICYDIR} created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create ${POLICYDIR}"
  fi

  # Create Global Configuration File.
  if [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating ${GLOBALCONFIGFILE}"
    touch -a "${GLOBALCONFIGFILE}" \
    && chmod 666 "${GLOBALCONFIGFILE}" \
    && { globalconfigsync="0" && setglobalconfig ;} \
    && logger -p 4 -st "${ALIAS}" "Install - ${GLOBALCONFIGFILE} created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create ${GLOBALCONFIGFILE}"
  fi

  # Create Configuration File.
  if [[ ! -f "${CONFIGFILE}" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating ${CONFIGFILE}"
    touch -a "${CONFIGFILE}" \
    && chmod 666 "${CONFIGFILE}" \
    && logger -p 4 -st "${ALIAS}" "Install - ${CONFIGFILE} created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create ${CONFIGFILE}"
  fi
  
  # Create ASN File
  if [[ ! -f "${ASNFILE}" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating ${ASNFILE}"
    touch -a ${ASNFILE} \
    && chmod 666 ${ASNFILE} \
    && logger -p 4 -st "${ALIAS}" "Install - ${ASNFILE} created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create ${ASNFILE}"
  fi

  # Create wan-event if it does not exist
    if [[ ! -f "/jffs/scripts/wan-event" ]] &>/dev/null;then
      logger -p 5 -st "${ALIAS}" "Install - Creating wan-event script"
      touch -a /jffs/scripts/wan-event \
      && chmod 755 /jffs/scripts/wan-event \
      && echo "#!/bin/sh" >> /jffs/scripts/wan-event \
      && logger -p 4 -st "${ALIAS}" "Install - wan-event script has been created" \
      || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create wan-event script"
    fi

  # Add Script to wan-event
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh ${0} cron"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} cron job to wan-event"
    echo -e "\r\n${cmdline} # domain_vpn_routing" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} cron job added to wan-event" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} cron job to wan-event"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh ${0} querypolicy all"
    logger -t "${ALIAS}" "Install - Adding ${ALIAS} to wan-event"
    echo -e "\r\n${cmdline} # domain_vpn_routing_queryall" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} added to wan-event" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} to wan-event"
  fi

  # Create openvpn-event if it does not exist
  if [[ ! -f "/jffs/scripts/openvpn-event" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating openvpn-event"
    touch -a /jffs/scripts/openvpn-event \
    && chmod 755 /jffs/scripts/openvpn-event \
    && echo "#!/bin/sh" >> /jffs/scripts/openvpn-event \
    && logger -p 4 -st "${ALIAS}" "Install - openvpn-event has been created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create openvpn-event"
  fi

  # Add Script to openvpn-event
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    cmdline="sh ${0} cron"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} cron job to openvpn-event"
    echo -e "\r\n${cmdline} # domain_vpn_routing" >> /jffs/scripts/openvpn-event \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} cron job added to openvpn-event" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} cron job to openvpn-event"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    cmdline="sh ${0} querypolicy all"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} to openvpn-event"
    echo -e "\r\n${cmdline} # domain_vpn_routing_queryall" >> /jffs/scripts/openvpn-event \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} added to openvpn-event" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} to openvpn-event"
  fi

  # Create wgclient-start if it does not exist
  if [[ ! -f "/jffs/scripts/wgclient-start" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating wgclient-start script"
    touch -a /jffs/scripts/wgclient-start \
    && chmod 755 /jffs/scripts/wgclient-start \
    && echo "#!/bin/sh" >> /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Install - wgclient-start script has been created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create wgclient-start script"
  fi

  # Add Script to wgclient-start
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/wgclient-start)" ]] &>/dev/null;then 
    cmdline="sh ${0} cron"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} Cron Job to wgclient-start"
    echo -e "\r\n${cmdline} # domain_vpn_routing" >> /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} Cron Job added to wgclient-start" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} Cron Job to wgclient-start"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/wgclient-start)" ]] &>/dev/null;then 
    cmdline="sh ${0} querypolicy all"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} Query Policy All to wgclient-start"
    echo -e "\r\n${cmdline} # domain_vpn_routing_queryall" >> /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} Query Policy All added to wgclient-start" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} Query Policy All to wgclient-start"
  fi

  # Check Alias
  checkalias || return

  # Create Initial Cron Jobs
  cronjob || return
  
  # Read Global Config File
  setglobalconfig || return
  
  # Execute Restore Policy if restoring from back up
  if [[ "${restoreconfig}" == "1" ]] &>/dev/null;then
    POLICY="all"
    restorepolicy
  fi

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
    case ${yn} in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  
  # Prompt for backup of configuration
  while true &>/dev/null;do
    read -p "Do you want to backup configuration of ${FRIENDLYNAME}? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    case ${yn} in
      [Yy]* ) backupconfig="1";break;;
      [Nn]* ) backupconfig="0";return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done

  # Check if POLICYDIR exists
  if [[ ! -d "${POLICYDIR}" ]] &>/dev/null;then
    echo -e "${RED}${ALIAS} - Uninstall: ${ALIAS} not installed...${NOCOLOR}"
    return
  fi
  
  # Perform Backup
  if [[ "${backupconfig}" == "1" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Uninstall - Backing up configuration of ${FRIENDLYNAME} to ${BACKUPPATH}"
    /bin/tar czf ${BACKUPPATH} ${POLICYDIR} \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Backed up configuration of ${FRIENDLYNAME} to ${BACKUPPATH}" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to backup configuration of ${FRIENDLYNAME} to ${BACKUPPATH}"
  fi

  # Remove Cron Job
  cronjob || return

  # Remove Script from wan-event
  cmdline="sh ${0} cron"
  if [[ -n "$(grep -e "^${cmdline}" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing Cron Job from wan-event"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/wan-event \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed Cron Job from wan-event" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove Cron Job from wan-event"
  fi
  cmdline="sh ${0} querypolicy all"
  if [[ -n "$(grep -e "^${cmdline}" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing Query Policy All from wan-event"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/wan-event \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed Query Policy All from wan-event" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove Query Policy All from wan-event"
  fi

  # Remove Script from openvpn-event
  cmdline="sh ${0} cron"
  if [[ -n "$(grep -e "^${cmdline}" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing Cron Job from openvpn-event"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/openvpn-event \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed Cron Job from openvpn-event" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove Cron Job from openvpn-event"
  fi
  cmdline="sh ${0} querypolicy all"
  if [[ -n "$(grep -e "^${cmdline}" /jffs/scripts/openvpn-event)" ]] &>/dev/null;then 
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing Query Policy All from openvpn-event"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/openvpn-event \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed Query Policy All from openvpn-event" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove Query Policy All from openvpn-event"
  fi

  # Remove Script from wgclient-start
  cmdline="sh ${0} cron"
  if [[ -n "$(grep -e "^${cmdline}" /jffs/scripts/wgclient-start)" ]] &>/dev/null;then 
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing Cron Job from wgclient-start"
    sed -i '\~# domain_vpn_routing~d' /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed Cron Job from wgclient-start" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove Cron Job from wgclient-start"
  fi
  cmdline="sh ${0} querypolicy all"
  if [[ -n "$(grep -e "^${cmdline}" /jffs/scripts/wgclient-start)" ]] &>/dev/null;then 
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing Query Policy All from wgclient-start"
    sed -i '\~# domain_vpn_routing_queryall~d' /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed Query Policy All from wgclient-start" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove Query Policy All from wgclient-start"
  fi

  # Delete Policies
  POLICY="all"
  deletepolicy

  # Delete Policy Directory
  if [[ -d "${POLICYDIR}" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Uninstall - Deleting ${POLICYDIR}"
    rm -rf "${POLICYDIR}" \
    && logger -p 4 -st "${ALIAS}" "Uninstall - ${POLICYDIR} deleted" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to delete ${POLICYDIR}"
  fi
  # Remove Lock File
  if [[ -f "${LOCKFILE}" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Uninstall - Removing ${LOCKFILE}"
    rm -f "${LOCKFILE}" \
    && logger -p 4 -st "${ALIAS}" "Uninstall - Removed ${LOCKFILE}" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ***Error*** Failed to remove ${LOCKFILE}"
  fi

  # Remove Alias
  checkalias

  # Check for Script File
  if [[ -f ${0} ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Uninstall - Deleting ${0}"
    rm -f ${0} \
    && logger -p 4 -st "${ALIAS}" "Uninstall - ${0} deleted" \
    || logger -p 2 -st "${ALIAS}" "Uninstall - ${0} failed to delete"
  fi

fi
return
}

# Firewall Restore
setfirewallrestore ()
{
  # Set Firewall Event File
  firewallfile="/jffs/scripts/firewall-start"

  if [[ -z "${FIREWALLRESTORE+x}" ]] &>/dev/null;then
    return
  elif [[ "${FIREWALLRESTORE}" == "1" ]] &>/dev/null;then
    # Create file if it does not exist
    if [[ ! -f "${firewallfile}" ]] &>/dev/null;then
      logger -p 5 -st "${ALIAS}" "Firewall Restore - Creating ${firewallfile}"
      touch -a ${firewallfile} \
      && chmod 755 ${firewallfile} \
      && echo "#!/bin/sh" >> ${firewallfile} \
      && logger -p 4 -st "${ALIAS}" "Firewall Restore - ${firewallfile} has been created" \
      || logger -p 2 -st "${ALIAS}" "Firewall Restore - ***Error*** Failed to create ${firewallfile}"
    fi
    # Add Script to file
    if [[ -z "$(grep -w "# domain_vpn_routing_restoreall" ${firewallfile})" ]] &>/dev/null;then
      cmdline="sh ${0} restorepolicy all"
      logger -p 5 -st "${ALIAS}" "Firewall Restore - Adding ${ALIAS} to ${firewallfile}"
      echo -e "\n${cmdline} # domain_vpn_routing_restoreall" >> ${firewallfile} \
      && logger -p 4 -st "${ALIAS}" "Firewall Restore - ${ALIAS} added to ${firewallfile}" \
      || logger -p 2 -st "${ALIAS}" "Firewall Restore - ***Error*** Failed to add ${ALIAS} to ${firewallfile}"
    fi
  elif [[ "${FIREWALLRESTORE}" == "0" ]] &>/dev/null && [[ -f "${firewallfile}" ]] &>/dev/null;then
    # Remove Script from file
    cmdline="sh ${0} restorepolicy all"
    if [[ -n "$(grep -e "^${cmdline}" ${firewallfile})" ]] &>/dev/null;then 
      logger -p 5 -st "${ALIAS}" "Firewall Restore - Removing ${ALIAS} from ${firewallfile}"
      sed -i '\~# domain_vpn_routing_restoreall~d' ${firewallfile} \
      && logger -p 4 -st "${ALIAS}" "Firewall Restore - Removed ${ALIAS} from ${firewallfile}" \
      || logger -p 2 -st "${ALIAS}" "Firewall Restore - ***Error*** Failed to remove ${ALIAS} from ${firewallfile}"
    fi
  fi
  
  unset cmdline
  
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
if [[ "${globalconfigsync}" == "0" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Checking for missing global configuration options"
  
  # ENABLE
  if [[ -z "$(sed -n '/\bENABLE=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating ENABLE Default: Enabled"
    echo -e "ENABLE=1" >> ${GLOBALCONFIGFILE}
  fi

  # DEVMODE
  if [[ -z "$(sed -n '/\bDEVMODE=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating DEVMODE Default: Disabled"
    echo -e "DEVMODE=0" >> ${GLOBALCONFIGFILE}
  fi

  # CHECKNVRAM
  if [[ -z "$(sed -n '/\bCHECKNVRAM=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating CHECKNVRAM Default: Disabled"
    echo -e "CHECKNVRAM=0" >> ${GLOBALCONFIGFILE}
  fi

  # PROCESSPRIORITY
  if [[ -z "$(sed -n '/\bPROCESSPRIORITY\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating PROCESSPRIORITY Default: Normal"
    echo -e "PROCESSPRIORITY=0" >> ${GLOBALCONFIGFILE}
  fi

  # CHECKINTERVAL
  if [[ -z "$(sed -n '/\bCHECKINTERVAL\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating CHECKINTERVAL Default: 15 minutes"
    echo -e "CHECKINTERVAL=15" >> ${GLOBALCONFIGFILE}
  fi

  # BOOTDELAYTIMER
  if [[ -z "$(sed -n '/\bBOOTDELAYTIMER\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating BOOTDELAYTIMER Default: 0 seconds"
    echo -e "BOOTDELAYTIMER=0" >> ${GLOBALCONFIGFILE}
  fi
  
  # FIREWALLRESTORE
  if [[ -z "$(sed -n '/\bFIREWALLRESTORE=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating FIREWALLRESTORE Default: Disabled"
    echo -e "FIREWALLRESTORE=0" >> ${GLOBALCONFIGFILE}
  fi
  
  # QUERYADGUARDHOMELOG
  if [[ -z "$(sed -n '/\bQUERYADGUARDHOMELOG=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating QUERYADGUARDHOMELOG Default: Disabled"
    echo -e "QUERYADGUARDHOMELOG=0" >> ${GLOBALCONFIGFILE}
  fi
  
  # ASNCACHE
  if [[ -z "$(sed -n '/\bASNCACHE=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating ASNCACHE Default: Disabled"
    echo -e "ASNCACHE=0" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC1FWMARK
  if [[ -z "$(sed -n '/\bOVPNC1FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC1FWMARK Default: 0x1000"
    echo -e "OVPNC1FWMARK=0x1000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC1MASK
  if [[ -z "$(sed -n '/\bOVPNC1MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC1MASK Default: 0xf000"
    echo -e "OVPNC1MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC1DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "OVPNC1DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC1DNSSERVER Default: N/A"
    echo -e "OVPNC1DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC1DOT
  if [[ -z "$(sed -n '/\bOVPNC1DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC1DOT Default: Disabled"
    echo -e "OVPNC1DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC2FWMARK
  if [[ -z "$(sed -n '/\bOVPNC2FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC2FWMARK Default: 0x2000"
    echo -e "OVPNC2FWMARK=0x2000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC2MASK
  if [[ -z "$(sed -n '/\bOVPNC2MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC2MASK Default: 0xf000"
    echo -e "OVPNC2MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC2DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "OVPNC2DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC2DNSSERVER Default: N/A"
    echo -e "OVPNC2DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC2DOT
  if [[ -z "$(sed -n '/\bOVPNC2DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC2DOT Default: Disabled"
    echo -e "OVPNC2DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC3FWMARK
  if [[ -z "$(sed -n '/\bOVPNC3FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC3FWMARK Default: 0x4000"
    echo -e "OVPNC3FWMARK=0x4000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC3MASK
  if [[ -z "$(sed -n '/\bOVPNC3MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC3MASK Default: 0xf000"
    echo -e "OVPNC3MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC3DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "OVPNC3DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC3DNSSERVER Default: N/A"
    echo -e "OVPNC3DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC3DOT
  if [[ -z "$(sed -n '/\bOVPNC3DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC3DOT Default: Disabled"
    echo -e "OVPNC3DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC4FWMARK
  if [[ -z "$(sed -n '/\bOVPNC4FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC4FWMARK Default: 0x7000"
    echo -e "OVPNC4FWMARK=0x7000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC4MASK
  if [[ -z "$(sed -n '/\bOVPNC4MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC4MASK Default: 0xf000"
    echo -e "OVPNC4MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC4DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "OVPNC4DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC4DNSSERVER Default: N/A"
    echo -e "OVPNC4DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC4DOT
  if [[ -z "$(sed -n '/\bOVPNC4DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC4DOT Default: Disabled"
    echo -e "OVPNC4DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC5FWMARK
  if [[ -z "$(sed -n '/\bOVPNC5FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC5FWMARK Default: 0x3000"
    echo -e "OVPNC5FWMARK=0x3000" >> ${GLOBALCONFIGFILE}
  fi

  # OVPNC5MASK
  if [[ -z "$(sed -n '/\bOVPNC5MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating OVPNC5MASK Default: 0xf000"
    echo -e "OVPNC5MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC5DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "OVPNC5DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC5DNSSERVER Default: N/A"
    echo -e "OVPNC5DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # OVPNC5DOT
  if [[ -z "$(sed -n '/\bOVPNC5DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting OVPNC5DOT Default: Disabled"
    echo -e "OVPNC5DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # WGC1FWMARK
  if [[ -z "$(sed -n '/\bWGC1FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC1FWMARK Default: 0xa000"
    echo -e "WGC1FWMARK=0xa000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC1MASK
  if [[ -z "$(sed -n '/\bWGC1MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC1MASK Default: 0xf000"
    echo -e "WGC1MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC1DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WGC1DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC1DNSSERVER Default: N/A"
    echo -e "WGC1DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC1DOT
  if [[ -z "$(sed -n '/\bWGC1DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC1DOT Default: Disabled"
    echo -e "WGC1DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # WGC2FWMARK
  if [[ -z "$(sed -n '/\bWGC2FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC2FWMARK Default: 0xb000"
    echo -e "WGC2FWMARK=0xb000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC2MASK
  if [[ -z "$(sed -n '/\bWGC2MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC2MASK Default: 0xf000"
    echo -e "WGC2MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC2DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WGC2DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC2DNSSERVER Default: N/A"
    echo -e "WGC2DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC2DOT
  if [[ -z "$(sed -n '/\bWGC2DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC2DOT Default: Disabled"
    echo -e "WGC2DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # WGC3FWMARK
  if [[ -z "$(sed -n '/\bWGC3FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC3FWMARK Default: 0xc000"
    echo -e "WGC3FWMARK=0xc000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC3MASK
  if [[ -z "$(sed -n '/\bWGC3MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC3MASK Default: 0xf000"
    echo -e "WGC3MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC3DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WGC3DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC3DNSSERVER Default: N/A"
    echo -e "WGC3DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC3DOT
  if [[ -z "$(sed -n '/\bWGC3DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC3DOT Default: Disabled"
    echo -e "WGC3DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # WGC4FWMARK
  if [[ -z "$(sed -n '/\bWGC4FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC4FWMARK Default: 0xd000"
    echo -e "WGC4FWMARK=0xd000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC4MASK
  if [[ -z "$(sed -n '/\bWGC4MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC4MASK Default: 0xf000"
    echo -e "WGC4MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC4DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WGC4DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC4DNSSERVER Default: N/A"
    echo -e "WGC4DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC4DOT
  if [[ -z "$(sed -n '/\bWGC4DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC4DOT Default: Disabled"
    echo -e "WGC4DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # WGC5FWMARK
  if [[ -z "$(sed -n '/\bWGC5FWMARK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC5FWMARK Default: 0xe000"
    echo -e "WGC5FWMARK=0xe000" >> ${GLOBALCONFIGFILE}
  fi

  # WGC5MASK
  if [[ -z "$(sed -n '/\bWGC5MASK\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Creating WGC5MASK Default: 0xf000"
    echo -e "WGC5MASK=0xf000" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC5DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WGC5DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC5DNSSERVER Default: N/A"
    echo -e "WGC5DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WGC5DOT
  if [[ -z "$(sed -n '/\bWGC5DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WGC5DOT Default: Disabled"
    echo -e "WGC5DOT=0" >> ${GLOBALCONFIGFILE}
  fi
  
  # WANDNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WANDNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WANDNSSERVER Default: N/A"
    echo -e "WANDNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WANDOT
  if [[ -z "$(sed -n '/\bWANDOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WANDOT Default: Disabled"
    echo -e "WANDOT=0" >> ${GLOBALCONFIGFILE}
  fi
  
  # WAN0DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WAN0DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WAN0DNSSERVER Default: N/A"
    echo -e "WAN0DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WAN0DOT
  if [[ -z "$(sed -n '/\bWAN0DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WAN0DOT Default: Disabled"
    echo -e "WAN0DOT=0" >> ${GLOBALCONFIGFILE}
  fi
  
  # WAN1DNSSERVER
  if [[ -z "$(awk -F "=" '$1 == "WAN1DNSSERVER" {print $1}' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WAN1DNSSERVER Default: N/A"
    echo -e "WAN1DNSSERVER=" >> ${GLOBALCONFIGFILE}
  fi
  
  # WAN1DOT
  if [[ -z "$(sed -n '/\bWAN1DOT=\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Setting WAN1DOT Default: Disabled"
    echo -e "WAN1DOT=0" >> ${GLOBALCONFIGFILE}
  fi

  # Reading updated Global Configuration
  logger -p 6 -t "${ALIAS}" "Debug - Reading ${GLOBALCONFIGFILE}"
  . ${GLOBALCONFIGFILE}

  # Set flag for Global Config Sync to 1
  [[ "${globalconfigsync}" == "0" ]] &>/dev/null && globalconfigsync="1"
fi

# Read Configuration File if Global Config Sync flag is 1
if [[ "${globalconfigsync}" == "1" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Reading ${GLOBALCONFIGFILE}"
  . ${GLOBALCONFIGFILE}
fi

return
}

# Reset Global Config
resetconfig ()
{
if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  logger -p 3 -t "${ALIAS}" "Reset Config - Resetting Global Configuration"
  > ${GLOBALCONFIGFILE} \
  && { globalconfigsync="0" && setglobalconfig && logger -p 4 -st "${ALIAS}" "Reset Config - Reset Global Configuration" ;} \
  || logger -p 2 -st "${ALIAS}" "Reset Config - ***Error*** Failed to reset Global Configuration"
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
  && logger -p 4 -st "${ALIAS}" "Install - Successfully backed up policy configuration" \
  || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to back up policy configuration"

  # Create Global Configuration File
  if [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Install - Creating ${GLOBALCONFIGFILE}"
    touch -a "${GLOBALCONFIGFILE}" \
    && chmod 666 "${GLOBALCONFIGFILE}" \
    && setglobalconfig \
    && logger -p 4 -st "${ALIAS}" "Install - ${GLOBALCONFIGFILE} created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create ${GLOBALCONFIGFILE}"
  fi

  # Create wan-event if it does not exist
  if [[ ! -f "/jffs/scripts/wan-event" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating wan-event script"
    touch -a /jffs/scripts/wan-event \
    && chmod 755 /jffs/scripts/wan-event \
    && echo "#!/bin/sh" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "${ALIAS}" "Install - wan-event script has been created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create wan-event script"
  fi

  # Add Script to wan-event
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh ${0} cron"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} Cron Job to wan-event"
    echo -e "\r\n${cmdline} # domain_vpn_routing" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} Cron Job added to wan-event" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} Cron Job to wan-event"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/wan-event)" ]] &>/dev/null;then 
    cmdline="sh ${0} querypolicy all"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} Query Policy All to wan-event"
    echo -e "\r\n${cmdline} # domain_vpn_routing_queryall" >> /jffs/scripts/wan-event \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} Query Policy All added to wan-event" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} Query Policy All to wan-event"
  fi

  # Read Configuration File for Policies
  Lines="$(cat ${CONFIGFILE})"

  # Identify OpenVPN Tunnel Interfaces
  c1="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
  c2="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client2/config.ovpn 2>/dev/null)"
  c3="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client3/config.ovpn 2>/dev/null)"
  c4="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client4/config.ovpn 2>/dev/null)"
  c5="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client5/config.ovpn 2>/dev/null)"
  s1="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server1/config.ovpn 2>/dev/null)"
  s2="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server2/config.ovpn 2>/dev/null)"

  # Update Interfaces
  for Line in ${Lines};do
    if [[ -n "$(echo ${Line} | grep -e "${c1}\|${c2}\|${c3}\|${c4}\|${c5}\|${s1}\|${s2}\|${WAN0GWIFNAME}\|${WAN1GWIFNAME}")" ]] &>/dev/null;then
      fixpolicy="$(echo "${Line}" | awk -F "|" '{print $1}')"
      fixpolicydomainlist="$(echo "${Line}" | awk -F "|" '{print $2}')"
      fixpolicydomainiplist="$(echo "${Line}" | awk -F "|" '{print $3}')"
      fixpolicyinterface="$(echo "${Line}" | awk -F "|" '{print $4}')"
      fixpolicyverboselog="$(echo "${Line}" | awk -F "|" '{print $5}')"
      fixpolicyprivateips="$(echo "${Line}" | awk -F "|" '{print $6}')"
      if [[ "${fixpolicyinterface}" == "${c1}" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc1"
      elif [[ "${fixpolicyinterface}" == "${c2}" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc2"
      elif [[ "${fixpolicyinterface}" == "${c3}" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc3"
      elif [[ "${fixpolicyinterface}" == "${c4}" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc4"
      elif [[ "${fixpolicyinterface}" == "${c5}" ]] &>/dev/null;then
        fixpolicyinterface="ovpnc5"
      elif [[ "${fixpolicyinterface}" == "${s1}" ]] &>/dev/null;then
        fixpolicyinterface="ovpns1"
      elif [[ "${fixpolicyinterface}" == "${s2}" ]] &>/dev/null;then
        fixpolicyinterface="ovpns2"
      elif [[ "${fixpolicyinterface}" == "${WAN0GWIFNAME}" ]] &>/dev/null;then
        fixpolicyinterface="wan0"
      elif [[ "${fixpolicyinterface}" == "${WAN1GWIFNAME}" ]] &>/dev/null;then
        fixpolicyinterface="wan1"
      fi
      sed -i "\:"${Line}":d" "${CONFIGFILE}"
      echo -e "${fixpolicy}|${fixpolicydomainlist}|${fixpolicydomainiplist}|${fixpolicyinterface}|${fixpolicyverboselog}|${fixpolicyprivateips}" >> ${CONFIGFILE}
    else
      continue
    fi
  done

  unset Lines fixpolicy fixpolicydomainlist fixpolicydomainiplist fixpolicyinterface fixpolicyverboselog fixpolicyprivateips c1 c2 c3 c4 c5 s1 s2
fi

return
}

# Delete IPSets format prior to version 2.1.4
deleteoldipsetsprev300 ()
{
  DELETEOLDIPSETPOLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
  for DELETEOLDIPSETPOLICY in ${DELETEOLDIPSETPOLICIES};do
    # Determine Interface and Route Table for IP Routes to delete.
    INTERFACE="$(awk -F "|" '/^'${DELETEOLDIPSETPOLICY}'/ {print $4}' ${CONFIGFILE})"
    routingdirector || return
    # Delete IPv6 IP6Tables OUTPUT Rule
    if [[ -n "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${DELETEOLDIPSETPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Deleting IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D OUTPUT -m set --match-set DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IP6Tables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables PREROUTING Rule
    if [[ -n "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "DomainVPNRouting-'${DELETEOLDIPSETPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Deleting IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D PREROUTING -m set --match-set DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IP6Tables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "DomainVPNRouting-'${DELETEOLDIPSETPOLICY}'-ipv6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Deleting IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IP6Tables POSTROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IPSET
    if [[ -n "$(ipset list DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Deleting IPv6 IPSET for ${DELETEOLDIPSETPOLICY}"
      ipset destroy DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv6 \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IPv6 IPSET for ${DELETEOLDIPSETPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IPv6 IPSET for ${DELETEOLDIPSETPOLICY}"
    fi
    # Delete IPv6 IPSET File
    if [[ -f "${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv6.ipset" ]] &>/dev/null;then
      logger -p 5 -st "${ALIAS}" "Delete Old IPSets - Deleting ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv6.ipset"
      rm -f ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv6.ipset \
      && logger -p 4 -st "${ALIAS}" "Delete Old IPSets - ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv6.ipset" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv6.ipset"
    fi
    # Delete IPv4 IPTables OUTPUT Rule
    if [[ -n "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${DELETEOLDIPSETPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Deleting IPTables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 FWMark: ${FWMARK}"
      iptables -t mangle -D OUTPUT -m set --match-set DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IPTables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IPTables OUTPUT rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables PREROUTING Rule
    if [[ -n "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "DomainVPNRouting-'${DELETEOLDIPSETPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Deleting IPTables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 FWMark: ${FWMARK}"
      iptables -t mangle -D PREROUTING -m set --match-set DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IPTables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IPTables PREROUTING rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables POSTROUTING Rule
    if [[ -n "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "DomainVPNRouting-'${DELETEOLDIPSETPOLICY}'-ipv4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Deleting IPTables rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}"
      iptables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IPTables rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IPTables rule for IPSET: DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPSET
    if [[ -n "$(ipset list DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Old IPSets - Creating IPv4 IPSET for ${DELETEOLDIPSETPOLICY}"
      ipset destroy DomainVPNRouting-${DELETEOLDIPSETPOLICY}-ipv4 \
      && logger -p 4 -t "${ALIAS}" "Delete Old IPSets - Deleted IPv4 IPSET for ${DELETEOLDIPSETPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete IPv4 IPSET for ${DELETEOLDIPSETPOLICY}"
    fi
    # Delete IPv4 IPSET File
    if [[ -f "${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv4.ipset" ]] &>/dev/null;then
      logger -p 5 -st "${ALIAS}" "Delete Old IPSets - Deleting ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv4.ipset"
      rm -f ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv4.ipset \
      && logger -p 4 -st "${ALIAS}" "Delete Old IPSets - ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv4.ipset" \
      || logger -p 2 -st "${ALIAS}" "Delete Old IPSets - ***Error*** Failed to delete ${POLICYDIR}/policy_${DELETEOLDIPSETPOLICY}-ipv4.ipset"
    fi
  done
	
  return
}

# Update Configuration from Pre-Version 2.1.2
updateconfigprev212 ()
{
# Check if config file exists and global config file is missing and then update from prev2 configuration
if [[ -f "${CONFIGFILE}" ]] &>/dev/null && [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  # Create wgclient-start if it does not exist
  if [[ ! -f "/jffs/scripts/wgclient-start" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Install - Creating wgclient-start script"
    touch -a /jffs/scripts/wgclient-start \
    && chmod 755 /jffs/scripts/wgclient-start \
    && echo "#!/bin/sh" >> /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Install - wgclient-start script has been created" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to create wgclient-start script"
  fi

  # Add Script to wgclient-start
  if [[ -z "$(grep -w "# domain_vpn_routing" /jffs/scripts/wgclient-start)" ]] &>/dev/null;then 
    cmdline="sh ${0} cron"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} Cron Job to wgclient-start"
    echo -e "\r\n${cmdline} # domain_vpn_routing" >> /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} Cron Job added to wgclient-start" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} Cron Job to wgclient-start"
  fi
  if [[ -z "$(grep -w "# domain_vpn_routing_queryall" /jffs/scripts/wgclient-start)" ]] &>/dev/null;then 
    cmdline="sh ${0} querypolicy all"
    logger -p 5 -st "${ALIAS}" "Install - Adding ${ALIAS} Query Policy All to wgclient-start"
    echo -e "\r\n${cmdline} # domain_vpn_routing_queryall" >> /jffs/scripts/wgclient-start \
    && logger -p 4 -st "${ALIAS}" "Install - ${ALIAS} Query Policy All added to wgclient-start" \
    || logger -p 2 -st "${ALIAS}" "Install - ***Error*** Failed to add ${ALIAS} Query Policy All to wgclient-start"
  fi
fi

return
}

# Configuration Menu
config ()
{
# Check for configuration and load configuration
if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  setglobalconfig || return
else
  printf "${RED}***${FRIENDLYNAME} is not Installed***${NOCOLOR}\n"
  if [[ "${mode}" == "menu" ]] &>/dev/null;then
    printf "\n  (r)  return    Return to Main Menu"
    printf "\n  (e)  exit      Exit" 
  else
    printf "\n  (e)  exit      Exit" 
  fi
  printf "\nMake a selection: "

  read -r input
  case ${input} in
    'r'|'R'|'menu'|'return'|'Return' )
    clear
    menu
    break
    ;;
    'e'|'E'|'exit' )
    clear
    if [[ "${mode}" == "menu" ]] &>/dev/null;then
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
if [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  echo -e "${RED}${FRIENDLYNAME} currently has no configuration file present${NOCOLOR}"
elif [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  setglobalconfig || return
fi

# Load Config Menu
clear
printf "\n  ${BOLD}Global Settings:${NOCOLOR}\n"
printf "  (0)  Enable Domain VPN Routing       Status:   " && { [[ "${ENABLE}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (1)  Configure Dev Mode              Dev Mode: " && { [[ "${DEVMODE}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (2)  Configure NVRAM Checks          NVRAM Checks: " && { [[ "${CHECKNVRAM}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (3)  Configure Process Priority      Process Priority: " && { { [[ "${PROCESSPRIORITY}" == "0" ]] &>/dev/null && printf "${LIGHTBLUE}Normal${NOCOLOR}" ;} || { [[ "${PROCESSPRIORITY}" == "-20" ]] &>/dev/null && printf "${LIGHTCYAN}Real Time${NOCOLOR}" ;} || { [[ "${PROCESSPRIORITY}" == "-10" ]] &>/dev/null && printf "${LIGHTMAGENTA}High${NOCOLOR}" ;} || { [[ "${PROCESSPRIORITY}" == "10" ]] &>/dev/null && printf "${LIGHTYELLOW}Low${NOCOLOR}" ;} || { [[ "${PROCESSPRIORITY}" == "20" ]] &>/dev/null && printf "${LIGHTRED}Lowest${NOCOLOR}" ;} || printf "${LIGHTGRAY}${PROCESSPRIORITY}${NOCOLOR}" ;} && printf "\n"
printf "  (4)  Configure Check Interval        Check Interval: ${LIGHTBLUE}${CHECKINTERVAL} Minutes${NOCOLOR}\n"
printf "  (5)  Configure Boot Delay Timer      Boot Delay Timer: ${LIGHTBLUE}${BOOTDELAYTIMER} Seconds${NOCOLOR}\n"
printf "  (6)  Configure Firewall Restore      Firewall Restore: " && { [[ "${FIREWALLRESTORE}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (7)  Enable AdGuardHome Log Query    AdGuardHome Log Query: " && { [[ "${QUERYADGUARDHOMELOG}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (8)  Enable ASN Query Cache          ASN Query Cache: " && { [[ "${ASNCACHE}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"

printf "\n  ${BOLD}Advanced Settings:${NOCOLOR}  ${LIGHTRED}***Recommended to leave default unless necessary to change***${NOCOLOR}\n"
printf "  (9)  OpenVPN Client 1 FWMark         OpenVPN Client 1 FWMark:   ${LIGHTBLUE}${OVPNC1FWMARK}${NOCOLOR}\n"
printf "  (10) OpenVPN Client 1 Mask           OpenVPN Client 1 Mask:     ${LIGHTBLUE}${OVPNC1MASK}${NOCOLOR}\n"
printf "  (11) OpenVPN Client 2 FWMark         OpenVPN Client 2 FWMark:   ${LIGHTBLUE}${OVPNC2FWMARK}${NOCOLOR}\n"
printf "  (12) OpenVPN Client 2 Mask           OpenVPN Client 2 Mask:     ${LIGHTBLUE}${OVPNC2MASK}${NOCOLOR}\n"
printf "  (13) OpenVPN Client 3 FWMark         OpenVPN Client 3 FWMark:   ${LIGHTBLUE}${OVPNC3FWMARK}${NOCOLOR}\n"
printf "  (14) OpenVPN Client 3 Mask           OpenVPN Client 3 Mask:     ${LIGHTBLUE}${OVPNC3MASK}${NOCOLOR}\n"
printf "  (15) OpenVPN Client 4 FWMark         OpenVPN Client 4 FWMark:   ${LIGHTBLUE}${OVPNC4FWMARK}${NOCOLOR}\n"
printf "  (16) OpenVPN Client 4 Mask           OpenVPN Client 4 Mask:     ${LIGHTBLUE}${OVPNC4MASK}${NOCOLOR}\n"
printf "  (17) OpenVPN Client 5 FWMark         OpenVPN Client 5 FWMark:   ${LIGHTBLUE}${OVPNC5FWMARK}${NOCOLOR}\n"
printf "  (18) OpenVPN Client 5 Mask           OpenVPN Client 5 Mask:     ${LIGHTBLUE}${OVPNC5MASK}${NOCOLOR}\n"
printf "  (19) WireGuard Client 1 FWMark       WireGuard Client 1 FWMark: ${LIGHTBLUE}${WGC1FWMARK}${NOCOLOR}\n"
printf "  (20) WireGuard Client 1 Mask         WireGuard Client 1 Mask:   ${LIGHTBLUE}${WGC1MASK}${NOCOLOR}\n"
printf "  (21) WireGuard Client 2 FWMark       WireGuard Client 2 FWMark: ${LIGHTBLUE}${WGC2FWMARK}${NOCOLOR}\n"
printf "  (22) WireGuard Client 2 Mask         WireGuard Client 2 Mask:   ${LIGHTBLUE}${WGC2MASK}${NOCOLOR}\n"
printf "  (23) WireGuard Client 3 FWMark       WireGuard Client 3 FWMark: ${LIGHTBLUE}${WGC3FWMARK}${NOCOLOR}\n"
printf "  (24) WireGuard Client 3 Mask         WireGuard Client 3 Mask:   ${LIGHTBLUE}${WGC3MASK}${NOCOLOR}\n"
printf "  (25) WireGuard Client 4 FWMark       WireGuard Client 4 FWMark: ${LIGHTBLUE}${WGC4FWMARK}${NOCOLOR}\n"
printf "  (26) WireGuard Client 4 Mask         WireGuard Client 4 Mask:   ${LIGHTBLUE}${WGC4MASK}${NOCOLOR}\n"
printf "  (27) WireGuard Client 5 FWMark       WireGuard Client 5 FWMark: ${LIGHTBLUE}${WGC5FWMARK}${NOCOLOR}\n"
printf "  (28) WireGuard Client 5 Mask         WireGuard Client 5 Mask:   ${LIGHTBLUE}${WGC5MASK}${NOCOLOR}\n"

printf "\n  ${BOLD}DNS Settings:${NOCOLOR}\n"
printf "  (29) OpenVPN Client 1 DNS Server     OpenVPN Client 1 DNS Server:    " && { [[ -z "${OVPNC1DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${OVPNC1DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${OVPNC1DNSSERVER}" ]] &>/dev/null;then
  printf "   (29a) OpenVPN Client 1 DoT          Status: " && { [[ "${OVPNC1DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (30) OpenVPN Client 2 DNS Server     OpenVPN Client 2 DNS Server:    " && { [[ -z "${OVPNC2DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${OVPNC2DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${OVPNC2DNSSERVER}" ]] &>/dev/null;then
  printf "   (30a) OpenVPN Client 2 DoT          Status: " && { [[ "${OVPNC2DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (31) OpenVPN Client 3 DNS Server     OpenVPN Client 3 DNS Server:    " && { [[ -z "${OVPNC3DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${OVPNC3DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${OVPNC3DNSSERVER}" ]] &>/dev/null;then
  printf "   (31a) OpenVPN Client 3 DoT          Status: " && { [[ "${OVPNC3DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (32) OpenVPN Client 4 DNS Server     OpenVPN Client 4 DNS Server:    " && { [[ -z "${OVPNC4DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${OVPNC4DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${OVPNC4DNSSERVER}" ]] &>/dev/null;then
  printf "   (32a) OpenVPN Client 4 DoT          Status: " && { [[ "${OVPNC4DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (33) OpenVPN Client 5 DNS Server     OpenVPN Client 5 DNS Server:    " && { [[ -z "${OVPNC5DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${OVPNC5DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${OVPNC5DNSSERVER}" ]] &>/dev/null;then
  printf "   (33a) OpenVPN Client 5 DoT          Status: " && { [[ "${OVPNC5DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (34) WireGuard Client 1 DNS Server   WireGuard Client 1 DNS Server:  " && { [[ -z "${WGC1DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WGC1DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${WGC1DNSSERVER}" ]] &>/dev/null;then
  printf "   (34a) WireGuard Client 1 DoT        Status: " && { [[ "${WGC1DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (35) WireGuard Client 2 DNS Server   WireGuard Client 2 DNS Server:  " && { [[ -z "${WGC2DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WGC2DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${WGC2DNSSERVER}" ]] &>/dev/null;then
  printf "   (35a) WireGuard Client 2 DoT        Status: " && { [[ "${WGC2DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (36) WireGuard Client 3 DNS Server   WireGuard Client 3 DNS Server:  " && { [[ -z "${WGC3DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WGC3DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${WGC3DNSSERVER}" ]] &>/dev/null;then
  printf "   (36a) WireGuard Client 1 DoT        Status: " && { [[ "${WGC3DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (37) WireGuard Client 4 DNS Server   WireGuard Client 4 DNS Server:  " && { [[ -z "${WGC4DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WGC4DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${WGC4DNSSERVER}" ]] &>/dev/null;then
  printf "   (37a) WireGuard Client 4 DoT        Status: " && { [[ "${WGC4DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
printf "  (38) WireGuard Client 5 DNS Server   WireGuard Client 5 DNS Server:  " && { [[ -z "${WGC5DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WGC5DNSSERVER}${NOCOLOR}" ;} && printf "\n"
if [[ -n "${WGC5DNSSERVER}" ]] &>/dev/null;then
  printf "   (38a) WireGuard Client 5 DoT        Status: " && { [[ "${WGC5DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi
if [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
  printf "  (39) WAN DNS Server                  WAN DNS Server:                 " && { [[ -z "${WANDNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WANDNSSERVER}${NOCOLOR}" ;} && printf "\n"
  if [[ -n "${WANDNSSERVER}" ]] &>/dev/null;then
    printf "   (39a) WAN DoT                       Status: " && { [[ "${WANDOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
  fi
else
  printf "  (39) Active WAN DNS Server           Active WAN DNS Server:          " && { [[ -z "${WANDNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WANDNSSERVER}${NOCOLOR}" ;} && printf "\n"
  if [[ -n "${WANDNSSERVER}" ]] &>/dev/null;then
    printf "   (39a) WAN DoT                       Status: " && { [[ "${WANDOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
  fi
  printf "  (40) WAN0 DNS Server                 WAN0 DNS Server:                " && { [[ -z "${WAN0DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WAN0DNSSERVER}${NOCOLOR}" ;} && printf "\n"
  if [[ -n "${WAN0DNSSERVER}" ]] &>/dev/null;then
    printf "   (40a) WAN0 DoT                      Status: " && { [[ "${WAN0DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
  fi
  printf "  (41) WAN1 DNS Server                 WAN1 DNS Server:                " && { [[ -z "${WAN1DNSSERVER}" ]] &>/dev/null && printf "${RED}(System Default)${NOCOLOR}" || printf "${LIGHTBLUE}${WAN1DNSSERVER}${NOCOLOR}" ;} && printf "\n"
  if [[ -n "${WAN1DNSSERVER}" ]] &>/dev/null;then
    printf "   (41a) WAN1 DoT                      Status: " && { [[ "${WAN1DOT}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
  fi
fi

printf "\n  ${BOLD}System Information:${NOCOLOR}\n"
printf "   DNS Logging Status                  Status:              " && { [[ "${DNSLOGGINGENABLED}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "   DNS Log Path                        Log Path:            ${LIGHTBLUE}${DNSLOGPATH}${NOCOLOR}\n"
printf "   DNS DNS-over-TLS Enabled            Status:              " && { [[ "${DOTENABLED}" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
if [[ "${DOTENABLED}" == "1" ]] &>/dev/null && [[ -n "${DOTDNSSERVERS}" ]] &>/dev/null;then
  displaydotdnsservers=${DOTDNSSERVERS//[$'\t\r\n']/ | }
  printf "   DNS DNS-over-TLS Servers            Servers:             ${LIGHTBLUE}${displaydotdnsservers}${NOCOLOR}\n"
fi
printf "   AdGuardHome Status                  Status:              " && { [[ "${ADGUARDHOMEACTIVE}" == "1" ]] &>/dev/null && printf "${GREEN}Active${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
if [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
  WAN0RPFILTER="$(cat /proc/sys/net/ipv4/conf/${WAN0GWIFNAME}/rp_filter)"
  WAN1RPFILTER="$(cat /proc/sys/net/ipv4/conf/${WAN1GWIFNAME}/rp_filter)"
  printf "   WAN0 FWMark                         WAN0 FWMark:         ${LIGHTBLUE}${WAN0FWMARK}${NOCOLOR}\n"
  printf "   WAN0 Mask                           WAN0 Mask:           ${LIGHTBLUE}${WAN0MASK}${NOCOLOR}\n"
  printf "   WAN0 Reverse Path Filter            WAN0 RP Filter:      " && { { [[ "${WAN0RPFILTER}" == "2" ]] &>/dev/null && printf "${LIGHTCYAN}Loose Filtering${NOCOLOR}" ;} || { [[ "${WAN0RPFILTER}" == "1" ]] &>/dev/null && printf "${LIGHTCYAN}Strict Filtering${NOCOLOR}" ;} || { [[ "${WAN0RPFILTER}" == "0" ]] &>/dev/null && printf "${RED}Disabled${NOCOLOR}" ;} ;} && printf "\n"
  printf "   WAN1 FWMark                         WAN1 FWMark:         ${LIGHTBLUE}${WAN1FWMARK}${NOCOLOR}\n"
  printf "   WAN1 Mask                           WAN1 Mask:           ${LIGHTBLUE}${WAN1MASK}${NOCOLOR}\n"
  printf "   WAN1 Reverse Path Filter            WAN1 RP Filter:      " && { { [[ "${WAN1RPFILTER}" == "2" ]] &>/dev/null && printf "${LIGHTCYAN}Loose Filtering${NOCOLOR}" ;} || { [[ "${WAN1RPFILTER}" == "1" ]] &>/dev/null && printf "${LIGHTCYAN}Strict Filtering${NOCOLOR}" ;} || { [[ "${WAN1RPFILTER}" == "0" ]] &>/dev/null && printf "${RED}Disabled${NOCOLOR}" ;} ;} && printf "\n"
else
  WAN0RPFILTER="$(cat /proc/sys/net/ipv4/conf/${WAN0GWIFNAME}/rp_filter)"
  printf "   WAN FWMark                          WAN FWMark:          ${LIGHTBLUE}${WAN0FWMARK}${NOCOLOR}\n"
  printf "   WAN Mask                            WAN Mask:            ${LIGHTBLUE}${WAN0MASK}${NOCOLOR}\n"
  printf "   WAN Reverse Path Filter             WAN RP Filter:       " && { { [[ "${WAN0RPFILTER}" == "2" ]] &>/dev/null && printf "${LIGHTCYAN}Loose Filtering${NOCOLOR}" ;} || { [[ "${WAN0RPFILTER}" == "1" ]] &>/dev/null && printf "${LIGHTCYAN}Strict Filtering${NOCOLOR}" ;} || { [[ "${WAN0RPFILTER}" == "0" ]] &>/dev/null && printf "${RED}Disabled${NOCOLOR}" ;} ;} && printf "\n"
fi
printf "   IP Version                          IP Version:          ${LIGHTBLUE}${IPVERSION}${NOCOLOR} ${RED}${ipversionwarning}${NOCOLOR}\n"
printf "   Dig Installed                       DIG Installed:       " && { [[ "${DIGINSTALLED}" == "1" ]] &>/dev/null && printf "${GREEN}Yes${NOCOLOR}" || printf "${RED}No${NOCOLOR}" ;} && printf "\n"
printf "   Jq Installed                        JQ Installed:        " && { [[ "${JQINSTALLED}" == "1" ]] &>/dev/null && printf "${GREEN}Yes${NOCOLOR}" || printf "${RED}No${NOCOLOR}" ;} && printf "\n"
printf "   Python3 Installed                   Python3 Installed:   " && { [[ "${PYTHON3INSTALLED}" == "1" ]] &>/dev/null && printf "${GREEN}Yes${NOCOLOR}" || printf "${RED}No${NOCOLOR}" ;} && printf "\n"


if [[ "${mode}" == "menu" ]] &>/dev/null;then
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
  '0')      # ENABLE
  while true &>/dev/null;do
    read -r -p "Do you want to enable Domain VPN Routing? This defines if the Script is enabled for execution: ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETENABLE="1"; break;;
      [Nn]* ) SETENABLE="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  zENABLE="${ENABLE}"
  NEWVARIABLES="${NEWVARIABLES} ENABLE=|${SETENABLE}"
  ;;
  '1')      # DEVMODE
  while true &>/dev/null;do
    read -r -p "Do you want to enable Developer Mode? This defines if the Script is set to Developer Mode where updates will apply beta releases: ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETDEVMODE="1"; break;;
      [Nn]* ) SETDEVMODE="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} DEVMODE=|${SETDEVMODE}"
  ;;
  '2')      # CHECKNVRAM
  while true &>/dev/null;do
    read -p "Do you want to enable NVRAM Checks? This defines if the Script is set to perform NVRAM checks before peforming key functions: ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETCHECKNVRAM="1"; break;;
      [Nn]* ) SETCHECKNVRAM="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} CHECKNVRAM=|${SETCHECKNVRAM}"
  ;;
  '3')      # PROCESSPRIORITY
  while true &>/dev/null;do  
    read -p "Configure Process Priority - 4 for Real Time Priority, 3 for High Priority, 2 for Low Priority, 1 for Lowest Priority, 0 for Normal Priority: " value
    case ${value} in
      4 ) SETPROCESSPRIORITY="-20"; break;;
      3 ) SETPROCESSPRIORITY="-10"; break;;
      2 ) SETPROCESSPRIORITY="10"; break;;
      1 ) SETPROCESSPRIORITY="20"; break;;
      0 ) SETPROCESSPRIORITY="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Select a Value between 4 and 0***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} PROCESSPRIORITY=|${SETPROCESSPRIORITY}"
  ;;
  '4')      # CHECKINTERVAL
  while true &>/dev/null;do  
    read -p "Configure Check Interval for how frequent ${ALIAS} checks policies - Valid range is 1 - 59 minutes: " value
    case ${value} in
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
  NEWVARIABLES="${NEWVARIABLES} CHECKINTERVAL=|${SETCHECKINTERVAL}"
  ;;
  '5')      # BOOTDELAYTIMER
  while true &>/dev/null;do
    read -p "Configure Boot Delay Timer - This will delay execution until System Uptime reaches this time (seconds): " value
    case ${value} in
      [0123456789]* ) SETBOOTDELAYTIMER="${value}"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} BOOTDELAYTIMER=|${SETBOOTDELAYTIMER}"
  ;;
  '6')      # FIREWALLRESTORE
  while true &>/dev/null;do
    read -p "Do you want to enable restore policy during firewall restarts?: ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETFIREWALLRESTORE="1"; break;;
      [Nn]* ) SETFIREWALLRESTORE="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  zFIREWALLRESTORE="${FIREWALLRESTORE}"
  NEWVARIABLES="${NEWVARIABLES} FIREWALLRESTORE=|${SETFIREWALLRESTORE}"
  ;;
  '7')      # QUERYADGUARDHOMELOG
  while true &>/dev/null;do
    read -r -p "Do you want to enable querying of the AdGuardHome log? This defines if Domain VPN Routing queries the AdGuardHome log if it is enabled: ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETQUERYADGUARDHOMELOG="1"; break;;
      [Nn]* ) SETQUERYADGUARDHOMELOG="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} QUERYADGUARDHOMELOG=|${SETQUERYADGUARDHOMELOG}"
  ;;
  '8')      # ASNCACHE
  while true &>/dev/null;do
    read -r -p "Do you want to enable ASN query cache? This defines if Domain VPN Routing caches ASN IP subnets queried from API: ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETASNCACHE="1"; break;;
      [Nn]* ) SETASNCACHE="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} ASNCACHE=|${SETASNCACHE}"
  ;;
  '9')      # OVPNC1FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC1 FWMark - This defines the OVPNC1 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC1FWMARK="${value}"; break;;
        "" ) SETOVPNC1FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC1FWMARK=|${SETOVPNC1FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '10')      # OVPNC1MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC1 Mask - This defines the OVPNC1 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC1MASK="${value}"; break;;
        "" ) SETOVPNC1MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC1MASK=|${SETOVPNC1MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '11')      # OVPNC2FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC2 FWMark - This defines the OVPNC2 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC2FWMARK="${value}"; break;;
        "" ) SETOVPNC2FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC2FWMARK=|${SETOVPNC2FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '12')      # OVPNC2MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC2 Mask - This defines the OVPNC2 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC2MASK="${value}"; break;;
        "" ) SETOVPNC2MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC2MASK=|${SETOVPNC2MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '13')      # OVPNC3FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC3 FWMark - This defines the OVPNC3 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC3FWMARK="${value}"; break;;
        "" ) SETOVPNC3FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC3FWMARK=|${SETOVPNC3FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '14')      # OVPNC3MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC3 Mask - This defines the OVPNC3 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC3MASK="${value}"; break;;
        "" ) SETOVPNC3MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC3MASK=|${SETOVPNC3MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '15')      # OVPNC4FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC4 FWMark - This defines the OVPNC4 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC4FWMARK="${value}"; break;;
        "" ) SETOVPNC4FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC4FWMARK=|${SETOVPNC4FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '16')      # OVPNC4MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC4 Mask - This defines the OVPNC4 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC4MASK="${value}"; break;;
        "" ) SETOVPNC4MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC4MASK=|${SETOVPNC4MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '17')      # OVPNC5FWMARK
  while true &>/dev/null;do
    read -p "Configure OVPNC5 FWMark - This defines the OVPNC5 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC5FWMARK="${value}"; break;;
        "" ) SETOVPNC5FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC5FWMARK=|${SETOVPNC5FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '18')      # OVPNC5MASK
  while true &>/dev/null;do
    read -p "Configure OVPNC5 Mask - This defines the OVPNC5 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETOVPNC5MASK="${value}"; break;;
        "" ) SETOVPNC5MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC5MASK=|${SETOVPNC5MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '19')      # WGC1FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC1 FWMark - This defines the WGC1 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC1FWMARK="${value}"; break;;
        "" ) SETWGC1FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC1FWMARK=|${SETWGC1FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '20')      # WGC1MASK
  while true &>/dev/null;do
    read -p "Configure WGC1 Mask - This defines the WGC1 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC1MASK="${value}"; break;;
        "" ) SETWGC1MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC1MASK=|${SETWGC1MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '21')      # WGC2FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC2 FWMark - This defines the WGC2 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC2FWMARK="${value}"; break;;
        "" ) SETWGC2FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC2FWMARK=|${SETWGC2FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '22')      # WGC2MASK
  while true &>/dev/null;do
    read -p "Configure WGC2 Mask - This defines the WGC2 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC2MASK="${value}"; break;;
        "" ) SETWGC2MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC2MASK=|${SETWGC2MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '23')      # WGC3FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC3 FWMark - This defines the WGC3 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC3FWMARK="${value}"; break;;
        "" ) SETWGC3FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC3FWMARK=|${SETWGC3FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '24')      # WGC3MASK
  while true &>/dev/null;do
    read -p "Configure WGC3 Mask - This defines the WGC3 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC3MASK="${value}"; break;;
        "" ) SETWGC3MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC3MASK=|${SETWGC3MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '25')      # WGC4FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC4 FWMark - This defines the WGC4 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC4FWMARK="${value}"; break;;
        "" ) SETWGC4FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi  done
  NEWVARIABLES="${NEWVARIABLES} WGC4FWMARK=|${SETWGC4FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '26')      # WGC4MASK
  while true &>/dev/null;do
    read -p "Configure WGC4 Mask - This defines the WGC4 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC4MASK="${value}"; break;;
        "" ) SETWGC4MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi  done
  NEWVARIABLES="${NEWVARIABLES} WGC4MASK=|${SETWGC4MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '27')      # WGC5FWMARK
  while true &>/dev/null;do
    read -p "Configure WGC5 FWMark - This defines the WGC5 FWMark for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC5FWMARK="${value}"; break;;
        "" ) SETWGC5FWMARK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC5FWMARK=|${SETWGC5FWMARK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '28')      # WGC5MASK
  while true &>/dev/null;do
    read -p "Configure WGC5 Mask - This defines the WGC5 Mask for marking traffic: " value
    if [[ -n "${value}" ]] &>/dev/null && [[ "$(echo "$((${value}))" 2>/dev/null)" == "0" ]] &>/dev/null && [[ "${value}" != "0x0" ]] &>/dev/null;then
      echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      continue
    else
      case ${value} in
        0[xX][[:xdigit:]]* ) SETWGC5MASK="${value}"; break;;
        "" ) SETWGC5MASK="${value}"; break;;
        * ) echo -e "${RED}***Invalid hexidecimal value*** Valid Range: 0x0 - 0xffffffff${NOCOLOR}"
      esac
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC5MASK=|${SETWGC5MASK}"
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  '29')      # OVPNC1DNSSERVER
  while true &>/dev/null;do
    read -p "Configure OpenVPN Client 1 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 1 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETOVPNC1DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 1 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETOVPNC1DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 1 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 1 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC1DNSSERVER=|${SETOVPNC1DNSSERVER}"
  ;;
  '29a')      # OVPNC1DOT
  while true &>/dev/null;do
    read -r -p "Enable OpenVPN Client 1 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETOVPNC1DOT="1"; break;;
      [Nn]* ) SETOVPNC1DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC1DOT=|${SETOVPNC1DOT}"
  ;;
  '30')      # OVPNC2DNSSERVER
  while true &>/dev/null;do
    read -p "Configure OpenVPN Client 2 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 2 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETOVPNC2DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 2 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETOVPNC2DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 2 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 2 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC2DNSSERVER=|${SETOVPNC2DNSSERVER}"
  ;;
  '30a')      # OVPNC2DOT
  while true &>/dev/null;do
    read -r -p "Enable OpenVPN Client 2 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETOVPNC2DOT="1"; break;;
      [Nn]* ) SETOVPNC2DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC2DOT=|${SETOVPNC2DOT}"
  ;;
  '31')      # OVPNC3DNSSERVER
  while true &>/dev/null;do
    read -p "Configure OpenVPN Client 3 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 3 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETOVPNC3DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 3 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETOVPNC3DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 3 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 3 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC3DNSSERVER=|${SETOVPNC3DNSSERVER}"
  ;;
  '31a')      # OVPNC3DOT
  while true &>/dev/null;do
    read -r -p "Enable OpenVPN Client 3 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETOVPNC3DOT="1"; break;;
      [Nn]* ) SETOVPNC3DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC3DOT=|${SETOVPNC3DOT}"
  ;;
  '32')      # OVPNC4DNSSERVER
  while true &>/dev/null;do
    read -p "Configure OpenVPN Client 4 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 4 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETOVPNC4DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 4 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETOVPNC4DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 4 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 4 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC4DNSSERVER=|${SETOVPNC4DNSSERVER}"
  ;;
  '32a')      # OVPNC4DOT
  while true &>/dev/null;do
    read -r -p "Enable OpenVPN Client 4 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETOVPNC4DOT="1"; break;;
      [Nn]* ) SETOVPNC4DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC4DOT=|${SETOVPNC4DOT}"
  ;;
  '33')      # OVPNC5DNSSERVER
  while true &>/dev/null;do
    read -p "Configure OpenVPN Client 5 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 5 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETOVPNC5DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 5 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETOVPNC5DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 5 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - OpenVPN Client 5 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC5DNSSERVER=|${SETOVPNC5DNSSERVER}"
  ;;
  '33a')      # OVPNC5DOT
  while true &>/dev/null;do
    read -r -p "Enable OpenVPN Client 5 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETOVPNC5DOT="1"; break;;
      [Nn]* ) SETOVPNC5DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNC5DOT=|${SETOVPNC5DOT}"
  ;;
  '34')      # WGC1DNSSERVER
  while true &>/dev/null;do
    read -p "Configure WireGuard Client 1 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 1 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWGC1DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 1 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWGC1DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 1 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 1 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC1DNSSERVER=|${SETWGC1DNSSERVER}"
  ;;
  '34a')      # WGC1DOT
  while true &>/dev/null;do
    read -r -p "Enable WireGuard Client 1 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWGC1DOT="1"; break;;
      [Nn]* ) SETWGC1DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WGC1DOT=|${SETWGC1DOT}"
  ;;
  '35')      # WGC2DNSSERVER
  while true &>/dev/null;do
    read -p "Configure WireGuard Client 2 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 2 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWGC2DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 2 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWGC2DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 2 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 2 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC2DNSSERVER=|${SETWGC2DNSSERVER}"
  ;;
  '35a')      # WGC2DOT
  while true &>/dev/null;do
    read -r -p "Enable WireGuard Client 2 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWGC2DOT="1"; break;;
      [Nn]* ) SETWGC2DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WGC2DOT=|${SETWGC2DOT}"
  ;;
  '36')      # WGC3DNSSERVER
  while true &>/dev/null;do
    read -p "Configure WireGuard Client 3 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 3 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWGC3DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 3 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWGC3DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 3 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 3 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC3DNSSERVER=|${SETWGC3DNSSERVER}"
  ;;
  '36a')      # WGC3DOT
  while true &>/dev/null;do
    read -r -p "Enable WireGuard Client 3 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWGC3DOT="1"; break;;
      [Nn]* ) SETWGC3DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WGC3DOT=|${SETWGC3DOT}"
  ;;
  '37')      # WGC4DNSSERVER
  while true &>/dev/null;do
    read -p "Configure WireGuard Client 4 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 4 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWGC4DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 4 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWGC4DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 4 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 4 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC4DNSSERVER=|${SETWGC4DNSSERVER}"
  ;;
  '37a')      # WGC4DOT
  while true &>/dev/null;do
    read -r -p "Enable WireGuard Client 4 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWGC4DOT="1"; break;;
      [Nn]* ) SETWGC4DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WGC4DOT=|${SETWGC4DOT}"
  ;;
  '38')      # WGC5DNSSERVER
  while true &>/dev/null;do
    read -p "Configure WireGuard Client 5 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 5 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWGC5DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 5 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWGC5DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 5 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WireGuard Client 5 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WGC5DNSSERVER=|${SETWGC5DNSSERVER}"
  ;;
  '38a')      # WGC5DOT
  while true &>/dev/null;do
    read -r -p "Enable WireGuard Client 5 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWGC5DOT="1"; break;;
      [Nn]* ) SETWGC5DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WGC5DOT=|${SETWGC5DOT}"
  ;;
  '39')      # WANDNSSERVER
  while true &>/dev/null;do
    read -p "Configure WAN DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WAN DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWANDNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WAN DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWANDNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WAN DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WAN DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WANDNSSERVER=|${SETWANDNSSERVER}"
  ;;
  '39a')      # WANDOT
  while true &>/dev/null;do
    read -r -p "Enable WAN DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWANDOT="1"; break;;
      [Nn]* ) SETWANDOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WANDOT=|${SETWANDOT}"
  ;;
  '40')      # WAN0DNSSERVER
  while true &>/dev/null;do
    read -p "Configure WAN0 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WAN0 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWAN0DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WAN0 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWAN0DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WAN0 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WAN0 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0DNSSERVER=|${SETWAN0DNSSERVER}"
  ;;
  '40a')      # WAN0DOT
  while true &>/dev/null;do
    read -r -p "Enable WAN0 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWAN0DOT="1"; break;;
      [Nn]* ) SETWAN0DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0DOT=|${SETWAN0DOT}"
  ;;
  '41')      # WAN1DNSSERVER
  while true &>/dev/null;do
    read -p "Configure WAN1 DNS Server: " ip
    ip=${ip//[$'\t\r\n']/}
    if expr "${ip}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "${ip}" | cut -d. -f${i}) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "${ALIAS}" "Debug - WAN1 DNS Server: ${ip} is an invalid IP Address"
          break 1
        else
          SETWAN1DNSSERVER="${ip}"
          logger -p 6 -t "${ALIAS}" "Debug - WAN1 DNS Server: ${ip}"
          break 2
        fi
      done
    elif [[ -z "${ip}" ]] &>/dev/null;then
      SETWAN1DNSSERVER="${ip}"
      logger -p 6 -t "${ALIAS}" "Debug - WAN1 DNS Server not set"
      break 1
    else  
      echo -e "${RED}***${ip} is an invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${ALIAS}" "Debug - WAN1 DNS Server: ${ip} is an invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1DNSSERVER=|${SETWAN1DNSSERVER}"
  ;;
  '41a')      # WAN1DOT
  while true &>/dev/null;do
    read -r -p "Enable WAN1 DNS Server to use DNS over TLS? (Requires dig to be installed): ***Enter Y for Yes or N for No***" yn
    case ${yn} in
      [Yy]* ) SETWAN1DOT="1"; break;;
      [Nn]* ) SETWAN1DOT="0"; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1DOT=|${SETWAN1DOT}"
  ;;

  'r'|'R'|'menu'|'return'|'Return' )
  clear
  menu
  break
  ;;
  'x'|'X'|'reset'|'Reset'|'default' )
  while true &>/dev/null;do
    read -p "Are you sure you want to reset back to default configuration? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    case ${yn} in
      [Yy]* ) resetconfig && break;;
      [Nn]* ) break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  [[ "${RESTARTREQUIRED}" == "0" ]] &>/dev/null && RESTARTREQUIRED="1"
  ;;
  'e'|'E'|'exit')
  clear
  if [[ "${mode}" == "menu" ]] &>/dev/null;then
    exit
  else
    return
  fi
  break
  ;;
esac

# Configure Changed Setting in Configuration File
if [[ -n "${NEWVARIABLES}" ]] &>/dev/null;then
  for NEWVARIABLE in ${NEWVARIABLES};do
    if [[ -z "$(grep -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" ${GLOBALCONFIGFILE})" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      echo -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" >> ${GLOBALCONFIGFILE}
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F "|" '{print $2}')"/" ${GLOBALCONFIGFILE}
    elif [[ -n "$(grep -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" ${GLOBALCONFIGFILE})" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F "|" '{print $2}')"/" ${GLOBALCONFIGFILE}
    elif [[ "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')" == "CUSTOMLOGPATH=" ]] &>/dev/null;then
      [[ -n "$(sed -n '/\bCUSTOMLOGPATH\b/p' "${GLOBALCONFIGFILE}")" ]] &>/dev/null && sed -i '/CUSTOMLOGPATH=/d' ${GLOBALCONFIGFILE}
      echo -e "$(echo ${NEWVARIABLE} | awk -F "|" '{print $1}')$(echo ${NEWVARIABLE} | awk -F "|" '{print $2}')" >> ${GLOBALCONFIGFILE}
    fi
  done

  # Update Configuration
  setglobalconfig || return
  
  # Check if ENABLE was changed and delete or create FWMark rules accordingly
  if [[ -n "${zENABLE+x}" ]] &>/dev/null;then
    if [[ "${ENABLE}" == "1" ]] &>/dev/null;then
      enablescript
    else
      disablescript
    fi
    unset zENABLE
  fi

  # Check if cron job needs to be updated
  if [[ -n "${zCHECKINTERVAL+x}" ]] &>/dev/null;then
    cronjob || return
    unset zCHECKINTERVAL
  fi
  
  # Check if Firewall Restore needs to be modified
  if [[ -n "${zFIREWALLRESTORE+x}" ]] &>/dev/null;then
    setfirewallrestore || return
  fi
fi

# Check for Restart Flag
if [[ "${RESTARTREQUIRED}" == "1" ]] &>/dev/null;then
  echo -e "${LIGHTRED}***Changes are pending that require a reboot***${NOCOLOR}"
  # Prompt for Reboot
  while true &>/dev/null;do
    read -p "Do you want to reboot now? ***Enter Y for Yes or N for No***" yn
    case ${yn} in
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

# DNS Director
dnsdirector ()
{
logger -p 6 -t "${ALIAS}" "Debug - DNS Director Interface: ${INTERFACE}"

# Set default values to null
DNSSERVER=""

# Set paramaeters based on interface
if [[ "${INTERFACE}" == "ovpnc1" ]] &>/dev/null;then
  DNSSERVER="${OVPNC1DNSSERVER}"
  DOT="${OVPNC1DOT}"
elif [[ "${INTERFACE}" == "ovpnc2" ]] &>/dev/null;then
  DNSSERVER="${OVPNC2DNSSERVER}"
  DOT="${OVPNC2DOT}"
elif [[ "${INTERFACE}" == "ovpnc3" ]] &>/dev/null;then
  DNSSERVER="${OVPNC3DNSSERVER}"
  DOT="${OVPNC3DOT}"
elif [[ "${INTERFACE}" == "ovpnc4" ]] &>/dev/null;then
  DNSSERVER="${OVPNC4DNSSERVER}"
  DOT="${OVPNC4DOT}"
elif [[ "${INTERFACE}" == "ovpnc5" ]] &>/dev/null;then
  DNSSERVER="${OVPNC5DNSSERVER}"
  DOT="${OVPNC5DOT}"
elif [[ "${INTERFACE}" == "wgc1" ]] &>/dev/null;then
  DNSSERVER="${WGC1DNSSERVER}"
  DOT="${WGC1DOT}"
elif [[ "${INTERFACE}" == "wgc2" ]] &>/dev/null;then
  DNSSERVER="${WGC2DNSSERVER}"
  DOT="${WGC2DOT}"
elif [[ "${INTERFACE}" == "wgc3" ]] &>/dev/null;then
  DNSSERVER="${WGC3DNSSERVER}"
  DOT="${WGC3DOT}"
elif [[ "${INTERFACE}" == "wgc4" ]] &>/dev/null;then
  DNSSERVER="${WGC4DNSSERVER}"
  DOT="${WGC4DOT}"
elif [[ "${INTERFACE}" == "wgc5" ]] &>/dev/null;then
  DNSSERVER="${WGC5DNSSERVER}"
  DOT="${WGC5DOT}"
elif [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
  DNSSERVER="${WANDNSSERVER}"
  DOT="${WANDOT}"
elif [[ "${INTERFACE}" == "wan0" ]] &>/dev/null;then
  DNSSERVER="${WAN0DNSSERVER}"
  DOT="${WAN0DOT}"
elif [[ "${INTERFACE}" == "wan1" ]] &>/dev/null;then
  DNSSERVER="${WAN1DNSSERVER}"
  DOT="${WAN1DOT}"
fi

return
}

# Generate Interface List
generateinterfacelist ()
{
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
    if [[ -f "${OVPNCONFIGFILE}" ]] &>/dev/null;then
      if [[ -n "$(echo ${OVPNCONFIGFILE} | grep -e "client")" ]] &>/dev/null;then
        INTERFACE="ovpnc"$(echo ${OVPNCONFIGFILE} | grep -o '[0-9]')""
      elif [[ -n "$(echo ${OVPNCONFIGFILE} | grep -e "server")" ]] &>/dev/null;then
        INTERFACE="ovpns"$(echo ${OVPNCONFIGFILE} | grep -o '[0-9]')""
      fi
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done

  # Check if Wireguard Interfaces are Active
  for WGFILE in ${WGFILES};do
    if [[ -f "${WGFILE}" ]] &>/dev/null && [[ -s "${WGFILE}" ]] &>/dev/null;then
      INTERFACE="wgc"$(echo ${WGFILE} | grep -o '[0-9]')""
      INTERFACES="${INTERFACES} ${INTERFACE}"
    fi
  done
  
  # Generate available WAN interfaces
  if [[ "${WANSDUALWANENABLE}" == "0" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
  elif [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
    INTERFACES="${INTERFACES} wan"
    INTERFACES="${INTERFACES} wan0"
    INTERFACES="${INTERFACES} wan1"
  fi
  
  return
}

# Create IP FWMark Rules
createipmarkrules ()
{
if [[ "${STATE}" != "0" ]] &>/dev/null && [[ -n "${FWMARK}" ]] &>/dev/null && [[ "${ENABLE}" == "1" ]] &>/dev/null;then
  if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
    # Create FWMark IPv6 Rule
    if { [[ -n "${IPV6ADDR}" ]] &>/dev/null || [[ -n "$(${ipbinpath}ip -6 route show default dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null ;} && [[ -z "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${IPV6ROUTETABLE}'") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Checking for IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip -6 rule add from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} \
      && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Added IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - Failed to add IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      # Remove FWMark Unreachable IPv6 Rule if it exists
      if [[ -n "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Deleting Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
        ${ipbinpath}ip -6 rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
        && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Deleted Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
        || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - ***Error*** Failed to delete Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      fi
    # Create FWMark Unreachable IPv6 Rule
    elif { [[ -z "${IPV6ADDR}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip -6 route show default dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null ;} && [[ -z "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Checking for Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip -6 rule add unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Added Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - ***Error*** Failed to add Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      # Delete FWMark IPv6 Rule if it exists
      if [[ -n "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${IPV6ROUTETABLE}'") {print}')" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Deleting IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
        ${ipbinpath}ip -6 rule del from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} \
        && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Deleted IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
        || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - Failed to delete IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      fi
    fi
  fi
	
  # Create FWMark IPv4 Rule
  if [[ -n "$(${ipbinpath}ip route show default table ${ROUTETABLE})" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Checking for IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip rule add from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} \
    && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Added IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - ***Error*** Failed to add IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    # Remove FWMark Unreachable IPv4 Rule if it exists
    if [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Deleting Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Deleted Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - ***Error*** Failed to delete Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
  # Create FWMark Unreachable IPv4 Rule
  elif [[ -z "$(${ipbinpath}ip route show default table ${ROUTETABLE})" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Checking for Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip rule add unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
    && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Added Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - ***Error*** Failed to add Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    # Remove FWMark IPv4 Rule if it exists
    if [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Create IP Mark Rules - Deleting IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip rule del from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} \
      && logger -p 4 -st "${ALIAS}" "Create IP Mark Rules - Deleted IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - ***Error*** Failed to delete IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
  fi
else
  logger -p 2 -st "${ALIAS}" "Create IP Mark Rules - ***Error*** FWMark not set for ${INTERFACE}"
fi
  
return
}

# Delete IP FWMark Rules
deleteipmarkrules ()
{
if [[ "${ENABLE}" == "0" ]] &>/dev/null || { [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(awk -F "|" '$4 == "'${INTERFACE}'" {print $4}' "${CONFIGFILE}" | sort -u)" ]] &>/dev/null && [[ -z "$(awk -F "|" '$2 == "'${INTERFACE}'" {print $2}' "${ASNFILE}" | sort -u)" ]] &>/dev/null ;};then
  # Delete IPv6
  # Delete FWMark IPv6 Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${IPV6ROUTETABLE}'") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Delete IP Mark Rules - Checking for IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip -6 rule del from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} \
    && logger -p 4 -st "${ALIAS}" "Delete IP Mark Rules - Deleted IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Delete IP Mark Rules - ***Error*** Failed to delete IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
  fi
  # Delete Old FWMark IPv6 Unreachable Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Delete IP Mark Rules - Checking for Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip -6 rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
    && logger -p 4 -st "${ALIAS}" "Delete IP Mark Rules - Deleted Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Delete IP Mark Rules - ***Error*** Failed to delete Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
  fi
  # Delete IPv4
  # Delete FWMark IPv4 Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Delete IP Mark Rules - Checking for IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip rule del from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} \
    && logger -p 4 -st "${ALIAS}" "Delete IP Mark Rules - Deleted IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Delete IP Mark Rules - ***Error*** Failed to delete IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
  fi
  # Delete Old FWMark IPv4 Unreachable Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Delete IP Mark Rules - Checking for Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
    && logger -p 4 -st "${ALIAS}" "Delete IP Mark Rules - Deleted Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Delete IP Mark Rules - ***Error*** Failed to delete Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
  fi
fi
return
}

# Routing Director
routingdirector ()
{
logger -p 6 -t "${ALIAS}" "Debug - Routing Director Interface: ${INTERFACE}"

# Set default values to null
GATEWAY=""
IFNAME=""
IPV6ADDR=""
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
if [[ "${INTERFACE}" == "ovpnc1" ]] &>/dev/null;then
  IFNAME="${OVPNC1IFNAME}"
  IPV6ADDR="${OVPNC1IPV6ADDR}"
  IPV6VPNGW="${OVPNC1IPV6VPNGW}"
  RGW="${OVPNC1RGW}"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="1000"
  FWMARK="${OVPNC1FWMARK}"
  MASK="${OVPNC1MASK}"
  STATE="${OVPNC1STATE}"
elif [[ "${INTERFACE}" == "ovpnc2" ]] &>/dev/null;then
  IFNAME="${OVPNC2IFNAME}"
  IPV6ADDR="${OVPNC2IPV6ADDR}"
  IPV6VPNGW="${OVPNC2IPV6VPNGW}"
  RGW="${OVPNC2RGW}"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="2000"
  FWMARK="${OVPNC2FWMARK}"
  MASK="${OVPNC2MASK}"
  STATE="${OVPNC2STATE}"
elif [[ "${INTERFACE}" == "ovpnc3" ]] &>/dev/null;then
  IFNAME="${OVPNC3IFNAME}"
  IPV6ADDR="${OVPNC3IPV6ADDR}"
  IPV6VPNGW="${OVPNC3IPV6VPNGW}"
  RGW="${OVPNC3RGW}"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="3000"
  FWMARK="${OVPNC3FWMARK}"
  MASK="${OVPNC3MASK}"
  STATE="${OVPNC3STATE}"
elif [[ "${INTERFACE}" == "ovpnc4" ]] &>/dev/null;then
  IFNAME="${OVPNC4IFNAME}"
  IPV6ADDR="${OVPNC4IPV6ADDR}"
  IPV6VPNGW="${OVPNC4IPV6VPNGW}"
  RGW="${OVPNC4RGW}"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="4000"
  FWMARK="${OVPNC4FWMARK}"
  MASK="${OVPNC4MASK}"
  STATE="${OVPNC4STATE}"
elif [[ "${INTERFACE}" == "ovpnc5" ]] &>/dev/null;then
  IFNAME="${OVPNC5IFNAME}"
  IPV6ADDR="${OVPNC5IPV6ADDR}"
  IPV6VPNGW="${OVPNC5IPV6VPNGW}"
  RGW="${OVPNC5RGW}"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="5000"
  FWMARK="${OVPNC5FWMARK}"
  MASK="${OVPNC5MASK}"
  STATE="${OVPNC5STATE}"
elif [[ "${INTERFACE}" == "ovpns1" ]] &>/dev/null;then
  IFNAME="${OVPNS1IFNAME}"
  ROUTETABLE="main"
  IPV6ROUTETABLE="main"
  RGW="0"
  PRIORITY="0"
elif [[ "${INTERFACE}" == "ovpns2" ]] &>/dev/null;then
  IFNAME="${OVPNS2IFNAME}"
  ROUTETABLE="main"
  IPV6ROUTETABLE="main"
  RGW="0"
  PRIORITY="0"
elif [[ "${INTERFACE}" == "wgc1" ]] &>/dev/null;then
  IFNAME="${INTERFACE}"
  IPV6ADDR="${WGC1IPV6ADDR}"
  RGW="2"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="6000"
  FWMARK="${WGC1FWMARK}"
  MASK="${WGC1MASK}"
  STATE="${WGC1STATE}"
elif [[ "${INTERFACE}" == "wgc2" ]] &>/dev/null;then
  IFNAME="${INTERFACE}"
  IPV6ADDR="${WGC2IPV6ADDR}"
  RGW="2"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="7000"
  FWMARK="${WGC2FWMARK}"
  MASK="${WGC2MASK}"
  STATE="${WGC2STATE}"
elif [[ "${INTERFACE}" == "wgc3" ]] &>/dev/null;then
  IFNAME="${INTERFACE}"
  IPV6ADDR="${WGC3IPV6ADDR}"
  RGW="2"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="8000"
  FWMARK="${WGC3FWMARK}"
  MASK="${WGC3MASK}"
  STATE="${WGC3STATE}"
elif [[ "${INTERFACE}" == "wgc4" ]] &>/dev/null;then
  IFNAME="${INTERFACE}"
  IPV6ADDR="${WGC4IPV6ADDR}"
  RGW="2"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="9000"
  FWMARK="${WGC4FWMARK}"
  MASK="${WGC4MASK}"
  STATE="${WGC4STATE}"
elif [[ "${INTERFACE}" == "wgc5" ]] &>/dev/null;then
  IFNAME="${INTERFACE}"
  IPV6ADDR="${WGC5IPV6ADDR}"
  RGW="2"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
    IPV6ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
    IPV6ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  PRIORITY="10000"
  FWMARK="${WGC5FWMARK}"
  MASK="${WGC5MASK}"
  STATE="${WGC5STATE}"
elif [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
  if [[ "${WAN0PRIMARY}" == "1" ]] &>/dev/null;then
    STATE="${WAN0STATE}"
    PRIMARY="${WAN0PRIMARY}"
    GATEWAY="${WAN0GATEWAY}"
    OLDGATEWAY="${WAN1GATEWAY}"
    IFNAME="${WAN0GWIFNAME}"
    OLDIFNAME="${WAN1GWIFNAME}"
    IPV6ADDR="${WAN0IPV6ADDR}"
    FWMARK="${WAN0FWMARK}"
    MASK="${WAN0MASK}"
    OLDFWMARK="${WAN1FWMARK}"
    OLDMASK="${WAN1MASK}"
    OLDSTATE="${WAN1STATE}"
  elif [[ "${WAN1PRIMARY}" == "1" ]] &>/dev/null;then
    STATE="${WAN1STATE}"
    PRIMARY="${WAN1PRIMARY}"
    GATEWAY="${WAN1GATEWAY}"
    OLDGATEWAY="${WAN0GATEWAY}"
    IFNAME="${WAN1GWIFNAME}"
    OLDIFNAME="${WAN0GWIFNAME}"
    IPV6ADDR="${WAN1IPV6ADDR}"
    FWMARK="${WAN1FWMARK}"
    MASK="${WAN1MASK}"
    OLDFWMARK="${WAN0FWMARK}"
    OLDMASK="${WAN0MASK}"
    OLDSTATE="${WAN0STATE}"
  fi
  ROUTETABLE="main"
  IPV6ROUTETABLE="main"
  RGW="2"
  PRIORITY="150"
elif [[ "${INTERFACE}" == "wan0" ]] &>/dev/null;then
  STATE="${WAN0STATE}"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  IPV6ROUTETABLE="main"
  RGW="2"
  PRIORITY="150"
  GATEWAY="${WAN0GATEWAY}"
  IFNAME="${WAN0GWIFNAME}"
  IPV6ADDR="${WAN0IPV6ADDR}"
  FWMARK="${WAN0FWMARK}"
  MASK="${WAN0MASK}"
  PRIMARY="${WAN0PRIMARY}"
elif [[ "${INTERFACE}" == "wan1" ]] &>/dev/null;then
  STATE="${WAN1STATE}"
  if [[ "${ipcompmode}" == "1" ]] &>/dev/null;then
    ROUTETABLE="${INTERFACE}"
  elif [[ "${ipcompmode}" == "2" ]] &>/dev/null;then
    ROUTETABLE="$(awk '($2 == "'${INTERFACE}'") {print $1}' ${RTTABLESFILE})"
  fi
  IPV6ROUTETABLE="main"
  RGW="2"
  PRIORITY="150"
  GATEWAY="${WAN1GATEWAY}"
  IFNAME="${WAN1GWIFNAME}"
  IPV6ADDR="${WAN1IPV6ADDR}"
  FWMARK="${WAN1FWMARK}"
  MASK="${WAN1MASK}"
  PRIMARY="${WAN1PRIMARY}"
else
  echo -e "${RED}Policy: Unable to query Interface${NOCOLOR}"
  return
fi

# Set State to 0 if Null
if [[ -z "${STATE}" ]] &>/dev/null;then
  STATE="0"
fi

# Adjust Reverse Path Filter to Loose Filtering if enabled for Interface if FWMark is set
if [[ -n "${FWMARK}" ]] &>/dev/null && [[ "$(cat /proc/sys/net/ipv4/conf/${IFNAME}/rp_filter 2>/dev/null)" == "1" ]] &>/dev/null;then
  logger -p 5 -t "${ALIAS}" "Routing Director - Setting Reverse Path Filter for ${IFNAME} to Loose Filtering"
  echo 2 > /proc/sys/net/ipv4/conf/${IFNAME}/rp_filter \
  && logger -p 4 -t "${ALIAS}" "Routing Director - Set Reverse Path Filter for ${IFNAME} to Loose Filtering" \
  || logger -p 2 -st "${ALIAS}" "Routing Director - ***Error*** Failed to set Reverse Path Filter for ${IFNAME} to Loose Filtering"
fi

# Create Default Route for WAN Interface Routing Tables
if [[ -n "${GATEWAY}" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Checking ${INTERFACE} for Default Route in Routing Table ${ROUTETABLE}"
  if [[ -z "$(${ipbinpath}ip route list default table ${ROUTETABLE} | grep -w "${IFNAME}")" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Routing Director - Adding default route for ${INTERFACE} Routing Table via ${GATEWAY} dev ${IFNAME}"
    ${ipbinpath}ip route add default via ${GATEWAY} dev ${IFNAME} table ${ROUTETABLE} \
    && logger -p 4 -t "${ALIAS}" "Routing Director - Added default route for ${INTERFACE} Routing Table via ${GATEWAY} dev ${IFNAME}" \
    || logger -p 2 -st "${ALIAS}" "Routing Director - ***Error*** Failed to add default route for ${INTERFACE} Routing Table via ${GATEWAY} dev ${IFNAME}"
  fi
fi

# Create IPv6 Default Route for VPN Client Interface Routing Tables
if [[ -n "${IPV6VPNGW}" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Checking ${INTERFACE} for Default IPv6 Route in Routing Table ${ROUTETABLE}"
  if [[ -z "$(${ipbinpath}ip -6 route list default table ${ROUTETABLE})" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Routing Director - Adding default IPv6 route for ${INTERFACE} IPv6 Routing Table via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE}"
    ${ipbinpath}ip -6 route add default via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
    && logger -p 4 -t "${ALIAS}" "Routing Director - Added default route for ${INTERFACE} IPv6 Routing Table via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE}" \
    || logger -p 2 -st "${ALIAS}" "Routing Director - ***Error*** Failed to add default route for ${INTERFACE} IPv6 Routing Table via ${IPV6VPNGW} dev ${IFNAME} table ${ROUTETABLE}"
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
    read -r -p "Policy Name (Maximum Length: ${POLICYNAMEMAXLENGTH} characters):" NEWPOLICYNAME
	  # Check Policy Name Length
      if [[ "${#NEWPOLICYNAME}" -gt "${POLICYNAMEMAXLENGTH}" ]] &>/dev/null;then
        echo -e "${RED}***Enter a policy name that is less than ${POLICYNAMEMAXLENGTH} characters***${NOCOLOR}"
        continue
      fi
	  # Check Policy Name Characters
      case "${NEWPOLICYNAME}" in
         [abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_-]* ) CREATEPOLICYNAME=${NEWPOLICYNAME}; break;;
        * ) echo -e "${RED}***Enter a valid Policy Name*** Use the following characters: A-Z, a-z, 0-9,-_${NOCOLOR}"
      esac
  done

  # Generate Interfaces
  generateinterfacelist || return

  echo -e "Interfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "${INTERFACE}"
  done
  # User Input for Interface
  while true;do  
    read -r -p "Select an Interface for this Policy: " NEWPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [[ "${NEWPOLICYINTERFACE}" == "${INTERFACE}" ]] &>/dev/null;then
        CREATEPOLICYINTERFACE="${NEWPOLICYINTERFACE}"
        break 2
      elif [[ -n "$(echo "${INTERFACES}" | grep -w "${NEWPOLICYINTERFACE}")" ]] &>/dev/null;then
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
      case ${yn} in
        [Yy]* ) SETVERBOSELOGGING="VERBOSELOGGING=1"; break;;
        [Nn]* ) SETVERBOSELOGGING="VERBOSELOGGING=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Enable Private IP Addresses
  while true;do  
    read -r -p "Enable Private IP Addresses for this policy? ***Enter Y for Yes or N for No*** " yn
      case ${yn} in
        [Yy]* ) SETPRIVATEIPS="PRIVATEIPS=1"; break;;
        [Nn]* ) SETPRIVATEIPS="PRIVATEIPS=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done
  
  # Enable Add CNAMES
  while true;do  
    read -r -p "Enable adding CNAMES for this policy? ***Enter Y for Yes or N for No*** " yn
      case ${yn} in
        [Yy]* ) SETADDCNAMES="ADDCNAMES=1"; break;;
        [Nn]* ) SETADDCNAMES="ADDCNAMES=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Create Policy Files
  if [[ ! -f ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Create Policy - Creating ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist"
    touch -a ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist \
    && chmod 666 ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist \
    && logger -p 4 -st "${ALIAS}" "Create Policy - ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist created" \
    || logger -p 2 -st "${ALIAS}" "Create Policy - ***Error*** Failed to create ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist"
  fi
  if [[ ! -f ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Create Policy - Creating ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP"
    touch -a ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP \
    && chmod 666 ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP \
    && logger -p 4 -st "${ALIAS}" "Create Policy - ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP created" \
    || logger -p 2 -st "${ALIAS}" "Create Policy - ***Error*** Failed to create ${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP"
  fi
  # Adding Policy to Config File
  if [[ -z "$(awk -F "|" '/^'${CREATEPOLICYNAME}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Create Policy - Adding ${CREATEPOLICYNAME} to ${CONFIGFILE}"
    echo -e "${CREATEPOLICYNAME}|${POLICYDIR}/policy_${CREATEPOLICYNAME}_domainlist|${POLICYDIR}/policy_${CREATEPOLICYNAME}_domaintoIP|${CREATEPOLICYINTERFACE}|${SETVERBOSELOGGING}|${SETPRIVATEIPS}|${SETADDCNAMES}" >> ${CONFIGFILE} \
    && logger -p 4 -st "${ALIAS}" "Create Policy - Added ${CREATEPOLICYNAME} to ${CONFIGFILE}" \
    || logger -p 2 -st "${ALIAS}" "Create Policy - ***Error*** Failed to add ${CREATEPOLICYNAME} to ${CONFIGFILE}"
  fi
fi
return
}

# Add ASN
addasn ()
{
if [[ "${mode}" == "addasn" ]] &>/dev/null;then
  if [[ -z "${ASN}" ]] &>/dev/null;then
    # User Input for ASN
    while true;do  
      read -r -p "Enter ASN:" NEWASN
        # Convert input to upper case
        NEWASN="$(echo ${NEWASN} | awk '{print toupper($0)}')"
	    # Check ASN
        if [[ -n "$(echo ${NEWASN} | grep -oE "(AS[0-9]+)")" ]] &>/dev/null;then
          ASN=${NEWASN}
          break
        else
          echo -e "${RED}***Enter a valid ASN*** Use the following format: AS[0-9]${NOCOLOR}"
		  continue
        fi
    done
  else
    # Convert input to upper case
    ASN="$(echo ${ASN} | awk '{print toupper($0)}')"
	# Check ASN
    if [[ -z "$(echo ${ASN} | grep -oE "(AS[0-9]+)")" ]] &>/dev/null;then
      echo -e "${RED}***Enter a valid ASN*** Use the following format: AS[0-9]${NOCOLOR}"
      return
    fi
  fi

  # Generate Interfaces
  generateinterfacelist || return

  echo -e "Interfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "${INTERFACE}"
  done
  # User Input for Interface
  while true;do  
    read -r -p "Select an Interface for this ASN: " NEWASNINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [[ "${NEWASNINTERFACE}" == "${INTERFACE}" ]] &>/dev/null;then
        ADDASNINTERFACE="${NEWASNINTERFACE}"
        break 2
      elif [[ -n "$(echo "${INTERFACES}" | grep -w "${NEWASNINTERFACE}")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Interface***${NOCOLOR}"
        break 1
      fi
    done
  done

  # Create ASN File
  if [[ ! -f ${ASNFILE} ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Add ASN - Creating ${ASNFILE}"
    touch -a ${ASNFILE} \
    && chmod 666 ${ASNFILE} \
    && logger -p 4 -st "${ALIAS}" "Add ASN - ${ASNFILE} created" \
    || { logger -p 2 -st "${ALIAS}" "Add ASN - ***Error*** Failed to create ${ASNFILE}" && return 1 ;}
  fi
  # Adding Policy to Config File
  if [[ -z "$(awk -F "|" '/^'${ASN}'/ {print $1}' ${ASNFILE})" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Add ASN - Adding ${ASN} to ${ASNFILE}"
    echo -e "${ASN}|${ADDASNINTERFACE}" >> ${ASNFILE} \
    && logger -p 4 -st "${ALIAS}" "Add ASN - Added ${ASN} to ${ASNFILE}" \
    || { logger -p 2 -st "${ALIAS}" "Add ASN - ***Error*** Failed to add ${ASN} to ${ASNFILE}" && return 1 ;}
  fi
fi

# Query ASN
queryasn ${ASN}

return
}

# Delete ASN
deleteasn ()
{
# Set Process Priority
setprocesspriority

# Prompt for confirmation
if [[ "${mode}" == "deleteasn" ]] &>/dev/null || [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  if [[ "${ASN}" == "all" ]] &>/dev/null;then
    [[ "${mode}" != "uninstall" ]] &>/dev/null && read -n 1 -s -r -p "Press any key to continue to delete all ASNs"
    ASNS="$(awk -F"|" '{print $1}' ${ASNFILE})"
  elif [[ "${ASN}" == "$(awk -F "|" '/^'${ASN}'/ {print $1}' ${ASNFILE})" ]] &>/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to delete ASN: ${ASN}"
    ASNS=${ASN}
  else
    echo -e "${RED}Policy: ${ASN} not found${NOCOLOR}"
    return
  fi
  for ASN in ${ASNS};do
    # Determine Domain Policy Files and Interface and Route Table for IP Routes to delete.
    INTERFACE="$(awk -F "|" '/^'${ASN}'/ {print $2}' ${ASNFILE})"
    routingdirector || return

    # Delete IP FWMark Rules
    deleteipmarkrules
  
   # Delete IPv6
    # Delete IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${ASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${ASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${ASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${ASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "'${IPSETPREFIX}'-'${ASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${ASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IPSET
    if [[ -n "$(ipset list ${IPSETPREFIX}-${ASN}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IPv6 IPSET for ${ASN}"
      ipset destroy ${IPSETPREFIX}-${ASN}-v6 \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IPv6 IPSET for ${ASN}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IPv6 IPSET for ${ASN}"
    fi
    # Delete saved IPv6 IPSET
    if [[ -f "${POLICYDIR}/asn_${ASN}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IPv6 IPSET saved file for ${ASN}"
      rm -f ${POLICYDIR}/asn_${ASN}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IPv6 IPSET saved file for ${ASN}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IPv6 IPSET saved file for ${ASN}"
    fi
	
    # Delete IPv4
    # Delete IPv4 IPTables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${ASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 FWMark: ${FWMARK}"
      iptables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${ASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${ASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 FWMark: ${FWMARK}"
      iptables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${ASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "'${IPSETPREFIX}'-'${ASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IPTables rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
      iptables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${ASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IPTables rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IPTables rule for IPSET: ${IPSETPREFIX}-${ASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPSET
    if [[ -n "$(ipset list ${IPSETPREFIX}-${ASN}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Creating IPv4 IPSET for ${ASN}"
      ipset destroy ${IPSETPREFIX}-${ASN}-v4 \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IPv4 IPSET for ${ASN}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IPv4 IPSET for ${ASN}"
    fi
    # Delete saved IPv4 IPSET
    if [[ -f "${POLICYDIR}/asn_${ASN}-v4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete ASN - Deleting IPv4 IPSET saved file for ${ASN}"
      rm -f ${POLICYDIR}/asn_${ASN}-v4.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete ASN - Deleted IPv4 IPSET saved file for ${ASN}" \
      || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete IPv4 IPSET saved file for ${ASN}"
    fi
	
    # Delete ASN from ASN File
    logger -p 5 -st "${ALIAS}" "Delete ASN - Deleting ${ASN}"
    sed -i "\:"^${ASN}"|:d" ${ASNFILE} \
    && logger -p 4 -st "${ALIAS}" "Delete ASN - Deleted ${ASN}" \
    || logger -p 2 -st "${ALIAS}" "Delete ASN - ***Error*** Failed to delete ${ASN}"
  done
fi
  
unset ASN

return
}

# Show Policy
showpolicy ()
{
if [[ "${POLICY}" == "all" ]] &>/dev/null;then
  [[ -z "${policiesnum+x}" ]] &>/dev/null && policiesnum=""
  policies="all $(awk -F "|" '{print $1}' ${CONFIGFILE})"
  policynum="1"
  for policy in ${policies};do
    if [[ "${policy}" == "all" ]] &>/dev/null;then
      echo -e "${BOLD}${policynum}:${NOCOLOR} (All Policies)"
    else
      echo -e "${BOLD}${policynum}:${NOCOLOR} ${policy}"
    fi
	policiesnum="${policiesnum} ${policynum}|${policy}"
    policynum="$((${policynum}+1))"
  done
  unset policynum
  return
elif [[ "${POLICY}" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
  echo -e "${BOLD}Policy Name:${NOCOLOR} $(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})"
  echo -e "${BOLD}Interface:${NOCOLOR} $(awk -F "|" '/^'${POLICY}'/ {print $4}' ${CONFIGFILE})"
  if [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=1" ]] &>/dev/null;then
    echo -e "${BOLD}Verbose Logging:${NOCOLOR} Enabled"
  elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=0" ]] &>/dev/null;then
    echo -e "${BOLD}Verbose Logging:${NOCOLOR} Disabled"
  elif [[ -z "$(awk -F "|" '/^'${POLICY}'/ {print $5}' ${CONFIGFILE})" ]] &>/dev/null;then
    echo -e "${BOLD}Verbose Logging:${NOCOLOR} Not Configured"
  fi
  if [[ "$(awk -F "|" '/^'${POLICY}'/ {print $6}' ${CONFIGFILE})" == "PRIVATEIPS=1" ]] &>/dev/null;then
    echo -e "${BOLD}Private IP Addresses:${NOCOLOR} Enabled"
  elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $6}' ${CONFIGFILE})" == "PRIVATEIPS=0" ]] &>/dev/null;then
    echo -e "${BOLD}Private IP Addresses:${NOCOLOR} Disabled"
  elif [[ -z "$(awk -F "|" '/^'${POLICY}'/ {print $6}' ${CONFIGFILE})" ]] &>/dev/null;then
    echo -e "${BOLD}Private IP Addresses:${NOCOLOR} Not Configured"
  fi
  if [[ "$(awk -F "|" '/^'${POLICY}'/ {print $7}' ${CONFIGFILE})" == "ADDCNAMES=1" ]] &>/dev/null;then
    echo -e "${BOLD}Add CNAMES:${NOCOLOR} Enabled"
  elif [[ "$(awk -F "|" '/^'${POLICY}'/ {print $7}' ${CONFIGFILE})" == "ADDCNAMES=0" ]] &>/dev/null;then
    echo -e "${BOLD}Add CNAMES:${NOCOLOR} Disabled"
  elif [[ -z "$(awk -F "|" '/^'${POLICY}'/ {print $7}' ${CONFIGFILE})" ]] &>/dev/null;then
    echo -e "${BOLD}Add CNAMES:${NOCOLOR} Not Configured"
  fi
  DOMAINS="$(cat ${POLICYDIR}/policy_${POLICY}_domainlist | sort -u)"


  echo -e "${BOLD}Domains:${NOCOLOR}"
  for DOMAIN in ${DOMAINS};do
    echo -e "${DOMAIN}"
  done
  return
else
  echo -e "${RED}Policy: ${POLICY} not found${NOCOLOR}"
  return
fi
return
}

# Show ASN
showasn ()
{
if [[ "${ASN}" == "all" ]] &>/dev/null;then
  [[ -z "${asnsnum+x}" ]] &>/dev/null && asnsnum=""
  asns="all $(awk -F "|" '{print $1}' ${ASNFILE})"
  asnnum="1"
  for asn in ${asns};do
    if [[ "${asn}" == "all" ]] &>/dev/null;then
      echo -e "${BOLD}${asnnum}:${NOCOLOR} (All ASNs)"
    else
      echo -e "${BOLD}${asnnum}:${NOCOLOR} ${asn}"
    fi
	asnsnum="${asnsnum} ${asnnum}|${asn}"
    asnnum="$((${asnnum}+1))"
  done
  unset asnnum
  return
elif [[ "${ASN}" == "$(awk -F "|" '/^'${ASN}'/ {print $1}' ${ASNFILE})" ]] &>/dev/null;then
  echo -e "${BOLD}ASN:${NOCOLOR} $(awk -F "|" '/^'${ASN}'/ {print $1}' ${ASNFILE})"
  echo -e "${BOLD}Interface:${NOCOLOR} $(awk -F "|" '/^'${ASN}'/ {print $2}' ${ASNFILE})"
  if [[ -f "/tmp/${ASN}_query.tmp" ]] &>/dev/null;then
    echo -e "${BOLD}Status: ${NOCOLOR}${YELLOW}Querying${NOCOLOR}"
  elif [[ ! -f "/tmp/${ASN}_query.tmp" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${ASN}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${ASN}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
    echo -e "${BOLD}Status: ${NOCOLOR}${RED}Inactive${NOCOLOR}"
  else
    echo -e "${BOLD}Status: ${NOCOLOR}${GREEN}Active${NOCOLOR}"
  fi
  return
else
  echo -e "${RED}ASN: ${ASN} not found${NOCOLOR}"
  return
fi
return
}

# Query ASN
queryasn ()
{
# Set start timer for processing time
asnstart="$(date +%s)"

# Check if Domain VPN Routing is enabled
checkscriptstatus || return

# Check Alias
checkalias || return

# Boot Delay Timer
bootdelaytimer

# Set Process Priority
setprocesspriority

# Check WAN Status
checkwanstatus || return 1

# Generate Query ASN List
if [[ ! -f "${ASNFILE}" ]] &>/dev/null;then
  if [[ "${mode}" == "queryasn" ]] &>/dev/null;then
    logger -p 3 -st "${ALIAS}" "Query ASN - ***No ASNs Detected***"
  fi
  return
elif [[ "${ASN}" == "all" ]] &>/dev/null;then
  QUERYASNS="$(awk -F"|" '{print $1}' ${ASNFILE})"
  if [[ -z "${QUERYASNS}" ]] &>/dev/null;then
    if [[ "${mode}" == "queryasn" ]] &>/dev/null;then
      logger -p 3 -st "${ALIAS}" "Query ASN - ***No ASNs Detected***"
    fi
    return
  fi
elif [[ "${ASN}" == "$(awk -F "|" '/^'${ASN}'/ {print $1}' ${ASNFILE})" ]] &>/dev/null;then
  QUERYASNS="${ASN}"
else
  echo -e "${RED}ASN: ${ASN} not found${NOCOLOR}"
  return
fi

# Check if jq package is installed
if [[ "${JQINSTALLED}" == "0" ]] &>/dev/null;then
  if [[ "${mode}" == "queryasn" ]] &>/dev/null;then
    logger -p 2 -t "${ALIAS}" "Query ASN - ***jq package is not installed from Entware***"
    echo -e "${RED}***jq package is not installed from Entware***${NOCOLOR}"
  else
    logger -p 2 -t "${ALIAS}" "Query ASN - ***jq package is not installed from Entware***"
  fi
  return
fi

# Check for ASN Cache if ASNCACHE is enabled
[[ "${ASNCACHE}" == "1" ]] &>/dev/null && restoreasncache

# Query ASNs
for QUERYASN in ${QUERYASNS};do
  # Get Interface for ASN
  INTERFACE="$(grep -w "${QUERYASN}" "${ASNFILE}" | awk -F"|" '{print $2}')"
  routingdirector || return
  
  # Query ASN for IP Subnets
  if tty >/dev/null 2>&1;then
    printf '\033[K%b\r' "${UNDERLINE}Query ASN: ${QUERYASN}...${NOCOLOR}\n"
  fi

  logger -p 5 -t "${ALIAS}" "Query ASN - Querying ASN: ${QUERYASN}"
  /usr/sbin/curl --connect-timeout 60 --max-time 300 --url "https://api.bgpview.io/asn/${QUERYASN}/prefixes" --ssl-reqd 2>/dev/null | /opt/bin/jq 2>/dev/null > /tmp/${QUERYASN}_query.tmp \
  || { logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to query ASN: ${QUERYASN}" && continue ;}
  
  # Check if IPv6 is enabled and query for IPv6 subnets
  if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
  
    # Query for IPv6 subnets
    ASNIPV6S="$(cat /tmp/${QUERYASN}_query.tmp | /opt/bin/jq ".data.ipv6_prefixes[].prefix" 2>/dev/null | tr -d \" | sort -u)"
	
    # Create IPv6 IPSET
    # Check for saved IPSET if ASNCACHE is enabled
    if [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/asn_${QUERYASN}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Restoring IPv6 IPSET for ${QUERYASN}"
      ipset restore -! <"${POLICYDIR}/asn_${QUERYASN}-v6.ipset" \
      && logger -p 4 -t "${ALIAS}" "Query ASN - Restored IPv6 IPSET for ${QUERYASN}" \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to restore IPv6 IPSET for ${QUERYASN}"
    # Create saved IPv6 IPSET file if IPSET exists and ASNCACHE is enabled
    elif [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/asn_${QUERYASN}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Saving IPv6 IPSET for ${QUERYASN}"
      ipset save ${IPSETPREFIX}-${QUERYASN}-v6 -file ${POLICYDIR}/asn_${QUERYASN}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Query ASN - Saved IPv6 IPSET for ${QUERYASN}" \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to save IPv6 IPSET for ${QUERYASN}"
    # Create new IPv6 IPSET if it does not exist and ASNCACHE is enabled
    elif [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Creating IPv6 IPSET for ${QUERYASN}"
      ipset create ${IPSETPREFIX}-${QUERYASN}-v6 hash:net family inet6 \
      && { saveipv6ipset="1" && logger -p 4 -t "${ALIAS}" "Query ASN - Created IPv6 IPSET for ${QUERYASN}" ;} \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to create IPv6 IPSET for ${QUERYASN}"
    # Create new IPv6 IPSET if it does not exist and ASNCACHE is disabled
    elif [[ "${ASNCACHE}" == "0" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Creating IPv6 IPSET for ${QUERYASN}"
      ipset create ${IPSETPREFIX}-${QUERYASN}-v6 hash:net family inet6 \
      && logger -p 4 -t "${ALIAS}" "Query ASN - Created IPv6 IPSET for ${QUERYASN}" \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to create IPv6 IPSET for ${QUERYASN}"
    fi
	
    # Create IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${QUERYASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Adding IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${QUERYASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Query ASN - Added IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${QUERYASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Adding IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${QUERYASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Query ASN - Added IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "'${IPSETPREFIX}'-'${QUERYASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Adding IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${QUERYASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Query ASN - Added IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
	
    # Add ASN IPv6 Subnets to IPSET
    for ASNIPV6 in ${ASNIPV6S};do
      if tty >/dev/null 2>&1;then
        printf '\033[K%b\r' "${LIGHTCYAN}Processing IPv6 Subnet: ${ASNIPV6}...${NOCOLOR}"
      fi
      # Add to IPv6 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 | grep -wo "${ASNIPV6}")" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Query ASN - Adding ${ASNIPV6} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v6"
        ipset add ${IPSETPREFIX}-${QUERYASN}-v6 ${ASNIPV6} \
        || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add ${ASNIPV6} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v6" \
        && { saveipv6ipset="1" && logger -p 4 -t "${ALIAS}" "Query ASN - Added ${ASNIPV6} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v6" ;}
      elif [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
        break
      fi
    done

    # Cleanup IPv6 IPSET
    if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
      ASNIPV6SIPSET="$(ipset list ${IPSETPREFIX}-${QUERYASN}-v6 | grep -E "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
      for ASNIPV6IPSET in ${ASNIPV6SIPSET};do
	    if [[ -z "$(echo "${ASNIPV6S}" | grep -wo "${ASNIPV6IPSET}")" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Query ASN - Deleting ${ASNIPV6IPSET} from IPSET: ${IPSETPREFIX}-${QUERYASN}-v6"
          ipset del ${IPSETPREFIX}-${QUERYASN}-v6 ${ASNIPV6IPSET} \
          || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to delete ${ASNIPV6IPSET} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v6" \
          && { saveipv6ipset="1" && logger -p 4 -t "${ALIAS}" "Query ASN - Deleted ${ASNIPV6IPSET} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v6" ;}
        fi
      done
    fi
	
    # Save IPv6 IPSET if modified or does not exist if ASNCACHE is enabled
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if { [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ "${saveipv6ipset}" == "1" ]] &>/dev/null ;} || { [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/asn_${QUERYASN}-v6.ipset" ]] &>/dev/null ;};then
      logger -p 5 -t "${ALIAS}" "Query ASN - Saving IPv6 IPSET for ${QUERYASN}"
      ipset save ${IPSETPREFIX}-${QUERYASN}-v6 -file ${POLICYDIR}/asn_${QUERYASN}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Query ASN - Save IPv6 IPSET for ${QUERYASN}" \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to save IPv6 IPSET for ${QUERYASN}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset
  fi
  
  # Query for IPv4 subnets
  ASNIPV4S="$(cat /tmp/${QUERYASN}_query.tmp | /opt/bin/jq ".data.ipv4_prefixes[].prefix" 2>/dev/null | tr -d \" | sort -u)"

  # Create IPv4 IPSET
  # Check for saved IPv4 IPSET if ASNCACHE is enabled
  if [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/asn_${QUERYASN}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query ASN - Restoring IPv4 IPSET for ${QUERYASN}"
    ipset restore -! <"${POLICYDIR}/asn_${QUERYASN}-v4.ipset" \
    && logger -p 4 -t "${ALIAS}" "Query ASN - Restored IPv4 IPSET for ${QUERYASN}" \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to restore IPv4 IPSET for ${QUERYASN}"
  # Create saved IPv4 IPSET file if IPSET exists and ASNCACHE is enabled
  elif [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/asn_${QUERYASN}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query ASN - Saving IPv4 IPSET for ${QUERYASN}"
    ipset save ${IPSETPREFIX}-${QUERYASN}-v4 -file ${POLICYDIR}/asn_${QUERYASN}-v4.ipset \
    && logger -p 4 -t "${ALIAS}" "Query ASN - Saved IPv4 IPSET for ${QUERYASN}" \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to save IPv4 IPSET for ${QUERYASN}"
  # Create new IPv4 IPSET if it does not exist and ASNCACHE is enabled
  elif [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query ASN - Creating IPv4 IPSET for ${QUERYASN}"
    ipset create ${IPSETPREFIX}-${QUERYASN}-v4 hash:net family inet \
    && { saveipv4ipset="1" && logger -p 4 -t "${ALIAS}" "Query ASN - Created IPv4 IPSET for ${QUERYASN}" ;} \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to create IPv4 IPSET for ${QUERYASN}"
  # Create new IPv4 IPSET if it does not exist and ASNCACHE is disabled
  elif [[ "${ASNCACHE}" == "0" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query ASN - Creating IPv4 IPSET for ${QUERYASN}"
    ipset create ${IPSETPREFIX}-${QUERYASN}-v4 hash:net family inet \
    && logger -p 4 -t "${ALIAS}" "Query ASN - Created IPv4 IPSET for ${QUERYASN}" \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to create IPv4 IPSET for ${QUERYASN}"
  fi
  
  # Create IPv4 IPTables OUTPUT Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${QUERYASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query ASN - Adding IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${QUERYASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Query ASN - Added IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables PREROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${QUERYASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query ASN - Adding IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${QUERYASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Query ASN - Added IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables POSTROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "'${IPSETPREFIX}'-'${QUERYASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query ASN - Adding IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    iptables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${QUERYASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Query ASN - Added IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
  fi
  
  # Add ASN IPv4 Subnets to IPSET
  for ASNIPV4 in ${ASNIPV4S};do
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' "${LIGHTCYAN}Processing IPv4 Subnet: ${ASNIPV4}...${NOCOLOR}"
    fi
    if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 | grep -wo "${ASNIPV4}")" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query ASN - Adding ${ASNIPV4} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v4"
      ipset add ${IPSETPREFIX}-${QUERYASN}-v4 ${ASNIPV4} \
      || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to add ${ASNIPV4} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v4" \
      && { saveipv4ipset="1" && logger -p 4 -t "${ALIAS}" "Query ASN - Added ${ASNIPV4} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v4" ;}
    elif [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
      break
    fi
  done
  
  # Cleanup IPv4 IPSET
  if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
    ASNIPV4SIPSET="$(ipset list ${IPSETPREFIX}-${QUERYASN}-v4 | grep -E "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))")"
    for ASNIPV4IPSET in ${ASNIPV4SIPSET};do
	  if [[ -z "$(echo "${ASNIPV4S}" | grep -wo "${ASNIPV4IPSET}")" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Query ASN - Deleting ${ASNIPV4IPSET} from IPSET: ${IPSETPREFIX}-${QUERYASN}-v4"
        ipset del ${IPSETPREFIX}-${QUERYASN}-v4 ${ASNIPV4IPSET} \
        || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to delete ${ASNIPV4IPSET} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v4" \
        && { saveipv4ipset="1" && logger -p 4 -t "${ALIAS}" "Query ASN - Deleted ${ASNIPV4IPSET} to IPSET: ${IPSETPREFIX}-${QUERYASN}-v4" ;}
      fi
    done
  fi
  
  # Save IPv4 IPSET if modified or does not exist if ASNCACHE is enabled
  [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
  if { [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ "${saveipv4ipset}" == "1" ]] &>/dev/null ;} || { [[ "${ASNCACHE}" == "1" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/asn_${QUERYASN}-v4.ipset" ]] &>/dev/null ;};then
    logger -p 5 -t "${ALIAS}" "Query ASN - Saving IPv4 IPSET for ${QUERYASN}"
    ipset save ${IPSETPREFIX}-${QUERYASN}-v4 -file ${POLICYDIR}/asn_${QUERYASN}-v4.ipset \
    && logger -p 4 -t "${ALIAS}" "Query ASN - Save IPv4 IPSET for ${QUERYASN}" \
    || logger -p 2 -st "${ALIAS}" "Query ASN - ***Error*** Failed to save IPv4 IPSET for ${QUERYASN}"
  fi
  [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset
  
  # Create IP FWMark Rules
  createipmarkrules
  
  # Delete Temporary Output File
  if [[ -f "/tmp/${QUERYASN}_query.tmp" ]] &>/dev/null;then
    rm -rf /tmp/${QUERYASN}_query.tmp &>/dev/null
  fi
  
done

# Parse new line
if tty >/dev/null 2>&1;then
  printf '\033[K'
fi

# Process Query execution time
asnend="$(date +%s)"
processtime="$((${asnend}-${asnstart}))"
logger -p 5 -st "${ALIAS}" "Query ASN - Processing Time: ${processtime} seconds"

# Unset Variables
unset ASNIPV4S ASNIPV6S ASNIPV4SIPSET ASNIPV6SIPSET processtime asnend asnstart

return
}

# Edit Policy
editpolicy ()
{
# Prompt for confirmation to edit policy
if [[ "${mode}" == "editpolicy" ]] &>/dev/null;then
  if [[ "${POLICY}" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to edit Policy: ${POLICY}"
    EDITPOLICY="${POLICY}"
  else
    echo -e "${RED}Policy: ${POLICY} not found${NOCOLOR}"
    return
  fi

  # Generate Interfaces
  generateinterfacelist || return

  # Display available interfaces
  echo -e "\nInterfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "${INTERFACE}"
  done

  # User input to select an interface
  while true;do  
    echo -e "Current Interface: $(awk -F "|" '/^'${EDITPOLICY}'/ {print $4}' ${CONFIGFILE})"
    read -r -p "Select an Interface for this Policy: " EDITPOLICYINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [[ "${EDITPOLICYINTERFACE}" == "${INTERFACE}" ]] &>/dev/null;then
        NEWPOLICYINTERFACE=${EDITPOLICYINTERFACE}
        break 2
      elif [[ -n "$(echo "${INTERFACES}" | grep -w "${EDITPOLICYINTERFACE}")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Interface***${NOCOLOR}"
        echo -e "Interfaces: \r\n${INTERFACES}"
        break 1
      fi
    done
  done

  # Enable Verbose Logging
  while true;do  
    read -r -p "Enable verbose logging for this policy? ***Enter Y for Yes or N for No*** " yn
      case ${yn} in
        [Yy]* ) SETVERBOSELOGGING="VERBOSELOGGING=1"; break;;
        [Nn]* ) SETVERBOSELOGGING="VERBOSELOGGING=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Enable Private IP Addresses
  while true;do  
    read -r -p "Enable Private IP Addresses for this policy? ***Enter Y for Yes or N for No*** " yn
      case ${yn} in
        [Yy]* ) SETPRIVATEIPS="PRIVATEIPS=1"; break;;
        [Nn]* ) SETPRIVATEIPS="PRIVATEIPS=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done
  
  # Enable Add CNAMES
  while true;do  
    read -r -p "Enable adding CNAMES for this policy? ***Enter Y for Yes or N for No*** " yn
      case ${yn} in
        [Yy]* ) SETADDCNAMES="ADDCNAMES=1"; break;;
        [Nn]* ) SETADDCNAMES="ADDCNAMES=0"; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

  # Set Process Priority
  setprocesspriority
  
  # Editing Policy in Config File
  if [[ -n "$(awk -F "|" '/^'${EDITPOLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Edit Policy - Modifying ${EDITPOLICY} in ${CONFIGFILE}"
    OLDINTERFACE="$(awk -F "|" '/^'${EDITPOLICY}'/ {print $4}' ${CONFIGFILE})"
    sed -i "\:"${EDITPOLICY}":d" "${CONFIGFILE}"
    echo -e "${EDITPOLICY}|${POLICYDIR}/policy_${EDITPOLICY}_domainlist|${POLICYDIR}/policy_${EDITPOLICY}_domaintoIP|${NEWPOLICYINTERFACE}|${SETVERBOSELOGGING}|${SETPRIVATEIPS}|${SETADDCNAMES}" >> ${CONFIGFILE} \
    && logger -p 4 -st "${ALIAS}" "Edit Policy - Modified ${EDITPOLICY} in ${CONFIGFILE}" \
    || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to modify ${EDITPOLICY} in ${CONFIGFILE}"
  else
    echo -e "${YELLOW}${EDITPOLICY} not found in ${CONFIGFILE}...${NOCOLOR}"
    logger -p 3 -t "${ALIAS}" "Edit Policy - ${EDITPOLICY} not found in ${CONFIGFILE}"
  fi
  
  # Check if routes need to be modified
  if [[ "${NEWPOLICYINTERFACE}" != "${OLDINTERFACE}" ]] &>/dev/null;then

    # Create IPv4 and IPv6 Arrays from Policy File. 
    IPV6S="$(grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "${POLICYDIR}/policy_${EDITPOLICY}_domaintoIP" | sort -u)"
    IPV4S="$(grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" "${POLICYDIR}/policy_${EDITPOLICY}_domaintoIP" | sort -u)"

    # Create IPv6 IPSET
    if [[ -z "$(ipset list ${IPSETPREFIX}-${EDITPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Edit Policy - Creating IPv6 IPSET for ${EDITPOLICY}"
      ipset create ${IPSETPREFIX}-${EDITPOLICY}-v6 hash:ip family inet6 comment \
      && logger -p 4 -st "${ALIAS}" "Edit Policy - Created IPv6 IPSET for ${EDITPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to create IPv6 IPSET for ${EDITPOLICY}"
    fi
    # Create IPv4 IPSET
    if [[ -z "$(ipset list ${IPSETPREFIX}-${EDITPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Edit Policy - Creating IPv4 IPSET for ${EDITPOLICY}"
      ipset create ${IPSETPREFIX}-${EDITPOLICY}-v4 hash:ip family inet comment \
      && logger -p 4 -st "${ALIAS}" "Edit Policy - Created IPv4 IPSET for ${EDITPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to create IPv4 IPSET for ${EDITPOLICY}"
    fi

    # Array for old and new interfaces
    INTERFACES="${NEWPOLICYINTERFACE} ${OLDINTERFACE}"

    # Generate old and new values for each interface
    for INTERFACE in ${INTERFACES};do
      routingdirector || return
      if [[ "${INTERFACE}" == "${OLDINTERFACE}" ]] &>/dev/null;then
        # Delete IP FWMark Rules
        deleteipmarkrules

        OLDROUTETABLE="${ROUTETABLE}"
        OLDRGW="${RGW}"
        OLDPRIORITY="${PRIORITY}"
        OLDIFNAME="${IFNAME}"
        OLDFWMARK="${FWMARK}"
        OLDMASK="${MASK}"
        OLDIPV6ADDR="${IPV6ADDR}"
        OLDIPV6VPNGW="${IPV6VPNGW}"
        OLDIPV6ROUTETABLE="${IPV6ROUTETABLE}"
        OLDSTATE="${STATE}"
		
        # Delete Old IPv6
        if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
          # Delete Old IPv6 IP6Tables OUTPUT Rule
          if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}"
            ip6tables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit Policy - Deleted IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}"
          fi
          # Delete Old IPv6 IP6Tables PREROUTING Rule
          if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}"
            ip6tables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit Policy - Deleted IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}"
          fi
          # Delete Old IPv6 IP6Tables POSTROUTING Rule
          if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${OLDIFNAME}'" && $10 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}"
            ip6tables -t mangle -D POSTROUTING -o ${OLDIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit Policy - Deleted IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${OLDFWMARK}"
          fi
        fi
		
        # Delete Old IPv4
        # Delete Old IPv4 IPTables OUTPUT Rule
        if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}"
          iptables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit Policy - Deleted IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}"
        fi
        # Delete Old IPv4 IPTables PREROUTING Rule
        if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}"
          iptables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit Policy - Deleted IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}"
        fi
        # Delete Old IPv4 IPTables POSTROUTING Rule
        if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${OLDIFNAME}'" && $11 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}"
          iptables -t mangle -D POSTROUTING -o ${OLDIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit Policy - Deleted IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${OLDFWMARK}"
        fi

        continue
      elif [[ "${INTERFACE}" == "${NEWPOLICYINTERFACE}" ]] &>/dev/null;then
        # Create IP FWMark Rules
        createipmarkrules

        NEWROUTETABLE="${ROUTETABLE}"
        NEWRGW="${RGW}"
        NEWPRIORITY="${PRIORITY}"
        NEWIFNAME="${IFNAME}"
        NEWFWMARK="${FWMARK}"
        NEWMASK="${MASK}"
        NEWIPV6ADDR="${IPV6ADDR}"
        NEWIPV6VPNGW="${IPV6VPNGW}"
        NEWIPV6ROUTETABLE="${IPV6ROUTETABLE}"
        NEWSTATE="${STATE}"
        # Recreate IPv6
        if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
          # Recreate IPv6 IP6Tables OUTPUT Rule
          if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Adding IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}"
            ip6tables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit Policy - Added IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}"
          fi
          # Recreate IPv6 IP6Tables PREROUTING Rule
          if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Adding IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}"
            ip6tables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit Policy - Added IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}"
          fi
          # Recreate IPv6 IP6Tables POSTROUTING Rule
          if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${NEWIFNAME}'" && $10 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Adding IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}"
            ip6tables -t mangle -A POSTROUTING -o ${NEWIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit Policy - Added IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v6 FWMark: ${NEWFWMARK}"
          fi
        fi

        # Recreate IPv4
        # Recreate IPv4 IPTables OUTPUT Rule
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Adding IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}"
          iptables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit Policy - Added IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}"
        fi
        # Recreate IPv4 IPTables PREROUTING Rule
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Adding IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}"
          iptables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit Policy - Added IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}"
        fi
        # Recreate IPv4 IPTables POSTROUTING Rule
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${NEWIFNAME}'" && $11 == "'${IPSETPREFIX}'-'${EDITPOLICY}'-v4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Adding IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}"
          iptables -t mangle -A POSTROUTING -o ${NEWIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITPOLICY}-v4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit Policy - Added IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITPOLICY}-v4 FWMark: ${NEWFWMARK}"
        fi

        continue
      fi
    done

    # Recreate IPv6
    if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
      # Recreate IPv6 Routes
      for IPV6 in ${IPV6S}; do
        # Delete old IPv6 Route
        if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
          ${ipbinpath}ip -6 route del ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
          && logger -p 4 -st "${ALIAS}" "Edit Policy - Route deleted for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
        fi
        # Create IPv6 Routes if necessary due to lack of FWMark Rules
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -z "${NEWFWMARK}" ]] &>/dev/null && { [[ -z "${IPV6ADDR}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip -6 route show default dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null ;};then
          # Check for IPv6 prefix error and create new IPv6 routes
          if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} 2>&1 | grep -w "Error: inet6 prefix is expected rather than \"${IPV6}\".")" ]] &>/dev/null;then
            if [[ -z "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null;then
              logger -p 5 -t "${ALIAS}" "Edit Policy - Adding route for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              ${ipbinpath}ip -6 route add ${IPV6}:: dev ${IFNAME} table ${NEWIPV6ROUTETABLE} &>/dev/null \
              || rc="$?" \
              && { rc="$?" && logger -p 4 -t "${ALIAS}" "Edit Policy - Route added for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}" ;}
              # Generate Error Log
              if [[ "${rc+x}" ]] &>/dev/null;then
                continue
              elif [[ "${rc}" == "2" ]] &>/dev/null;then
                logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Route already exists for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              elif [[ "${rc}" != "0" ]] &>/dev/null;then
                logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Unable to add route for ${IPV6}:: dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              fi
            fi
          else
            if [[ -z "$(${ipbinpath}ip -6 route list ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE})" ]] &>/dev/null;then
              logger -p 5 -t "${ALIAS}" "Edit Policy - Adding route for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              ${ipbinpath}ip -6 route add ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE} &>/dev/null \
              || rc="$?" \
              && { rc="$?" && logger -p 4 -t "${ALIAS}" "Edit Policy - Route added for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}" ;}
              # Generate Error Log
              if [[ "${rc+x}" ]] &>/dev/null;then
                continue
              elif [[ "${rc}" == "2" ]] &>/dev/null;then
                logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Route already exists for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              elif [[ "${rc}" != "0" ]] &>/dev/null;then
                logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Unable to add route for ${IPV6} dev ${NEWIFNAME} table ${NEWIPV6ROUTETABLE}"
              fi
            fi
          fi
        fi
      done

      # Save IPv6 IPSET if save file does not exist
      if [[ ! -f "${POLICYDIR}/policy_${EDITPOLICY}-v6.ipset" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Edit Policy - Saving IPv6 IPSET for ${EDITPOLICY}"
        ipset save ${IPSETPREFIX}-${EDITPOLICY}-v6 -file ${POLICYDIR}/policy_${EDITPOLICY}-v6.ipset \
        && logger -p 4 -st "${ALIAS}" "Edit Policy - Save IPv6 IPSET for ${EDITPOLICY}" \
        || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to save IPv6 IPSET for ${EDITPOLICY}"
      fi
    fi

    # Recreate IPv4
    # Recreate IPv4 Routes and IPv4 Rules
    for IPV4 in ${IPV4S}; do
      if [[ "${OLDRGW}" == "0" ]] &>/dev/null;then
        # Delete old IPv4 routes
        if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE})" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting route for ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE}"
          ${ipbinpath}ip route del ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE} &>/dev/null \
          && logger -p 4 -t "${ALIAS}" "Edit Policy - Route deleted for ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete route for ${IPV4} dev ${OLDIFNAME} table ${OLDROUTETABLE}"
        fi
      # Delete old IPv4 rules
      elif [[ "${OLDRGW}" != "0" ]] &>/dev/null;then
        if [[ -n "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${OLDROUTETABLE} priority ${OLDPRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${OLDPRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${OLDROUTETABLE}'") {print}')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit Policy - Deleting IP Rule for ${IPV4} table ${OLDROUTETABLE} priority ${OLDPRIORITY}"
          ${ipbinpath}ip rule del from all to ${IPV4} table ${OLDROUTETABLE} priority ${OLDPRIORITY} &>/dev/null \
          && logger -p 4 -t "${ALIAS}" "Edit Policy - Deleted IP Rule for ${IPV4} table ${OLDROUTETABLE} priority ${OLDPRIORITY}" \
          || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to delete IP Rule for ${IPV4} table ${OLDROUTETABLE} priority ${OLDPRIORITY}"
        fi
      fi
      # Create new IPv4 routes and IPv4 rules if necessary
      if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -z "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip route show default table ${NEWROUTETABLE})" ]] &>/dev/null;then
        # Create new IPv4 routes
        if [[ "${NEWRGW}" == "0" ]] &>/dev/null;then
          if [[ -z "$(${ipbinpath}ip route list ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE})" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Adding route for ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE}"
            ${ipbinpath}ip route add ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE} &>/dev/null \
            && logger -p 4 -t "${ALIAS}" "Edit Policy - Route added for ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add route for ${IPV4} dev ${NEWIFNAME} table ${NEWROUTETABLE}"
          fi
        # Create new IPv4 rules
        elif [[ "${NEWRGW}" != "0" ]] &>/dev/null;then
          if [[ -z "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${NEWROUTETABLE} priority ${NEWPRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${NEWPRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${NEWROUTETABLE}'") {print}')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit Policy - Adding IP Rule for ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY}"
            ${ipbinpath}ip rule add from all to ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY} &>/dev/null \
            && logger -p 4 -t "${ALIAS}" "Edit Policy - Added IP Rule for ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY}" \
            || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to add IP Rule for ${IPV4} table ${NEWROUTETABLE} priority ${NEWPRIORITY}"
          fi
        fi
      fi
    done
    # Save IPv4 IPSET if save file does not exist
    if [[ ! -f "${POLICYDIR}/policy_${EDITPOLICY}-v4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Edit Policy - Saving IPv4 IPSET for ${EDITPOLICY}"
      ipset save ${IPSETPREFIX}-${EDITPOLICY}-v4 -file ${POLICYDIR}/policy_${EDITPOLICY}-v4.ipset \
      && logger -p 4 -st "${ALIAS}" "Edit Policy - Save IPv4 IPSET for ${EDITPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Edit Policy - ***Error*** Failed to save IPv4 IPSET for ${EDITPOLICY}"
    fi
  fi
fi

return
}

# Edit ASN
editasn ()
{
# Prompt for confirmation to edit policy
if [[ "${mode}" == "editasn" ]] &>/dev/null;then
  if [[ "${ASN}" == "$(awk -F "|" '/^'${ASN}'/ {print $1}' ${ASNFILE})" ]] &>/dev/null;then
    read -n 1 -s -r -p "Press any key to continue to edit ASN: ${ASN}"
    EDITASN="${ASN}"
  else
    echo -e "${RED}${ASN} not found${NOCOLOR}"
    return
  fi

  # Generate Interfaces
  generateinterfacelist || return

  # Display available interfaces
  echo -e "\nInterfaces:"
  for INTERFACE in ${INTERFACES};do
    echo -e "${INTERFACE}"
  done

  # User input to select an interface
  while true;do  
    echo -e "Current Interface: $(awk -F "|" '/^'${EDITASN}'/ {print $2}' ${ASNFILE})"
    read -r -p "Select an Interface for this Policy: " EDITASNINTERFACE
    for INTERFACE in ${INTERFACES};do
      if [[ "${EDITASNINTERFACE}" == "${INTERFACE}" ]] &>/dev/null;then
        NEWASNINTERFACE=${EDITASNINTERFACE}
        break 2
      elif [[ -n "$(echo "${INTERFACES}" | grep -w "${EDITASNINTERFACE}")" ]] &>/dev/null;then
        continue
      else
        echo -e "${RED}***Enter a valid Interface***${NOCOLOR}"
        echo -e "Interfaces: \r\n${INTERFACES}"
        break 1
      fi
    done
  done
  
  # Set Process Priority
  setprocesspriority
  
  # Editing Policy in Config File
  if [[ -n "$(awk -F "|" '/^'${EDITASN}'/ {print $1}' ${ASNFILE})" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Edit ASN - Modifying ${EDITASN} in ${ASNFILE}"
    OLDINTERFACE="$(awk -F "|" '/^'${EDITASN}'/ {print $2}' ${ASNFILE})"
    sed -i "\:"${EDITASN}":d" "${ASNFILE}"
    echo -e "${EDITASN}|${NEWASNINTERFACE}" >> ${ASNFILE} \
    && logger -p 4 -st "${ALIAS}" "Edit ASN - Modified ${EDITASN} in ${ASNFILE}" \
    || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to modify ${EDITASN} in ${ASNFILE}"
  else
    echo -e "${YELLOW}${EDITASN} not found in ${ASNFILE}...${NOCOLOR}"
    logger -p 3 -t "${ALIAS}" "Edit ASN - ${EDITASN} not found in ${ASNFILE}"
  fi
  
  # Check if routes need to be modified
  if [[ "${NEWASNINTERFACE}" != "${OLDINTERFACE}" ]] &>/dev/null;then

    # Array for old and new interfaces
    INTERFACES="${NEWASNINTERFACE} ${OLDINTERFACE}"

    # Generate old and new values for each interface
    for INTERFACE in ${INTERFACES};do
      routingdirector || return
      if [[ "${INTERFACE}" == "${OLDINTERFACE}" ]] &>/dev/null;then
        # Delete IP FWMark Rules
        deleteipmarkrules

        OLDROUTETABLE="${ROUTETABLE}"
        OLDRGW="${RGW}"
        OLDPRIORITY="${PRIORITY}"
        OLDIFNAME="${IFNAME}"
        OLDFWMARK="${FWMARK}"
        OLDMASK="${MASK}"
        OLDIPV6ADDR="${IPV6ADDR}"
        OLDIPV6VPNGW="${IPV6VPNGW}"
        OLDIPV6ROUTETABLE="${IPV6ROUTETABLE}"
        OLDSTATE="${STATE}"

        # Delete Old IPv6
        if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
          # Delete Old IPv6 IP6Tables OUTPUT Rule
          if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITASN}'-v6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit ASN - Deleting IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}"
            ip6tables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITASN}-v6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit ASN - Deleted IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to delete IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}"
          fi
          # Delete Old IPv6 IP6Tables PREROUTING Rule
          if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITASN}'-v6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit ASN - Deleting IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}"
            ip6tables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITASN}-v6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit ASN - Deleted IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to delete IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}"
          fi
          # Delete Old IPv6 IP6Tables POSTROUTING Rule
          if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${OLDIFNAME}'" && $10 == "'${IPSETPREFIX}'-'${EDITASN}'-v6" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit ASN - Deleting IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}"
            ip6tables -t mangle -D POSTROUTING -o ${OLDIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITASN}-v6 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit ASN - Deleted IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to delete IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${OLDFWMARK}"
          fi
        fi

        # Delete Old IPv4
        # Delete Old IPv4 IPTables OUTPUT Rule
        if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITASN}'-v4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit ASN - Deleting IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}"
          iptables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITASN}-v4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit ASN - Deleted IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to delete IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}"
        fi
        # Delete Old IPv4 IPTables PREROUTING Rule
        if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITASN}'-v4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit ASN - Deleting IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}"
          iptables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITASN}-v4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit ASN - Deleted IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to delete IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}"
        fi
        # Delete Old IPv4 IPTables POSTROUTING Rule
        if [[ -n "${OLDFWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${OLDIFNAME}'" && $11 == "'${IPSETPREFIX}'-'${EDITASN}'-v4" && ( $NF == "'${OLDFWMARK}'" || $NF == "'${OLDFWMARK}'/'${OLDMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit ASN - Deleting IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}"
          iptables -t mangle -D POSTROUTING -o ${OLDIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITASN}-v4 dst -j MARK --set-xmark ${OLDFWMARK}/${OLDMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit ASN - Deleted IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to delete IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${OLDFWMARK}"
        fi
        continue
      elif [[ "${INTERFACE}" == "${NEWASNINTERFACE}" ]] &>/dev/null;then
        # Create IP FWMark Rules
        createipmarkrules

        NEWROUTETABLE="${ROUTETABLE}"
        NEWRGW="${RGW}"
        NEWPRIORITY="${PRIORITY}"
        NEWIFNAME="${IFNAME}"
        NEWFWMARK="${FWMARK}"
        NEWMASK="${MASK}"
        NEWIPV6ADDR="${IPV6ADDR}"
        NEWIPV6VPNGW="${IPV6VPNGW}"
        NEWIPV6ROUTETABLE="${IPV6ROUTETABLE}"
        NEWSTATE="${STATE}"

        # Recreate IPv6
        if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
          # Recreate IPv6 IP6Tables OUTPUT Rule
          if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITASN}'-v6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit ASN - Adding IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}"
            ip6tables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITASN}-v6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit ASN - Added IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}"
          fi
          # Recreate IPv6 IP6Tables PREROUTING Rule
          if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${EDITASN}'-v6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit ASN - Adding IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}"
            ip6tables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITASN}-v6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit ASN - Added IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}" \
            || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}"
          fi
          # Recreate IPv6 IP6Tables POSTROUTING Rule
          if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${NEWIFNAME}'" && $10 == "'${IPSETPREFIX}'-'${EDITASN}'-v6" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
            logger -p 5 -t "${ALIAS}" "Edit ASN - Adding IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}"
            ip6tables -t mangle -A POSTROUTING -o ${NEWIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITASN}-v6 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
            && logger -p 4 -st "${ALIAS}" "Edit ASN - Added IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}" \
           || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v6 FWMark: ${NEWFWMARK}"
          fi
		fi

        # Recreate IPv4
        # Recreate IPv4 IPTables OUTPUT Rule
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITASN}'-v4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit ASN - Adding IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}"
          iptables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${EDITASN}-v4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit ASN - Added IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}"
        fi
        # Recreate IPv4 IPTables PREROUTING Rule
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${EDITASN}'-v4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit ASN - Adding IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}"
          iptables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${EDITASN}-v4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit ASN - Added IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}"
        fi
        # Recreate IPv4 IPTables POSTROUTING Rule
        if [[ "${NEWSTATE}" != "0" ]] &>/dev/null && [[ -n "${NEWFWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${NEWIFNAME}'" && $11 == "'${IPSETPREFIX}'-'${EDITASN}'-v4" && ( $NF == "'${NEWFWMARK}'" || $NF == "'${NEWFWMARK}'/'${NEWMASK}'")')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Edit ASN - Adding IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}"
          iptables -t mangle -A POSTROUTING -o ${NEWIFNAME} -m set --match-set ${IPSETPREFIX}-${EDITASN}-v4 dst -j MARK --set-xmark ${NEWFWMARK}/${NEWMASK} \
          && logger -p 4 -st "${ALIAS}" "Edit ASN - Added IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}" \
          || logger -p 2 -st "${ALIAS}" "Edit ASN - ***Error*** Failed to add IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${EDITASN}-v4 FWMark: ${NEWFWMARK}"
        fi
        continue
      fi
    done
  fi
fi

return
}

# Delete Policy
deletepolicy ()
{
# Prompt for confirmation
if [[ "${mode}" == "deletepolicy" ]] &>/dev/null || [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  if [[ "${POLICY}" == "all" ]] &>/dev/null;then
    [[ "${mode}" != "uninstall" ]] &>/dev/null && read -n 1 -s -r -p "Press any key to continue to delete all policies"
    DELETEPOLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
  elif [[ "${POLICY}" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
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

    # Delete IP FWMark Rules
    deleteipmarkrules

    # Delete IPv6
    # Delete IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${DELETEPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${DELETEPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${DELETEPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${DELETEPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "'${IPSETPREFIX}'-'${DELETEPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${DELETEPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv6 IPSET
    if [[ -n "$(ipset list ${IPSETPREFIX}-${DELETEPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IPv6 IPSET for ${DELETEPOLICY}"
      ipset destroy ${IPSETPREFIX}-${DELETEPOLICY}-v6 \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IPv6 IPSET for ${DELETEPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IPv6 IPSET for ${DELETEPOLICY}"
    fi
    # Delete saved IPv6 IPSET
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IPv6 IPSET saved file for ${DELETEPOLICY}"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IPv6 IPSET saved file for ${DELETEPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IPv6 IPSET saved file for ${DELETEPOLICY}"
    fi
    # Delete IPv6 Routes
    for IPV6 in ${IPV6S};do
      if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ${ipbinpath}ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && logger -p 4 -t "${ALIAS}" "Delete Policy - Route deleted for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" \
        || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi
    done

    # Delete IPv4
    # Delete IPv4 IPTables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${DELETEPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 FWMark: ${FWMARK}"
      iptables -t mangle -D OUTPUT -m set --match-set ${IPSETPREFIX}-${DELETEPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${DELETEPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 FWMark: ${FWMARK}"
      iptables -t mangle -D PREROUTING -m set --match-set ${IPSETPREFIX}-${DELETEPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPTables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "'${IPSETPREFIX}'-'${DELETEPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IPTables rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
      iptables -t mangle -D POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${DELETEPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IPTables rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IPTables rule for IPSET: ${IPSETPREFIX}-${DELETEPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
    # Delete IPv4 IPSET
    if [[ -n "$(ipset list ${IPSETPREFIX}-${DELETEPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Creating IPv4 IPSET for ${DELETEPOLICY}"
      ipset destroy ${IPSETPREFIX}-${DELETEPOLICY}-v4 \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IPv4 IPSET for ${DELETEPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IPv4 IPSET for ${DELETEPOLICY}"
    fi
    # Delete saved IPv4 IPSET
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}-v4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IPv4 IPSET saved file for ${DELETEPOLICY}"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}-v4.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IPv4 IPSET saved file for ${DELETEPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IPv4 IPSET saved file for ${DELETEPOLICY}"
    fi

    # Delete IPv4 routes and IP rules
    for IPV4 in ${IPV4S};do
      if [[ "${RGW}" == "0" ]] &>/dev/null;then
        if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
          ${ipbinpath}ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} \
          && logger -p 4 -t "${ALIAS}" "Delete Policy - Route deleted for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" \
          || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
        fi
      elif [[ "${RGW}" != "0" ]] &>/dev/null;then
        if [[ -n "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Delete Policy - Deleting IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
          ${ipbinpath}ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} \
          && logger -p 4 -t "${ALIAS}" "Delete Policy - Deleted IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
          || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
        fi
      fi
    done

    # Removing policy files
    # Removing domain list
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}_domainlist" ]] &>/dev/null;then
      logger -p 5 -st "${ALIAS}" "Delete Policy - Deleting ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist \
      && logger -p 4 -st "${ALIAS}" "Delete Policy - ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist deleted" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete ${POLICYDIR}/policy_${DELETEPOLICY}_domainlist"
    fi
    # Removing domain to IP list
    if [[ -f "${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP" ]] &>/dev/null;then
      logger -p 5 -st "${ALIAS}" "Delete Policy - Deleting ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP"
      rm -f ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP \
      && logger -p 4 -st "${ALIAS}" "Delete Policy - ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP deleted" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete ${POLICYDIR}/policy_${DELETEPOLICY}_domaintoIP"
    fi
    # Removing Policy from Config File
    if [[ -n "$(awk -F "|" '/^'${DELETEPOLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
      logger -p 5 -st "${ALIAS}" "Delete Policy - Deleting ${DELETEPOLICY} to ${CONFIGFILE}"
      POLICYTODELETE="$(grep -w "${DELETEPOLICY}" ${CONFIGFILE})"
      sed -i "\:"${POLICYTODELETE}":d" "${CONFIGFILE}" \
      && logger -p 4 -st "${ALIAS}" "Delete Policy - Deleted ${POLICY} from ${CONFIGFILE}" \
      || logger -p 2 -st "${ALIAS}" "Delete Policy - ***Error*** Failed to delete ${POLICY} from ${CONFIGFILE}"
    fi
  done
fi
return
}

# Add Domain to Policy
adddomain ()
{
if [[ -n "${DOMAIN}" ]] &>/dev/null;then

  # If policy is not selected, pick one.
  if [[ -z "${POLICY+x}" ]] &>/dev/null;then
    # Select Policy for New Domain
    POLICY="all"
    showpolicy
    while true &>/dev/null;do
      printf "\n"
      read -r -p "Select the Policy where you want to add ${DOMAIN}: " value
      for policysel in ${policiesnum};do
        if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
          POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
          break 2
        elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
          echo -e "${RED}***Select a valid number***${NOCOLOR}"
          break 1
        else
          continue
        fi
      done
    done
  fi

  # Check if Domain is already added to policy and if not add it
  if [[ -z "$(awk '$0 == "'${DOMAIN}'" {print}' "${POLICYDIR}/policy_${POLICY}_domainlist")" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Add Domain - Adding ${DOMAIN} to ${POLICY}"
    echo -e "${DOMAIN}" >> "${POLICYDIR}/policy_${POLICY}_domainlist" \
    && logger -p 4 -st "${ALIAS}" "Add Domain - Added ${DOMAIN} to ${POLICY}" \
    || logger -p 2 -st "${ALIAS}" "Add Domain - ***Error*** Failed to add ${DOMAIN} to ${POLICY}"
  else
    echo -e "${RED}***Domain already added to ${POLICY}***${NOCOLOR}"
  fi
elif [[ -z "${DOMAIN}" ]] &>/dev/null;then
  echo -e "${RED}***No Domain Specified***${NOCOLOR}"
fi

unset DOMAIN POLICY

return
}

# Delete domain from policy
deletedomain ()
{
# If policy is not selected, pick one.
if [[ -z "${POLICY+x}" ]] &>/dev/null;then
  # Select Policy for New Domain
  POLICY="all"
  showpolicy
  while true &>/dev/null;do
    printf "\n"
    read -r -p "Select the Policy where you want to delete ${DOMAIN}: " value
    for policysel in ${policiesnum};do
      if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
        POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
        break 2
      elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
        echo -e "${RED}***Select a valid number***${NOCOLOR}"
        break 1
      else
        continue
      fi
    done
  done
fi

# Set Process Priority
setprocesspriority

# Check if Domain is null and delete from policy
if [[ -n "${DOMAIN}" ]] &>/dev/null;then
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
    IPV6S="$(grep -w "${DOMAIN}" ${DOMAINIPLIST} | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" | sort -u)"
    IPV4S="$(grep -w "${DOMAIN}" ${DOMAINIPLIST} | grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | sort -u)"
 
    # Delete IPv6
    for IPV6 in ${IPV6S};do

      # Delete from IPv6 IPSET with prefix fixed
      if [[ -n "$(ipset list ${IPSETPREFIX}-${POLICY}-v6 | grep -wo "${IPV6}::" 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete Domain - Deleting ${IPV6}:: to IPSET: ${IPSETPREFIX}-${POLICY}-v6"
        ipset del ${IPSETPREFIX}-${POLICY}-v6 ${IPV6}:: \
        || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete ${IPV6}:: to IPSET: ${IPSETPREFIX}-${POLICY}-v6" \
        && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete Domain - Deleting ${IPV6}:: to IPSET: ${IPSETPREFIX}-${POLICY}-v6" ;} ;}
      fi

      # Delete from IPv6 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${POLICY}-v6 | grep -wo "${IPV6}" 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete Domain - Deleting ${IPV6} to IPSET: ${IPSETPREFIX}-${POLICY}-v6"
        ipset del ${IPSETPREFIX}-${POLICY}-v6 ${IPV6} \
        || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete ${IPV6} to IPSET: ${IPSETPREFIX}-${POLICY}-v6" \
        && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete Domain - Deleting ${IPV6} to IPSET: ${IPSETPREFIX}-${POLICY}-v6" ;} ;}
      fi

      # Delete IPv6 Route with prefix fixed
      if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete Domain - Deleting route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ${ipbinpath}ip -6 route del ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete Domain - Route deleted for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi

      # Delete IPv6 Route
      if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete Domain - Deleting route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ${ipbinpath}ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete Domain - Route deleted for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** ***Error*** Failed to delete route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi
    done

    # Save IPv6 IPSET if modified or does not exist
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if [[ "${saveipv6ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Domain - Saving IPv6 IPSET for ${POLICY}"
      ipset save ${IPSETPREFIX}-${POLICY}-v6 -file ${POLICYDIR}/policy_${POLICY}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete Domain - Saved IPv6 IPSET for ${POLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to save IPv6 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset


    # Delete IPv4
    for IPV4 in ${IPV4S};do

      # Delete from IPv4 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${POLICY}-v4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete Domain - Deleting ${IPV4} to IPSET: ${IPSETPREFIX}-${POLICY}-v4"
        ipset del ${IPSETPREFIX}-${POLICY}-v4 ${IPV4} \
        || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete ${IPV4} to IPSET: ${IPSETPREFIX}-${POLICY}-v4" \
        && { saveipv4ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete Domain - Deleted ${IPV4} to IPSET: ${IPSETPREFIX}-${POLICY}-v4" ;} ;}
      fi

      # Delete IPv4 IP Rule
      if [[ -n "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete Domain - Deleting IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
        ${ipbinpath}ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} \
        && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete Domain - Deleted IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" ;} \
        || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
      fi

      # Delete IPv4 Route
      if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete Domain - Deleting route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
        ${ipbinpath}ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} \
        && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete Domain - Route deleted for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;} \
        || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete Route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
      fi
    done

    # Save IPv4 IPSET if modified or does not exist
    [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
    if [[ "${saveipv4ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-v4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete Domain - Saving IPv4 IPSET for ${POLICY}"
      ipset save ${IPSETPREFIX}-${POLICY}-v4 -file ${POLICYDIR}/policy_${POLICY}-v4.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete Domain - Saved IPv4 IPSET for ${POLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to save IPv4 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset

    # Delete domain from policy files
    logger -p 5 -st "${ALIAS}" "Delete Domain - Deleting ${DOMAIN} from Policy: ${POLICY}"
    domaindeleted="0"
    logger -p 5 -st "${ALIAS}" "Delete Domain - Deleting ${DOMAIN} from ${DOMAINLIST}"
    sed -i "\:"${DOMAIN}":d" ${DOMAINLIST} \
    && { domaindeleted="1" ; logger -p 4 -st "${ALIAS}" "Delete Domain - Deleted ${DOMAIN} from ${DOMAINLIST}" ;} \
    || { domaindeleted="0" ; logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete ${DOMAIN} from ${DOMAINLIST}" ;}
    logger -p 5 -st "${ALIAS}" "Delete Domain - Deleting ${DOMAIN} from ${DOMAINIPLIST}"
    sed -i "\:"^${DOMAIN}":d" ${DOMAINIPLIST} \
    && { domaindeleted="1" ; logger -p 4 -st "${ALIAS}" "Delete Domain - Deleted ${DOMAIN} from ${DOMAINIPLIST}" ;} \
    || { domaindeleted="0" ; logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete ${DOMAIN} from ${DOMAINIPLIST}" ;}
    if [[ "${domaindeleted}" == "1" ]] &>/dev/null;then
      logger -p 4 -st "${ALIAS}" "Delete Domain - Deleted ${DOMAIN} from Policy: ${POLICY}"
    else
      logger -p 2 -st "${ALIAS}" "Delete Domain - ***Error*** Failed to delete ${DOMAIN} from Policy: ${POLICY}"
    fi
    unset domaindeleted
  else
    echo -e "${RED}***Domain not added to Policy: ${POLICY}***${NOCOLOR}"
  fi
fi

unset POLICY DOMAIN DOMAINLIST DOMAINIPLIST

return
}

# Delete IP from Policy
deleteip ()
{
# Select IP if null
if [[ -z "${IP}" ]] &>/dev/null;then
  while true &>/dev/null;do
    read -r -p "Select an IP Address to delete from a policy: " value
    case ${value} in
      * ) IP=${value}; break;;
    esac
  done
fi

# If policy is not selected, pick one.
if [[ -z "${POLICY+x}" ]] &>/dev/null;then
  # Select Policy for New Domain
  POLICY="all"
  showpolicy
  while true &>/dev/null;do
    printf "\n"
    read -r -p "Select the Policy where you want to delete ${IP}: " value
    for policysel in ${policiesnum};do
      if [[ "${value}" == "$(echo ${policysel} | awk -F "|" '{print $1}')" ]] &>/dev/null;then
        POLICY="$(echo ${policysel} | awk -F "|" '{print $2}')"
        break 2
      elif [[ -z "$(echo ${policiesnum} | grep -o "${value}|")" ]] &>/dev/null;then
        echo -e "${RED}***Select a valid number***${NOCOLOR}"
        break 1
      else
        continue
      fi
    done
  done
fi

# Set Process Priority
setprocesspriority

# Check if IP is null and delete from policy
if [[ -n "${IP}" ]] &>/dev/null;then
  if [[ -n "$(grep -w "${IP}" "${POLICYDIR}/policy_${POLICY}_domaintoIP" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))")" ]] &>/dev/null;then
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
    IPV6S="$(grep -m 1 -w "${IP}" ${DOMAINIPLIST} | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" | sort -u)"
    IPV4S="$(grep -m 1 -w "${IP}" ${DOMAINIPLIST} | grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | sort -u)"

    # Delete IPv6
    for IPV6 in ${IPV6S};do

      # Delete from IPv6 IPSET with prefix fixed
      if [[ -n "$(ipset list ${IPSETPREFIX}-${POLICY}-v6 | grep -wo "${IPV6}::" 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete IP - Deleting ${IPV6}:: to IPSET: ${IPSETPREFIX}-${POLICY}-v6"
        ipset del ${IPSETPREFIX}-${POLICY}-v6 ${IPV6}:: \
        || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete ${IPV6}:: to IPSET: ${IPSETPREFIX}-${POLICY}-v6" \
        && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete IP - Deleting ${IPV6}:: to IPSET: ${IPSETPREFIX}-${POLICY}-v6" ;} ;}
      fi

      # Delete from IPv6 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${POLICY}-v6 | grep -wo "${IPV6}" 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete IP - Deleting ${IPV6} to IPSET: ${IPSETPREFIX}-${POLICY}-v6"
        ipset del ${IPSETPREFIX}-${POLICY}-v6 ${IPV6} \
        || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete ${IPV6} to IPSET: ${IPSETPREFIX}-${POLICY}-v6" \
        && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete IP - Deleting ${IPV6} to IPSET: ${IPSETPREFIX}-${POLICY}-v6" ;} ;}
      fi

      # Delete IPv6 Route with prefix fixed
      if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete IP - Deleting route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ${ipbinpath}ip -6 route del ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete IP - Route deleted for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete Route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi

      # Delete IPv6 Route
      if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} 2>/dev/null)" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete IP - Deleting route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
        ${ipbinpath}ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} \
        && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete IP - Route deleted for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;} \
        || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete Route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
      fi

    done

    # Save IPv6 IPSET if modified or does not exist
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if [[ "${saveipv6ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete IP - Saving IPv6 IPSET for ${POLICY}"
      ipset save ${IPSETPREFIX}-${POLICY}-v6 -file ${POLICYDIR}/policy_${POLICY}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete IP - Saved IPv6 IPSET for ${POLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to save IPv6 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset


    # Delete IPv4
    for IPV4 in ${IPV4S};do

      # Delete from IPv4 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${POLICY}-v4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete IP - Deleting ${IPV4} to IPSET: ${IPSETPREFIX}-${POLICY}-v4"
        ipset del ${IPSETPREFIX}-${POLICY}-v4 ${IPV4} \
        || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete ${IPV4} to IPSET: ${IPSETPREFIX}-${POLICY}-v4" \
        && { saveipv4ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete IP - Deleted ${IPV4} to IPSET: ${IPSETPREFIX}-${POLICY}-v4" ;} ;}
      fi

      # Delete IPv4 IPv4 Rule
      if [[ -n "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete IP - Deleting IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
        ${ipbinpath}ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} \
        && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete IP - Deleted IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
        || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
      fi

      # Delete IPv4 Route
      if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Delete IP - Deleting route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
        ${ipbinpath}ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} \
        && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Delete IP - Route deleted for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;} \
        || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete Route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
      fi
    done

    # Save IPv4 IPSET if modified or does not exist
    [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
    if [[ "${saveipv4ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${POLICY}-v4.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Delete IP - Saving IPv4 IPSET for ${POLICY}"
      ipset save ${IPSETPREFIX}-${POLICY}-v4 -file ${POLICYDIR}/policy_${POLICY}-v4.ipset \
      && logger -p 4 -t "${ALIAS}" "Delete IP - Saved IPv4 IPSET for ${POLICY}" \
      || logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to save IPv4 IPSET for ${POLICY}"
    fi
    [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset

    # Delete IPv4 from policy
    logger -p 5 -st "${ALIAS}" "Delete IP - Deleting ${IP} from Policy: ${POLICY}"
    DELETEDOMAINTOIPS="$(grep -w "${IP}" ${DOMAINIPLIST})"
    for DELETEDOMAINTOIP in ${DELETEDOMAINTOIPS}; do
      sed -i "\:"^${DELETEDOMAINTOIP}":d" ${DOMAINIPLIST} \
      && { ipdeleted="1" ; logger -p 4 -st "${ALIAS}" "Delete IP - Deleted ${IP} from ${DOMAINIPLIST}" ;} \
      || { ipdeleted="0" ; logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete ${IP} from ${DOMAINIPLIST}" ;}
    done
    if [[ "${ipdeleted}" == "1" ]] &>/dev/null;then
      logger -p 4 -st "${ALIAS}" "Delete IP - Deleted ${IP} from Policy: ${POLICY}"
    else
      logger -p 2 -st "${ALIAS}" "Delete IP - ***Error*** Failed to delete ${IP} from Policy: ${POLICY}"
    fi
    unset ipdeleted
  else
    echo -e "${RED}***IP not added to Policy: ${POLICY}***${NOCOLOR}"
  fi
fi

unset POLICY IP DOMAINIPLIST

return
}

# Select Random DoT DNS Server
randomdotdnsserver ()
{
if [[ "${PYTHON3INSTALLED}" == "0" ]] &>/dev/null;then
  logger -p 2 -t "${ALIAS}" "Format IPv6 - ***Error*** Python3 is not installed"
  return 1
fi

/opt/bin/python3 - ${DOTDNSSERVERS} << END
import random
import sys

def pick_random_string(args):
    """Picks a random string from a list of arguments.

    Args:
        args: A list of strings.

    Returns:
        A randomly selected string from the input list, or None if the list is empty.
    """
    if not args:
        return None
    return random.choice(args)

if __name__ == "__main__":
    arguments = sys.argv[1:]  # Get arguments passed from the command line (excluding the script name)
    random_string = pick_random_string(arguments)
    
    if random_string:
        print(f"{random_string}")
END

return
}


# Parse AdGuardHome Log
parseadguardhomelog ()
{
# Check if AdGuardHome is active
if [[ "${ADGUARDHOMEACTIVE}" == "0" ]] &>/dev/null;then
  logger -p 2 -t "${ALIAS}" "Parse AdguardHome Log - ***Error*** AdGuardHome is not currently active or installed"
  return 1
fi

/opt/bin/python3 - ${answer} << END
import struct
import base64
import sys

def parse_dns_response(data):
    # Parse DNS data header
    transaction_id = data[:2]
    flags = data[2:4]
    qdcount = struct.unpack('!H', data[4:6])[0]
    ancount = struct.unpack('!H', data[6:8])[0]
    nscount = struct.unpack('!H', data[8:10])[0]
    arcount = struct.unpack('!H', data[10:12])[0]

    print("Transaction ID:", transaction_id.hex())
    print("Flags:", flags.hex())
    print("Questions:", qdcount)
    print("Answer RRs:", ancount)
    print("Authority RRs:", nscount)
    print("Additional RRs:", arcount)

    # Skip header length
    offset = 12

    # Parse query part
    for _ in range(qdcount):
        offset, qname = parse_name(data, offset)
        qtype, qclass = struct.unpack('!HH', data[offset:offset+4])
        offset += 4
        print("Query Name:", qname)
        print("Query Type:", qtype)
        print("Query Class:", qclass)

    # Parse answer part
    for _ in range(ancount):
        offset, name = parse_name(data, offset)
        atype, aclass, ttl, rdlength = struct.unpack('!HHIH', data[offset:offset+10])
        offset += 10
        rdata = data[offset:offset+rdlength]
        offset += rdlength
        print("Answer Name:", name)
        print("Answer Type:", atype)
        print("Answer Class:", aclass)
        print("Answer TTL:", ttl)
        print("Answer Data Length:", rdlength)
        if atype == 1:  # If A record
            ip = struct.unpack('!BBBB', rdata)
            print("Answer Address:", ".".join(map(str, ip)))
        else:
            print("Answer Data:", rdata.hex())

def parse_name(data, offset):
    labels = []
    while True:
        length = data[offset]
        if length & 0xc0 == 0xc0:  # If pointer
            pointer = struct.unpack('!H', data[offset:offset+2])[0]
            offset += 2
            return offset, parse_name(data, pointer & 0x3fff)[1]
        if length == 0:  # Domain end if length == 0
            offset += 1
            break
        offset += 1
        labels.append(data[offset:offset+length].decode('utf-8'))
        offset += length
    return offset, ".".join(labels)

encoded_string = sys.argv[1]

decoded_bytes = base64.b64decode(encoded_string)

print(f'Raw: {encoded_string}\n')
parse_dns_response(decoded_bytes)
END

return
}

# Format IPv6 from AdGuardHome
formatipv6 ()
{
if [[ "${PYTHON3INSTALLED}" == "0" ]] &>/dev/null;then
  logger -p 2 -t "${ALIAS}" "Format IPv6 - ***Error*** Python3 is not installed"
  return 1
fi

/opt/bin/python3 - ${ipv6answerdata} << END
import ipaddress
import sys

ipv6_addr = ipaddress.ip_address(int(sys.argv[1], 16))
print(ipv6_addr)
END

return
}



# Query Policies for New IP Addresses
querypolicy ()
{
# Set start timer for processing time
querystart="$(date +%s)"

# Check if Domain VPN Routing is enabled
checkscriptstatus || return

# Check Alias
checkalias || return

# Boot Delay Timer
bootdelaytimer

# Set Process Priority
setprocesspriority

# Check WAN Status
checkwanstatus || return 1

# Query Policies
if [[ "${POLICY}" == "all" ]] &>/dev/null;then
  QUERYPOLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
  if [[ -z "${QUERYPOLICIES}" ]] &>/dev/null;then
    logger -p 3 -st "${ALIAS}" "Query Policy - ***No Policies Detected***"
    return
  fi
  # Capture AdGuardHome log checkpoint or set default checkpoint
  if [[ -f "${ADGUARDHOMELOGCHECKPOINT}" ]] &>/dev/null;then
    adguardhomelogcheckpoint="$(cat ${ADGUARDHOMELOGCHECKPOINT})"
  else
    adguardhomelogcheckpoint="0"
  fi
elif [[ "${POLICY}" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
  QUERYPOLICIES="${POLICY}"
  adguardhomelogcheckpoint="0"
else
  echo -e "${RED}Policy: ${POLICY} not found${NOCOLOR}"
  return
fi

# Check if existing policies are configured
restorepolicy

# Query Policies
for QUERYPOLICY in ${QUERYPOLICIES};do
  # Check for DNS Override Configuration
  INTERFACE="$(grep -w "${QUERYPOLICY}" "${CONFIGFILE}" | awk -F"|" '{print $4}')"
  dnsdirector || return

  # Check if IPv6 IP Addresses are in policy file if IPv6 is Disabled and delete them
  if [[ "${IPV6SERVICE}" == "disabled" ]] &>/dev/null && [[ -n "$(grep -m1 -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP")" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Query Policy - Removing IPv6 IP Addresses from Policy: ${QUERYPOLICY}***"
    sed -i '/:/d' "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP" \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Removed IPv6 IP Addresses from Policy: ${QUERYPOLICY}***" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to remove IPv6 IP Addresses from Policy: ${QUERYPOLICY}***"
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
  
  # Check if ADDCNAMES are Enabled
  if [[ -z "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $7}' ${CONFIGFILE})" ]] &>/dev/null;then
    ADDCNAMES="0"
  elif [[ "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $7}' ${CONFIGFILE})" == "ADDCNAMES=0" ]] &>/dev/null;then
    ADDCNAMES="0"
  elif [[ "$(awk -F "|" '/^'${QUERYPOLICY}'/ {print $7}' ${CONFIGFILE})" == "ADDCNAMES=1" ]] &>/dev/null;then
    ADDCNAMES="1"
  fi

  # Display Query Policy
  if tty >/dev/null 2>&1;then
    printf '\033[K%b\r' "${BOLD}${UNDERLINE}Query Policy: ${QUERYPOLICY}${NOCOLOR}\n"
  fi

  # Read Domain List File
  DOMAINS="$(cat ${POLICYDIR}/policy_${QUERYPOLICY}_domainlist)"
  
  # Configure DNSSERVER for dig
  digdnsserver=""
  if [[ -n "${DNSSERVER}" ]] &>/dev/null;then
    digdnsserver="${DNSSERVER}"
    logger -p 6 -t "${ALIAS}" "Debug - Dig has been configured to use DNS Server: ${digdnsserver}"
  # Configure dig to use random DNS Server from DNS-over-TLS list if configured and enabled.  Python3 must be installed.
  elif [[ "${DOTENABLED}" == "1" ]] &>/dev/null && [[ -n "${DOTDNSSERVERS}" ]] &>/dev/null && [[ "${PYTHON3INSTALLED}" == "1" ]] &>/dev/null;then
    digdnsserver="$(randomdotdnsserver ${DOTDNSSERVERS})"
    logger -p 6 -t "${ALIAS}" "Debug - Dig has been configured to use DNS Server: ${digdnsserver}"
  else
    digdnsserver=""
    logger -p 6 -t "${ALIAS}" "Debug - Dig has been configured to use system DNS Server"
  fi
  
  # Configure dig for DNS-over-TLS if enabled on interface
  if [[ "${DOT}" == "1" ]] &>/dev/null && [[ -n "${digdnsserver}" ]] &>/dev/null;then
    digdnsconfig="@${digdnsserver} +tls"
    logger -p 6 -t "${ALIAS}" "Debug - Dig has been configured to use DNS-over-TLS using DNS Server: ${digdnsserver}"
  # Configure dig for DNS-over-TLS if enabled on router and digdnsserver is in DOTDNSSERVERS list. Python3 must be installed.
  elif [[ "${DOTENABLED}" == "1" ]] &>/dev/null && [[ -n "${DOTDNSSERVERS}" ]] &>/dev/null && [[ "${PYTHON3INSTALLED}" == "1" ]] &>/dev/null && [[ -n "${digdnsserver}" ]] &>/dev/null && [[ -n "$(echo ${DOTDNSSERVERS} | grep -o "${digdnsserver}")" ]] &>/dev/null;then
    digdnsconfig="@${digdnsserver} +tls"
    logger -p 6 -t "${ALIAS}" "Debug - Dig has been configured to use DNS-over-TLS using DNS Server: ${digdnsserver}"
  # Configure dig without DNS-over-TLS
  else
    digdnsconfig="@${digdnsserver}"
    logger -p 6 -t "${ALIAS}" "Debug - Dig has been configured without DNS-over-TLS using DNS Server: ${digdnsserver}"
  fi
  
  # Add CNAME records to Domains if enabled and dig is installed
  if [[ "${DIGINSTALLED}" == "1" ]] &>/dev/null && [[ "${ADDCNAMES}" == "1" ]] &>/dev/null && [[ "${QUERYPOLICY}" != "all" ]] &>/dev/null;then
    for DOMAIN in ${DOMAINS};do
      domaincnames="$(/opt/bin/dig ${digdnsconfig} ${DOMAIN} CNAME +short +noall +answer 2>/dev/null | grep -Ev "unreachable|\+" | grep -E '([-[:alnum:]]+\.)+[\n]' | awk '{print substr($NF, 1, length ($NF)-1)}')"
      for domaincname in ${domaincnames};do
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying CNAME records for ${DOMAIN}...${NOCOLOR}"
        fi
        if [[ -z "$(awk '$0 == "'${domaincname}'" {print}' "${POLICYDIR}/policy_${QUERYPOLICY}_domainlist")" ]] &>/dev/null;then
          logger -p 5 -t "${ALIAS}" "Query Policy - Adding CNAME: ${domaincname} to ${QUERYPOLICY}"
          echo -e "${domaincname}" >> "${POLICYDIR}/policy_${QUERYPOLICY}_domainlist" \
          && logger -p 4 -t "${ALIAS}" "Query Policy - Added CNAME: ${domaincname} to ${QUERYPOLICY}" \
          || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add CNAME: ${domaincname} to ${QUERYPOLICY}"
        else
          logger -p 6 -t "${ALIAS}" "Debug - CNAME: ${domaincname} is already added to ${QUERYPOLICY}"
        fi
      done
    done
	
    # Read Domain list file after CNAME query
    DOMAINS="$(cat ${POLICYDIR}/policy_${QUERYPOLICY}_domainlist)"
  fi

  # Query Domains for IP Addresses
  for DOMAIN in ${DOMAINS};do
    [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -st "${ALIAS}" "Query Policy - Policy: ${QUERYPOLICY} Querying ${DOMAIN}"
    [[ -n "$(echo ${DOMAIN} | grep '^[*].')" ]] &>/dev/null && domainwildcard="${DOMAIN:2}" || unset domainwildcard
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' "${LIGHTCYAN}Querying ${DOMAIN}...${NOCOLOR}"
    fi
    # Determine to query for IPv6 and IPv4 IP Addresses or only IPv4 Addresses
    if [[ "${IPV6SERVICE}" == "disabled" ]] &>/dev/null;then
      # Query AdGuardHome log if enabled for IPv4 and check if domain is wildcard
      if [[ "${QUERYADGUARDHOMELOG}" == "1" ]] &>/dev/null && [[ -n "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMELOGENABLED}" == "1" ]] &>/dev/null && [[ "${JQINSTALLED}" == "1" ]] &>/dev/null && [[ "${PYTHON3INSTALLED}" == "1" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying AdGuardHome log for ${DOMAIN}...${NOCOLOR}"
        fi
        answers="$(grep -e ".${domainwildcard}" ${ADGUARDHOMELOGFILE} | /opt/bin/jq -c '. | select (.T > ('${adguardhomelogcheckpoint}' | strflocaltime("%FT%T"))) | select(.QH|endswith(".'${domainwildcard}'")) | select(.QT == "A") | .Answer' 2>/dev/null | tr -d \" | sort -u)" && adguardhomelognewcheckpoint="$(date +%s)"
		for answer in ${answers};do
          if tty >/dev/null 2>&1;then
            printf '\033[K%b\r' "${LIGHTCYAN}Parsing answer: ${answer} for ${DOMAIN} in AdGuardHome log...${NOCOLOR}"
          fi
          answerips="$(parseadguardhomelog ${answer} | awk '($1 == "Answer" && $2 == "Address:") {print $3}')"
          if [[ -n "${answerips}" ]] &>/dev/null;then
            for IP in ${answerips};do
              if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
                echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
              elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
                if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
                elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
                  if tty >/dev/null 2>&1;then
                    printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
                  fi
                fi
              fi
            done
          fi
        done
        unset answers answerips IP
      # Query dnsmasq log if enabled for IPv4 and check if domain is wildcard
      elif [[ -n "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMEACTIVE}" == "0" ]] &>/dev/null && [[ "${DNSLOGGINGENABLED}" == "1" ]] &>/dev/null && [[ -n "${DNSLOGPATH}" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying DNSMasq log for ${DOMAIN}...${NOCOLOR}"
        fi
        for IP in $(awk '($5 == "reply" || $5 == "cached") && $6 ~ /.*.'${domainwildcard}'/ && $8 ~ /((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/ {print $8}' "${DNSLOGPATH}" | sort -u | grep -xv "0.0.0.0"); do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      # Query AdGuardHome log if enabled for IPv4 for non wildcard
      elif [[ "${QUERYADGUARDHOMELOG}" == "1" ]] &>/dev/null && [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMELOGENABLED}" == "1" ]] &>/dev/null && [[ "${JQINSTALLED}" == "1" ]] &>/dev/null && [[ "${PYTHON3INSTALLED}" == "1" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying AdGuardHome log for ${DOMAIN}...${NOCOLOR}"
        fi
        answers="$(grep -e "${DOMAIN}" ${ADGUARDHOMELOGFILE} | /opt/bin/jq -c '. | select (.T > ('${adguardhomelogcheckpoint}' | strflocaltime("%FT%T"))) | select(.QH == "'${DOMAIN}'" and .QT == "A") | .Answer' 2>/dev/null | tr -d \" | sort -u)" && adguardhomelognewcheckpoint="$(date +%s)"
		for answer in ${answers};do
          if tty >/dev/null 2>&1;then
            printf '\033[K%b\r' "${LIGHTCYAN}Parsing answer: ${answer} for ${DOMAIN} in AdGuardHome log...${NOCOLOR}"
          fi
          answerips="$(parseadguardhomelog ${answer} | awk '($1 == "Answer" && $2 == "Address:") {print $3}')"
          if [[ -n "${answerips}" ]] &>/dev/null;then
            for IP in ${answerips};do
              if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
                echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
              elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
                if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
                elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
                  if tty >/dev/null 2>&1;then
                    printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
                  fi
                fi
              fi
            done
          fi
        done
        unset answers answerips IP
      # Query dnsmasq log if enabled for IPv4 for non wildcard
      elif [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMEACTIVE}" == "0" ]] &>/dev/null && [[ "${DNSLOGGINGENABLED}" == "1" ]] &>/dev/null && [[ -n "${DNSLOGPATH}" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying DNSMasq log for ${DOMAIN}...${NOCOLOR}"
        fi
        for IP in $(awk '($5 == "reply" || $5 == "cached") && $6 == "'${DOMAIN}'" && $8 ~ /((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/ {print $8}' "${DNSLOGPATH}" | sort -u | grep -xv "0.0.0.0"); do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      fi
      # Perform dig lookup if installed for IPv4
      if [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ "${DIGINSTALLED}" == "1" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying ${DOMAIN} using dig...${NOCOLOR}"
        fi
        for IP in $(/opt/bin/dig ${digdnsconfig} ${DOMAIN} A +short +noall +answer 2>/dev/null | grep -Ev "unreachable|\+" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | grep -xv "0.0.0.0\|::");do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 3 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      # Perform nslookup if nslookup is installed for IPv4
      elif [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ -L "/usr/bin/nslookup" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying ${DOMAIN} using nslookup...${NOCOLOR}"
        fi
        for IP in $(/usr/bin/nslookup ${DOMAIN} ${DNSSERVER} 2>/dev/null | awk '(NR>2)' | grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | grep -xv "0.0.0.0"); do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 3 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      fi
    else
      # Query AdGuardHome log if enabled for IPv6 and IPv4 and check if domain is wildcard
      if [[ "${QUERYADGUARDHOMELOG}" == "1" ]] &>/dev/null && [[ -n "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMELOGENABLED}" == "1" ]] &>/dev/null && [[ "${JQINSTALLED}" == "1" ]] &>/dev/null && [[ "${PYTHON3INSTALLED}" == "1" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying AdGuardHome log for ${DOMAIN}...${NOCOLOR}"
        fi
        # Query IPv4
        answers="$(grep -e ".${domainwildcard}" ${ADGUARDHOMELOGFILE} | /opt/bin/jq -c '. | select (.T > ('${adguardhomelogcheckpoint}' | strflocaltime("%FT%T"))) | select(.QH|endswith(".'${domainwildcard}'")) | select(.QT == "A") | .Answer' 2>/dev/null | tr -d \" | sort -u)" && adguardhomelognewcheckpoint="$(date +%s)"
		for answer in ${answers};do
          if tty >/dev/null 2>&1;then
            printf '\033[K%b\r' "${LIGHTCYAN}Parsing answer: ${answer} for ${DOMAIN} in AdGuardHome log...${NOCOLOR}"
          fi
          answerips="$(parseadguardhomelog ${answer} | awk '($1 == "Answer" && $2 == "Address:") {print $3}')"
          if [[ -n "${answerips}" ]] &>/dev/null;then
            for IP in ${answerips};do
              if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
                echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
              elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
                if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
                elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
                  if tty >/dev/null 2>&1;then
                    printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
                  fi
                fi
              fi
            done
          fi
        done
        unset answers answerips IP
        # Query IPv6
        answers="$(grep -e ".${domainwildcard}" ${ADGUARDHOMELOGFILE} | /opt/bin/jq -c '. | select (.T > ('${adguardhomelogcheckpoint}' | strflocaltime("%FT%T"))) | select(.QH|endswith(".'${domainwildcard}'")) | select(.QT == "AAAA") | .Answer' 2>/dev/null | tr -d \" | sort -u)" && adguardhomelognewcheckpoint="$(date +%s)"
		for answer in ${answers};do
          if tty >/dev/null 2>&1;then
            printf '\033[K%b\r' "${LIGHTCYAN}Parsing answer: ${answer} for ${DOMAIN} in AdGuardHome log...${NOCOLOR}"
          fi
          ipv6answerdata="$(parseadguardhomelog ${answer} | awk '($1 == "Answer" && $2 == "Data:") {print $3}')"
          if [[ -n "${ipv6answerdata}" ]] &>/dev/null;then
            answerips="$(formatipv6 ${ipv6answerdata})"
            for IP in ${answerips};do
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            done
          fi
        done
        unset answers answerips ipv6answerdata IP
      # Query dnsmasq log if enabled for IPv6 and IPv4 and check if domain is wildcard
      elif [[ -n "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMEACTIVE}" == "0" ]] &>/dev/null && [[ "${DNSLOGGINGENABLED}" == "1" ]] &>/dev/null && [[ -n "${DNSLOGPATH}" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying DNSMasq log for ${DOMAIN}...${NOCOLOR}"
        fi
        for IP in $(awk '($5 == "reply" || $5 == "cached") && $6 ~ /.*.'${domainwildcard}'/ && $8 ~ /(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/ {print $8}' "${DNSLOGPATH}" | sort -u | grep -xv "0.0.0.0\|::"); do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 3 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      # Query AdGuardHome log if enabled for IPv6 and IPv4 for non wildcard
      elif [[ "${QUERYADGUARDHOMELOG}" == "1" ]] &>/dev/null && [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMELOGENABLED}" == "1" ]] &>/dev/null && [[ "${JQINSTALLED}" == "1" ]] &>/dev/null && [[ "${PYTHON3INSTALLED}" == "1" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying AdGuardHome log for ${DOMAIN}...${NOCOLOR}"
        fi
        # Query IPv4
        answers="$(grep -e "${DOMAIN}" ${ADGUARDHOMELOGFILE} | /opt/bin/jq -c '. | select (.T > ('${adguardhomelogcheckpoint}' | strflocaltime("%FT%T"))) | select(.QH == "'${DOMAIN}'" and .QT == "A") | .Answer' 2>/dev/null | tr -d \" | sort -u)" && adguardhomelognewcheckpoint="$(date +%s)"
		for answer in ${answers};do
          if tty >/dev/null 2>&1;then
            printf '\033[K%b\r' "${LIGHTCYAN}Parsing answer: ${answer} for ${DOMAIN} in AdGuardHome log...${NOCOLOR}"
          fi
          answerips="$(parseadguardhomelog ${answer} | awk '($1 == "Answer" && $2 == "Address:") {print $3}')"
          if [[ -n "${answerips}" ]] &>/dev/null;then
            for IP in ${answerips};do
              if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
                echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
              elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
                if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
                elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
                  [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
                  if tty >/dev/null 2>&1;then
                    printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
                  fi
                fi
              fi
            done
          fi
        done
        unset answers answerips IP
        # Query IPv6
        answers="$(grep -e "${DOMAIN}" ${ADGUARDHOMELOGFILE} | /opt/bin/jq -c '. | select (.T > ('${adguardhomelogcheckpoint}' | strflocaltime("%FT%T"))) | select(.QH == "'${DOMAIN}'" and .QT == "AAAA") | .Answer' 2>/dev/null | tr -d \" | sort -u)" && adguardhomelognewcheckpoint="$(date +%s)"
		for answer in ${answers};do
          if tty >/dev/null 2>&1;then
            printf '\033[K%b\r' "${LIGHTCYAN}Parsing answer: ${answer} for ${DOMAIN} in AdGuardHome log...${NOCOLOR}"
          fi
          ipv6answerdata="$(parseadguardhomelog ${answer} | awk '($1 == "Answer" && $2 == "Data:") {print $3}')"
          if [[ -n "${ipv6answerdata}" ]] &>/dev/null;then
            answerips="$(formatipv6 ${ipv6answerdata})"
            for IP in ${answerips};do
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            done
          fi
        done
        unset answers ipv6answerdata IP
      # Query dnsmasq log if enabled for IPv6 and IPv4 for non wildcard
      elif [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ "${ADGUARDHOMEACTIVE}" == "0" ]] &>/dev/null && [[ "${DNSLOGGINGENABLED}" == "1" ]] &>/dev/null && [[ -n "${DNSLOGPATH}" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying DNSMasq log for ${DOMAIN}...${NOCOLOR}"
        fi
        for IP in $(awk '($5 == "reply" || $5 == "cached") && $6 == "'${DOMAIN}'" && $8 ~ /(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))/ {print $8}' "${DNSLOGPATH}" | sort -u | grep -xv "0.0.0.0\|::"); do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 3 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      fi
      # Perform dig lookup if installed for IPv6 and IPv4
      if [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ "${DIGINSTALLED}" == "1" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying ${DOMAIN} using dig...${NOCOLOR}"
        fi
        # Capture IPv6 Records
        for IP in $(/opt/bin/dig ${digdnsconfig} ${DOMAIN} AAAA +short +noall +answer 2>/dev/null | grep -Ev "unreachable|\+" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | grep -xv "0.0.0.0\|::");do
          echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
        done
        # Capture IPv4 Records
        for IP in $(/opt/bin/dig ${digdnsconfig} ${DOMAIN} A +short +noall +answer 2>/dev/null | grep -Ev "unreachable|\+" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | grep -xv "0.0.0.0\|::");do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 3 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
              if tty >/dev/null 2>&1;then
                printf '\033[K%b\r' "${RED}Query Policy: Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***${NOCOLOR}"
              fi
            fi
          fi
        done
      # Perform nslookup if nslookup is installed for IPv6 and IPv4
      elif [[ -z "${domainwildcard+x}" ]] &>/dev/null && [[ -L "/usr/bin/nslookup" ]] &>/dev/null;then
        if tty >/dev/null 2>&1;then
          printf '\033[K%b\r' "${LIGHTCYAN}Querying ${DOMAIN} using nslookup...${NOCOLOR}"
        fi
        for IP in $(/usr/bin/nslookup ${DOMAIN} ${DNSSERVER} 2>/dev/null | awk '(NR>2)' | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" | grep -xv "0.0.0.0\|::"); do
          if [[ "${PRIVATEIPS}" == "1" ]] &>/dev/null;then
            echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
          elif [[ "${PRIVATEIPS}" == "0" ]] &>/dev/null;then
            if [[ -z "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              echo "${DOMAIN}>>${IP}" >> "/tmp/policy_${QUERYPOLICY}_domaintoIP"
            elif [[ -n "$(echo ${IP} | grep -oE "\b^(((10|127)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})|(((172\.(1[6-9]|2[0-9]|3[0-1]))|(192\.168))(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}))$\b")" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 3 -st "${ALIAS}" "Query Policy - Domain: ${DOMAIN} queried ${IP} ***Excluded because Private IPs are disabled for Policy: ${QUERYPOLICY}***"
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
    unset domainwildcard
  done

  # Remove duplicates from Temporary File
  sort -u "/tmp/policy_${QUERYPOLICY}_domaintoIP" -o "/tmp/policy_${QUERYPOLICY}_domaintoIP"

  # Compare Temporary File to Policy File
  if ! diff "/tmp/policy_${QUERYPOLICY}_domaintoIP" "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP" &>/dev/null;then
    echo -e "${LIGHTMAGENTA}***New IP Addresses detected for ${QUERYPOLICY}***${NOCOLOR}"
    echo -e "${LIGHTCYAN}Updating Policy: ${QUERYPOLICY}${NOCOLOR}"
    logger -p 5 -t "${ALIAS}" "Query Policy - Updating Policy: ${QUERYPOLICY}"
    cp "/tmp/policy_${QUERYPOLICY}_domaintoIP" "${POLICYDIR}/policy_${QUERYPOLICY}_domaintoIP" \
    && { echo -e "${GREEN}Updated Policy: ${QUERYPOLICY}${NOCOLOR}" ; logger -p 4 -t "${ALIAS}" "Query Policy - Updated Policy: ${QUERYPOLICY}" ;} \
    || { echo -e "${RED}Failed to update Policy: ${QUERYPOLICY}${NOCOLOR}" ; logger -p 2 -t "${ALIAS}" "Query Policy - ***Error*** Failed to update Policy: ${QUERYPOLICY}" ;}
  else
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' "${LIGHTCYAN}Query Policy: No new IP Addresses detected for ${QUERYPOLICY}${NOCOLOR}"
    fi
  fi

  # Determine Domain Policy Files and Interface and Route Table for IP Routes to delete.
  DOMAINIPLIST="$(grep -w "${QUERYPOLICY}" "${CONFIGFILE}" | awk -F"|" '{print $3}')"
  INTERFACE="$(grep -w "${QUERYPOLICY}" "${CONFIGFILE}" | awk -F"|" '{print $4}')"
  routingdirector || return

  # Check if Interface State is Up or Down
  if [[ "${STATE}" == "0" ]] &>/dev/null;then
    logger -p 3 -st "${ALIAS}" "Query Policy - Interface ${INTERFACE} for ${QUERYPOLICY} is down"
    continue
  fi

  # Create IPv6 IPSET
  # Check for saved IPSET
  if [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${QUERYPOLICY}-v6.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Restoring IPv6 IPSET for ${QUERYPOLICY}"
    ipset restore -! <"${POLICYDIR}/policy_${QUERYPOLICY}-v6.ipset" \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Restored IPv6 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to restore IPv6 IPSET for ${QUERYPOLICY}"
  # Create saved IPv6 IPSET file if IPSET exists
  elif [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-v6.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Saving IPv6 IPSET for ${QUERYPOLICY}"
    ipset save ${IPSETPREFIX}-${QUERYPOLICY}-v6 -file ${POLICYDIR}/policy_${QUERYPOLICY}-v6.ipset \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Saved IPv6 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to save IPv6 IPSET for ${QUERYPOLICY}"
  # Create new IPv6 IPSET if it does not exist
  elif [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Creating IPv6 IPSET for ${QUERYPOLICY}"
    ipset create ${IPSETPREFIX}-${QUERYPOLICY}-v6 hash:ip family inet6 comment \
    && { saveipv6ipset="1" && logger -p 4 -t "${ALIAS}" "Query Policy - Created IPv6 IPSET for ${QUERYPOLICY}" ;} \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to create IPv6 IPSET for ${QUERYPOLICY}"
  fi
  # Create IPv4 IPSET
  # Check for saved IPv4 IPSET
  if [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${QUERYPOLICY}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Restoring IPv4 IPSET for ${QUERYPOLICY}"
    ipset restore -! <"${POLICYDIR}/policy_${QUERYPOLICY}-v4.ipset" \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Restored IPv4 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to restore IPv4 IPSET for ${QUERYPOLICY}"
  # Create saved IPv4 IPSET file if IPSET exists
  elif [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Saving IPv4 IPSET for ${QUERYPOLICY}"
    ipset save ${IPSETPREFIX}-${QUERYPOLICY}-v4 -file ${POLICYDIR}/policy_${QUERYPOLICY}-v4.ipset \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Saved IPv4 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to save IPv4 IPSET for ${QUERYPOLICY}"
  # Create new IPv4 IPSET if it does not exist
  elif [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Creating IPv4 IPSET for ${QUERYPOLICY}"
    ipset create ${IPSETPREFIX}-${QUERYPOLICY}-v4 hash:ip family inet comment \
    && { saveipv4ipset="1" && logger -p 4 -t "${ALIAS}" "Query Policy - Created IPv4 IPSET for ${QUERYPOLICY}" ;} \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to create IPv4 IPSET for ${QUERYPOLICY}"
  fi

  # Create IPv4 and IPv6 Arrays from Policy File. 
  IPV6S="$(grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "${DOMAINIPLIST}" | sort -u)"
  IPV4S="$(grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" "${DOMAINIPLIST}" | sort -u)"
  
  # Show visual status for updating routes and rules
  if tty >/dev/null 2>&1;then
    printf '\033[K%b\r' "${LIGHTCYAN}Query Policy: Updating IP Routes and IP Rules${NOCOLOR}"
  fi
  
  # Create IP FWMark Rules
  createipmarkrules

  # IPv6
  if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
    # Create IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${QUERYPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query Policy - Adding IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${QUERYPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Query Policy - Added IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${QUERYPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query Policy - Adding IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${QUERYPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Query Policy - Added IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "'${IPSETPREFIX}'-'${QUERYPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query Policy - Adding IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${QUERYPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Query Policy - Added IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi

    # Add IPv6s to IPSET or create IPv6 Routes
    if [[ -n "${FWMARK}" ]] &>/dev/null;then
      for IPV6 in ${IPV6S};do
        # Check IPv6 for prefix error
        if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} 2>&1 | grep -e "Error: inet6 prefix is expected rather than")" ]] &>/dev/null;then
          # Add to IPv6 IPSET with prefix fixed
          if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 | grep -wo "${IPV6}::")" ]] &>/dev/null;then
            comment="$(awk -F ">>" '$2 == "'${IPV6}'::" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding ${IPV6}:: to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6"
            ipset add ${IPSETPREFIX}-${QUERYPOLICY}-v6 ${IPV6}:: comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add ${IPV6}:: to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Added ${IPV6}:: to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" ;} ;}
            unset comment
          fi
          # Remove IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Removing route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route del ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route removed for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Route does not exist for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to remove route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
          # Remove IPv6 Route for WAN Failover
          if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ -n "${OLDIPV6ROUTETABLE+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
            if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Deleting route for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
              ${ipbinpath}ip -6 route del ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
              || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to delete route for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
              && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route deleted for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" ;}
            fi
          fi
        else
          # Add to IPv6 IPSET
          if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 | grep -wo "${IPV6}")" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding ${IPV6} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            ipset add ${IPSETPREFIX}-${QUERYPOLICY}-v6 ${IPV6} comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add ${IPV6} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Added ${IPV6} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" ;} ;}
            unset comment
          fi
          # Remove IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Removing route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route removed for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Route does not exist for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to remove route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
          # Remove IPv6 Route for WAN Failover
          if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ -n "${OLDIPV6ROUTETABLE+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
            if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Deleting route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
              ${ipbinpath}ip -6 route del ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
              || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to delete route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
              && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route deleted for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" ;}
            fi
          fi
        fi
      done
    elif [[ -z "${FWMARK}" ]] &>/dev/null;then
      for IPV6 in ${IPV6S};do
        # Check IPv6 for prefix error
        if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} 2>&1 | grep -e "Error: inet6 prefix is expected rather than")" ]] &>/dev/null;then
          # Add to IPv6 IPSET with prefix fixed
          if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 | grep -w "${IPV6}::")" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding ${IPV6}:: to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'::" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            ipset add ${IPSETPREFIX}-${QUERYPOLICY}-v6 ${IPV6}:: comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add ${IPV6}:: to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Added ${IPV6}:: to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" ;} ;}
            unset comment
          fi
          # Add IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route add ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route added for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Route already exists for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
        else
          # Add to IPv6 IPSET
          if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v6 | grep -wo "${IPV6}")" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding ${IPV6} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            ipset add ${IPSETPREFIX}-${QUERYPOLICY}-v6 ${IPV6} comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add ${IPV6} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Added ${IPV6} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v6" ;} ;}
          fi
          # Add IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route add ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route added for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Route already exists for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
        fi
      done
    fi

    # Save IPv6 IPSET if modified or does not exist
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if [[ "${saveipv6ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Query Policy - Saving IPv6 IPSET for ${QUERYPOLICY}"
      ipset save ${IPSETPREFIX}-${QUERYPOLICY}-v6 -file ${POLICYDIR}/policy_${QUERYPOLICY}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Query Policy - Save IPv6 IPSET for ${QUERYPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to save IPv6 IPSET for ${QUERYPOLICY}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset
  fi

  # IPv4
  # Create IPv4 IPTables OUTPUT Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${QUERYPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Adding IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${QUERYPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Added IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables PREROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${QUERYPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Adding IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${QUERYPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Added IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables POSTROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "'${IPSETPREFIX}'-'${QUERYPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Adding IPTables rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    iptables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${QUERYPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Added IPTables rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add IPTables rule for IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
  fi

  # Add IPv4s to IPSET or create IPv4 Routes or rules and remove old IPv4 Routes or Rules
  if [[ -n "${FWMARK}" ]] &>/dev/null && { [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null || [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null ;};then
    for IPV4 in ${IPV4S};do
      # Add to IPv4 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding ${IPV4} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4"
        comment="$(awk -F ">>" '$2 == "'${IPV4}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
        if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
          comment="$(echo ${comment} | cut -f1 -d",")"
        fi
        ipset add ${IPSETPREFIX}-${QUERYPOLICY}-v4 ${IPV4} comment "${comment}" \
        || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add ${IPV4} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4" \
        && { saveipv4ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Added ${IPV4} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4" ;} ;}
        unset comment
      fi
      # Remove IPv4 Routes
      if [[ "${RGW}" == "0" ]] &>/dev/null;then
        if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Removing route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
          ${ipbinpath}ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to remove route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route removed for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;}
        fi
        if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
          if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Deleting route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}"
            ${ipbinpath}ip route del ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE} &>/dev/null \
            || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to delete route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" \
            && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route deleted for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" ;}
          fi
        fi
      elif [[ "${RGW}" != "0" ]] &>/dev/null;then
        # Remove IPv4 Rules
        if [[ -n "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Removing IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
          ${ipbinpath}ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to remove IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Removed IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" ;}
        fi
      fi
    done
  elif [[ -z "${FWMARK}" ]] &>/dev/null || [[ -z "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
    for IPV4 in ${IPV4S};do
      # Add to IPv4 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding ${IPV4} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4"
        comment="$(awk -F ">>" '$2 == "'${IPV4}'" {print $1}' /tmp/policy_${QUERYPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
        if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
          comment="$(echo ${comment} | cut -f1 -d",")"
        fi
        ipset add ${IPSETPREFIX}-${QUERYPOLICY}-v4 ${IPV4} comment "${comment}" \
        || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add ${IPV4} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4" \
        && { saveipv4ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Added ${IPV4} to IPSET: ${IPSETPREFIX}-${QUERYPOLICY}-v4" ;} ;}
        unset comment
      fi
      # Create IPv4 Routes
      if [[ "${RGW}" == "0" ]] &>/dev/null;then
        if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
          ${ipbinpath}ip route add ${IPV4} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route added for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;}
        fi
        if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
          if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Deleting route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}"
            ${ipbinpath}ip route del ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE} &>/dev/null \
            || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to delete route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" \
            && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Route deleted for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" ;}
          fi
        fi
      elif [[ "${RGW}" != "0" ]] &>/dev/null;then
        # Create IPv4 Rules
        if [[ -z "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Query Policy - Adding IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
          ${ipbinpath}ip rule add from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to add IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Query Policy - Added IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" ;}
        fi
      fi
    done
  fi

  # Save IPv4 IPSET if modified or does not exist
  [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
  if [[ "${saveipv4ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${QUERYPOLICY}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Query Policy - Saving IPv4 IPSET for ${QUERYPOLICY}"
    ipset save ${IPSETPREFIX}-${QUERYPOLICY}-v4 -file ${POLICYDIR}/policy_${QUERYPOLICY}-v4.ipset \
    && logger -p 4 -t "${ALIAS}" "Query Policy - Save IPv4 IPSET for ${QUERYPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Query Policy - ***Error*** Failed to save IPv4 IPSET for ${QUERYPOLICY}"
  fi
  [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset

done

# Set new checkpoint for AdGuardHome log
if [[ "${QUERYADGUARDHOMELOG}" == "1" ]] &>/dev/null && [[ "${POLICY}" == "all" ]] &>/dev/null && [[ -n "${adguardhomelognewcheckpoint+x}" ]] &>/dev/null;then
  echo "${adguardhomelognewcheckpoint}" > ${ADGUARDHOMELOGCHECKPOINT}
fi

if tty >/dev/null 2>&1;then
  printf '\033[K'
fi

# Process Query execution time
queryend="$(date +%s)"
processtime="$((${queryend}-${querystart}))"
logger -p 5 -st "${ALIAS}" "Query Policy - Processing Time: ${processtime} seconds"

# Clear Parameters
unset VERBOSELOGGING PRIVATEIPS INTERFACE IFNAME OLDIFNAME IPV6S IPV4S RGW PRIORITY ROUTETABLE DOMAIN IP FWMARK MASK IPV6ROUTETABLE OLDIPV6ROUTETABLE domainwildcard adguardhomelognewcheckpoint processtime querystart queryend

return
}

# Enable Script
enablescript ()
{
logger -p 5 -t "${ALIAS}" "Enable Script - Enabling Domain VPN Routing"

# Set Process Priority
setprocesspriority

# Check for FWMark Rules to enable
POLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
for POLICY in ${POLICIES};do
  INTERFACE="$(grep -w "${POLICY}" "${CONFIGFILE}" | awk -F"|" '{print $4}')"
  routingdirector || return
  
  # Create IP FWMark Rules
  createipmarkrules
done

# Create Cron Job
cronjob || return

logger -p 4 -t "${ALIAS}" "Enable Script - Enabled Domain VPN Routing"

return
}

# Enable Script
disablescript ()
{
logger -p 5 -t "${ALIAS}" "Disable Script - Disabling Domain VPN Routing"

# Set Process Priority
setprocesspriority

# Check for FWMark Rules to enable
POLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
for POLICY in ${POLICIES};do
  INTERFACE="$(grep -w "${POLICY}" "${CONFIGFILE}" | awk -F"|" '{print $4}')"
  routingdirector || return
  
  # Delete IP FWMark Rules
  deleteipmarkrules
done

# Delete Cron Job
cronjob || return

logger -p 4 -t "${ALIAS}" "Disable Script - Disabled Domain VPN Routing"

return
}

# Check if Script Status is Enabled
checkscriptstatus ()
{
if [[ "${ENABLE}" == "1" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Domain VPN Routing is Enabled"
  return
else
  logger -p 6 -t "${ALIAS}" "Debug - Domain VPN Routing is Disabled"
  return 1
fi
}

# Restore ASN Cache
restoreasncache ()
{
# Check if Domain VPN Routing is enabled
checkscriptstatus || return

# Check if ASNCACHE is enabled
[[ "${ASNCACHE}" == "0" ]] &>/dev/null && return

# Boot Delay Timer
bootdelaytimer

# Set Process Priority
setprocesspriority

# Generate Restore ASN Cache List
if [[ -f "${ASNFILE}" ]] &>/dev/null;then
  RESTOREASNS="$(awk -F"|" '{print $1}' ${ASNFILE})"
  if [[ -z "${RESTOREASNS}" ]] &>/dev/null;then
    logger -p 3 -t "${ALIAS}" "Restore ASN Cache - ***No ASNs Detected***"
    return
  fi
else
  logger -p 3 -t "${ALIAS}" "Restore ASN Cache - ***No ASNs Detected***"
  return
fi

# Query ASNs
for RESTOREASN in ${RESTOREASNS};do
  # Check if IPSET fies exist
  if [[ ! -f "${POLICYDIR}/asn_${RESTOREASN}-v6.ipset" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/asn_${RESTOREASN}-v4.ipset" ]] &>/dev/null &>/dev/null;then
    continue
  fi

  # Get Interface for ASN
  INTERFACE="$(grep -w "${RESTOREASN}" "${ASNFILE}" | awk -F"|" '{print $2}')"
  routingdirector || return
  
  # Restore ASN for IP Subnets
  if tty >/dev/null 2>&1;then
    printf '\033[K%b\r' "${UNDERLINE}Restore ASN: ${RESTOREASN}...${NOCOLOR}\n"
  fi
  
  # Check if IPv6 is enabled and query for IPv6 subnets
  if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
  
    # Restore IPv6 IPSET
    if [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREASN}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/asn_${RESTOREASN}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Restoring IPv6 IPSET for ${RESTOREASN}"
      ipset restore -! <"${POLICYDIR}/asn_${RESTOREASN}-v6.ipset" \
      && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Restored IPv6 IPSET for ${RESTOREASN}" \
      || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to restore IPv6 IPSET for ${RESTOREASN}"
    fi
	
    # Create IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${RESTOREASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Adding IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${RESTOREASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Added IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${RESTOREASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Adding IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${RESTOREASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Added IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "'${IPSETPREFIX}'-'${RESTOREASN}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Adding IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${RESTOREASN}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Added IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi
  fi
	
  # Restore IPv4 IPSET
  if [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREASN}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/asn_${RESTOREASN}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Restoring IPv4 IPSET for ${RESTOREASN}"
    ipset restore -! <"${POLICYDIR}/asn_${RESTOREASN}-v4.ipset" \
    && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Restored IPv4 IPSET for ${RESTOREASN}" \
    || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to restore IPv4 IPSET for ${RESTOREASN}"
  fi
  
  # Create IPv4 IPTables OUTPUT Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${RESTOREASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Adding IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${RESTOREASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Added IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables PREROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${RESTOREASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Adding IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${RESTOREASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Added IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables POSTROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "'${IPSETPREFIX}'-'${RESTOREASN}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore ASN Cache - Adding IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    iptables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${RESTOREASN}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Restore ASN Cache - Added IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Restore ASN Cache - ***Error*** Failed to add IPTables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREASN}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
  fi
  
  # Create IP FWMark Rules
  createipmarkrules
  
done

# Clear Parameters
unset RESTOREASNS INTERFACE IFNAME OLDIFNAME IPV6S IPV4S RGW PRIORITY ROUTETABLE DOMAIN IP FWMARK MASK IPV6ROUTETABLE OLDIPV6ROUTETABLE

return
}

# Restore Existing Policies
restorepolicy ()
{
# Check if Domain VPN Routing is enabled
checkscriptstatus || return

# Boot Delay Timer
bootdelaytimer

# Set Process Priority
setprocesspriority

# Restore Policies
if [[ "${POLICY}" == "all" ]] &>/dev/null;then
  RESTOREPOLICIES="$(awk -F"|" '{print $1}' ${CONFIGFILE})"
  if [[ -z "${RESTOREPOLICIES}" ]] &>/dev/null;then
    logger -p 3 -st "${ALIAS}" "Restore Policy - ***No Policies Detected***"
    return
  fi
elif [[ "${POLICY}" == "$(awk -F "|" '/^'${POLICY}'/ {print $1}' ${CONFIGFILE})" ]] &>/dev/null;then
  RESTOREPOLICIES="${POLICY}"
else
  echo -e "${RED}Policy: ${POLICY} not found${NOCOLOR}"
  return
fi
for RESTOREPOLICY in ${RESTOREPOLICIES};do
  
  # Display Restore Policy
  if [[ "${mode}" == "restorepolicy" ]] &>/dev/null;then
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r' "${BOLD}${UNDERLINE}Restore Policy: ${RESTOREPOLICY}${NOCOLOR}\n"
    fi
  fi
  
  # Check if Verbose Logging is Enabled
  if [[ -z "$(awk -F "|" '/^'${RESTOREPOLICY}'/ {print $5}' ${CONFIGFILE})" ]] &>/dev/null;then
    VERBOSELOGGING="1"
  elif [[ "$(awk -F "|" '/^'${RESTOREPOLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=0" ]] &>/dev/null;then
    VERBOSELOGGING="0"
  elif [[ "$(awk -F "|" '/^'${RESTOREPOLICY}'/ {print $5}' ${CONFIGFILE})" == "VERBOSELOGGING=1" ]] &>/dev/null;then
    VERBOSELOGGING="1"
  fi

  # Determine Domain Policy Files and Interface and Route Table for IP Routes to delete.
  DOMAINIPLIST="$(grep -w "${RESTOREPOLICY}" "${CONFIGFILE}" | awk -F"|" '{print $3}')"
  INTERFACE="$(grep -w "${RESTOREPOLICY}" "${CONFIGFILE}" | awk -F"|" '{print $4}')"
  routingdirector || return

  # Check if Interface State is Up or Down
  if [[ "${STATE}" == "0" ]] &>/dev/null;then
    logger -p 3 -st "${ALIAS}" "Restore Policy - Interface ${INTERFACE} for ${RESTOREPOLICY} is down"
    continue
  fi
  
  # Set Restore Mode to default flags - Mode 1: Does not check IPSet against policy files, Mode 2: Check IPSet against policy files
  restoreipv6mode="0"
  restoreipv4mode="0"

  # Create IPv6 IPSET
  # Check for saved IPSET
  if [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v6.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Restoring IPv6 IPSET for ${RESTOREPOLICY}"
    ipset restore -! <"${POLICYDIR}/policy_${RESTOREPOLICY}-v6.ipset" \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Restored IPv6 IPSET for ${RESTOREPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to restore IPv6 IPSET for ${RESTOREPOLICY}"
	[[ "${restoreipv6mode}" == "0" ]] &>/dev/null && restoreipv6mode="1"
  # Create saved IPv6 IPSET file if IPSET exists
  elif [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v6.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Saving IPv6 IPSET for ${RESTOREPOLICY}"
    ipset save ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -file ${POLICYDIR}/policy_${RESTOREPOLICY}-v6.ipset \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Saved IPv6 IPSET for ${RESTOREPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to save IPv6 IPSET for ${RESTOREPOLICY}"
	[[ "${restoreipv6mode}" == "0" ]] &>/dev/null && restoreipv6mode="1"
  # Create new IPv6 IPSET if it does not exist
  elif [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Creating IPv6 IPSET for ${RESTOREPOLICY}"
    ipset create ${IPSETPREFIX}-${RESTOREPOLICY}-v6 hash:ip family inet6 comment \
    && { saveipv6ipset="1" && logger -p 4 -t "${ALIAS}" "Restore Policy - Created IPv6 IPSET for ${RESTOREPOLICY}" ;} \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to create IPv6 IPSET for ${RESTOREPOLICY}"
	[[ "${restoreipv6mode}" == "0" ]] &>/dev/null && restoreipv6mode="2"
  # Set IPSet restore flag if both IPSET and file exist
  elif [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v6.ipset" ]] &>/dev/null;then
	[[ "${restoreipv6mode}" == "0" ]] &>/dev/null && restoreipv6mode="1"
  fi
  # Create IPv4 IPSET
  # Check for saved IPv4 IPSET
  if [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Restoring IPv4 IPSET for ${RESTOREPOLICY}"
    ipset restore -! <"${POLICYDIR}/policy_${RESTOREPOLICY}-v4.ipset" \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Restored IPv4 IPSET for ${RESTOREPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to restore IPv4 IPSET for ${RESTOREPOLICY}"
	[[ "${restoreipv4mode}" == "0" ]] &>/dev/null && restoreipv4mode="1"
  # Create saved IPv4 IPSET file if IPSET exists
  elif [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ ! -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Saving IPv4 IPSET for ${RESTOREPOLICY}"
    ipset save ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -file ${POLICYDIR}/policy_${RESTOREPOLICY}-v4.ipset \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Saved IPv4 IPSET for ${RESTOREPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to save IPv4 IPSET for ${RESTOREPOLICY}"
	[[ "${restoreipv4mode}" == "0" ]] &>/dev/null && restoreipv4mode="1"
  # Create new IPv4 IPSET if it does not exist
  elif [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Creating IPv4 IPSET for ${RESTOREPOLICY}"
    ipset create ${IPSETPREFIX}-${RESTOREPOLICY}-v4 hash:ip family inet comment \
    && { saveipv4ipset="1" && logger -p 4 -t "${ALIAS}" "Restore Policy - Created IPv4 IPSET for ${RESTOREPOLICY}" ;} \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to create IPv4 IPSET for ${RESTOREPOLICY}"
	[[ "${restoreipv4mode}" == "0" ]] &>/dev/null && restoreipv4mode="2"
  # Set IPSet restore flag if both IPSET and file exist
  elif [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v4.ipset" ]] &>/dev/null;then
	[[ "${restoreipv4mode}" == "0" ]] &>/dev/null && restoreipv4mode="1"
  fi

  # Create IPv4 and IPv6 Arrays from Policy File. 
  IPV6S="$(grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})" "${DOMAINIPLIST}" | sort -u)"
  IPV4S="$(grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" "${DOMAINIPLIST}" | sort -u)"
  
  # Show visual status for updating routes and rules
  if tty >/dev/null 2>&1 && { [[ "${restoreipv6mode}" == "2" ]] || [[ "${restoreipv4mode}" == "2" ]] ;}&>/dev/null;then
    printf '\033[K%b\r' "${LIGHTCYAN}Restore Policy: Restoring IP Routes and IP Rules${NOCOLOR}"
  fi

  # IPv6
  if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
    # Create FWMark IPv6 Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && { [[ -n "${IPV6ADDR}" ]] &>/dev/null || [[ -n "$(${ipbinpath}ip -6 route show default dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null ;} && [[ -z "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${IPV6ROUTETABLE}'") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Checking for IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip -6 rule add from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - Failed to add IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      # Remove FWMark Unreachable IPv6 Rule if it exists
      if [[ -n "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Restore Policy - Checking for Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
        ${ipbinpath}ip -6 rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
        && logger -p 4 -t "${ALIAS}" "Restore Policy - Added Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
        || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add Unreachable IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      fi
    # Create FWMark Unreachable IPv6 Rule
    elif [[ -n "${FWMARK}" ]] &>/dev/null && { [[ -z "${IPV6ADDR}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip -6 route show default dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null ;} && [[ -z "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Checking for Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip -6 rule add unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Added Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add Unreachable IP Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      # Delete FWMark IPv6 Rule if it exists
      if [[ -n "$(${ipbinpath}ip -6 rule list from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip -6 rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${IPV6ROUTETABLE}'") {print}')" ]] &>/dev/null;then
        logger -p 5 -t "${ALIAS}" "Restore Policy - Deleting IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
        ${ipbinpath}ip -6 rule del from all fwmark ${FWMARK}/${MASK} table ${IPV6ROUTETABLE} priority ${PRIORITY} \
        && logger -p 4 -t "${ALIAS}" "Restore Policy - Deleted IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
        || logger -p 2 -st "${ALIAS}" "Restore Policy - Failed to delete IPv6 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      fi
    fi

    # Create IPv6 IP6Tables OUTPUT Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${RESTOREPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Adding IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${RESTOREPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IP6Tables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables PREROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $10 == "'${IPSETPREFIX}'-'${RESTOREPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Adding IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 FWMark: ${FWMARK}"
      ip6tables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${RESTOREPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IP6Tables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 FWMark: ${FWMARK}"
    fi

    # Create IPv6 IP6Tables POSTROUTING Rule
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(ip6tables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $6 == "'${IFNAME}'" && $10 == "'${IPSETPREFIX}'-'${RESTOREPOLICY}'-v6" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Adding IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
      ip6tables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${RESTOREPOLICY}-v6 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IP6Tables POSTROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6 Interface: ${IFNAME} FWMark: ${FWMARK}"
    fi

    # Add IPv6s to IPSET or create IPv6 Routes
    if [[ -n "${FWMARK}" ]] &>/dev/null && [[ "${restoreipv6mode}" == "2" ]] &>/dev/null;then
      for IPV6 in ${IPV6S};do
        # Check IPv6 for prefix error
        if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} 2>&1 | grep -e "Error: inet6 prefix is expected rather than")" ]] &>/dev/null;then
          # Add to IPv6 IPSET with prefix fixed
          if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 | grep -wo "${IPV6}::")" ]] &>/dev/null;then
            comment="$(awk -F ">>" '$2 == "'${IPV6}'::" {print $1}' /tmp/policy_${RESTOREPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding ${IPV6}:: to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6"
            ipset add ${IPSETPREFIX}-${RESTOREPOLICY}-v6 ${IPV6}:: comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add ${IPV6}:: to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Added ${IPV6}:: to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" ;} ;}
            unset comment
          fi
          # Remove IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Removing route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route del ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route removed for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Route does not exist for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to remove route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
          # Remove IPv6 Route for WAN Failover
          if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ -n "${OLDIPV6ROUTETABLE+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
            if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Deleting route for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
              ${ipbinpath}ip -6 route del ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
              || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to delete route for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
              && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route deleted for ${IPV6}:: dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" ;}
            fi
          fi
        else
          # Add to IPv6 IPSET
          if [[ -n "$(ipset list ${IPSETPREFIX}-${QUERYPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 | grep -wo "${IPV6}")" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding ${IPV6} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'" {print $1}' /tmp/policy_${RESTOREPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            ipset add ${IPSETPREFIX}-${RESTOREPOLICY}-v6 ${IPV6} comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add ${IPV6} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Added ${IPV6} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" ;} ;}
            unset comment
          fi
          # Remove IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Removing route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route del ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route removed for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Route does not exist for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to remove route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
          # Remove IPv6 Route for WAN Failover
          if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ -n "${OLDIPV6ROUTETABLE+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
            if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE})" ]] &>/dev/null;then
              [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Deleting route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}"
              ${ipbinpath}ip -6 route del ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE} &>/dev/null \
              || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to delete route for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" \
              && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route deleted for ${IPV6} dev ${OLDIFNAME} table ${OLDIPV6ROUTETABLE}" ;}
            fi
          fi
        fi
      done
    elif [[ -z "${FWMARK}" ]] &>/dev/null;then
      for IPV6 in ${IPV6S};do
        # Check IPv6 for prefix error
        if [[ -n "$(${ipbinpath}ip -6 route list ${IPV6} 2>&1 | grep -e "Error: inet6 prefix is expected rather than")" ]] &>/dev/null;then
          # Add to IPv6 IPSET with prefix fixed
          if [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 | grep -w "${IPV6}::")" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding ${IPV6}:: to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'::" {print $1}' /tmp/policy_${RESTOREPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            ipset add ${IPSETPREFIX}-${RESTOREPOLICY}-v6 ${IPV6}:: comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add ${IPV6}:: to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Added ${IPV6}:: to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" ;} ;}
            unset comment
          fi
          # Add IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip -6 route list ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route add ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route added for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Route already exists for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add route for ${IPV6}:: dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
        else
          # Add to IPv6 IPSET
          if [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v6 | grep -wo "${IPV6}")" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding ${IPV6} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6"
            comment="$(awk -F ">>" '$2 == "'${IPV6}'" {print $1}' /tmp/policy_${RESTOREPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
            if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
              comment="$(echo ${comment} | cut -f1 -d",")"
            fi
            ipset add ${IPSETPREFIX}-${RESTOREPOLICY}-v6 ${IPV6} comment "${comment}" \
            || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add ${IPV6} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" \
            && { saveipv6ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Added ${IPV6} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v6" ;} ;}
          fi
          # Add IPv6 Route
          if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip -6 route list ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            ${ipbinpath}ip -6 route add ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE} &>/dev/null \
            || rc="$?" \
            && { rc="$?" && [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route added for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}" ;}
            # Generate Error Log
            if [[ "${rc+x}" ]] &>/dev/null;then
              continue
            elif [[ "${rc}" == "2" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Route already exists for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            elif [[ "${rc}" != "0" ]] &>/dev/null;then
              logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add route for ${IPV6} dev ${IFNAME} table ${IPV6ROUTETABLE}"
            fi
          fi
        fi
      done
    fi

    # Save IPv6 IPSET if modified or does not exist
    [[ -z "${saveipv6ipset+x}" ]] &>/dev/null && saveipv6ipset="0"
    if [[ "${saveipv6ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v6.ipset" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Saving IPv6 IPSET for ${RESTOREPOLICY}"
      ipset save ${IPSETPREFIX}-${RESTOREPOLICY}-v6 -file ${POLICYDIR}/policy_${RESTOREPOLICY}-v6.ipset \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Save IPv6 IPSET for ${RESTOREPOLICY}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to save IPv6 IPSET for ${RESTOREPOLICY}"
    fi
    [[ -n "${saveipv6ipset+x}" ]] &>/dev/null && unset saveipv6ipset
  fi

  # IPv4
  # Create FWMark IPv4 Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip route show default table ${ROUTETABLE})" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Checking for IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip rule add from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    # Remove FWMark Unreachable IPv4 Rule if it exists
    if [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Checking for Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip rule del unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Added Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
  # Create FWMark Unreachable IPv4 Rule
  elif [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip route show default table ${ROUTETABLE})" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Checking for Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    ${ipbinpath}ip rule add unreachable from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Added Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add Unreachable IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    # Remove FWMark IPv4 Rule if it exists
    if [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
      logger -p 5 -t "${ALIAS}" "Restore Policy - Deleting IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
      ${ipbinpath}ip rule del from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} \
      && logger -p 4 -t "${ALIAS}" "Restore Policy - Deleted IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}" \
      || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to delete IPv4 Rule for Interface: ${INTERFACE} using FWMark: ${FWMARK}/${MASK}"
    fi
  fi

  # Create IPv4 IPTables OUTPUT Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL OUTPUT | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${RESTOREPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Adding IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A OUTPUT -m set --match-set ${IPSETPREFIX}-${RESTOREPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IPTables OUTPUT rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables PREROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL PREROUTING | awk '$3 == "MARK" && $4 == "all" && $11 == "'${IPSETPREFIX}'-'${RESTOREPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Adding IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 FWMark: ${FWMARK}"
    iptables -t mangle -A PREROUTING -m set --match-set ${IPSETPREFIX}-${RESTOREPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IPTables PREROUTING rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 FWMark: ${FWMARK}"
  fi

  # Create IPv4 IPTables POSTROUTING Rule
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ -z "$(iptables -t mangle -nvL POSTROUTING | awk '$3 == "MARK" && $4 == "all" && $7 == "'${IFNAME}'" && $11 == "'${IPSETPREFIX}'-'${RESTOREPOLICY}'-v4" && ( $NF == "'${FWMARK}'" || $NF == "'${FWMARK}'/'${MASK}'")')" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Adding IPTables rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
    iptables -t mangle -A POSTROUTING -o ${IFNAME} -m set --match-set ${IPSETPREFIX}-${RESTOREPOLICY}-v4 dst -j MARK --set-xmark ${FWMARK}/${MASK} \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IPTables rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IPTables rule for IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4 Interface: ${IFNAME} FWMark: ${FWMARK}"
  fi

  # Add IPv4s to IPSET or create IPv4 Routes or rules and remove old IPv4 Routes or Rules
  if [[ -n "${FWMARK}" ]] &>/dev/null && [[ "${restoreipv4mode}" == "2" ]] &>/dev/null && { [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} table ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null || [[ -n "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null ;};then
    for IPV4 in ${IPV4S};do
      # Add to IPv4 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding ${IPV4} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4"
        comment="$(awk -F ">>" '$2 == "'${IPV4}'" {print $1}' /tmp/policy_${RESTOREPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
        if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
          comment="$(echo ${comment} | cut -f1 -d",")"
        fi
        ipset add ${IPSETPREFIX}-${RESTOREPOLICY}-v4 ${IPV4} comment "${comment}" \
        || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add ${IPV4} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4" \
        && { saveipv4ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Added ${IPV4} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4" ;} ;}
        unset comment
      fi
      # Remove IPv4 Routes
      if [[ "${RGW}" == "0" ]] &>/dev/null;then
        if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Removing route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
          ${ipbinpath}ip route del ${IPV4} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to remove route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route removed for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;}
        fi
        if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
          if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Deleting route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}"
            ${ipbinpath}ip route del ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE} &>/dev/null \
            || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to delete route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" \
            && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route deleted for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" ;}
          fi
        fi
      elif [[ "${RGW}" != "0" ]] &>/dev/null;then
        # Remove IPv4 Rules
        if [[ -n "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Removing IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
          ${ipbinpath}ip rule del from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to remove IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Removed IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" ;}
        fi
      fi
    done
  elif [[ -z "${FWMARK}" ]] &>/dev/null || { [[ "${restoreipv4mode}" == "2" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip rule list from all fwmark ${FWMARK}/${MASK} priority ${PRIORITY} 2>/dev/null | grep -w "unreachable" || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "fwmark" && $5 == "'${FWMARK}'/'${MASK}'" && $NF == "unreachable") {print}')" ]] &>/dev/null ;};then
    for IPV4 in ${IPV4S};do
      # Add to IPv4 IPSET
      if [[ -n "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -n 2>/dev/null)" ]] &>/dev/null && [[ -z "$(ipset list ${IPSETPREFIX}-${RESTOREPOLICY}-v4 | grep -wo "${IPV4}")" ]] &>/dev/null;then
        [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding ${IPV4} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4"
        comment="$(awk -F ">>" '$2 == "'${IPV4}'" {print $1}' /tmp/policy_${RESTOREPOLICY}_domaintoIP | sort -u)" && comment=${comment//[$'\t\r\n']/,}
        if [[ "${#comment}" -gt "${IPSETMAXCOMMENTLENGTH}" ]] &>/dev/null;then
          comment="$(echo ${comment} | cut -f1 -d",")"
        fi
        ipset add ${IPSETPREFIX}-${RESTOREPOLICY}-v4 ${IPV4} comment "${comment}" \
        || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add ${IPV4} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4" \
        && { saveipv4ipset="1" && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Added ${IPV4} to IPSET: ${IPSETPREFIX}-${RESTOREPOLICY}-v4" ;} ;}
        unset comment
      fi
      # Create IPv4 Routes
      if [[ "${RGW}" == "0" ]] &>/dev/null;then
        if [[ -n "${IFNAME}" ]] &>/dev/null && [[ -z "$(${ipbinpath}ip route list ${IPV4} dev ${IFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}"
          ${ipbinpath}ip route add ${IPV4} dev ${IFNAME} table ${ROUTETABLE} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add route for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route added for ${IPV4} dev ${IFNAME} table ${ROUTETABLE}" ;}
        fi
        if [[ -n "${OLDIFNAME+x}" ]] &>/dev/null && [[ "${INTERFACE}" == "wan" ]] &>/dev/null;then
          if [[ -n "$(${ipbinpath}ip route list ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE})" ]] &>/dev/null;then
            [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Deleting route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}"
            ${ipbinpath}ip route del ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE} &>/dev/null \
            || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to delete route for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" \
            && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Route deleted for ${IPV4} dev ${OLDIFNAME} table ${ROUTETABLE}" ;}
          fi
        fi
      elif [[ "${RGW}" != "0" ]] &>/dev/null;then
        # Create IPv4 Rules
        if [[ -z "$(${ipbinpath}ip rule list from all to ${IPV4} lookup ${ROUTETABLE} priority ${PRIORITY} 2>/dev/null || ${ipbinpath}ip rule list | awk '($1 == "'${PRIORITY}':" && $2 == "from" && $3 == "all" && $4 == "to" && $5 == "'${IPV4}'" && $NF == "'${ROUTETABLE}'") {print}')" ]] &>/dev/null;then
          [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 5 -t "${ALIAS}" "Restore Policy - Adding IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}"
          ${ipbinpath}ip rule add from all to ${IPV4} table ${ROUTETABLE} priority ${PRIORITY} &>/dev/null \
          || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to add IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" \
          && { [[ "${VERBOSELOGGING}" == "1" ]] &>/dev/null && logger -p 4 -t "${ALIAS}" "Restore Policy - Added IP Rule for ${IPV4} table ${ROUTETABLE} priority ${PRIORITY}" ;}
        fi
      fi
    done
  fi

  # Save IPv4 IPSET if modified or does not exist
  [[ -z "${saveipv4ipset+x}" ]] &>/dev/null && saveipv4ipset="0"
  if [[ "${saveipv4ipset}" == "1" ]] &>/dev/null || [[ ! -f "${POLICYDIR}/policy_${RESTOREPOLICY}-v4.ipset" ]] &>/dev/null;then
    logger -p 5 -t "${ALIAS}" "Restore Policy - Saving IPv4 IPSET for ${RESTOREPOLICY}"
    ipset save ${IPSETPREFIX}-${RESTOREPOLICY}-v4 -file ${POLICYDIR}/policy_${RESTOREPOLICY}-v4.ipset \
    && logger -p 4 -t "${ALIAS}" "Restore Policy - Save IPv4 IPSET for ${RESTOREPOLICY}" \
    || logger -p 2 -st "${ALIAS}" "Restore Policy - ***Error*** Failed to save IPv4 IPSET for ${RESTOREPOLICY}"
  fi
  [[ -n "${saveipv4ipset+x}" ]] &>/dev/null && unset saveipv4ipset

  # Reset Restore flags
  unset restoreipv6mode restoreipv4mode

done

# Clear Parameters
unset INTERFACE IFNAME OLDIFNAME IPV6S IPV4S RGW PRIORITY ROUTETABLE DOMAIN IP FWMARK MASK IPV6ROUTETABLE OLDIPV6ROUTETABLE

if tty >/dev/null 2>&1;then
  printf '\033[K'
fi

# Delete old IPSets Pre-version 2.1.4
if [[ -n "$(ipset list -name | grep -e "DomainVPNRouting-")" ]] &>/dev/null;then
  deleteoldipsetsprev300
fi

# Restore ASN Cache if ASNCACHE is enabled
if [[ "${ASNCACHE}" == "1" ]] &>/dev/null;then
  restoreasncache
fi

return
}

# Cronjob
cronjob ()
{
# Check CHECKINTERVAL Setting for valid range and if not default to 15
if [[ -n "${CHECKINTERVAL+x}" ]] &>/dev/null && { [[ "${CHECKINTERVAL}" -ge "1" ]] &>/dev/null && [[ "${CHECKINTERVAL}" -le "59" ]] &>/dev/null ;};then
  logger -p 6 -t "${ALIAS}" "Debug - CHECKINTERVAL is within valid range: ${CHECKINTERVAL}"
else
  logger -p 6 -t "${ALIAS}" "Debug - CHECKINTERVAL is out of valid range: ${CHECKINTERVAL}"
  CHECKINTERVAL="15"
  logger -p 6 -t "${ALIAS}" "Debug - CHECKINTERVAL using default value: ${CHECKINTERVAL} Minutes"
fi

# Create Cron Job
if [[ "${ENABLE}" == "1" ]] &>/dev/null && [[ "${mode}" != "uninstall" ]] &>/dev/null;then
  logger -p 6 -st "${ALIAS}" "Cron - Checking if Cron Job is Scheduled"

  # Delete old cron job if flag is set by configuration menu
  if [[ -n "${zCHECKINTERVAL+x}" ]] &>/dev/null && [[ -n "$(cru l | grep -w "${0}" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    logger -p 3 -st "${ALIAS}" "Cron - Removing old Cron Job"
    cru d setup_domain_vpn_routing "*/${zCHECKINTERVAL} * * * *" ${0} querypolicy all \
    && logger -p 3 -st "${ALIAS}" "Cron - Removed old Cron Job" \
    || logger -p 2 -st "${ALIAS}" "Cron - ***Error*** Failed to remove old Cron Job"
  fi
  # Create cron job if it does not exist
  if [[ -z "$(cru l | grep -w "${0}" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    logger -p 5 -st "${ALIAS}" "Cron - Creating Cron Job"
    cru a setup_domain_vpn_routing "*/${CHECKINTERVAL} * * * *" ${0} querypolicy all \
    && { logger -p 4 -st "${ALIAS}" "Cron - Created Cron Job" ; echo -e "${GREEN}Created Cron Job${NOCOLOR}" ;} \
    || logger -p 2 -st "${ALIAS}" "Cron - ***Error*** Failed to create Cron Job"
    # Execute initial query policy if interval was changed in configuration
    [[ -n "${zCHECKINTERVAL+x}" ]] &>/dev/null && ${0} querypolicy all &>/dev/null &
  elif [[ -n "$(cru l | grep -w "${0}" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    if tty &>/dev/null;then
      echo -e "${GREEN}Cron Job already exists${NOCOLOR}"
    fi
  fi

# Remove Cron Job
elif [[ "${ENABLE}" == "0" ]] &>/dev/null || [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  if [[ -n "$(cru l | grep -w "${0}" | grep -w "setup_domain_vpn_routing")" ]] &>/dev/null;then
    logger -p 3 -st "${ALIAS}" "Cron - Removing Cron Job"
    cru d setup_domain_vpn_routing "*/${CHECKINTERVAL} * * * *" ${0} querypolicy all \
    && logger -p 3 -st "${ALIAS}" "Cron - Removed Cron Job" \
    || logger -p 2 -st "${ALIAS}" "Cron - ***Error*** Failed to remove Cron Job"
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
  read -p "Are you sure you want to kill ${FRIENDLYNAME}? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
  case ${yn} in
    [Yy]* ) break;;
    [Nn]* ) return;;
    * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
  esac
done

# Determine PIDs to kill
logger -p 6 -t "${ALIAS}" "Debug - Selecting PIDs to kill"
PIDS="$(ps | grep -v "grep" | grep -w "${0}" | awk '{print $1}' | grep -v "$$")"

logger -p 6 -t "${ALIAS}" "Debug - ***Checking if PIDs array is null*** Process ID: ${PIDS}"
if [[ -n "${PIDS+x}" ]] &>/dev/null && [[ -n "${PIDS}" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Killing Process ID: ${PIDS}"
  # Kill PIDs
  until [[ -z "${PIDS}" ]] &>/dev/null;do
    if [[ -z "$(echo "${PIDS}" | grep -o '[0-9]*')" ]] &>/dev/null;then
      logger -p 6 -t "${ALIAS}" "Debug - ***PIDs array is null***"
      break
    fi
    for PID in ${PIDS};do
      if [[ "${PID}" == "$$" ]] &>/dev/null;then
        PIDS="${PIDS//[${PID}$'\t\r\n']/}" && continue
      fi
      [[ -n "$(ps | grep -v "grep" | grep -w "${0}" | awk '{print $1}' | grep -o "${PID}")" ]] \
      && logger -p 1 -st "${ALIAS}" "Restart - Killing ${ALIAS} Process ID: ${PID}" \
        && { kill -9 ${PID} \
        && { PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 1 -st "${ALIAS}" "Restart - Killed ${ALIAS} Process ID: ${PID}" && continue ;} \
        || { [[ -z "$(ps | grep -v "grep" | grep -w "${0}" | grep -w "run\|manual" | awk '{print $1}' | grep -o "${PID}")" ]] &>/dev/null && PIDS=${PIDS//[${PID}$'\t\r\n']/} && continue || PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 2 -st "${ALIAS}" "Restart - ***Error*** Failed to kill ${ALIAS} Process ID: ${PID}" ;} ;} \
      || PIDS="${PIDS//[${PID}$'\t\r\n']/}" && continue
    done
  done
elif [[ "${mode}" != "update" ]] &>/dev/null && { [[ -z "${PIDS+x}" ]] &>/dev/null || [[ -z "${PIDS}" ]] &>/dev/null ;};then
  # Log no PIDs found and return
  logger -p 2 -st "${ALIAS}" "Restart - ***${ALIAS} is not running*** No Process ID Detected"
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
# Check WAN Status
checkwanstatus || return 1

# Read Global Config File
if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  setglobalconfig || return
fi

# Determine Update Channel
if [[ -n "$(echo ${VERSION} | grep -o "alpha")" ]] &>/dev/null;then
  echo -e "${RED}***${ALIAS} current version is an alpha release and does not support automatic updates***${NOCOLOR}"
  return
elif [[ -z "${DEVMODE+x}" ]] &>/dev/null;then
  echo -e "Dev Mode not configured in Global Configuration"
elif [[ "${DEVMODE}" == "0" ]] &>/dev/null;then
  DOWNLOADPATH="${REPO}domain_vpn_routing.sh"
elif [[ "${DEVMODE}" == "1" ]] &>/dev/null;then
  DOWNLOADPATH="${REPO}domain_vpn_routing-beta.sh"
fi

# Determine if newer version is available
REMOTEVERSION="$(echo "$(/usr/sbin/curl "${DOWNLOADPATH}" 2>/dev/null | grep -v "grep" | grep -w "# Version:" | awk '{print $3}')")"

# Remote Checksum
if [[ -f "/usr/sbin/openssl" ]] &>/dev/null;then
  REMOTECHECKSUM="$(/usr/sbin/curl -s "${DOWNLOADPATH}" | /usr/sbin/openssl sha256 | awk -F " " '{print $2}')"
elif [[ -f "/usr/bin/md5sum" ]] &>/dev/null;then
  REMOTECHECKSUM="$(echo "$(/usr/sbin/curl -s "${DOWNLOADPATH}" 2>/dev/null | /usr/bin/md5sum | awk -F " " '{print $1}')")"
fi

# Convert versions in numbers for evaluation
if [[ "${DEVMODE}" == "0" ]] &>/dev/null;then
  version="$(echo ${VERSION} | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && version=${version//[$'\t\r\n']/}
  remoteversion="$(echo ${REMOTEVERSION} | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && remoteversion=${remoteversion//[$'\t\r\n']/}
elif [[ "${DEVMODE}" == "1" ]] &>/dev/null;then
  if [[ -n "$(echo ${REMOTEVERSION} | grep -e "beta")" ]] &>/dev/null;then
    version="$(echo ${VERSION} | grep -o '[0-9]*')" && version=${version//[$'\t\r\n']/}
    remoteversion="$(echo ${REMOTEVERSION} | grep -o '[0-9]*')" && remoteversion=${remoteversion//[$'\t\r\n']/}
  elif [[ -z "$(echo ${REMOTEVERSION} | grep -e "beta")" ]] &>/dev/null;then
    version="$(echo ${VERSION} | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && version=${version//[$'\t\r\n']/}
    remoteversion="$(echo ${REMOTEVERSION} | awk -F "-beta" '{print $1}' | grep -o '[0-9]*')" && remoteversion=${remoteversion//[$'\t\r\n']/}
  fi
fi

if [[ "${version}" -lt "${remoteversion}" ]] &>/dev/null;then
  logger -p 3 -t "${ALIAS}" "${ALIAS} is out of date - Current Version: ${VERSION} Available Version: ${REMOTEVERSION}"
  [[ "${DEVMODE}" == "1" ]] &>/dev/null && echo -e "${RED}***Dev Mode is Enabled***${NOCOLOR}"
  echo -e "${YELLOW}${ALIAS} is out of date - Current Version: ${LIGHTBLUE}${VERSION}${YELLOW} Available Version: ${LIGHTCYAN}${REMOTEVERSION}${NOCOLOR}${NOCOLOR}"
  while true &>/dev/null;do
    if [[ "${DEVMODE}" == "0" ]] &>/dev/null;then
      read -r -p "Do you want to update to the latest production version? ${REMOTEVERSION} ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    elif [[ "${DEVMODE}" == "1" ]] &>/dev/null;then
      read -r -p "Do you want to update to the latest beta version? ${REMOTEVERSION} ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    fi
    case ${yn} in
      [Yy]* ) break;;
      [Nn]* ) unset passiveupdate && return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "${DOWNLOADPATH}" -o "${0}" 2>/dev/null && chmod 755 ${0} \
  && { logger -p 4 -st "${ALIAS}" "Update - ${ALIAS} has been updated to version: ${REMOTEVERSION}" && killscript ;} \
  || logger -p 2 -st "${ALIAS}" "Update - ***Error*** Failed to update ${ALIAS} to version: ${REMOTEVERSION}"
elif [[ "${version}" == "${remoteversion}" ]] &>/dev/null;then
  logger -p 5 -t "${ALIAS}" "${ALIAS} is up to date - Version: ${VERSION}"
  if [[ "${CHECKSUM}" != "${REMOTECHECKSUM}" ]] &>/dev/null;then
    logger -p 2 -st "${ALIAS}" "***${ALIAS} failed Checksum Check*** Current Checksum: ${CHECKSUM}  Valid Checksum: ${REMOTECHECKSUM}"
    echo -e "${RED}***Checksum Failed***${NOCOLOR}"
    echo -e "${LIGHTGRAY}Current Checksum: ${LIGHTRED}${CHECKSUM}  ${LIGHTGRAY}Valid Checksum: ${GREEN}${REMOTECHECKSUM}${NOCOLOR}"
  fi
  while true &>/dev/null;do  
    read -r -p "${ALIAS} is up to date. Do you want to reinstall ${ALIAS} Version: ${VERSION}? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
    case ${yn} in
      [Yy]* ) break;;
      [Nn]* ) unset passiveupdate && return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  /usr/sbin/curl -s "${DOWNLOADPATH}" -o "${0}" 2>/dev/null && chmod 755 ${0} \
  && { logger -p 4 -st "${ALIAS}" "Update - ${ALIAS} has reinstalled version: ${VERSION}" && killscript ;} \
  || logger -p 2 -st "${ALIAS}" "Update - ***Error*** Failed to reinstall ${ALIAS} with version: ${VERSION}"
elif [[ "${version}" -gt "${remoteversion}" ]] &>/dev/null;then
  echo -e "${LIGHTMAGENTA}${ALIAS} is newer than Available Version: ${REMOTEVERSION} ${NOCOLOR}- ${LIGHTCYAN}Current Version: ${VERSION}${NOCOLOR}"
fi

return
}

# Get System Parameters
getsystemparameters ()
{
# Get Global System Parameters
while [[ -z "${systemparameterssync+x}" ]] &>/dev/null || [[ "${systemparameterssync}" == "0" ]] &>/dev/null;do
  if [[ -z "${systemparameterssync+x}" ]] &>/dev/null;then
    systemparameterssync="0"
  elif [[ "${systemparameterssync}" == "1" ]] &>/dev/null;then
    break
  else
    sleep 1
  fi
  
  # Boot Delay Timer
  bootdelaytimer
  
  # PRODUCTID
  if [[ -z "${PRODUCTID+x}" ]] &>/dev/null;then
    PRODUCTID="$(nvram get productid & nvramcheck)"
    [[ -n "${PRODUCTID}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set PRODUCTID" && unset PRODUCTID && continue ;}
  fi
  
  # Set number of OVPN Client Slots
  if [[ "${PRODUCTID}" == "RT-AC68U" ]] &>/dev/null || [[ "${PRODUCTID}" == "DSL-AC68U" ]] &>/dev/null;then
	ovpncslots="2"
    wgcslots="0"
  else
    ovpncslots="5"
    wgcslots="5"
  fi
  
  # IPSYSVERSION
  if [[ -z "${IPSYSVERSION+x}" ]] &>/dev/null;then
    IPSYSVERSION="$(/usr/sbin/ip -V | awk -F "-" '/iproute2/ {print $2}')"
    [[ -n "${IPSYSVERSION}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set IPSYSVERSION" && unset IPSYSVERSION && continue ;}
	if [[ "${IPSYSVERSION}" == "ss150210" ]] &>/dev/null;then
	  IPSYSVERSION="3.19.0"
    fi
  fi
  
  # IPOPTVERSION
  if [[ -z "${IPOPTVERSION+x}" ]] &>/dev/null && [[ -f "/opt/sbin/ip" ]] &>/dev/null;then
    IPOPTVERSION="$(/opt/sbin/ip -V | awk -F "-" '/iproute2/ {print $2}')"
    [[ -n "${IPOPTVERSION}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set IPOPTVERSION" && unset IPOPTVERSION && continue ;}
	if [[ "${IPOPTVERSION}" == "ss4.4.0" ]] &>/dev/null;then
	  IPOPTVERSION="4.4.0"
    fi
  elif [[ -z "${IPOPTVERSION+x}" ]] &>/dev/null && [[ ! -f "/opt/sbin/ip" ]] &>/dev/null;then
    IPOPTVERSION=""
  fi
  
  # WANSDUALWANENABLE
  if [[ -z "${WANSDUALWANENABLE+x}" ]] &>/dev/null;then
    wansdualwanenable="$(nvram get wans_dualwan & nvramcheck)"
    [[ -n "$(echo "${wansdualwanenable}" | awk '{if ($0 != "" && $2 != "none") {print $2}}')" ]] &>/dev/null && WANSDUALWANENABLE="1" || WANSDUALWANENABLE="0"
    [[ -n "${WANSDUALWANENABLE}" ]] &>/dev/null && unset wansdualwanenable || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WANSDUALWANENABLE" && unset WANSDUALWANENABLE && continue ;}
  fi

  # IPV6SERVICE
  if [[ -z "${IPV6SERVICE+x}" ]] &>/dev/null;then
    IPV6SERVICE="$(nvram get ipv6_service & nvramcheck)"
    [[ -n "${IPV6SERVICE}" ]] &>/dev/null && logger -p 6 -t "${ALIAS}" "Debug - IPv6 Service: ${IPV6SERVICE}" || { logger -p 6 -t "${ALIAS}" "Debug - failed to set IPV6SERVICE" && unset IPV6SERVICE && continue ;}
  fi

  # IPV6IPADDR
  if [[ -z "${IPV6IPADDR+x}" ]] &>/dev/null;then
    IPV6IPADDR="$(nvram get ipv6_wan_addr & nvramcheck)"
    { [[ -n "${IPV6IPADDR}" ]] &>/dev/null || [[ "${IPV6SERVICE}" == "disabled" ]] &>/dev/null || [[ -z "$(nvram get ipv6_wan_addr & nvramcheck)" ]] &>/dev/null ;} \
    || { logger -p 6 -t "${ALIAS}" "Debug - failed to set IPV6IPADDR" && unset IPV6IPADDR && continue ;}
  fi

  # WAN0STATE
  if [[ -z "${WAN0STATE+x}" ]] &>/dev/null;then
    WAN0STATE="$(nvram get wan0_state_t & nvramcheck)"
    [[ -n "${WAN0STATE}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN0STATE" && unset WAN0STATE && continue ;}
  fi

  # WAN0GWIFNAME
  if [[ -z "${WAN0GWIFNAME+x}" ]] &>/dev/null;then
    WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
    [[ -n "${WAN0GWIFNAME}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN0GWIFNAME" && unset WAN0GWIFNAME && continue ;}
  fi

  # WAN0IPV6ADDR
  if [[ -z "${WAN0IPV6ADDR+x}" ]] &>/dev/null;then
    WAN0IPV6ADDR="$(ifconfig ${WAN0GWIFNAME} 2>/dev/null | grep "inet6 addr.*Scope:Global" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
  fi

  # WAN0GATEWAY
  if [[ -z "${WAN0GATEWAY+x}" ]] &>/dev/null;then
    WAN0GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
    [[ -n "${WAN0GATEWAY}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN0GATEWAY" && unset WAN0GATEWAY && continue ;}
  fi

  # WAN0PRIMARY
  if [[ -z "${WAN0PRIMARY+x}" ]] &>/dev/null;then
    WAN0PRIMARY="$(nvram get wan0_primary & nvramcheck)"
    if [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
      [[ -n "${WAN0PRIMARY}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN0PRIMARY" && unset WAN0PRIMARY && continue ;}
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
    { [[ -n "${WAN1STATE}" ]] &>/dev/null || [[ "${WANSDUALWANENABLE}" == "0" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN1STATE" && unset WAN1STATE && continue ;}
  fi

  # WAN1GWIFNAME
  if [[ -z "${WAN1GWIFNAME+x}" ]] &>/dev/null;then
    WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
    if [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
      [[ -n "${WAN1GWIFNAME}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN1GWIFNAME" && unset WAN1GWIFNAME && continue ;}
    fi
  fi

  # WAN1IPV6ADDR
  if [[ -z "${WAN1IPV6ADDR+x}" ]] &>/dev/null;then
    WAN1IPV6ADDR="$(ifconfig ${WAN1GWIFNAME} 2>/dev/null | grep "inet6 addr.*Scope:Global" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
  fi

  # WAN1GATEWAY
  if [[ -z "${WAN1GATEWAY+x}" ]] &>/dev/null;then
    WAN1GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
    if [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
      [[ -n "${WAN1GATEWAY}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN1GATEWAY" && unset WAN1GATEWAY && continue ;}
    fi
  fi

  # WAN1PRIMARY
  if [[ -z "${WAN1PRIMARY+x}" ]] &>/dev/null;then
    WAN1PRIMARY="$(nvram get wan1_primary & nvramcheck)"
    if [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
      [[ -n "${WAN1PRIMARY}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WAN1PRIMARY" && unset WAN1PRIMARY && continue ;}
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

  if [[ "${ovpncslots}" -ge "1" ]] &>/dev/null;then
    # OVPNC1STATE
    if [[ -z "${OVPNC1STATE+x}" ]] &>/dev/null;then
      OVPNC1STATE="$(nvram get vpn_client1_state & nvramcheck)"
      { [[ -n "${OVPNC1STATE}" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client1" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC1STATE" && unset OVPNC1STATE && continue ;}
    fi

    # OVPNC1IFNAME
    if [[ -z "${OVPNC1IFNAME+x}" ]] &>/dev/null;then
      OVPNC1IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
    fi

    # OVPNC1IPV6ADDR
    if [[ -z "${OVPNC1IPV6ADDR+x}" ]] &>/dev/null;then
      OVPNC1IPV6ADDR="$(awk '$1 == "ifconfig-ipv6" {print $2}' /etc/openvpn/client1/config.ovpn 2>/dev/null | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi

    # OVPNC1RGW
    if [[ -z "${OVPNC1RGW+x}" ]] &>/dev/null;then
      OVPNC1RGW="$(nvram get vpn_client1_rgw & nvramcheck)"
      [[ -n "${OVPNC1RGW}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC1RGW" && unset OVPNC1RGW && continue ;}
    fi

    # OVPNC1IPV6VPNGW
    if [[ -z "${OVPNC1IPV6VPNGW+x}" ]] &>/dev/null;then
      OVPNC1IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client1/config.ovpn 2>/dev/null)"
    fi
  fi

  if [[ "${ovpncslots}" -ge "2" ]] &>/dev/null;then
    # OVPNC2STATE
    if [[ -z "${OVPNC2STATE+x}" ]] &>/dev/null;then
      OVPNC2STATE="$(nvram get vpn_client2_state & nvramcheck)"
      { [[ -n "${OVPNC2STATE}" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client2" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC2STATE" && unset OVPNC2STATE && continue ;}
    fi

    # OVPNC2IFNAME
    if [[ -z "${OVPNC2IFNAME+x}" ]] &>/dev/null;then
      OVPNC2IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client2/config.ovpn 2>/dev/null)"
    fi

    # OVPNC2IPV6ADDR
    if [[ -z "${OVPNC2IPV6ADDR+x}" ]] &>/dev/null;then
      OVPNC2IPV6ADDR="$(awk '$1 == "ifconfig-ipv6" {print $2}' /etc/openvpn/client2/config.ovpn 2>/dev/null | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi

    # OVPNC2RGW
    if [[ -z "${OVPNC2RGW+x}" ]] &>/dev/null;then
      OVPNC2RGW="$(nvram get vpn_client2_rgw & nvramcheck)"
      [[ -n "${OVPNC2RGW}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC2RGW" && unset OVPNC2RGW && continue ;}
    fi

    # OVPNC2IPV6VPNGW
    if [[ -z "${OVPNC2IPV6VPNGW+x}" ]] &>/dev/null;then
      OVPNC2IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client2/config.ovpn 2>/dev/null)"
    fi
  fi
  
  if [[ "${ovpncslots}" -ge "3" ]] &>/dev/null;then
    # OVPNC3STATE
    if [[ -z "${OVPNC3STATE+x}" ]] &>/dev/null;then
      OVPNC3STATE="$(nvram get vpn_client3_state & nvramcheck)"
      { [[ -n "${OVPNC3STATE}" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client3" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC3STATE" && unset OVPNC3STATE && continue ;}
    fi

    # OVPNC3IFNAME
    if [[ -z "${OVPNC3IFNAME+x}" ]] &>/dev/null;then
      OVPNC3IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client3/config.ovpn 2>/dev/null)"
    fi

    # OVPNC3IPV6ADDR
    if [[ -z "${OVPNC3IPV6ADDR+x}" ]] &>/dev/null;then
      OVPNC3IPV6ADDR="$(awk '$1 == "ifconfig-ipv6" {print $2}' /etc/openvpn/client3/config.ovpn 2>/dev/null | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi

    # OVPNC3RGW
    if [[ -z "${OVPNC3RGW+x}" ]] &>/dev/null;then
      OVPNC3RGW="$(nvram get vpn_client3_rgw & nvramcheck)"
      [[ -n "${OVPNC3RGW}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC3RGW" && unset OVPNC3RGW && continue ;}
    fi

    # OVPNC3IPV6VPNGW
    if [[ -z "${OVPNC3IPV6VPNGW+x}" ]] &>/dev/null;then
      OVPNC3IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client3/config.ovpn 2>/dev/null)"
    fi
  fi
	
  if [[ "${ovpncslots}" -ge "4" ]] &>/dev/null;then
    # OVPNC4STATE
    if [[ -z "${OVPNC4STATE+x}" ]] &>/dev/null;then
      OVPNC4STATE="$(nvram get vpn_client4_state & nvramcheck)"
      { [[ -n "${OVPNC4STATE}" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client4" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC4STATE" && unset OVPNC4STATE && continue ;}
    fi

    # OVPNC4IFNAME
    if [[ -z "${OVPNC4IFNAME+x}" ]] &>/dev/null;then
      OVPNC4IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client4/config.ovpn 2>/dev/null)"
    fi

    # OVPNC4IPV6ADDR
    if [[ -z "${OVPNC4IPV6ADDR+x}" ]] &>/dev/null;then
      OVPNC4IPV6ADDR="$(awk '$1 == "ifconfig-ipv6" {print $2}' /etc/openvpn/client4/config.ovpn 2>/dev/null | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi

    # OVPNC4RGW
    if [[ -z "${OVPNC4RGW+x}" ]] &>/dev/null;then
      OVPNC4RGW="$(nvram get vpn_client4_rgw & nvramcheck)"
      [[ -n "${OVPNC4RGW}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC4RGW" && unset OVPNC4RGW && continue ;}
    fi

    # OVPNC4IPV6VPNGW
    if [[ -z "${OVPNC4IPV6VPNGW+x}" ]] &>/dev/null;then
      OVPNC4IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client4/config.ovpn 2>/dev/null)"
    fi
  fi
  
  if [[ "${ovpncslots}" -ge "5" ]] &>/dev/null;then
    # OVPNC5STATE
    if [[ -z "${OVPNC5STATE+x}" ]] &>/dev/null;then
      OVPNC5STATE="$(nvram get vpn_client5_state & nvramcheck)"
      { [[ -n "${OVPNC5STATE}" ]] &>/dev/null || [[ ! -d "/etc/openvpn/client5" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC5STATE" && unset OVPNC5STATE && continue ;}
    fi

    # OVPNC5IFNAME
    if [[ -z "${OVPNC5IFNAME+x}" ]] &>/dev/null;then
      OVPNC5IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/client5/config.ovpn 2>/dev/null)"
    fi

    # OVPNC5IPV6ADDR
    if [[ -z "${OVPNC5IPV6ADDR+x}" ]] &>/dev/null;then
      OVPNC5IPV6ADDR="$(awk '$1 == "ifconfig-ipv6" {print $2}' /etc/openvpn/client5/config.ovpn 2>/dev/null | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi

    # OVPNC5RGW
    if [[ -z "${OVPNC5RGW+x}" ]] &>/dev/null;then
      OVPNC5RGW="$(nvram get vpn_client5_rgw & nvramcheck)"
      [[ -n "${OVPNC5RGW}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set OVPNC5RGW" && unset OVPNC5RGW && continue ;}
    fi

    # OVPNC5IPV6VPNGW
    if [[ -z "${OVPNC5IPV6VPNGW+x}" ]] &>/dev/null;then
      OVPNC5IPV6VPNGW="$(awk '$1 == "ifconfig-ipv6" {print $3}' /etc/openvpn/client5/config.ovpn 2>/dev/null)"
    fi
  fi

  # OVPNS1IFNAME
  if [[ -z "${OVPNS1IFNAME+x}" ]] &>/dev/null;then
    OVPNS1IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server1/config.ovpn 2>/dev/null)"
  fi

  # OVPNS2IFNAME
  if [[ -z "${OVPNS2IFNAME+x}" ]] &>/dev/null;then
    OVPNS2IFNAME="$(awk '$1 == "dev" {print $2}' /etc/openvpn/server2/config.ovpn 2>/dev/null)"
  fi

  if [[ "${wgcslots}" -ge "1" ]] &>/dev/null;then
    # WGC1STATE
    if [[ -z "${WGC1STATE+x}" ]] &>/dev/null;then
      WGC1STATE="$(nvram get wgc1_enable & nvramcheck)"
      { [[ -n "${WGC1STATE}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc1_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC1STATE" && unset WGC1STATE && continue ;}
    fi
  
    # WGC1IPADDR
    if [[ -z "${WGC1IPADDR+x}" ]] &>/dev/null;then
      WGC1IPADDR="$(nvram get wgc1_addr & nvramcheck)"
      { [[ -n "${WGC1IPADDR}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc1_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC1IPADDR" && unset WGC1IPADDR && continue ;}
    fi

    # WGC1IPV6ADDR
    if [[ -z "${WGC1IPV6ADDR+x}" ]] &>/dev/null;then
      WGC1IPV6ADDR="$(ifconfig wgc1 2>/dev/null | grep "inet6 addr.*Scope:Global" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi
  fi

  if [[ "${wgcslots}" -ge "2" ]] &>/dev/null;then
    # WGC2STATE
    if [[ -z "${WGC2STATE+x}" ]] &>/dev/null;then
      WGC2STATE="$(nvram get wgc2_enable & nvramcheck)"
      { [[ -n "${WGC2STATE}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc2_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC2STATE" && unset WGC2STATE && continue ;}
    fi

    # WGC2IPADDR
    if [[ -z "${WGC2IPADDR+x}" ]] &>/dev/null;then
      WGC2IPADDR="$(nvram get wgc2_addr & nvramcheck)"
      { [[ -n "${WGC2IPADDR}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc2_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC2IPADDR" && unset WGC2IPADDR && continue ;}
    fi

    # WGC2IPV6ADDR
    if [[ -z "${WGC2IPV6ADDR+x}" ]] &>/dev/null;then
      WGC2IPV6ADDR="$(ifconfig wgc2 2>/dev/null | grep "inet6 addr.*Scope:Global" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi
  fi

  if [[ "${wgcslots}" -ge "3" ]] &>/dev/null;then
    # WGC3STATE
    if [[ -z "${WGC3STATE+x}" ]] &>/dev/null;then
      WGC3STATE="$(nvram get wgc3_enable & nvramcheck)"
      { [[ -n "${WGC3STATE}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc3_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC3STATE" && unset WGC3STATE && continue ;}
    fi

    # WGC3IPADDR
    if [[ -z "${WGC3IPADDR+x}" ]] &>/dev/null;then
      WGC3IPADDR="$(nvram get wgc3_addr & nvramcheck)"
      { [[ -n "${WGC3IPADDR}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc3_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC3IPADDR" && unset WGC3IPADDR && continue ;}
    fi

    # WGC3IPV6ADDR
    if [[ -z "${WGC3IPV6ADDR+x}" ]] &>/dev/null;then
      WGC3IPV6ADDR="$(ifconfig wgc3 2>/dev/null | grep "inet6 addr.*Scope:Global" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi
  fi

  if [[ "${wgcslots}" -ge "4" ]] &>/dev/null;then
    # WGC4STATE
    if [[ -z "${WGC4STATE+x}" ]] &>/dev/null;then
      WGC4STATE="$(nvram get wgc4_enable & nvramcheck)"
      { [[ -n "${WGC4STATE}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc4_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC4STATE" && unset WGC4STATE && continue ;}
    fi

    # WGC4IPADDR
    if [[ -z "${WGC4IPADDR+x}" ]] &>/dev/null;then
      WGC4IPADDR="$(nvram get wgc4_addr & nvramcheck)"
      { [[ -n "${WGC4IPADDR}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc4_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC4IPADDR" && unset WGC4IPADDR && continue ;}
    fi

    # WGC4IPV6ADDR
    if [[ -z "${WGC4IPV6ADDR+x}" ]] &>/dev/null;then
      WGC4IPV6ADDR="$(ifconfig wgc4 2>/dev/null | grep "inet6 addr.*Scope:Global" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi
  fi

  if [[ "${wgcslots}" -ge "5" ]] &>/dev/null;then
    # WGC5STATE
    if [[ -z "${WGC5STATE+x}" ]] &>/dev/null;then
      WGC5STATE="$(nvram get wgc5_enable & nvramcheck)"
      { [[ -n "${WGC5STATE}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc5_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC5STATE" && unset WGC5STATE && continue ;}
    fi

    # WGC5IPADDR
    if [[ -z "${WGC5IPADDR+x}" ]] &>/dev/null;then
      WGC5IPADDR="$(nvram get wgc5_addr & nvramcheck)"
      { [[ -n "${WGC5IPADDR}" ]] &>/dev/null || [[ ! -s "/etc/wg/wgc5_status" ]] &>/dev/null ;} || { logger -p 6 -t "${ALIAS}" "Debug - failed to set WGC5IPADDR" && unset WGC5IPADDR && continue ;}
    fi

    # WGC5IPV6ADDR
    if [[ -z "${WGC5IPV6ADDR+x}" ]] &>/dev/null;then
      WGC5IPV6ADDR="$(ifconfig wgc5 2>/dev/null | grep "inet6 addr.*Scope:Global" | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})")"
    fi
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

  # ENTWAREINSTALLED
  if [[ -f "/jffs/scripts/post-mount" ]] &>/dev/null && [[ -n "$(grep -w ". /jffs/addons/amtm/mount-entware.mod # Added by amtm" /jffs/scripts/post-mount)" ]] &>/dev/null;then
    logger -p 6 -t "${ALIAS}" "Debug - Entware is installed"
    ENTWAREINSTALLED="1"
    ENTWAREMOUNTED="0"
    i="1"
    while [[ "${i}" -le "${ENTWAREMOUNTCHECKS}" ]] &>/dev/null;do
	  if [[ -d "/opt/bin" ]] &>/dev/null;then
        ENTWAREMOUNTED="1"
        logger -p 6 -t "${ALIAS}" "Debug - Entware is mounted to /opt/bin"
        break
      else
        [[ "${i}" == "1" ]] &>/dev/null && logger -p 6 -t "${ALIAS}" "Debug - Entware is not mounted to /opt/bin"
        [[ "${i}" != "${ENTWAREMOUNTCHECKS}" ]] &>/dev/null && logger -p 6 -t "${ALIAS}" "Debug - Continuing to check if Entware is mounted to /opt/bin for $((${ENTWAREMOUNTCHECKS}-${i})) more attempts"
        i="$((${i}+1))"
        sleep 1
        continue
      fi
    done
    unset i
    [[ "${ENTWAREMOUNTED}" == "0" ]] &>/dev/null && logger -p 2 -t "${ALIAS}" "Entware - ***Error*** Entware failed to mount to /opt/bin"
  else
    ENTWAREINSTALLED="0"
    ENTWAREPATH=""
    ENTWAREMOUNTED="0"
  fi
  
  # DIGINSTALLED
  if [[ "${ENTWAREMOUNTED}" == "1" ]] &>/dev/null && [[ -f "/opt/bin/dig" ]] &>/dev/null;then
    DIGINSTALLED="1"
  else
    DIGINSTALLED="0"
  fi
  
  # JQINSTALLED
  if [[ "${ENTWAREMOUNTED}" == "1" ]] &>/dev/null && [[ -f "/opt/bin/jq" ]] &>/dev/null;then
    JQINSTALLED="1"
  else
    JQINSTALLED="0"
  fi
  
  # PYTHON3INSTALLED
  if [[ "${ENTWAREMOUNTED}" == "1" ]] &>/dev/null && [[ -f "/opt/bin/python3" ]] &>/dev/null;then
    PYTHON3INSTALLED="1"
  else
    PYTHON3INSTALLED="0"
  fi

  # ADGUARDHOMEACTIVE
  if [[ -n "$(pidof AdGuardHome)" ]] &>/dev/null || { [[ -f "/opt/etc/AdGuardHome/.config" ]] &>/dev/null && [[ -n "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ]] &>/dev/null ;};then
    ADGUARDHOMEACTIVE="1"
  else
    ADGUARDHOMEACTIVE="0"
  fi
  
  # ADGUARDHOMELOGENABLED
  if [[ "${ADGUARDHOMEACTIVE}" == "1" ]] &>/dev/null && [[ -f "${ADGUARDHOMELOGFILE}" ]] &>/dev/null;then
    ADGUARDHOMELOGENABLED="1"
  else
    ADGUARDHOMELOGENABLED="0"
  fi
  
  # DOTENABLED
  if [[ -z "${DOTENABLED+x}" ]] &>/dev/null;then
    DOTENABLED="$(nvram get dnspriv_enable & nvramcheck)"
    [[ -n "${DOTENABLED}" ]] &>/dev/null || { logger -p 6 -t "${ALIAS}" "Debug - failed to set DOTENABLED" && unset DOTENABLED && continue ;}
  fi
  
  # DOTDNSSERVERS
  if [[ "${DOTENABLED}" == "1" ]] &>/dev/null;then
    dotdnsservers="$(nvram get dnspriv_rulelist & nvramcheck)"
	if [[ -n "${dotdnsservers}" ]] &>/dev/null;then
      if [[ "${IPV6SERVICE}" != "disabled" ]] &>/dev/null;then
	    DOTDNSSERVERS="$(echo ${dotdnsservers} | grep -oE "(([[:xdigit:]]{1,4}::?){1,7}[[:xdigit:]|::]{1,4})|((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))")"
      else
        DOTDNSSERVERS="$(echo ${dotdnsservers} | grep -oE "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))")"
      fi
      unset dotdnsservers
	else
      logger -p 6 -t "${ALIAS}" "Debug - failed to set DOTDNSSERVERS"
	  unset dotdnsservers DOTDNSSERVERS
	  continue
    fi
  else
    DOTDNSSERVERS=""
  fi

 systemparameterssync="1"
done

unset systemparameterssync

return
}

# Test IP binary version
testipversion ()
{
  # CHECK IPVERSION and IPOPTVERSION are set
  if [[ -z "${IPSYSVERSION+x}" ]] &>/dev/null || [[ -z "${IPOPTVERSION+x}" ]] &>/dev/null;then
    getsystemparameters || return
  fi
  
  # Check if IPOPTVERSION is newer than IPVERSION
  highestipversion="$(printf "${IPSYSVERSION}\n${IPOPTVERSION}\n" | sort -r | head -n1)"
  if [[ "${IPSYSVERSION}" == "${highestipversion}" ]] &>/dev/null || [[ -z "${IPOPTVERSION}" ]] &>/dev/null;then
    ipbinpath="/usr/sbin/"
    IPVERSION="${IPSYSVERSION}"
  elif [[ "${IPOPTVERSION}" == "${highestipversion}" ]] &>/dev/null;then
    ipbinpath="/opt/sbin/"
    IPVERSION="${IPOPTVERSION}"
  fi
  
  logger -p 5 -t "${ALIAS}" "Test IP Version - Testing IP Version: ${IPVERSION}"
  ${ipbinpath}ip rule list all &>/dev/null \
  && { ipcompmode="1" ; ipversionwarning="" ; logger -p 4 -t "${ALIAS}" "Test IP Version - IP Version: ${IPVERSION} passed" ;} \
  || { ipcompmode="2" ; ipversionwarning="***This version may have compatibility issues***" ; logger -p 1 -t "${ALIAS}" "Test IP Version - ${FRIENDLYNAME} may have compatibility issues with IP Version: ${IPVERSION}" ;}

  return
}

# Boot Delay Timer
bootdelaytimer ()
{
# Check bootdelayinitialized flag
if [[ -z "${bootdelayinitialized+x}" ]] &>/dev/null;then
  bootdelayinitialized="0"
elif [[ "${bootdelayinitialized}" == "1" ]] &>/dev/null;then
  return
fi

# Get Global Configuration
if [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  setglobalconfig || return
fi

# Check Boot Delay Timer
if [[ -n "${BOOTDELAYTIMER+x}" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - System Uptime: $(awk -F "." '{print $1}' "/proc/uptime") Seconds"
  logger -p 6 -t "${ALIAS}" "Debug - Boot Delay Timer: ${BOOTDELAYTIMER} Seconds"
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "${BOOTDELAYTIMER}" ]] &>/dev/null;then
    logger -p 4 -st "${ALIAS}" "Boot Delay - Waiting for System Uptime to reach ${BOOTDELAYTIMER} seconds"
    while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "${BOOTDELAYTIMER}" ]] &>/dev/null;do
      sleep $((($(awk -F "." '{print $1}' "/proc/uptime")-${BOOTDELAYTIMER})*-1))
    done
    logger -p 5 -st "${ALIAS}" "Boot Delay - System Uptime is $(awk -F "." '{print $1}' "/proc/uptime") seconds"
  fi
  bootdelayinitialized="1"
fi

return
}

# Set Process Priority
setprocesspriority ()
{
if [[ -n "${PROCESSPRIORITY+x}" ]] &>/dev/null;then
  logger -p 6 -t "${ALIAS}" "Debug - Setting Process Priority to ${PROCESSPRIORITY}"
  renice -n ${PROCESSPRIORITY} $$ \
  && logger -p 4 -t "${ALIAS}" "Set Process Priority - Set Process Priority to ${PROCESSPRIORITY}" \
  || logger -p 2 -st "${ALIAS}" "Set Process Priority - ***Error*** Failed to set Process Priority to ${PROCESSPRIORITY}"
fi

return
}

# Check WAN Status
checkwanstatus ()
{
# Check if Dual WAN Mode
if [[ "${WANSDUALWANENABLE}" == "1" ]] &>/dev/null;then
  if [[ ${WAN0PRIMARY} == "1" ]] &>/dev/null;then
    if [[ "${WAN0STATE}" == "2" ]] &>/dev/null;then
	  return
	else
      echo -e "${RED}***WAN0 is not connected***${NOCOLOR}"
      logger -p 2 -t "${ALIAS}" "Check WAN Status - ***Error*** WAN0 is not connected"
      return 1
	fi
  elif [ ${WAN1PRIMARY} == "1" ]] &>/dev/null;then
    if [[ "${WAN1STATE}" == "2" ]] &>/dev/null;then
	  return
	else
      echo -e "${RED}***WAN1 is not connected***${NOCOLOR}"
      logger -p 2 -t "${ALIAS}" "Check WAN Status - ***Error*** WAN1 is not connected"
      return 1
	fi
  fi
# Check if Single WAN Mode
elif [[ "${WANSDUALWANENABLE}" == "0" ]] &>/dev/null;then
  if [[ "${WAN0STATE}" == "2" ]] &>/dev/null;then
    return
  else
    echo -e "${RED}***WAN is not connected***${NOCOLOR}"
    logger -p 2 -t "${ALIAS}" "Check WAN Status - ***Error*** WAN is not connected"
    return 1
  fi
fi

return
}

# Check if NVRAM Background Process is Stuck if CHECKNVRAM is Enabled
nvramcheck ()
{
# Return if CHECKNVRAM is Disabled
if [[ -z "${CHECKNVRAM+x}" ]] &>/dev/null || [[ "${CHECKNVRAM}" == "0" ]] &>/dev/null;then
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
    kill -9 ${lastpid} &>/dev/null \
    && logger -p 2 -t "${ALIAS}" "NVRAM Check - ***NVRAM Check Failure Detected***"
    unset lastpid
    return
  fi
fi

return
}
# Set System Binaries
systembinaries || return
# Get System Parameters
getsystemparameters || return
# Test IP Binary Version
testipversion || return
# Perform PreV2 Config Update
if [[ "${MAJORVERSION}" -lt "3" ]] &>/dev/null && [[ "${mode}" != "install" ]] &>/dev/null && [[ ! -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  updateconfigprev2 || return
# Get Global Configuration
elif [[ "${mode}" != "install" ]] &>/dev/null && [[ -f "${GLOBALCONFIGFILE}" ]] &>/dev/null;then
  setglobalconfig || return
  setfirewallrestore || return
  if [[ "${MAJORVERSION}" -lt "3" ]] &>/dev/null;then
    updateconfigprev212 || return
  fi
fi
# Check Alias
if [[ -d "${POLICYDIR}" ]] &>/dev/null && { [[ "${mode}" != "uninstall" ]] &>/dev/null || [[ "${mode}" != "install" ]] &>/dev/null ;};then
  checkalias || return
fi
# Set Mode and Execute
scriptmode
