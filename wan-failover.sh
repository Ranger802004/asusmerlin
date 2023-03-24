#!/bin/sh

# WAN Failover for ASUS Routers using ASUS Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 03/24/2023
# Version: v2.0.1

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
ALIAS="wan-failover"
VERSION="v2.0.1"
REPO="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/"
CONFIGFILE="/jffs/configs/wan-failover.conf"
DNSRESOLVFILE="/tmp/resolv.conf"
LOCKFILE="/var/lock/wan-failover.lock"
PIDFILE="/var/run/wan-failover.pid"
WAN0PACKETLOSSFILE="/tmp/wan0packetloss.tmp"
WAN1PACKETLOSSFILE="/tmp/wan1packetloss.tmp"
WANPREFIXES="wan0 wan1"
WAN0="wan0"
WAN1="wan1"

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
  if [[ -n "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ]] &>/dev/null;then
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
elif [[ "$#" != "0" ]] &>/dev/null;then
  [[ -z "${mode+x}" ]] &>/dev/null && mode="${1#}"
fi
scriptmode ()
{
if [[ "${mode}" == "menu" ]] &>/dev/null;then
  if tty &>/dev/null;then
    trap 'return' EXIT HUP INT QUIT TERM
    systembinaries || return
    [[ -f "$CONFIGFILE" ]] &>/dev/null && { setvariables || return ;}
    menu || return
  else
    return
  fi
elif [[ "${mode}" == "status" ]] &>/dev/null;then
  if tty &>/dev/null;then
    trap 'return' EXIT HUP INT QUIT TERM
    systembinaries || return
    [[ -f "$CONFIGFILE" ]] &>/dev/null && { setvariables || return ;}
    statusconsole || return
  else
    return
  fi
elif [[ "${mode}" == "config" ]] &>/dev/null;then
  config || return
elif [[ "${mode}" == "install" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  install
elif [[ "${mode}" == "run" ]] &>/dev/null;then
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { if tty &>/dev/null;then echo -e "${RED}***$ALIAS is already running***${NOCOLOR}";fi && exit ;}
  echo -e "$$" > $PIDFILE
  logger -p 6 -t "$ALIAS" "Debug - Locked File: $LOCKFILE"
  trap 'cleanup && kill -9 "$$"' EXIT HUP INT QUIT TERM
  logger -p 6 -t "$ALIAS" "Debug - Trap set to remove $LOCKFILE on exit"
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  systemcheck || return
  setvariables || return
  renice -n $PROCESSPRIORITY -p $$
  wanstatus || return
elif [[ "${mode}" == "manual" ]] &>/dev/null;then
  exec 100>"$LOCKFILE" || return
  flock -x -n 100 || { if tty &>/dev/null;then echo -e "${RED}***$ALIAS is already running***${NOCOLOR}";fi && exit ;}
  echo -e "$$" > $PIDFILE
  logger -p 6 -t "$ALIAS" "Debug - Locked File: $LOCKFILE"
  trap 'cleanup && kill -9 "$$"' EXIT HUP INT QUIT TERM
  logger -p 6 -t "$ALIAS" "Debug - Trap set to remove $LOCKFILE on exit"
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  systemcheck || return
  setvariables || return
  renice -n $PROCESSPRIORITY -p $$
  wanstatus || return
elif [[ "${mode}" == "initiate" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  systemcheck || return
  setvariables || return
  wanstatus || return
elif [[ "${mode}" == "restart" ]] &>/dev/null;then
  killscript
elif [[ "${mode}" == "monitor" ]] &>/dev/null || [[ "${mode}" == "capture" ]] &>/dev/null;then
  trap 'exit' EXIT HUP INT QUIT TERM
  logger -p 6 -t "$ALIAS" "Debug - Trap set to kill background process on exit"
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  monitor
elif [[ "${mode}" == "kill" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  killscript
elif [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  uninstall
elif [[ "${mode}" == "cron" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  setvariables || return
  cronjob
elif [[ "${mode}" == "switchwan" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  # Get Global WAN Parameters
  if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
    GETWANMODE=2
    getwanparameters || return
  fi
  if [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
    echo -e ""${BOLD}"${RED}***Switch WAN Mode is only available in Failover Mode***${NOCOLOR}"
    return
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
    while [[ "${mode}" == "switchwan" ]] &>/dev/null;do
      if tty &>/dev/null;then
        read -p "Are you sure you want to switch Primary WAN? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
        case $yn in
          [Yy]* ) break;;
          [Nn]* ) return;;
          * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
        esac
      else
        break
      fi
    done
    systembinaries || return
    setvariables || return
    failover || return
  fi
elif [[ "${mode}" == "update" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: ${mode}"
  update
fi
}

# Menu
menu ()
{
        # Set Mode back to Menu if Changed
        [[ "$mode" != "menu" ]] &>/dev/null && mode="menu"

        # Get Global WAN Parameters
        if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
          GETWANMODE=2
          getwanparameters || return
        fi
	clear
        # Buffer Menu
        output="$(
	sed -n '2,6p' "${0}"		# Display Banner
        printf "\n"
        printf "  ${BOLD}Information:${NOCOLOR}\n"
	printf "  (1)  status      Status Information about WAN Failover\n"
   	printf "  (2)  readme      View WAN Failover Readme\n"
     
        printf "\n"
        printf "  ${BOLD}Installation/Configuration:${NOCOLOR}\n"
	printf "  (3)  install     Install WAN Failover\n"
	printf "  (4)  uninstall   Uninstall WAN Failover\n"
	printf "  (5)  config      Configuration of WAN Failover\n"
	printf "  (6)  update      Check for updates for WAN Failover\n"
        printf "\n"
        printf "  ${BOLD}Operations:${NOCOLOR}\n"
        printf "  (7)  run         Schedule WAN Failover to run via Cron Job\n"
	printf "  (8)  manual      Execute WAN Failover from Interactive Console\n"
	printf "  (9)  initiate    Execute WAN Failover to only create Routing Table Rules, IP Rules, and IPTable Rules\n"
	printf "  (10) monitor     Monitor System Log for WAN Failover Events\n"
	printf "  (11) capture     Capture System Log for WAN Failover Events\n"
	printf "  (12) restart     Restart WAN Failover\n"
	printf "  (13) kill        Kill all instances of WAN Failover and unschedule Cron Jobs\n"
        if [[ "$WANSMODE" != "lb" ]] &>/dev/null || [[ "$DEVMODE" == "1" ]] &>/dev/null;then
          printf "  (14) switchwan   Manually switch Primary WAN.  ${RED}***Failover Mode Only***${NOCOLOR}\n"
        fi

	printf "\n  (e)  exit        Exit WAN Failover Menu\n"
	printf "\nMake a selection: "
        )"
        # Display Menu
        echo "$output" && unset output
	read -r input
	case "${input}" in
		'')
                        return
		;;
		'1')    # status
                       statusconsole || return
		;;
		'2')    # readme
                        # Check for configuration and load configuration
                        if [[ ! -f "$CONFIGFILE" ]] &>/dev/null;then
                          echo -e "${RED}WAN Failover currently has no configuration file present{$NOCOLOR}"
                        elif [[ -f "$CONFIGFILE" ]] &>/dev/null;then
                          setvariables || return
                        fi
                        # Determine if readme source is prod or beta
                        if [[ "$DEVMODE" == "1" ]] &>/dev/null;then
                          README=""$REPO"wan-failover-readme-beta.txt"
                        else
                          README=""$REPO"wan-failover-readme.txt"
                        fi
                        clear
                        /usr/sbin/curl --connect-timeout 30 --max-time 30 --url $README --ssl-reqd 2>/dev/null || echo -e "${RED}***Unable to access Readme***${NOCOLOR}"
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
                        config || return
		;;
		'6')    # update
			mode="update"
                        update
		;;
		'7')    # run
			mode="cron"
                        cronjob
		;;
		'8')    # manual
			mode="manual"
                        scriptmode
		;;
		'9')    # initiate
			mode="initiate"
                        scriptmode
		;;
		'10')   # monitor
			mode="monitor"
                        trap 'menu' EXIT HUP INT QUIT TERM
			monitor
		;;
		'11')   # capture
			mode="capture"
                        trap 'menu' EXIT HUP INT QUIT TERM
			monitor
		;;
		'12')   # restart
			mode="restart"
                        killscript
		;;
		'13')   # kill
			mode="kill"
                        killscript
		;;
		'14')   # switchman
			mode="switchwan"
                        scriptmode
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

systemcheck ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: systemcheck"

# Get System Parameters
getsystemparameters || return

# Get Log Level
logger -p 6 -t "$ALIAS" "Debug - Log Level: "$(nvram get log_level & nvramcheck)""

# Get PID
logger -p 5 -t "$ALIAS" "System Check - Process ID: "$$""

# Check System Binaries Path
systembinaries || return

# Script Version Logging
logger -p 5 -t "$ALIAS" "System Check - Version: "$VERSION""

# Script Checksum
logger -p 5 -t "$ALIAS" "System Check - Checksum: "$CHECKSUM""

# Supported Firmware Versions
FWVERSIONS='
386.5
386.7
386.9
388.1
388.2
'

# Firmware Version Check
logger -p 6 -t "$ALIAS" "Debug - Firmware: "$(nvram get buildno & nvramcheck)""
for FWVERSION in ${FWVERSIONS};do
  if [[ "$FIRMWARE" == "merlin" ]] &>/dev/null && [[ "$BUILDNO" == "$FWVERSION" ]] &>/dev/null;then
    break
  elif [[ "$FIRMWARE" == "merlin" ]] &>/dev/null && [[ -n "$(echo "${FWVERSIONS}" | grep -w "$BUILDNO")" ]] &>/dev/null;then
    continue
  else
    logger -p 3 -st "$ALIAS" "System Check - ***"$BUILDNO" is not supported, issues may occur from running this version***"
  fi
done

# IPRoute Version Check
logger -p 5 -t "$ALIAS" "System Check - IP Version: "$IPVERSION""

# JFFS Custom Scripts Enabled Check
logger -p 6 -t "$ALIAS" "Debug - JFFS custom scripts and configs: "$JFFSSCRIPTS""
if [[ "$JFFSSCRIPTS" == "0" ]] &>/dev/null;then
  logger -p 3 -st "$ALIAS" "System Check - ***JFFS custom scripts and configs not Enabled***"
fi

# Check Alias
logger -p 6 -t "$ALIAS" "Debug - Checking Alias in /jffs/configs/profile.add"
if [[ ! -f "/jffs/configs/profile.add" ]] &>/dev/null;then
  logger -p 5 -st "$ALIAS" "System Check - Creating /jffs/configs/profile.add"
  touch -a /jffs/configs/profile.add \
  && chmod 666 /jffs/configs/profile.add \
  && logger -p 4 -st "$ALIAS" "System Check - Created /jffs/configs/profile.add" \
  || logger -p 2 -st "$ALIAS" "System Check - ***Error*** Unable to create /jffs/configs/profile.add"
fi
if [[ -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ]] &>/dev/null;then
  logger -p 5 -st "$ALIAS" "System Check - Creating Alias for "$0" as wan-failover"
  echo -e "alias wan-failover=\"sh $0\" # Wan-Failover" >> /jffs/configs/profile.add \
  && source /jffs/configs/profile.add \
  && logger -p 4 -st "$ALIAS" "System Check - Created Alias for "$0" as wan-failover" \
  || logger -p 2 -st "$ALIAS" "System Check - ***Error*** Unable to create Alias for "$0" as wan-failover"
fi

# Check Configuration File
logger -p 6 -t "$ALIAS" "Debug - Checking for Configuration File: "$CONFIGFILE""
if [[ ! -f "$CONFIGFILE" ]] &>/dev/null;then
  echo -e ""${BOLD}"${RED}$ALIAS - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  logger -p 2 -t "$ALIAS" "System Check - ***No Configuration File Detected - Run Install Mode***"
  exit
fi

# Turn off email notification for initial load of WAN Failover
if [[ -z "${email+x}" ]] &>/dev/null;then
  email="0"
fi

# Check for Update
passiveupdate="1"
update && unset passiveupdate || return

# Check Process Priority
logger -p 5 -t "$ALIAS" "System Check - Process Priority: "$PROCESSPRIORITY""

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
  fi
  sleep 1

  # MODEL
  if [[ -z "${MODEL+x}" ]] &>/dev/null;then
    MODEL="$(nvram get model & nvramcheck)"
    [[ -n "$MODEL" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set MODEL" && unset MODEL && continue ;}
  fi

  # PRODUCTID
  if [[ -z "${PRODUCTID+x}" ]] &>/dev/null;then
    PRODUCTID="$(nvram get productid & nvramcheck)"
    [[ -n "$PRODUCTID" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set PRODUCTID" && unset PRODUCTID && continue ;}
  fi

  # BUILDNAME
  if [[ -z "${BUILDNAME+x}" ]] &>/dev/null;then
    BUILDNAME="$(nvram get build_name & nvramcheck)"
    [[ -n "$BUILDNAME" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set BUILDNAME" && unset BUILDNAME && continue ;}
  fi

  # FIRMWARE
  if [[ -z "${FIRMWARE+x}" ]] &>/dev/null;then
    FIRMWARE="$(nvram get 3rd-party & nvramcheck)"
    [[ -n "$FIRMWARE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set FIRMWARE" && unset FIRMWARE && continue ;}
  fi

  # BUILDNO
  if [[ -z "${BUILDNO+x}" ]] &>/dev/null;then
    BUILDNO="$(nvram get buildno & nvramcheck)"
    [[ -n "$BUILDNO" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set BUILDNO" && unset BUILDNO && continue ;}
  fi

  # LANHOSTNAME
  if [[ -z "${LANHOSTNAME+x}" ]] &>/dev/null;then
    LANHOSTNAME="$(nvram get lan_hostname & nvramcheck)"
    [[ -n "$LANHOSTNAME" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set LANHOSTNAME" && unset LANHOSTNAME && continue ;}
  fi

  # JFFSSCRIPTS
  if [[ -z "${JFFSSCRIPTS+x}" ]] &>/dev/null;then
    JFFSSCRIPTS="$(nvram get jffs2_scripts & nvramcheck)"
    [[ -n "$JFFSSCRIPTS" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set JFFSSCRIPTS" && unset JFFSSCRIPTS && continue ;}
  fi

  # IPVERSION
  if [[ -z "${IPVERSION+x}" ]] &>/dev/null;then
    IPVERSION="$(ip -V | awk -F "-" '{print $2}')"
    [[ -n "$IPVERSION" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPVERSION" && unset IPVERSION && continue ;}
  fi

 systemparameterssync="1"
done

# Get Active System Parameters
while [[ -z "${activesystemsync+x}" ]] &>/dev/null || [[ "$activesystemsync" == "0" ]] &>/dev/null;do
  activesystemsync="0"
  sleep 1

  # HTTPENABLE
  if [[ -z "${HTTPENABLE+x}" ]] &>/dev/null || [[ -z "${zHTTPENABLE+x}" ]] &>/dev/null;then
    HTTPENABLE="$(nvram get misc_http_x & nvramcheck)"
    [[ -n "$HTTPENABLE" ]] &>/dev/null \
    && zHTTPENABLE="$HTTPENABLE" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set HTTPENABLE" && unset HTTPENABLE ; unset zHTTPENABLE && continue ;}
  else
    [[ "$zHTTPENABLE" != "$HTTPENABLE" ]] &>/dev/null && zHTTPENABLE="$HTTPENABLE"
    HTTPENABLE="$(nvram get misc_http_x & nvramcheck)"
    [[ -n "$HTTPENABLE" ]] &>/dev/null || HTTPENABLE="$zHTTPENABLE"
  fi

  # FIREWALLENABLE
  if [[ -z "${FIREWALLENABLE+x}" ]] &>/dev/null || [[ -z "${zFIREWALLENABLE+x}" ]] &>/dev/null;then
    FIREWALLENABLE="$(nvram get fw_enable_x & nvramcheck)"
    [[ -n "$FIREWALLENABLE" ]] &>/dev/null \
    && zFIREWALLENABLE="$FIREWALLENABLE" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set FIREWALLENABLE" && unset FIREWALLENABLE ; unset zFIREWALLENABLE && continue ;}
  else
    [[ "$zFIREWALLENABLE" != "$FIREWALLENABLE" ]] &>/dev/null && zFIREWALLENABLE="$FIREWALLENABLE"
    FIREWALLENABLE="$(nvram get fw_enable_x & nvramcheck)"
    [[ -n "$FIREWALLENABLE" ]] &>/dev/null || FIREWALLENABLE="$zFIREWALLENABLE"
  fi

  # IPV6FIREWALLENABLE
  if [[ -z "${IPV6FIREWALLENABLE+x}" ]] &>/dev/null || [[ -z "${zIPV6FIREWALLENABLE+x}" ]] &>/dev/null;then
    IPV6FIREWALLENABLE="$(nvram get ipv6_fw_enable & nvramcheck)"
    [[ -n "$IPV6FIREWALLENABLE" ]] &>/dev/null \
    && zIPV6FIREWALLENABLE="$IPV6FIREWALLENABLE" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPV6FIREWALLENABLE" && unset IPV6FIREWALLENABLE ; unset zIPV6FIREWALLENABLE && continue ;}
  else
    [[ "$zIPV6FIREWALLENABLE" != "$IPV6FIREWALLENABLE" ]] &>/dev/null && zIPV6FIREWALLENABLE="$IPV6FIREWALLENABLE"
    IPV6FIREWALLENABLE="$(nvram get ipv6_fw_enable & nvramcheck)"
    [[ -n "$IPV6FIREWALLENABLE" ]] &>/dev/null || IPV6FIREWALLENABLE="$zIPV6FIREWALLENABLE"
  fi

  # LEDDISABLE
  if [[ -z "${LEDDISABLE+x}" ]] &>/dev/null || [[ -z "${zLEDDISABLE+x}" ]] &>/dev/null;then
    LEDDISABLE="$(nvram get led_disable & nvramcheck)"
    [[ -n "$LEDDISABLE" ]] &>/dev/null \
    && zLEDDISABLE="$LEDDISABLE" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set LEDDISABLE" && unset LEDDISABLE ; unset zLEDDISABLE && continue ;}
  else
    [[ "$zLEDDISABLE" != "$LEDDISABLE" ]] &>/dev/null && zLEDDISABLE="$LEDDISABLE"
    LEDDISABLE="$(nvram get led_disable & nvramcheck)"
    [[ -n "$LEDDISABLE" ]] &>/dev/null || LEDDISABLE="$zLEDDISABLE"
  fi

  # LOGLEVEL
  if [[ -z "${LOGLEVEL+x}" ]] &>/dev/null || [[ -z "${zLOGLEVEL+x}" ]] &>/dev/null;then
    LOGLEVEL="$(nvram get log_level & nvramcheck)"
    [[ -n "$LOGLEVEL" ]] &>/dev/null \
    && zLOGLEVEL="$LOGLEVEL" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set LOGLEVEL" && unset LOGLEVEL ; unset zLOGLEVEL && continue ;}
  else
    [[ "$zLOGLEVEL" != "$LOGLEVEL" ]] &>/dev/null && zLOGLEVEL="$LOGLEVEL"
    LOGLEVEL="$(nvram get log_level & nvramcheck)"
    [[ -n "$LOGLEVEL" ]] &>/dev/null || LOGLEVEL="$zLOGLEVEL"
  fi

  # DDNSENABLE
  if [[ -z "${DDNSENABLE+x}" ]] &>/dev/null || [[ -z "${zDDNSENABLE+x}" ]] &>/dev/null;then
    DDNSENABLE="$(nvram get ddns_enable_x & nvramcheck)"
    [[ -n "$DDNSENABLE" ]] &>/dev/null \
    && zDDNSENABLE="$DDNSENABLE" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set DDNSENABLE" && unset DDNSENABLE ; unset zDDNSENABLE && continue ;}
  else
    [[ "$zDDNSENABLE" != "$DDNSENABLE" ]] &>/dev/null && zDDNSENABLE="$DDNSENABLE"
    DDNSENABLE="$(nvram get ddns_enable_x & nvramcheck)"
    [[ -n "$DDNSENABLE" ]] &>/dev/null || DDNSENABLE="$zDDNSENABLE"
  fi

  # DDNSHOSTNAME
  if [[ -z "${DDNSHOSTNAME+x}" ]] &>/dev/null || [[ -z "${zDDNSHOSTNAME+x}" ]] &>/dev/null;then
    DDNSHOSTNAME="$(nvram get ddns_hostname_x & nvramcheck)"
    [[ -n "$DDNSHOSTNAME" ]] &>/dev/null || [[ "$DDNSENABLE" == "0" ]] &>/dev/null \
    && zDDNSHOSTNAME="$DDNSHOSTNAME" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set DDNSHOSTNAME" && unset DDNSHOSTNAME ; unset zDDNSHOSTNAME && continue ;}
  elif [[ "$DDNSENABLE" == "1" ]] &>/dev/null;then
    [[ "$zDDNSHOSTNAME" != "$DDNSHOSTNAME" ]] &>/dev/null && zDDNSHOSTNAME="$DDNSHOSTNAME"
    DDNSHOSTNAME="$(nvram get ddns_hostname_x & nvramcheck)"
    [[ -n "$DDNSHOSTNAME" ]] &>/dev/null || DDNSHOSTNAME="$zDDNSHOSTNAME"
  fi

  # OVPNSERVERINSTANCES
  if [[ -z "${OVPNSERVERINSTANCES+x}" ]] &>/dev/null || [[ -z "${zOVPNSERVERINSTANCES+x}" ]] &>/dev/null;then
    OVPNSERVERINSTANCES="$(nvram get vpn_serverx_start & nvramcheck)"
    [[ -n "$OVPNSERVERINSTANCES" ]] &>/dev/null || { [[ "$(nvram get vpn_server1_state & nvramcheck)" == "0" ]] &>/dev/null && [[ "$(nvram get vpn_server2_state & nvramcheck)" == "0" ]] &>/dev/null ;} \
    && zOVPNSERVERINSTANCES="$OVPNSERVERINSTANCES" \
    || { logger -p 6 -t "$ALIAS" "Debug - failed to set OVPNSERVERINSTANCES" && unset OVPNSERVERINSTANCES ; unset zOVPNSERVERINSTANCES && continue ;}
  else
    [[ "$zOVPNSERVERINSTANCES" != "$OVPNSERVERINSTANCES" ]] &>/dev/null && zOVPNSERVERINSTANCES="$OVPNSERVERINSTANCES"
    OVPNSERVERINSTANCES="$(nvram get vpn_serverx_start & nvramcheck)"
    [[ -n "$OVPNSERVERINSTANCES" ]] &>/dev/null || OVPNSERVERINSTANCES="$zOVPNSERVERINSTANCES"
  fi

  activesystemsync=1
done

# Unset Variables
unset activesystemsync

return
}

# Set Script to use System Binaries
systembinaries ()
{
# Check System Binaries Path
if [[ "$(echo $PATH | awk -F ":" '{print $1":"$2":"$3":"$4":"}')" != "/sbin:/bin:/usr/sbin:/usr/bin:" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Setting System Binaries Path"
  export PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH
  logger -p 6 -t "$ALIAS" "Debug - PATH: "$PATH""
fi
return
}

# Install
install ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: Install"

# Prompt for Confirmation to Install
while [[ "${mode}" == "install" ]] &>/dev/null;do
  read -p "Do you want to install WAN Failover? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) return;;
    * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
  esac
done

# Get System Parameters
echo -e "${LIGHTBLUE}Getting System Settings...${NOCOLOR}"
getsystemparameters && echo -e "${GREEN}Successfully acquired System Settings${NOCOLOR}" || { echo -e "${RED}Failed to acquire System Settings${NOCOLOR}" && return ;}

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  echo -e "${LIGHTBLUE}Getting WAN Parameters...${NOCOLOR}"
  GETWANMODE=2
  getwanparameters && echo -e "${GREEN}Successfully acquired WAN Parameters${NOCOLOR}" || { echo -e "${RED}Failed to acquire WAN Parameters${NOCOLOR}" && return ;}
fi

# Check for Config File
if [[ ! -f $CONFIGFILE ]] &>/dev/null;then
  echo -e "${LIGHTBLUE}Creating $CONFIGFILE...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating $CONFIGFILE"
  { touch -a $CONFIGFILE && chmod 666 $CONFIGFILE && setvariables || return ;} \
  && { echo -e "${GREEN}$CONFIGFILE created successfully.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $CONFIGFILE created successfully" ;} \
  || { echo -e "${RED}$CONFIGFILE failed to create.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $CONFIGFILE failed to create" ;}
else
  echo -e "${YELLOW}$CONFIGFILE already exists...${NOCOLOR}" ; logger -p 4 -t "$ALIAS" "Install - $CONFIGFILE already exists"
  setvariables || return
fi

# Create Wan-Event if it doesn't exist
if [[ ! -f "/jffs/scripts/wan-event" ]] &>/dev/null;then
  echo -e "${LIGHTBLUE}Creating wan-event script...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating wan-event script"
  { touch -a /jffs/scripts/wan-event && chmod 775 /jffs/scripts/wan-event && echo "#!/bin/sh" >> /jffs/scripts/wan-event ;} \
  && { echo -e "${GREEN}wan-event script has been created.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - wan-event script has been created" ;} \
  || { echo -e "${RED}wan-event script failed to create.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - wan-event script failed to create" ;}
else
  echo -e "${YELLOW}wan-event script already exists...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - wan-event script already exists"
fi

# Add Script to Wan-event
if [[ -n "$(cat /jffs/scripts/wan-event | grep -w "# Wan-Failover")" ]] &>/dev/null;then 
  echo -e "${GREEN}$ALIAS already added to wan-event...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $ALIAS already added to wan-event"
else
  echo -e "${LIGHTBLUE}Adding $ALIAS to wan-event...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Adding $ALIAS to wan-event"
  { cmdline="sh $0 cron" && echo -e "\r\n$cmdline # Wan-Failover" >> /jffs/scripts/wan-event ;} \
  && { echo -e "${GREEN}$ALIAS added to wan-event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $ALIAS added to wan-event" ;} \
  || { echo -e "${RED}$ALIAS failed to add to wan-event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $ALIAS failed to add to wan-event" ;}
fi

# Create /jffs/configs/profile.add if it doesn't exist
if [[ ! -f "/jffs/configs/profile.add" ]] &>/dev/null;then
  echo -e "${LIGHTBLUE}Creating /jffs/configs/profile.add...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating /jffs/configs/profile.add"
  { touch -a /jffs/configs/profile.add && chmod 666 /jffs/configs/profile.add ;} \
  && { echo -e "${GREEN}/jffs/configs/profile.add has been created.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - /jffs/configs/profile.add has been created" ;} \
  || { echo -e "${RED}/jffs/configs/profile.add failed to be created.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - /jffs/configs/profile.add failed to be created" ;}
else
  echo -e "${GREEN}/jffs/configs/profile.add already exists...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - /jffs/configs/profile.add already exists"
fi

# Create Alias
if [[ -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ]] &>/dev/null;then
  echo -e "${LIGHTBLUE}"$ALIAS" - Install: Creating Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating Alias for "$0" as wan-failover"
  { echo -e "alias wan-failover=\"sh $0\" # Wan-Failover" >> /jffs/configs/profile.add && source /jffs/configs/profile.add ;} \
  && { echo -e "${GREEN}"$ALIAS" - Install: Created Alias for "$0" as wan-failover...${NOCOLOR}" && logger -p 5 -t "$ALIAS" "Install - Created Alias for "$0" as wan-failover" ;} \
  || { echo -e "${RED}"$ALIAS" - Install: Failed to create Alias for "$0" as wan-failover...${NOCOLOR}" && logger -p 5 -t "$ALIAS" "Install - Failed to create Alias for "$0" as wan-failover" ;}
fi

# Create Initial Cron Jobs
echo -e "${LIGHTBLUE}Creating Cron Job...${NOCOLOR}"
cronjob &>/dev/null && echo -e "${GREEN}Created Cron Job${NOCOLOR}" || echo -e "${RED}Failed to create Cron Job${NOCOLOR}"

# Check if Dual WAN is Enabled
if [[ "$WANSDUALWANENABLE" == "0" ]] &>/dev/null;then
  echo -e "${RED}***Warning***  Dual WAN is not Enabled.${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Dual WAN is not Enabled"
elif [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null;then
  echo -e "${GREEN}Dual WAN is Enabled.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Dual WAN is Enabled"
fi

# Check if Dual WAN is Enabled
if [[ "$WANDOGENABLE" == "1" ]] &>/dev/null;then
  echo -e "${RED}***Warning***  Factory WAN Failover Enabled.${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Factory WAN Failover Enabled"
  echo -e "${RED}***Warning***  Disable WAN > Dual WAN > Basic Config > Allow failback${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Disable WAN > Dual WAN > Basic Config > Allow failback"
  echo -e "${RED}***Warning***  Disable WAN > Dual WAN > Auto Network Detection > Network Monitoring${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Disable WAN > Dual WAN > Auto Network Detection > Network Monitoring"
elif [[ "$WANDOGENABLE" == "0" ]] &>/dev/null;then
  echo -e "${GREEN}Factory WAN Failover Disabled.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Factory WAN Failover Disabled"
fi

# Check if JFFS Custom Scripts is enabled during installation
if [[ "$JFFSSCRIPTS" == "0" ]] &>/dev/null;then
  echo -e "${RED}***Warning***  Administration > System > Enable JFFS custom scripts and configs is not enabled.${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Administration > System > Enable JFFS custom scripts and configs is not enabled"
elif [[ "$JFFSSCRIPTS" == "1" ]] &>/dev/null;then
  echo -e "${GREEN}Administration > System > Enable JFFS custom scripts and configs is enabled...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Administration > System > Enable JFFS custom scripts and configs is enabled"
fi

return
}

# Uninstall
uninstall ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: Uninstall"
if [[ "${mode}" == "uninstall" ]] &>/dev/null;then
read -n 1 -s -r -p "Press any key to continue to uninstall..."
  # Remove Cron Job
  $(cronjob >/dev/null &)

  # Check for Configuration File
  if [[ -f $CONFIGFILE ]] &>/dev/null;then
    # Load Variables from Configuration first for Cleanup
    . $CONFIGFILE

    # Prompt for Deleting Config File
    while true &>/dev/null;do  
      read -p "Do you want to keep WAN Failover Configuration? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
      case $yn in
        [Yy]* ) deleteconfig="1" && break;;
        [Nn]* ) deleteconfig="0" && break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
    done
    [[ -z "${deleteconfig+x}" ]] &>/dev/null && deleteconfig="1"
    # Delete Config File or Retain
    if [[ "$deleteconfig" == "1" ]] &>/dev/null;then
      echo -e "${LIGHTBLUE}"$ALIAS" - Uninstall: Deleting $CONFIGFILE...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Deleting $CONFIGFILE"
      rm -f $CONFIGFILE \
      && { echo -e "${GREEN}"$ALIAS" - Uninstall: $CONFIGFILE deleted.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $CONFIGFILE deleted" ;} \
      || { echo -e "${RED}"$ALIAS" - Uninstall: $CONFIGFILE failed to delete.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $CONFIGFILE failed to delete" ;}
    elif [[ "$deleteconfig" == "0" ]] &>/dev/null;then
      echo -e "${GREEN}"$ALIAS" - Uninstall: Configuration file will be kept at $CONFIGFILE.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Configuration file will be kept at $CONFIGFILE"
    fi
  fi

  # Remove Script from Wan-event
  cmdline="sh $0 cron"
  if [[ -n "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ]] &>/dev/null;then 
    echo -e "${LIGHTBLUE}"$ALIAS" - Uninstall: Removing Cron Job from Wan-Event...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removing Cron Job from Wan-Event"
    sed -i '\~# Wan-Failover~d' /jffs/scripts/wan-event \
    && { echo -e "${GREEN}"$ALIAS" - Uninstall: Removed Cron Job from Wan-Event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removed Cron Job from Wan-Event" ;} \
    || { echo -e "${RED}"$ALIAS" - Uninstall: Failed to remove Cron Job from Wan-Event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Failed to remove Cron Job from Wan-Event" ;}
  fi

  # Remove Alias
  if [[ -n "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ]] &>/dev/null;then
    { echo -e "${LIGHTBLUE}"$ALIAS" - Uninstall: Removing Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removing Alias for "$0" as wan-failover" ;}
    { sed -i '\~# Wan-Failover~d' /jffs/configs/profile.add && source /jffs/configs/profile.add ;} \
    && { echo -e "${GREEN}"$ALIAS" - Uninstall: Removed Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removed Alias for "$0" as wan-failover" ;} \
    || { echo -e "${RED}"$ALIAS" - Uninstall: Failed to remove Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Failed to remove Alias for "$0" as wan-failover" ;}
  fi

  # Check for Script File
  if [[ -f $0 ]] &>/dev/null;then
    { echo -e "${LIGHTBLUE}"$ALIAS" - Uninstall: Deleting $0...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Deleting $0" ;}
    rm -f $0 \
    && { echo -e "${GREEN}"$ALIAS" - Uninstall: $0 deleted.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $0 deleted" ;} \
    || { echo -e "${RED}"$ALIAS" - Uninstall: $0 failed to delete.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $0 failed to delete" ;}
  fi

  # Cleanup
  cleanup || continue

  # Kill Running Processes
  echo -e "${RED}Killing "$ALIAS"...${NOCOLOR}" ; logger -p 0 -t ""$ALIAS"" "Uninstall - Killing "$ALIAS""
  sleep 3 && killall ${0##*/}
fi
return
}

# Cleanup
cleanup ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: cleanup"

for WANPREFIX in ${WANPREFIXES};do
  logger -p 6 -t "$ALIAS" "Debug - Setting parameters for ${WANPREFIX}"

  if [[ "${WANPREFIX}" == "$WAN0" ]] &>/dev/null;then
    TARGET="$WAN0TARGET"
    TABLE="$WAN0ROUTETABLE"
    PRIORITY="$WAN0TARGETRULEPRIORITY"
    GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
    GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
  elif [[ "${WANPREFIX}" == "$WAN1" ]] &>/dev/null;then
    TARGET="$WAN1TARGET"
    TABLE="$WAN1ROUTETABLE"
    PRIORITY="$WAN1TARGETRULEPRIORITY"
    GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
    GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
  fi

  # Delete WAN IP Rule
  logger -p 6 -t "$ALIAS" "Debug - Checking ${WANPREFIX} for IP Rule to $TARGET"
  if [[ -n "$(ip rule list from all to $TARGET lookup $TABLE)" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Cleanup - Deleting IP Rule for "$TARGET" to monitor "${WANPREFIX}""
    until [[ -z "$(ip rule list from all to $TARGET lookup "$TABLE")" ]] &>/dev/null;do
      ip rule del from all to $TARGET lookup $TABLE \
      && logger -p 4 -t "$ALIAS" "Cleanup - Deleted IP Rule for $TARGET to monitor ${WANPREFIX}" \
      || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete IP Rule for $TARGET to monitor ${WANPREFIX}"
    done
  fi

  # Delete WAN Route for Target IP
  logger -p 6 -t "$ALIAS" "Debug - Checking ${WANPREFIX} for Default Route in $TABLE"
  if [[ -n "$(ip route list $TARGET via $GATEWAY dev $GWIFNAME)" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Cleanup - Deleting route for $TARGET via $GATEWAY dev $GWIFNAME"
    ip route del $TARGET via $GATEWAY dev $GWIFNAME \
    && logger -p 4 -t "$ALIAS" "Cleanup - Deleted route for $TARGET via $GATEWAY dev $GWIFNAME" \
    || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete route for $TARGET via $GATEWAY dev $GWIFNAME"
  fi

  # Delete Blackhole IPv6 Rules
  if [[ -n "$(ip -6 rule list from all oif $GWIFNAME priority $PRIORITY | grep -w "blackhole")" ]] &>/dev/null;then
    logger -p 5 -t "$ALIAS" "Cleanup - Removing Blackhole IPv6 Rule for ${WANPREFIX}"
    ip -6 rule del blackhole from all oif $GWIFNAME priority $PRIORITY \
      && logger -p 4 -t "$ALIAS" "Cleanup - Removed Blackhole IPv6 Rule for ${WANPREFIX}" \
     || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to remove Blackhole IPv6 Rule for ${WANPREFIX}"
  fi
done

# Unset Variables
[[ -n "${TARGET+x}" ]] &>/dev/null && unset TARGET
[[ -n "${TABLE+x}" ]] &>/dev/null && unset TABLE
[[ -n "${GATEWAY+x}" ]] &>/dev/null && unset GATEWAY
[[ -n "${GWIFNAME+x}" ]] &>/dev/null && unset GWIFNAME

# Remove Lock File
logger -p 6 -t "$ALIAS" "Debug - Checking for Lock File: $LOCKFILE"
if [[ -f "$LOCKFILE" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting $LOCKFILE"
  rm -f $LOCKFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted $LOCKFILE" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete $LOCKFILE"
fi

# Remove PID FIle
logger -p 6 -t "$ALIAS" "Debug - Checking for PID File: $PIDFILE"
if [[ -f "$PIDFILE" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting $PIDFILE"
  rm -f $$PIDFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted $PIDFILE" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete $PIDFILE"
fi

# Delete Packet Loss Temp Files
logger -p 6 -t "$ALIAS" "Debug - Checking for $WAN0PACKETLOSSFILE"
if [[ -f "$WAN0PACKETLOSSFILE" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting $WAN0PACKETLOSSFILE"
  rm -f $WAN0PACKETLOSSFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted $WAN0PACKETLOSSFILE" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete $WAN0PACKETLOSSFILE"
fi
logger -p 6 -t "$ALIAS" "Debug - Checking for $WAN1PACKETLOSSFILE"
if [[ -f "$WAN1PACKETLOSSFILE" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting $WAN1PACKETLOSSFILE"
  rm -f $WAN1PACKETLOSSFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted $WAN1PACKETLOSSFILE" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete $WAN1PACKETLOSSFILE"
fi

return
}

# Kill Script
killscript ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: killscript"

if [[ "${mode}" == "restart" ]] &>/dev/null || [[ "${mode}" == "update" ]] &>/dev/null;then
  while [[ "${mode}" == "restart" ]] &>/dev/null;do
    read -p "Are you sure you want to restart WAN Failover? ***Enter Y for Yes or N for No*** $(echo $'\n> ')" yn
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
    PIDS="$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*')" || PIDS=""
  else
    PIDS="$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
  fi

  # Schedule CronJob  
  logger -p 6 -t "$ALIAS" "Debug - Calling Cron Job to be rescheduled"
  $(cronjob >/dev/null &) || return

  logger -p 6 -t "$ALIAS" "Debug - ***Checking if PIDs array is null*** Process ID: "$PIDS""
  if [[ -n "${PIDS+x}" ]] &>/dev/null && [[ -n "$PIDS" ]] &>/dev/null;then
    # Schedule kill for Old PIDs
    logger -p 1 -st "$ALIAS" "Restart - Restarting $ALIAS ***This can take up to approximately 1 minute***"
    logger -p 6 -t "$ALIAS" "Debug - Waiting to kill script until seconds into the minute are above 40 seconds or below 45 seconds"
    CURRENTSYSTEMUPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
    while [[ "$(date "+%-S")" -gt "45" ]] &>/dev/null;do
      [[ "${mode}" == "update" ]] &>/dev/null && break 1
      if tty &>/dev/null;then
        WAITTIMER=$(($(awk -F "." '{print $1}' "/proc/uptime")-$CURRENTSYSTEMUPTIME))
        if [[ "$WAITTIMER" -lt "30" ]] &>/dev/null;then
          printf '\033[K%b\r' "${BOLD}"${LIGHTMAGENTA}"***Waiting to kill $ALIAS*** Current Wait Time: ${LIGHTCYAN}$WAITTIMER Seconds${NOCOLOR}"
        elif [[ "$WAITTIMER" -lt "60" ]] &>/dev/null;then
          printf '\033[K%b\r' "${BOLD}"${LIGHTMAGENTA}"***Waiting to kill $ALIAS*** Current Wait Time: ${YELLOW}$WAITTIMER Seconds${NOCOLOR}"
        elif [[ "$WAITTIMER" -ge "60" ]] &>/dev/null;then
          printf '\033[K%b\r' "${BOLD}"${LIGHTMAGENTA}"***Waiting to kill $ALIAS*** Current Wait Time: ${RED}$WAITTIMER Seconds${NOCOLOR}"
        fi
      fi
      sleep 1
    done
    [[ -n "${CURRENTSYSTEMUPTIME+X}" ]] &>/dev/null && unset CURRENTSYSTEMUPTIME
    [[ -n "${WAITTIMER+X}" ]] &>/dev/null && unset WAITTIMER

    # Kill PIDs
    # Determine binary to use for detecting PIDs
    if [[ -f "/usr/bin/pstree" ]] &>/dev/null;then
      PIDS="$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*')" || PIDS=""
    else
      PIDS="$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
    fi

    until [[ -z "$PIDS" ]] &>/dev/null;do
      [[ -z "$PIDS" ]] && break
      if [[ -f "/usr/bin/pstree" ]] &>/dev/null;then
        for PID in ${PIDS};do
          [[ -n "$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*' | grep -o "${PID}")" ]] \
          && logger -p 1 -st "$ALIAS" "Restart - Killing $ALIAS Process ID: ${PID}" \
            && { kill -9 ${PID} \
            && { PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 1 -st "$ALIAS" "Restart - Killed "$ALIAS" Process ID: "${PID}"" && continue ;} \
            || { [[ -z "$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*' | grep -o "${PID}")" ]] &>/dev/null && PIDS=${PIDS//[${PID}$'\t\r\n']/} && continue || PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 2 -st "$ALIAS" "Restart - ***Error*** Unable to kill $ALIAS Process ID: "${PID}"" ;} ;} \
          || PIDS=${PIDS//[${PID}$'\t\r\n']/} && continue
        done
      else
        for PID in ${PIDS};do
          [[ -n "$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}' | grep -o "${PID}")" ]] \
          && logger -p 1 -st "$ALIAS" "Restart - Killing "$ALIAS" Process ID: "${PID}"" \
            && { kill -9 ${PID} \
            && { PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 1 -st "$ALIAS" "Restart - Killed "$ALIAS" Process ID: "${PID}"" && continue ;} \
            || { [[ -z "$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}' | grep -o "${PID}")" ]] &>/dev/null && PIDS=${PIDS//[${PID}$'\t\r\n']/} && continue || PIDS=${PIDS//[${PID}$'\t\r\n']/} && logger -p 2 -st "$ALIAS" "Restart - ***Error*** Unable to kill $ALIAS Process ID: "${PID}"" ;} ;} \
          || PIDS=${PIDS//[${PID}$'\t\r\n']/} && continue
        done
      fi
    done
    # Execute Cleanup
    . $CONFIGFILE
    cleanup || continue
  elif [[ -z "${PIDS+x}" ]] &>/dev/null || [[ -z "$PIDS" ]] &>/dev/null;then
    # Log no PIDs found and return
    logger -p 2 -st "$ALIAS" "Restart - ***$ALIAS is not running*** No Process ID Detected"
    if tty &>/dev/null;then
      printf '\033[K%b\r\a' "${BOLD}${RED}***$ALIAS is not running*** No Process ID Detected${NOCOLOR}"
      sleep 3
      printf '\033[K'
    fi
  fi
  [[ -n "${PIDS+x}" ]] &>/dev/null && unset PIDS

  # Check for Restart from Cron Job
  RESTARTTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+120))"
  logger -p 5 -st "$ALIAS" "Restart - Waiting for $ALIAS to restart from Cron Job"
  logger -p 6 -t "$ALIAS" "Debug - System Uptime: $(awk -F "." '{print $1}' "/proc/uptime") Seconds"
  logger -p 6 -t "$ALIAS" "Debug - Restart Timeout is in $(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime"))) Seconds"
  while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$RESTARTTIMEOUT" ]] &>/dev/null;do
    # Determine binary to use for detecting PIDs
    if [[ -f "/usr/bin/pstree" ]] &>/dev/null;then
      PIDS="$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*')" || PIDS=""
    else
      PIDS="$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
    fi
    if [[ -z "${PIDS+x}" ]] &>/dev/null || [[ -z "$PIDS" ]] &>/dev/null;then
      if tty &>/dev/null;then
        TIMEOUTTIMER=$(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))
        if [[ "$TIMEOUTTIMER" -ge "60" ]] &>/dev/null;then
          printf '\033[K%b\r' ""${BOLD}"${LIGHTMAGENTA}***Waiting for $ALIAS to restart from Cron Job*** Timeout: ${LIGHTCYAN}$TIMEOUTTIMER Seconds   ${NOCOLOR}"
        elif [[ "$TIMEOUTTIMER" -ge "30" ]] &>/dev/null;then
          printf '\033[K%b\r' ""${BOLD}"${LIGHTMAGENTA}***Waiting for $ALIAS to restart from Cron Job*** Timeout: ${YELLOW}$TIMEOUTTIMER Seconds   ${NOCOLOR}"
        elif [[ "$TIMEOUTTIMER" -ge "0" ]] &>/dev/null;then
          printf '\033[K%b\r' ""${BOLD}"${LIGHTMAGENTA}***Waiting for $ALIAS to restart from Cron Job*** Timeout: ${RED}$TIMEOUTTIMER Seconds   ${NOCOLOR}"
        fi
      fi
      sleep 1
    elif [[ -n "${PIDS+x}" ]] &>/dev/null && [[ -n "$PIDS" ]] &>/dev/null;then
      break
    fi
  done
  [[ -n "${TIMEOUTTIMER+X}" ]] &>/dev/null && unset TIMEOUTTIMER
  [[ -n "${RESTARTTIMEOUT+X}" ]] &>/dev/null && unset RESTARTTIMEOUT
  logger -p 6 -t "$ALIAS" "Debug - System Uptime: $(awk -F "." '{print $1}' "/proc/uptime") Seconds"

  # Check if script restarted
  logger -p 6 -t "$ALIAS" "Debug - Checking if $ALIAS restarted"
  # Determine binary to use for detecting PIDs
  if [[ -f "/usr/bin/pstree" ]] &>/dev/null;then
    PIDS="$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*')" || PIDS=""
  else
    PIDS="$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
  fi
  logger -p 6 -t "$ALIAS" "Debug - ***Checking if PIDs array is null*** Process ID(s): $PIDS"
  if [[ -n "${PIDS+x}" ]] &>/dev/null && [[ -n "$PIDS" ]] &>/dev/null;then
    logger -p 1 -st "$ALIAS" "Restart - Successfully Restarted $ALIAS Process ID(s): $PIDS"
    if tty &>/dev/null;then
      DISPLAYPIDS=${PIDS//[$'\t\r\n']/','}  
      printf '\033[K%b' "${BOLD}${LIGHTCYAN}Successfully Restarted $ALIAS Process ID(s): ${DISPLAYPIDS}${NOCOLOR}\n"
      sleep 10
      printf '\033[K'
      unset DISPLAYPIDS
    fi
  elif [[ -z "${PIDS+x}" ]] &>/dev/null || [[ -z "$PIDS" ]] &>/dev/null;then
    logger -p 1 -st "$ALIAS" "Restart - Failed to restart $ALIAS ***Check Logs***"
    if tty &>/dev/null;then
      printf '\033[K%b\r\a' "${BOLD}${RED}Failed to restart $ALIAS ***Check Logs***${NOCOLOR}"
      sleep 10
      printf '\033[K'
    fi
  fi
  unset PIDS
  return
elif [[ "${mode}" == "kill" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Calling Cron Job to delete jobs"
  cronjob &>/dev/null
  logger -p 0 -st "$ALIAS" "Kill - Killing $ALIAS"
  # Execute Cleanup
  . $CONFIGFILE
  cleanup || continue
  killall ${0##*/} \
  && echo -e "${GREEN}***$ALIAS has been killed${NOCOLOR}" \
  || echo -e "${RED}***$ALIAS is not running*** No Process ID Detected${NOCOLOR}"
  return
fi
return
}

# Update Script
update ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: update"

# Get Configuration Settings
. $CONFIGFILE

# Set Default Flags
[[ -z "${updateneeded+x}" ]] &>/dev/null && updateneeded="0"
[[ -z "${passiveupdate+x}" ]] &>/dev/null && passiveupdate="0"

# Determine Production or Beta Update Channel
if [[ "$DEVMODE" == "0" ]] &>/dev/null;then
  DOWNLOADPATH=""$REPO"wan-failover.sh"
elif [[ "$DEVMODE" == "1" ]] &>/dev/null;then
  DOWNLOADPATH=""$REPO"wan-failover-beta.sh"
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
  [[ "$updateneeded" != "1" ]] &>/dev/null && updateneeded="1"
  logger -p 3 -t "$ALIAS" ""$ALIAS" is out of date - Current Version: "$VERSION" Available Version: "$REMOTEVERSION""
  if [[ "$passiveupdate" == "0" ]] &>/dev/null;then
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
  fi
elif [[ "$version" == "$remoteversion" ]] &>/dev/null;then
  logger -p 5 -t "$ALIAS" ""$ALIAS" is up to date - Version: "$VERSION""
  [[ "$passiveupdate" == "0" ]] &>/dev/null && echo -e "${GREEN}"$ALIAS" is up to date - Version: "$VERSION"${NOCOLOR}"
  if [[ "$CHECKSUM" != "$REMOTECHECKSUM" ]] &>/dev/null;then
    [[ "$updateneeded" != "2" ]] &>/dev/null && updateneeded="2"
    logger -p 2 -t "$ALIAS" "***"$ALIAS" failed Checksum Check*** Current Checksum: "$CHECKSUM"  Valid Checksum: "$REMOTECHECKSUM""
    if [[ "$passiveupdate" == "0" ]] &>/dev/null;then
      echo -e "${RED}***Checksum Failed***${NOCOLOR}"
      echo -e "${LIGHTGRAY}Current Checksum: ${LIGHTRED}"$CHECKSUM"  ${LIGHTGRAY}Valid Checksum: ${GREEN}"$REMOTECHECKSUM"${NOCOLOR}"
    fi
  fi
  if [[ "$passiveupdate" == "0" ]] &>/dev/null;then
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
  fi
elif [[ "$version" -gt "$remoteversion" ]] &>/dev/null;then
  [[ "$updateneeded" != "3" ]] &>/dev/null && updateneeded="3"
  [[ "$passiveupdate" == "0" ]] &>/dev/null && echo -e "${LIGHTMAGENTA}"$ALIAS" is newer than Available Version: "$REMOTEVERSION" ${NOCOLOR}- ${LIGHTCYAN}Current Version: "$VERSION"${NOCOLOR}"
fi

[[ -n "${passiveupdate+x}" ]] &>/dev/null && unset passiveupdate
return
}

# Cronjob
cronjob ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: cronjob"

# Lock Cron Job to ensure only one instance is ran at a time
  CRONLOCKFILE="/var/lock/wan-failover-cron.lock"
  exec 101>"$CRONLOCKFILE" || return
  flock -x -n 101 && echo  || { echo -e "${RED}"$ALIAS" Cron Job Mode is already running...${NOCOLOR}" && return ;}
  trap 'rm -f "$CRONLOCKFILE" || return' EXIT HUP INT QUIT TERM

# Create Cron Job
[[ -z "${SCHEDULECRONJOB+x}" ]] &>/dev/null && SCHEDULECRONJOB=1
if [[ "$SCHEDULECRONJOB" == "1" ]] &>/dev/null && { [[ "${mode}" == "cron" ]] &>/dev/null || [[ "${mode}" == "install" ]] &>/dev/null || [[ "${mode}" == "restart" ]] &>/dev/null || [[ "${mode}" == "update" ]] &>/dev/null ;};then
  if [[ -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Cron - Creating Cron Job"
    $(cru a setup_wan_failover_run "*/1 * * * *" $0 run) \
    && logger -p 4 -st "$ALIAS" "Cron - Created Cron Job" \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Unable to create Cron Job"
  elif tty &>/dev/null && [[ -n "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ]] &>/dev/null;then
    echo -e "${GREEN}Cron Job already scheduled...${NOCOLOR}"
  fi
# Remove Cron Job
elif [[ "$SCHEDULECRONJOB" == "0" ]] &>/dev/null || [[ "${mode}" == "kill" ]] &>/dev/null || [[ "${mode}" == "uninstall" ]] &>/dev/null;then
  if [[ -n "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Cron - Removing Cron Job"
    $(cru d setup_wan_failover_run) \
    && logger -p 3 -st "$ALIAS" "Cron - Removed Cron Job" \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Unable to remove Cron Job"
  elif tty &>/dev/null && [[ -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ]] &>/dev/null;then
    echo -e "${GREEN}Cron Job already unscheduled...${NOCOLOR}"
  fi
fi
return
}

# Monitor Logging
monitor ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: monitor"

# Set System Binaries
systembinaries || return

# Set Variables
setvariables || return

# Reset System Log Path being Set
if [[ -z "${systemlogset+x}" ]] &>/dev/null;then
  systemlogset="0"
elif [[ "$systemlogset" != "0" ]] &>/dev/null;then
  systemlogset="0"
fi

# Check Custom Log Path is Specified
if [[ "$systemlogset" == "0" ]] &>/dev/null && [[ -n "$CUSTOMLOGPATH" ]] &>/dev/null && [[ -f "$CUSTOMLOGPATH" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking if Custom Log Path is Specified"
  logger -p 6 -t "$ALIAS" "Debug - Custom Log Path: "$CUSTOMLOGPATH""
  SYSLOG="$CUSTOMLOGPATH" && systemlogset=1
fi

# Check if Scribe is Installed
if [[ "$systemlogset" == "0" ]] &>/dev/null && { [[ -f "/jffs/scripts/scribe" ]] &>/dev/null && [[ -e "/opt/bin/scribe" ]] &>/dev/null && [[ -f "/opt/var/log/messages" ]] &>/dev/null ;};then
  logger -p 6 -t "$ALIAS" "Debug - Checking if Scribe is Installed"
  logger -p 6 -t "$ALIAS" "Debug - Scribe is installed, using System Log Path: /opt/var/log/messages"
  SYSLOG="/opt/var/log/messages" && systemlogset=1
fi

# Check if Entware syslog-ng package is Installed
if [[ "$systemlogset" == "0" ]] &>/dev/null && [[ -f "/opt/var/log/messages" ]] &>/dev/null && [[ -s "/opt/var/log/messages" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking if Entware syslog-ng package is Installed"
  logger -p 6 -t "$ALIAS" "Debug - Entware syslog-ng package is installed, using System Log Path: /opt/var/log/messages"
  SYSLOG="/opt/var/log/messages" && systemlogset=1
fi

# Check if System Log is located in TMP Directory
if [[ "$systemlogset" == "0" ]] &>/dev/null && { [[ -f "/tmp/syslog.log" ]] &>/dev/null && [[ -s "/tmp/syslog.log" ]] &>/dev/null ;};then
  logger -p 6 -t "$ALIAS" "Debug - Checking if System Log is located at /tmp/syslog.log and isn't a blank file"
  logger -p 6 -t "$ALIAS" "Debug - System Log is located at /tmp/syslog.log"
  SYSLOG="/tmp/syslog.log" && systemlogset=1
fi

# Check if System Log is located in JFFS Directory
if [[ "$systemlogset" == "0" ]] &>/dev/null && { [[ -f "/jffs/syslog.log" ]] &>/dev/null && [[ -s "/jffs/syslog.log" ]] &>/dev/null ;};then
  logger -p 6 -t "$ALIAS" "Debug - Checking if System Log is located at /jffs/syslog.log and isn't a blank file"
  logger -p 6 -t "$ALIAS" "Debug - System Log is located at /jffs/syslog.log"
  SYSLOG="/jffs/syslog.log" && systemlogset=1
fi

# Determine if System Log Path was located and load Monitor Mode
if [[ "$systemlogset" == "0" ]] &>/dev/null;then
  echo -e "${RED}***Unable to locate System Log Path***${NOCOLOR}"
  logger -p 2 -t "$ALIAS" "Monitor - ***Unable to locate System Log Path***"
  return
elif [[ "$systemlogset" == "1" ]] &>/dev/null;then
  if [[ "$mode" == "monitor" ]] &>/dev/null;then
    clear
    tail -1 -F $SYSLOG 2>/dev/null | awk '/'$ALIAS'/{print}' \
    && { unset systemlogset && return ;} \
    || echo -e "${RED}***Unable to load Monitor Mode***${NOCOLOR}"
  elif [[ "$mode" == "capture" ]] &>/dev/null;then
    LOGFILE="/tmp/wan-failover-$(date +"%F-%T-%Z").log"
    touch -a $LOGFILE
    clear
    tail -1 -F $SYSLOG 2>/dev/null | awk '/'$ALIAS'/{print}' | tee -a "$LOGFILE" \
    && { unset systemlogset && return ;} \
    || echo -e "${RED}***Unable to load Capture Mode***${NOCOLOR}"
  fi
fi
}

# Set Variables
setvariables ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: setvariables"
# Set Variables from Configuration
logger -p 6 -t "$ALIAS" "Debug - Reading "$CONFIGFILE""
. $CONFIGFILE

# Check Configuration File for Missing Settings and Set Default if Missing
[[ -z "${configdefaultssync+x}" ]] &>/dev/null && configdefaultssync="0"

if [[ "$configdefaultssync" == "0" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Checking for missing configuration options"
  [[ -n "${PRODUCTID+x}" ]] &>/dev/null || { getsystemparameters || return ;}
  [[ -n "${WANDOGTARGET+x}" ]] &>/dev/null || { getsystemparameters || return ;}
  QOSENABLE="$(nvram get qos_enable & nvramcheck)"
  QOSIBW="$(nvram get qos_ibw & nvramcheck)"
  QOSOBW="$(nvram get qos_obw & nvramcheck)"
  if [[ -z "$(sed -n '/\bWAN0TARGET=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    if [[ -n "$WANDOGTARGET" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0TARGET Default: "$WANDOGTARGET""
      echo -e "WAN0TARGET=$WANDOGTARGET" >> $CONFIGFILE
    else
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0TARGET Default: 8.8.8.8"
      echo -e "WAN0TARGET=8.8.8.8" >> $CONFIGFILE
    fi
  fi
  if [[ -z "$(sed -n '/\bWAN1TARGET=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1TARGET Default: 8.8.4.4"
    echo -e "WAN1TARGET=8.8.4.4" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bPINGCOUNT=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting PINGCOUNT Default: 3 Seconds"
    echo -e "PINGCOUNT=3" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bPINGTIMEOUT=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting PINGTIMEOUT Default: 1 Second"
    echo -e "PINGTIMEOUT=1" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0PACKETSIZE=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    [[ -z "${PACKETSIZE+x}" ]] &>/dev/null && PACKETSIZE="56"
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0PACKETSIZE Default: "$PACKETSIZE" Bytes"
    echo -e "WAN0PACKETSIZE=$PACKETSIZE" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN1PACKETSIZE=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    [[ -z "${PACKETSIZE+x}" ]] &>/dev/null && PACKETSIZE="56"
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1PACKETSIZE Default: "$PACKETSIZE" Bytes"
    echo -e "WAN1PACKETSIZE=$PACKETSIZE" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWANDISABLEDSLEEPTIMER=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WANDISABLEDSLEEPTIMER Default: 10 Seconds"
    echo -e "WANDISABLEDSLEEPTIMER=10" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0_QOS_ENABLE=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    if [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_ENABLE Default: Enabled"
      echo -e "WAN0_QOS_ENABLE=1" >> $CONFIGFILE
    elif [[ "$QOSENABLE" == "0" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_ENABLE Default: Disabled"
      echo -e "WAN0_QOS_ENABLE=0" >> $CONFIGFILE
    fi
  fi
  if [[ -z "$(sed -n '/\bWAN1_QOS_ENABLE=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    if [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_ENABLE Default: Enabled"
      echo -e "WAN1_QOS_ENABLE=1" >> $CONFIGFILE
    elif [[ "$QOSENABLE" == "0" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_ENABLE Default: Disabled"
      echo -e "WAN1_QOS_ENABLE=0" >> $CONFIGFILE
    fi
  fi
  if [[ -z "$(sed -n '/\bWAN0_QOS_IBW=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    if [[ "$QOSENABLE" == "1" ]] &>/dev/null && [[ "$QOSIBW" != "0" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_IBW Default: "$QOSIBW" Kbps"
      echo -e "WAN0_QOS_IBW=$QOSIBW" >> $CONFIGFILE
    else
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_IBW Default: 0 Kbps"
      echo -e "WAN0_QOS_IBW=0" >> $CONFIGFILE
    fi
  fi
  if [[ -z "$(sed -n '/\bWAN1_QOS_IBW=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_IBW Default: 0 Mbps"
    echo -e "WAN1_QOS_IBW=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0_QOS_OBW=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    if [[ "$QOSENABLE" == "1" ]] &>/dev/null && [[ "$QOSOBW" != "0" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_OBW Default: "$QOSOBW" Kbps"
      echo -e "WAN0_QOS_OBW=$QOSOBW" >> $CONFIGFILE
    else
      logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_IBW Default: 0 Kbps"
      echo -e "WAN0_QOS_OBW=0" >> $CONFIGFILE
    fi
  fi
  if [[ -z "$(sed -n '/\bWAN1_QOS_OBW=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_OBW Default: 0 Mbps"
    echo -e "WAN1_QOS_OBW=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0_QOS_OVERHEAD=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_OVERHEAD Default: 0 Bytes"
    echo -e "WAN0_QOS_OVERHEAD=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN1_QOS_OVERHEAD=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_OVERHEAD Default: 0 Bytes"
    echo -e "WAN1_QOS_OVERHEAD=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0_QOS_ATM=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_ATM Default: Disabled"
    echo -e "WAN0_QOS_ATM=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN1_QOS_ATM=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_ATM Default: Disabled"
    echo -e "WAN1_QOS_ATM=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bPACKETLOSSLOGGING=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting PACKETLOSSLOGGING Default: Enabled"
    echo -e "PACKETLOSSLOGGING=1" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bSENDEMAIL=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting SENDEMAIL Default: Enabled"
    echo -e "SENDEMAIL=1" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bSKIPEMAILSYSTEMUPTIME=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting SKIPEMAILSYSTEMUPTIME Default: 180 Seconds"
    echo -e "SKIPEMAILSYSTEMUPTIME=180" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bEMAILTIMEOUT=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
    echo -e "EMAILTIMEOUT=30" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bBOOTDELAYTIMER=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting BOOTDELAYTIMER Default: 0 Seconds"
    echo -e "BOOTDELAYTIMER=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bOVPNSPLITTUNNEL=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting OVPNSPLITTUNNEL Default: Enabled"
    echo -e "OVPNSPLITTUNNEL=1" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0ROUTETABLE=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0ROUTETABLE Default: Table 100"
    echo -e "WAN0ROUTETABLE=100" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN1ROUTETABLE=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1ROUTETABLE Default: Table 200"
    echo -e "WAN1ROUTETABLE=200" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0TARGETRULEPRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0TARGETRULEPRIORITY Default: Priority 100"
    echo -e "WAN0TARGETRULEPRIORITY=100" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN1TARGETRULEPRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1TARGETRULEPRIORITY Default: Priority 100"
    echo -e "WAN1TARGETRULEPRIORITY=100" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0MARK=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0MARK Default: 0x80000000"
    echo -e "WAN0MARK=0x80000000" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN1MARK=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1MARK Default: 0x90000000"
    echo -e "WAN1MARK=0x90000000" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN0MASK=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0MASK Default: 0xf0000000"
    echo -e "WAN0MASK=0xf0000000" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bWAN1MASK=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1MASK Default: 0xf0000000"
    echo -e "WAN1MASK=0xf0000000" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bLBRULEPRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting LBRULEPRIORITY Default: Priority 150"
    echo -e "LBRULEPRIORITY=150" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bFROMWAN0PRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting FROMWAN0PRIORITY Default: Priority 200"
    echo -e "FROMWAN0PRIORITY=200" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bTOWAN0PRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting TOWAN0PRIORITY Default: Priority 400"
    echo -e "TOWAN0PRIORITY=400" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bFROMWAN1PRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting FROMWAN1PRIORITY Default: Priority 200"
    echo -e "FROMWAN1PRIORITY=200" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bTOWAN1PRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting TOWAN1PRIORITY Default: Priority 400"
    echo -e "TOWAN1PRIORITY=400" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bOVPNWAN0PRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting OVPNWAN0PRIORITY Default: Priority 100"
    echo -e "OVPNWAN0PRIORITY=100" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bOVPNWAN1PRIORITY=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
    echo -e "OVPNWAN1PRIORITY=200" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bRECURSIVEPINGCHECK=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Setting RECURSIVEPINGCHECK Default: 1 Iteration"
    echo -e "RECURSIVEPINGCHECK=1" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bDEVMODE=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating DEVMODE Default: Disabled"
    echo -e "DEVMODE=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bCHECKNVRAM=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    if [[ "$PRODUCTID" == "RT-AC86U" ]] &>/dev/null || [[ "$PRODUCTID" == "GT-AC2900" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Creating CHECKNVRAM Default: Enabled"
      echo -e "CHECKNVRAM=1" >> $CONFIGFILE
    else
      logger -p 6 -t "$ALIAS" "Debug - Creating CHECKNVRAM Default: Disabled"
      echo -e "CHECKNVRAM=0" >> $CONFIGFILE
    fi
  fi
  if [[ -z "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating CUSTOMLOGPATH Default: N/A"
    echo -e "CUSTOMLOGPATH=" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bSCHEDULECRONJOB=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating SCHEDULECRONJOB Default: Enabled"
    echo -e "SCHEDULECRONJOB=1" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bSTATUSCHECK=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating STATUSCHECK Default: 30"
    echo -e "STATUSCHECK=30" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bPINGTIMEMIN=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating PINGTIMEMIN Default: 40"
    echo -e "PINGTIMEMIN=40" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bPINGTIMEMAX=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating PINGTIMEMAX Default: 80"
    echo -e "PINGTIMEMAX=80" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bPROCESSPRIORITY\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating PROCESSPRIORITY Default: 0"
    echo -e "PROCESSPRIORITY=0" >> $CONFIGFILE
  fi
  if [[ -z "$(sed -n '/\bFOBLOCKIPV6=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Creating FOBLOCKIPV6 Default: Disabled"
    echo -e "FOBLOCKIPV6=0" >> $CONFIGFILE
  fi

# Cleanup Config file of deprecated options
DEPRECATEDOPTIONS='
WAN0SUFFIX
WAN1SUFFIX
INTERFACE6IN4
RULEPRIORITY6IN4
PACKETSIZE
'

  for DEPRECATEDOPTION in ${DEPRECATEDOPTIONS};do
  if [[ -n "$(sed -n '/\b'${DEPRECATEDOPTION}'=\b/p' "$CONFIGFILE")" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Removing deprecated option: "${DEPRECATEDOPTION}" from "$CONFIGFILE""
    sed -i '/\b'${DEPRECATEDOPTION}'=\b/d' $CONFIGFILE
  fi
  done

  [[ "$configdefaultssync" == "0" ]] &>/dev/null && configdefaultssync="1"
fi

logger -p 6 -t "$ALIAS" "Debug - Reading "$CONFIGFILE""
. $CONFIGFILE

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE=2
  getwanparameters || return
fi

if [[ "$WANSMODE" == "lb" ]] &>/dev/null && [[ "$OVPNSPLITTUNNEL" == "0" ]] &>/dev/null;then
OVPNCONFIGFILES='
/etc/openvpn/client1/config.ovpn
/etc/openvpn/client2/config.ovpn
/etc/openvpn/client3/config.ovpn
/etc/openvpn/client4/config.ovpn
/etc/openvpn/client5/config.ovpn
'

  # Create Array for OVPN Remote Addresses
  [[ -z "${REMOTEADDRESSES+x}" ]] &>/dev/null && REMOTEADDRESSES=""  
  for OVPNCONFIGFILE in ${OVPNCONFIGFILES};do
    if [[ -f "${OVPNCONFIGFILE}" ]] &>/dev/null;then
      REMOTEADDRESS="$(awk -F " " '/remote/ {print $2}' "$OVPNCONFIGFILE")"
      logger -p 6 -t "$ALIAS" "Debug - Added $REMOTEADDRESS to OVPN Remote Addresses"
      REMOTEADDRESSES="${REMOTEADDRESSES} ${REMOTEADDRESS}"
    fi
  done
elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
  [[ -z "${REMOTEADDRESSES+x}" ]] &>/dev/null && REMOTEADDRESSES=""
fi

# Debug Logging
debuglog || return

return
}

# Configuration Menu
config ()
{
# Check for configuration and load configuration
if [[ -f "$CONFIGFILE" ]] &>/dev/null;then
  setvariables || return
else
  printf "${RED}***WAN Failover is not Installed***${NOCOLOR}\n"
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
if [[ ! -f "$CONFIGFILE" ]] &>/dev/null;then
  echo -e "${RED}WAN Failover currently has no configuration file present{$NOCOLOR}"
elif [[ -f "$CONFIGFILE" ]] &>/dev/null;then
  setvariables || return
fi

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE=2
  getwanparameters || return
fi

# Determine QoS Display
# WAN0_QOS_IBW
if [[ "$WAN0_QOS_IBW" == "0" ]] &>/dev/null;then
  wan0qosibw="Automatic"
elif [[ "$WAN0_QOS_IBW" -gt "1024" ]] &>/dev/null;then
  wan0qosibw=""$(($WAN0_QOS_IBW/1024))" Mbps"
else
  wan0qosibw="$WAN0_QOS_IBW Kbps"
fi

# WAN0_QOS_OBW
if [[ "$WAN0_QOS_OBW" == "0" ]] &>/dev/null;then
  wan0qosobw="Automatic"
elif [[ "$WAN0_QOS_OBW" -gt "1024" ]] &>/dev/null;then
  wan0qosobw=""$(($WAN0_QOS_OBW/1024))" Mbps"
else
  wan0qosobw="$WAN0_QOS_OBW Kbps"
fi

# WAN1_QOS_IBW
if [[ "$WAN1_QOS_IBW" == "0" ]] &>/dev/null;then
  wan1qosibw="Automatic"
elif [[ "$WAN1_QOS_IBW" -gt "1024" ]] &>/dev/null;then
  wan1qosibw=""$(($WAN1_QOS_IBW/1024))" Mbps"
else
  wan1qosibw="$WAN1_QOS_IBW Kbps"
fi

# WAN1_QOS_OBW
if [[ "$WAN1_QOS_OBW" == "0" ]] &>/dev/null;then
  wan1qosobw="Automatic"
elif [[ "$WAN1_QOS_OBW" -gt "1024" ]] &>/dev/null;then
  wan1qosobw=""$(($WAN1_QOS_OBW/1024))" Mbps"
else
  wan1qosobw="$WAN1_QOS_OBW Kbps"
fi

# Load Config Menu
clear
printf "\n  ${BOLD}Failover Monitoring Settings:${NOCOLOR}\n"
option=1
printf "  (1)  Configure WAN0 Target           WAN0 Target: ${LIGHTBLUE}$WAN0TARGET${NOCOLOR}\n"
printf "  (2)  Configure WAN1 Target           WAN1 Target: ${LIGHTBLUE}$WAN1TARGET${NOCOLOR}\n"
printf "  (3)  Configure Ping Count            Ping Count: ${LIGHTBLUE}$PINGCOUNT${NOCOLOR}\n"
printf "  (4)  Configure Ping Timeout          Ping Timeout: ${LIGHTBLUE}$PINGTIMEOUT${NOCOLOR}\n"
printf "  (5)  Configure Ping Time Min         Ping Time Minimum: ${GREEN}"$PINGTIMEMIN"ms${NOCOLOR}\n"
printf "  (6)  Configure Ping Time Max         Ping Time Maximum: ${RED}"$PINGTIMEMAX"ms${NOCOLOR}\n"

printf "\n  ${BOLD}QoS Settings:${NOCOLOR}\n"
printf "  (7)  Configure WAN0 QoS              WAN0 QoS: " && { [[ "$WAN0_QOS_ENABLE" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
if [[ "$WAN0_QOS_ENABLE" == "1" ]] || [[ "$DEVMODE" == "1" ]] &>/dev/null &>/dev/null;then
  printf "    (7a) Configure Download Speed       - Download Speed: ${LIGHTBLUE}$wan0qosibw${NOCOLOR}\n"
  printf "    (7b) Configure Upload Speed         - Upload Speed: ${LIGHTBLUE}$wan0qosobw${NOCOLOR}\n"
  printf "    (7c) Configure Packet Overhead      - Packet Overhead: ${LIGHTBLUE}"$WAN0_QOS_OVERHEAD" Bytes${NOCOLOR}\n"
  printf "    (7d) Configure ATM Mode             - ATM Mode: " && { [[ "$WAN0_QOS_ATM" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi

printf "  (8)  Configure WAN1 QoS              WAN1 QoS: " && { [[ "$WAN1_QOS_ENABLE" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
if [[ "$WAN1_QOS_ENABLE" == "1" ]] || [[ "$DEVMODE" == "1" ]] &>/dev/null &>/dev/null;then
  printf "    (8a) Configure Download Speed       - Download Speed: ${LIGHTBLUE}$wan1qosibw${NOCOLOR}\n"
  printf "    (8b) Configure Upload Speed         - Upload Speed: ${LIGHTBLUE}$wan1qosobw${NOCOLOR}\n"
  printf "    (8c) Configure Packet Overhead      - Packet Overhead: ${LIGHTBLUE}"$WAN1_QOS_OVERHEAD" Bytes${NOCOLOR}\n"
  printf "    (8d) Configure ATM Mode             - ATM Mode: " && { [[ "$WAN1_QOS_ATM" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
fi

printf "\n  ${BOLD}Optional Settings:${NOCOLOR}\n"
printf "  (9)  Configure Packet Loss Logging   Packet Loss Logging: " && { [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (10) Configure Boot Delay Timer      Boot Delay Timer: ${LIGHTBLUE}$BOOTDELAYTIMER Seconds${NOCOLOR}\n"
printf "  (11) Configure Email Notifications   Email Notifications: " && { [[ "$SENDEMAIL" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (12) Configure WAN0 Packet Size      WAN0 Packet Size: ${LIGHTBLUE}$WAN0PACKETSIZE Bytes${NOCOLOR}\n"
printf "  (13) Configure WAN1 Packet Size      WAN1 Packet Size: ${LIGHTBLUE}$WAN1PACKETSIZE Bytes${NOCOLOR}\n"
printf "  (14) Configure NVRAM Checks          NVRAM Checks: " && { [[ "$CHECKNVRAM" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (15) Configure Dev Mode              Dev Mode: " && { [[ "$DEVMODE" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "Disabled" ;} && printf "\n"
printf "  (16) Configure Custom Log Path       Custom Log Path: " && { [[ -n "$CUSTOMLOGPATH" ]] &>/dev/null && printf "${LIGHTBLUE}$CUSTOMLOGPATH${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"

printf "\n  ${BOLD}Advanced Settings:${NOCOLOR}  ${RED}***Recommended to leave default unless necessary to change***${NOCOLOR}\n"
printf "  (17) Configure WAN0 Route Table      WAN0 Route Table: ${LIGHTBLUE}$WAN0ROUTETABLE${NOCOLOR}\n"
printf "  (18) Configure WAN1 Route Table      WAN1 Route Table: ${LIGHTBLUE}$WAN1ROUTETABLE${NOCOLOR}\n"
printf "  (19) Configure WAN0 Target Priority  WAN0 Target Priority: ${LIGHTBLUE}$WAN0TARGETRULEPRIORITY${NOCOLOR}\n"
printf "  (20) Configure WAN1 Target Priority  WAN1 Target Priority: ${LIGHTBLUE}$WAN1TARGETRULEPRIORITY${NOCOLOR}\n"
printf "  (21) Configure Recursive Ping Check  Recursive Ping Check: ${LIGHTBLUE}$RECURSIVEPINGCHECK${NOCOLOR}\n"
printf "  (22) Configure WAN Disabled Timer    WAN Disabled Timer: ${LIGHTBLUE}$WANDISABLEDSLEEPTIMER Seconds${NOCOLOR}\n"
printf "  (23) Configure Email Boot Delay      Email Boot Delay: ${LIGHTBLUE}$SKIPEMAILSYSTEMUPTIME Seconds${NOCOLOR}\n"
printf "  (24) Configure Email Timeout         Email Timeout: ${LIGHTBLUE}$EMAILTIMEOUT Seconds${NOCOLOR}\n"
printf "  (25) Configure Cron Job              Cron Job: " && { [[ "$SCHEDULECRONJOB" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
printf "  (26) Configure Status Check          Status Check Interval: ${LIGHTBLUE}$STATUSCHECK Seconds${NOCOLOR}\n"
printf "  (27) Configure Process Priority      Process Priority: " && { { [[ "$PROCESSPRIORITY" == "0" ]] && printf "${LIGHTBLUE}Normal${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "-20" ]] && printf "${LIGHTCYAN}Real Time${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "-10" ]] && printf "${LIGHTMAGENTA}High${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "10" ]] && printf "${LIGHTYELLOW}Low${NOCOLOR}" ;} || { [[ "$PROCESSPRIORITY" == "20" ]] && printf "${LIGHTRED}Lowest${NOCOLOR}" ;} || printf "${LIGHTGRAY}$PROCESSPRIORITY${NOCOLOR}" ;} && printf "\n"
printf "  (28) Configure Failover Block IPV6   Failover Block IPV6: " && { [[ "$FOBLOCKIPV6" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"

if [[ "$WANSMODE" == "lb" ]] &>/dev/null || [[ "$DEVMODE" == "1" ]] &>/dev/null;then
  printf "\n  ${BOLD}Load Balance Mode Settings:${NOCOLOR}\n"
  printf "  (29) Configure LB Rule Priority      Load Balance Rule Priority: ${LIGHTBLUE}$LBRULEPRIORITY${NOCOLOR}\n"
  printf "  (30) Configure OpenVPN Split Tunnel  OpenVPN Split Tunneling: " && { [[ "$OVPNSPLITTUNNEL" == "1" ]] &>/dev/null && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
  printf "  (31) Configure WAN0 OVPN Priority    WAN0 OVPN Priority: ${LIGHTBLUE}$OVPNWAN0PRIORITY${NOCOLOR}\n"
  printf "  (32) Configure WAN1 OVPN Priority    WAN1 OVPN Priority: ${LIGHTBLUE}$OVPNWAN1PRIORITY${NOCOLOR}\n"
  printf "  (33) Configure WAN0 FWMark           WAN0 FWMark: ${LIGHTBLUE}$WAN0MARK${NOCOLOR}\n"
  printf "  (34) Configure WAN1 FWMark           WAN1 FWMark: ${LIGHTBLUE}$WAN1MARK${NOCOLOR}\n"
  printf "  (35) Configure WAN0 Mask             WAN0 Mask: ${LIGHTBLUE}$WAN0MASK${NOCOLOR}\n"
  printf "  (36) Configure WAN1 Mask             WAN1 Mask: ${LIGHTBLUE}$WAN1MASK${NOCOLOR}\n"
fi

# Unset Variables
[[ -n "${wan0qosibw+x}" ]] &>/dev/null && unset wan0qosibw
[[ -n "${wan0qosobw+x}" ]] &>/dev/null && unset wan0qosobw
[[ -n "${wan1qosibw+x}" ]] &>/dev/null && unset wan1qosibw
[[ -n "${wan1qosobw+x}" ]] &>/dev/null && unset wan1qosobw

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
  '1')      # WAN0TARGET
  while true &>/dev/null;do
    read -p "Configure WAN0 Target IP Address - Will be routed via "$(nvram get wan0_gateway & nvramcheck)" dev "$(nvram get wan0_gw_ifname & nvramcheck)": " ip
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "$ip" | cut -d. -f$i) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Address: "$ip" is an Invalid IP Address"
          break 1
        elif [[ "$(nvram get wan0_gateway & nvramcheck)" == "$ip" ]] &>/dev/null;then
          echo -e "${RED}***"$ip" is the WAN0 Gateway IP Address***${NOCOLOR}"
          logger -p 6 -t "$ALIAS" "WAN0 Target IP Address: "$ip" is WAN0 Gateway IP Address"
          break 1
        else
          SETWAN0TARGET=$ip
          logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Address: "$ip""
          break 2
        fi
      done
    else  
      echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Address: "$ip" is an Invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0TARGET=|$SETWAN0TARGET"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '2')      # WAN1TARGET
  while true &>/dev/null;do  
    read -p "Configure WAN1 Target IP Address - Will be routed via "$(nvram get wan1_gateway & nvramcheck)" dev "$(nvram get wan1_gw_ifname & nvramcheck)": " ip
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' &>/dev/null;then
      for i in 1 2 3 4;do
        if [[ $(echo "$ip" | cut -d. -f$i) -gt "255" ]] &>/dev/null;then
          echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
          logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Address: "$ip" is an Invalid IP Address"
          break 1
        elif [[ "$(nvram get wan1_gateway & nvramcheck)" == "$ip" ]] &>/dev/null;then
          echo -e "${RED}***"$ip" is the WAN1 Gateway IP Address***${NOCOLOR}"
          logger -p 6 -t "$ALIAS" "WAN1 Target IP Address: "$ip" is WAN0 Gateway IP Address"
          break 1
        else
          SETWAN1TARGET=$ip
          logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Address: "$ip""
          break 2
        fi
      done
    else  
      echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Address: "$ip" is an Invalid IP Address"
    fi
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1TARGET=|$SETWAN1TARGET"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '3')      # PINGCOUNT
  while true &>/dev/null;do  
    read -p "Configure Ping Count - This is how many consecutive times a ping will fail before a WAN connection is considered disconnected: " value
    case $value in
      [0123456789]* ) SETPINGCOUNT=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter a valid number***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} PINGCOUNT=|$SETPINGCOUNT"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '4')      # PINGTIMEOUT
  while true &>/dev/null;do  
    read -p "Configure Ping Timeout - Value is in seconds: " value
    case $value in
      [0123456789]* ) SETPINGTIMEOUT=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} PINGTIMEOUT=|$SETPINGTIMEOUT"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '5')      # PINGTIMEMIN
  while true &>/dev/null;do  
    read -p "Configure Minimum Ping Time - Value is in milliseconds: " value
    case $value in
      [0123456789]* ) SETPINGTIMEMIN=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in milliseconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} PINGTIMEMIN=|$SETPINGTIMEMIN"
  ;;
  '6')      # PINGTIMEMAX
  while true &>/dev/null;do  
    read -p "Configure Maximum Ping Time - Value is in milliseconds: " value
    case $value in
      [0123456789]* ) SETPINGTIMEMAX=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in milliseconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} PINGTIMEMAX=|$SETPINGTIMEMAX"
  ;;
  '7')      # WAN0_QOS_ENABLE
  while true &>/dev/null;do
    read -p "Do you want to enable QoS for WAN0? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETWAN0_QOS_ENABLE=1;;
      [Nn]* ) SETWAN0_QOS_ENABLE=0;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
    [[ "$SETWAN0_QOS_ENABLE" == "0" ]] &>/dev/null && { SETWAN0_QOS_IBW=0 ; SETWAN0_QOS_OBW=0 ;} && break 1
    read -p "Do you want to use Automatic QoS Settings for WAN0? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETWAN0_QOS_IBW=0;SETWAN0_QOS_OBW=0; break 1;;
      [Nn]* ) ;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
    read -p "Configure WAN0 QoS Download Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN0_QOS_IBW=$(($value*1024));;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
    read -p "Configure WAN0 QoS Upload Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN0_QOS_OBW=$(($value*1024)); break 1;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0_QOS_ENABLE=|$SETWAN0_QOS_ENABLE WAN0_QOS_IBW=|$SETWAN0_QOS_IBW WAN0_QOS_OBW=|$SETWAN0_QOS_OBW"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '7a')      # WAN0_QOS_IBW
  while true &>/dev/null;do
    read -p "Configure WAN0 QoS Download Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN0_QOS_IBW=$(($value*1024)); break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0_QOS_IBW=|$SETWAN0_QOS_IBW"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '7b')      # WAN0_QOS_OBW
  while true &>/dev/null;do
    read -p "Configure WAN0 QoS Upload Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN0_QOS_OBW=$(($value*1024)); break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0_QOS_OBW=|$SETWAN0_QOS_OBW"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '7c')      # WAN0_QOS_OVERHEAD
  while true &>/dev/null;do
    read -p "Configure WAN0 QoS Packet Overhead - Value is in Bytes: " value
    case $value in
      [0123456789]* ) SETWAN0_QOS_OVERHEAD=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0_QOS_OVERHEAD=|$SETWAN0_QOS_OVERHEAD"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '7d')      # WAN0_QOS_ATM
  while true &>/dev/null;do
    read -p "Do you want to enable ATM Mode for WAN0? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETWAN0_QOS_ATM=1; break;;
      [Nn]* ) SETWAN0_QOS_ATM=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0_QOS_ATM=|$SETWAN0_QOS_ATM"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '8')      # WAN1_QOS_ENABLE
  while true &>/dev/null;do
    read -p "Do you want to enable QoS for WAN1? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETWAN1_QOS_ENABLE=1;;
      [Nn]* ) SETWAN1_QOS_ENABLE=0;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
    [[ "$SETWAN1_QOS_ENABLE" == "0" ]] &>/dev/null && { SETWAN1_QOS_IBW=0 ; SETWAN1_QOS_OBW=0 ;} && break 1
    read -p "Do you want to use Automatic QoS Settings for WAN1? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETWAN1_QOS_IBW=0;SETWAN1_QOS_OBW=0; break 1;;
      [Nn]* ) ;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
    read -p "Configure WAN1 QoS Download Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN1_QOS_IBW=$(($value*1024));;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
    read -p "Configure WAN1 QoS Upload Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN1_QOS_OBW=$(($value*1024)); break 1;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1_QOS_ENABLE=|$SETWAN1_QOS_ENABLE WAN1_QOS_IBW=|$SETWAN1_QOS_IBW WAN1_QOS_OBW=|$SETWAN1_QOS_OBW"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '8a')      # WAN1_QOS_IBW
  while true &>/dev/null;do
    read -p "Configure WAN1 QoS Download Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN1_QOS_IBW=$(($value*1024)); break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1_QOS_IBW=|$SETWAN1_QOS_IBW"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '8b')      # WAN1_QOS_OBW
  while true &>/dev/null;do
    read -p "Configure WAN1 QoS Upload Bandwidth - Value is in Mbps: " value
    case $value in
      [0123456789]* ) SETWAN1_QOS_OBW=$(($value*1024)); break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1_QOS_OBW=|$SETWAN1_QOS_OBW"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '8c')      # WAN1_QOS_OVERHEAD
  while true &>/dev/null;do
    read -p "Configure WAN1 QoS Packet Overhead - Value is in Bytes: " value
    case $value in
      [0123456789]* ) SETWAN1_QOS_OVERHEAD=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1_QOS_OVERHEAD=|$SETWAN1_QOS_OVERHEAD"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '8d')      # WAN1_QOS_ATM
  while true &>/dev/null;do
    read -p "Do you want to enable ATM Mode for WAN1? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETWAN1_QOS_ATM=1; break;;
      [Nn]* ) SETWAN1_QOS_ATM=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1_QOS_ATM=|$SETWAN1_QOS_ATM"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '9')      # PACKETLOSSLOGGING
  while true &>/dev/null;do
    read -p "Do you want to enable Packet Loss Logging? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETPACKETLOSSLOGGING=1; break;;
      [Nn]* ) SETPACKETLOSSLOGGING=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} PACKETLOSSLOGGING=|$SETPACKETLOSSLOGGING"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '10')      # BOOTDELAYTIMER
  while true &>/dev/null;do
    read -p "Configure Boot Delay Timer - This will delay the script from executing until System Uptime reaches this time (seconds): " value
    case $value in
      [0123456789]* ) SETBOOTDELAYTIMER=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} BOOTDELAYTIMER=|$SETBOOTDELAYTIMER"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '11')      # SENDEMAIL
  while true &>/dev/null;do
    read -p "Do you want to enable Email Notifications? ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETSENDEMAIL=1; break;;
      [Nn]* ) SETSENDEMAIL=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} SENDEMAIL=|$SETSENDEMAIL"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '12')      # WAN0PACKETSIZE
  while true &>/dev/null;do
    read -p "Configure WAN0 Packet Size - This defines the Packet Size (Bytes) for pinging the WAN0 Target IP Address: " value
    case $value in
      [0123456789]* ) SETWAN0PACKETSIZE=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0PACKETSIZE=|$SETWAN0PACKETSIZE"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '13')      # WAN1PACKETSIZE
  while true &>/dev/null;do
    read -p "Configure WAN1 Packet Size - This defines the Packet Size (Bytes) for pinging the WAN1 Target IP Address: " value
    case $value in
      [0123456789]* ) SETWAN1PACKETSIZE=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1PACKETSIZE=|$SETWAN1PACKETSIZE"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '14')      # CHECKNVRAM
  while true &>/dev/null;do
    read -p "Do you want to enable NVRAM Checks? This defines if the Script is set to perform NVRAM checks before peforming key functions: ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETCHECKNVRAM=1; break;;
      [Nn]* ) SETCHECKNVRAM=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} CHECKNVRAM=|$SETCHECKNVRAM"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '15')      # DEVMODE
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
  '16')      # CUSTOMLOGPATH
  while true &>/dev/null;do
    read -p "Configure Custom Log Path - This defines a Custom System Log path for Monitor/Capture Mode: " value
    case $value in
      [:.-_/0123456789abcdefghijklmnopqstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]* ) SETCUSTOMLOGPATH=$value; break;;
      "" ) SETCUSTOMLOGPATH=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} CUSTOMLOGPATH=|$SETCUSTOMLOGPATH"
  ;;
  '17')      # WAN0ROUTETABLE
  while true &>/dev/null;do
    read -p "Configure WAN0 Route Table - This defines the Routing Table for WAN0, it is recommended to leave this default unless necessary to change: " value
    case $value in
      [0123456789]* ) SETWAN0ROUTETABLE=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0ROUTETABLE=|$SETWAN0ROUTETABLE"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '18')      # WAN1ROUTETABLE
  while true &>/dev/null;do
    read -p "Configure WAN1 Route Table - This defines the Routing Table for WAN1, it is recommended to leave this default unless necessary to change: " value
    case $value in
      [0123456789]* ) SETWAN1ROUTETABLE=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1ROUTETABLE=|$SETWAN1ROUTETABLE"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '19')      # WAN0TARGETRULEPRIORITY
  while true &>/dev/null;do
    read -p "Configure WAN0 Target Rule Priority - This defines the IP Rule Priority for the WAN0 Target IP Address: " value
    case $value in
      [0123456789]* ) SETWAN0TARGETRULEPRIORITY=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0TARGETRULEPRIORITY=|$SETWAN0TARGETRULEPRIORITY"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '20')      # WAN1TARGETRULEPRIORITY
  while true &>/dev/null;do
    read -p "Configure WAN1 Target Rule Priority - This defines the IP Rule Priority for the WAN1 Target IP Address: " value
    case $value in
      [0123456789]* ) SETWAN1TARGETRULEPRIORITY=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1TARGETRULEPRIORITY=|$SETWAN1TARGETRULEPRIORITY"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '21')      # RECURSIVEPINGCHECK
  while true &>/dev/null;do
    read -p "Configure Recursive Ping Check - This defines how many times a WAN Interface has to fail target pings to be considered failed (Ping Count x RECURSIVEPINGCHECK), this setting is for circumstances where ICMP Echo / Response can be disrupted by ISP DDoS Prevention or other factors.  It is recommended to leave this setting default: " value
    case $value in
      [0123456789]* ) SETRECURSIVEPINGCHECK=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} RECURSIVEPINGCHECK=|$SETRECURSIVEPINGCHECK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '22')      # WANDISABLEDSLEEPTIMER
  while true &>/dev/null;do
    read -p "Configure WAN Disabled Sleep Timer - This is how many seconds the WAN Failover pauses and checks again if Dual WAN, Failover/Load Balance Mode, or WAN links are disabled/disconnected: " value
    case $value in
      [0123456789]* ) SETWANDISABLEDSLEEPTIMER=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WANDISABLEDSLEEPTIMER=|$SETWANDISABLEDSLEEPTIMER"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '23')      # SKIPEMAILSYSTEMUPTIME
  while true &>/dev/null;do
    read -p "Configure Email Boot Delay Timer - This will delay sending emails while System Uptime is less than this time: " value
    case $value in
      [0123456789]* ) SETSKIPEMAILSYSTEMUPTIME=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} SKIPEMAILSYSTEMUPTIME=|$SETSKIPEMAILSYSTEMUPTIME"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '24')      # EMAILTIMEOUT
  while true &>/dev/null;do
    read -p "Configure Email Timeout - This defines the timeout for sending an email after a Failover event: " value
    case $value in
      [0123456789]* ) SETEMAILTIMEOUT=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} EMAILTIMEOUT=|$SETEMAILTIMEOUT"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '25')      # SCHEDULECRONJOB
  while true &>/dev/null;do
    read -p "Do you want to enable Cron Job? This defines if the script will create the Cron Job: ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETSCHEDULECRONJOB=1; break;;
      [Nn]* ) SETSCHEDULECRONJOB=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} SCHEDULECRONJOB=|$SETSCHEDULECRONJOB"
  ;;
  '26')      # STATUSCHECK
  while true &>/dev/null;do  
    read -p "Configure Status Check Interval - Value is in seconds: " value
    case $value in
      [0123456789]* ) SETSTATUSCHECK=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
    esac
  done
NEWVARIABLES="${NEWVARIABLES} STATUSCHECK=|$SETSTATUSCHECK"
  ;;
  '27')      # PROCESSPRIORITY
  while true &>/dev/null;do  
    read -p "Configure Process Priority - 4 for Real Time Priority, 3 for High Priority, 2 for Low Priority, 1 for Lowest Priority, 0 for Normal Priority: " value
    case $value in
      4 ) SETPROCESSPRIORITY=-20; break;;
      3 ) SETPROCESSPRIORITY=-10; break;;
      2 ) SETPROCESSPRIORITY=10; break;;
      1 ) SETPROCESSPRIORITY=20; break;;
      0 ) SETPROCESSPRIORITY=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Select a Value between 4 and 0***${NOCOLOR}"
    esac
  done
NEWVARIABLES="${NEWVARIABLES} PROCESSPRIORITY=|$SETPROCESSPRIORITY"
[[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '28')      # FOBLOCKIPV6
  while true &>/dev/null;do
    read -p "Do you want to enable Failover Block IPv6? This defines if the script will block IPv6 Traffic for Secondary WAN in Failover Mode: ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETFOBLOCKIPV6=1; break;;
      [Nn]* ) SETFOBLOCKIPV6=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} FOBLOCKIPV6=|$SETFOBLOCKIPV6"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '29')      # LBRULEPRIORITY
  while true &>/dev/null;do
    read -p "Configure Load Balance Rule Priority - This defines the IP Rule priority for Load Balance Mode, it is recommended to leave this default unless necessary to change: " value
    case $value in
      [0123456789]* ) SETLBRULEPRIORITY=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} LBRULEPRIORITY=|$SETLBRULEPRIORITY"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '30')      # OVPNSPLITTUNNEL
  while true &>/dev/null;do
    read -p "Do you want to enable OpenVPN Split Tunneling? This will enable or disable OpenVPN Split Tunneling while in Load Balance Mode: ***Enter Y for Yes or N for No***" yn
    case $yn in
      [Yy]* ) SETOVPNSPLITTUNNEL=1; break;;
      [Nn]* ) SETOVPNSPLITTUNNEL=0; break;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNSPLITTUNNEL=|$SETOVPNSPLITTUNNEL"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '31')      # OVPNWAN0PRIORITY
  while true &>/dev/null;do
    read -p "Configure OpenVPN WAN0 Priority - This defines the OpenVPN Tunnel Priority for WAN0 if OVPNSPLITTUNNEL is Disabled: " value
    case $value in
      [0123456789]* ) SETOVPNWAN0PRIORITY=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNWAN0PRIORITY=|$SETOVPNWAN0PRIORITY"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '32')      # OVPNWAN1PRIORITY
  while true &>/dev/null;do
    read -p "Configure OpenVPN WAN1 Priority - This defines the OpenVPN Tunnel Priority for WAN1 if OVPNSPLITTUNNEL is Disabled: " value
    case $value in
      [0123456789]* ) SETOVPNWAN1PRIORITY=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} OVPNWAN1PRIORITY=|$SETOVPNWAN1PRIORITY"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '33')      # WAN0MARK
  while true &>/dev/null;do
    read -p "Configure WAN0 FWMark - This defines the WAN0 FWMark for Load Balance Mode: " value
    case $value in
      [0123456789xf]* ) SETWAN0MARK=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0MARK=|$SETWAN0MARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '34')      # WAN1MARK
  while true &>/dev/null;do
    read -p "Configure WAN1 FWMark - This defines the WAN1 FWMark for Load Balance Mode: " value
    case $value in
      [0123456789xf]* ) SETWAN1MARK=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1MARK=|$SETWAN1MARK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '35')      # WAN0MASK
  while true &>/dev/null;do
    read -p "Configure WAN0 Mask - This defines the WAN0 Mask for Load Balance Mode: " value
    case $value in
      [0123456789xf]* ) SETWAN0MASK=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN0MASK=|$SETWAN0MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  '36')      # WAN1MASK
  while true &>/dev/null;do
    read -p "Configure WAN1 Mask - This defines the WAN1 Mask for Load Balance Mode: " value
    case $value in
      [0123456789xf]* ) SETWAN1MASK=$value; break;;
      * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
    esac
  done
  NEWVARIABLES="${NEWVARIABLES} WAN1MASK=|$SETWAN1MASK"
  [[ "$RESTARTREQUIRED" == "0" ]] &>/dev/null && RESTARTREQUIRED=1
  ;;
  'r'|'return'|'menu')
  clear
  menu
  break
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
    if [[ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    elif [[ -n "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ]] &>/dev/null && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] &>/dev/null;then
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    elif [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" == "CUSTOMLOGPATH=" ]] &>/dev/null;then
      [[ -n "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$CONFIGFILE")" ]] &>/dev/null && sed -i '/CUSTOMLOGPATH=/d' $CONFIGFILE
      echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')" >> $CONFIGFILE
    fi
  done
  if [[ "$RESTARTREQUIRED" == "1" ]] &>/dev/null;then
    echo -e "${RED}***This change will require WAN Failover to restart to take effect***${NOCOLOR}"
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

# WAN Status
wanstatus ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: wanstatus"

# Check if script has been loaded and is already in a Ready State
[[ -z "${READYSTATE+x}" ]] &>/dev/null && READYSTATE="0"

# Boot Delay Timer
logger -p 6 -t "$ALIAS" "Debug - System Uptime: $(awk -F "." '{print $1}' "/proc/uptime") Seconds"
logger -p 6 -t "$ALIAS" "Debug - Boot Delay Timer: $BOOTDELAYTIMER Seconds"
if [[ -n "$BOOTDELAYTIMER" ]] &>/dev/null;then
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] &>/dev/null;then
    logger -p 4 -st "$ALIAS" "Boot Delay - Waiting for System Uptime to reach $BOOTDELAYTIMER seconds"
    while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] &>/dev/null;do
      sleep 1
    done
    logger -p 5 -st "$ALIAS" "Boot Delay - System Uptime is $(awk -F "." '{print $1}' "/proc/uptime") seconds"
  fi
fi

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE="2"
  getwanparameters || return
fi

# Check Current Status of Dual WAN Mode
if [[ "$WANSDUALWANENABLE" == "0" ]] &>/dev/null;then
  logger -p 2 -st "$ALIAS" "WAN Status - Dual WAN: Disabled"
  wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$WANDOGENABLE" != "0" ]] &>/dev/null;then
  logger -p 2 -st "$ALIAS" "WAN Status - ASUS Factory Watchdog: Enabled"
  wandisabled
# Check if WAN Interfaces are Enabled and Connected
else
  for WANPREFIX in ${WANPREFIXES};do
    # Getting WAN Parameters
    GETWANMODE="1"
    getwanparameters || return

    # Check if WAN Interfaces are Disabled
    if [[ "$ENABLE" == "0" ]] &>/dev/null;then
      logger -p 1 -st "$ALIAS" "WAN Status - ${WANPREFIX} disabled"
      STATUS="DISABLED"
      logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
      setwanstatus && continue
    # Check if WAN is Enabled
    elif [[ "$ENABLE" == "1" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "WAN Status - ${WANPREFIX} enabled"
      # Check WAN Connection
      logger -p 6 -t "$ALIAS" "Debug - Checking ${WANPREFIX} State"
      if [[ "$AUXSTATE" == "1" ]] &>/dev/null || [[ -z "$GWIFNAME" ]] &>/dev/null || { [[ "$DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$IFNAME" ]] &>/dev/null ;} ;};then
        [[ "$DUALWANDEV" != "usb" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "WAN Status - ${WANPREFIX}: Cable Unplugged"
        [[ "$DUALWANDEV" == "usb" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "WAN Status - ${WANPREFIX}: USB Unplugged" && RESTARTSERVICESMODE="2" && restartservices
        STATUS="UNPLUGGED"
        logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
        setwanstatus && continue
      elif [[ "$AUXSTATE" == "0" ]] &>/dev/null && [[ "$STATE" == "3" ]] &>/dev/null;then
        nvram set "${WANPREFIX}"_state_t="2" ; STATE="2"
        sleep 3
        STATE="$(nvram get "${WANPREFIX}"_state_t & nvramcheck)"
      elif { [[ "$AUXSTATE" == "0" ]] &>/dev/null || { [[ "$DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$USBMODEMREADY" == "1" ]] &>/dev/null && [[ -n "$IFNAME" ]] &>/dev/null ;} ;} ;} && [[ "$STATE" != "2" ]] &>/dev/null;then
        restartwan${WANSUFFIX} &
        restartwanpid="$!"
        wait $restartwanpid && unset restartwanpid
        STATE="$(nvram get "${WANPREFIX}"_state_t & nvramcheck)"
        logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Post-Restart State: $STATE"
        if { [[ "$AUXSTATE" == "0" ]] &>/dev/null || { [[ "$DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$USBMODEMREADY" == "1" ]] &>/dev/null && [[ -n "$IFNAME" ]] &>/dev/null ;} ;} ;} && [[ "$STATE" != "2" ]] &>/dev/null;then
          logger -p 1 -st "$ALIAS" "WAN Status - ${WANPREFIX}: Disconnected"
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
          setwanstatus && continue
        elif [[ "$STATE" == "2" ]] &>/dev/null;then
          logger -p 4 -st "$ALIAS" "WAN Status - Successfully Restarted ${WANPREFIX}"
          [[ "$DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$USBMODEMREADY" == "1" ]] &>/dev/null && RESTARTSERVICESMODE="2" && restartservices
          sleep 5
        else
          wanstatus
        fi
      fi

      # Check if WAN Gateway IP or IP Address are 0.0.0.0 or null
      logger -p 6 -t "$ALIAS" "Debug - Checking ${WANPREFIX} for null IP or Gateway"
      if { { [[ "$IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$IPADDR" ]] &>/dev/null ;} || { [[ "$GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$GATEWAY" ]] &>/dev/null ;} ;};then
        [[ "$IPADDR" == "0.0.0.0" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} IP Address: $IPADDR"
        [[ -z "$IPADDR" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} IP Address: Null"
        [[ "$IPADDR" == "0.0.0.0" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} Gateway IP Address: $GATEWAY"
        [[ -z "$GATEWAY" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} Gateway IP Address: Null"
        STATUS="DISCONNECTED"
        logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
        setwanstatus && continue
      fi

      # Check WAN Routing Table for Default Routes
      checkroutingtable &
      CHECKROUTINGTABLEPID="$!"
      wait $CHECKROUTINGTABLEPID
      unset CHECKROUTINGTABLEPID

      # Check WAN Packet Loss
      logger -p 6 -t "$ALIAS" "Debug - Recursive Ping Check: $RECURSIVEPINGCHECK"
      i="1"
      PACKETLOSS=""
      PINGTIME=""
      while [[ "$i" -le "$RECURSIVEPINGCHECK" ]] &>/dev/null;do
        # Determine IP Rule or Route for successful ping
        [[ -z "${PINGPATH+x}" ]] &>/dev/null && PINGPATH="0"
        # Check WAN Target IP Rule specifying Outbound Interface
        logger -p 6 -t "$ALIAS" "Debug - Checking ${WANPREFIX} for IP Rule to $TARGET"
        if [[ "$PINGPATH" == "0" ]] &>/dev/null || [[ "$PINGPATH" == "1" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from all iif lo to $TARGET oif $GWIFNAME lookup ${TABLE} priority $PRIORITY)" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "WAN Status - Adding IP Rule for $TARGET to monitor ${WANPREFIX}"
            ip rule add from all iif lo to $TARGET oif $GWIFNAME table $TABLE priority $PRIORITY \
            && logger -p 4 -t "$ALIAS" "WAN Status - Added IP Rule for $TARGET to monitor ${WANPREFIX}" \
            || { logger -p 2 -t "$ALIAS" "WAN Status - ***Error*** Unable to add IP Rule for $TARGET to monitor ${WANPREFIX}" && sleep 1 && wanstatus ;}
          fi
          logger -p 6 -t "$ALIAS" "Debug - "Checking ${WANPREFIX}" for packet loss via $TARGET - Attempt: $i"
          ping${WANPREFIX}target &
          PINGWANPID="$!"
          wait $PINGWANPID
          PACKETLOSS="$(sed -n 1p /tmp/${WANPREFIX}packetloss.tmp)"
          PINGTIME="$(sed -n 2p /tmp/${WANPREFIX}packetloss.tmp)"          
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Packet Loss: $PACKETLOSS"
          if [[ "$PINGPATH" != "0" ]] &>/dev/null && [[ "$PACKETLOSS" != "0%" ]] &>/dev/null;then
            restartwan${WANSUFFIX} &
            restartwanpid="$!"
            wait $restartwanpid && unset restartwanpid
            STATE="$(nvram get "${WANPREFIX}"_state_t & nvramcheck)"
          fi
          if [[ "$PINGPATH" != "1" ]] &>/dev/null && [[ "$PACKETLOSS" == "0%" ]] &>/dev/null;then
            PINGPATH="1" && setwanstatus
          elif [[ "$PINGPATH" != "1" ]] &>/dev/null && [[ "$PACKETLOSS" != "0%" ]] &>/dev/null;then
            ip rule del from all iif lo to $TARGET oif $GWIFNAME table $TABLE priority $PRIORITY
          elif [[ "$PINGPATH" == "1" ]] &>/dev/null && [[ "$PACKETLOSS" == "100%" ]] &>/dev/null && [[ "$STATE" == "2" ]] &>/dev/null;then
            ip rule del from all iif lo to $TARGET oif $GWIFNAME table $TABLE priority $PRIORITY
            PINGPATH="0"
          fi
        fi

        # Check WAN Target IP Rule without specifying Outbound Interface
        if [[ "$PINGPATH" == "0" ]] &>/dev/null || [[ "$PINGPATH" == "2" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from all iif lo to $TARGET lookup ${TABLE} priority $PRIORITY)" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "WAN Status - Adding IP Rule for $TARGET to monitor ${WANPREFIX} without specifying Outbound Interface"
            ip rule add from all iif lo to $TARGET table $TABLE priority $PRIORITY \
            && logger -p 4 -t "$ALIAS" "WAN Status - Added IP Rule for $TARGET to monitor ${WANPREFIX} without specifying Outbound Interface" \
            || { logger -p 2 -t "$ALIAS" "WAN Status - ***Error*** Unable to add IP Rule for $TARGET to monitor ${WANPREFIX} without specifying Outbound Interface" && sleep 1 && wanstatus ;}
          fi
          ping${WANPREFIX}target &
          PINGWANPID="$!"
          wait $PINGWANPID
          PACKETLOSS="$(sed -n 1p /tmp/${WANPREFIX}packetloss.tmp)"
          PINGTIME="$(sed -n 2p /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Packet Loss: $PACKETLOSS"
          [[ "$PACKETLOSS" == "0%" ]] &>/dev/null && [[ "$PINGPATH" != "2" ]] &>/dev/null && PINGPATH="2" && setwanstatus
          [[ -z "${pingpath2warning+x}" ]] &>/dev/null && pingpath2warning="0"
          [[ "$pingpath2warning" == "0" ]] &>/dev/null && [[ "$PINGPATH" == "2" ]] &>/dev/null && logger -p 3 -t "$ALIAS" "WAN Status - ***Warning*** Compatibility issues with $TARGET may occur without specifying Outbound Interface" && pingpath2warning="1"
          [[ "$PINGPATH" == "0" ]] &>/dev/null && [[ "$PACKETLOSS" != "0%" ]] &>/dev/null && ip rule del from all iif lo to $TARGET table $TABLE priority $PRIORITY
        fi

        # Check WAN Route for Target IP
        logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
        if [[ "$PINGPATH" == "0" ]] &>/dev/null || [[ "$PINGPATH" == "3" ]] &>/dev/null;then
         if [[ -z "$(ip route list $TARGET via $GATEWAY dev $GWIFNAME table main)" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "WAN Status - Adding route for $TARGET via $GATEWAY dev $GWIFNAME"
            ip route add $TARGET via $GATEWAY dev $GWIFNAME table main \
            && logger -p 4 -t "$ALIAS" "WAN Status - Added route for $TARGET via $GATEWAY dev $GWIFNAME" \
            || { logger -p 2 -t "$ALIAS" "WAN Status - ***Error*** Unable to add route for $TARGET via $GATEWAY dev $GWIFNAME" && sleep 1 && wanstatus ;}
          fi
          ping${WANPREFIX}target &
          PINGWANPID="$!"
          wait $PINGWANPID
          PACKETLOSS="$(sed -n 1p /tmp/${WANPREFIX}packetloss.tmp)"
          PINGTIME="$(sed -n 2p /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Packet Loss: $PACKETLOSS"
          [[ "$PACKETLOSS" == "0%" ]] &>/dev/null && [[ "$PINGPATH" != "3" ]] &>/dev/null && PINGPATH="3" && setwanstatus
          [[ -z "${pingpath3warning+x}" ]] &>/dev/null && pingpath3warning="0"
          [[ "$pingpath3warning" == "0" ]] &>/dev/null && [[ "$PINGPATH" == "3" ]] &>/dev/null && logger -p 3 -t "$ALIAS" "WAN Status - ***Warning*** Compatibility issues with $TARGET may occur with adding route via $GATEWAY dev $GWIFNAME" && pingpath3warning="1"
          [[ "$PINGPATH" == "0" ]] &>/dev/null && [[ "$PACKETLOSS" != "0%" ]] &>/dev/null && ip route del $TARGET via $GATEWAY dev $GWIFNAME table main
        fi
        logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Ping Path: $PINGPATH"
        if [[ "$PINGPATH" == "0" ]] &>/dev/null;then
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] &>/dev/null;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
          restartwan${WANSUFFIX} &
          restartwanpid="$!"
          wait $restartwanpid && unset restartwanpid
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] &>/dev/null;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Post-Restart State: $STATE"
        fi

        # Determine WAN Status based on Packet Loss
        if { [[ "$PACKETLOSS" == "0%" ]] &>/dev/null || [[ "$PACKETLOSS" != "100%" ]] &>/dev/null ;} && [[ -n "$PACKETLOSS" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss"
          logger -p 5 -t "$ALIAS" "WAN Status - ${WANPREFIX} has a "$PINGTIME"ms ping time"
          STATUS="CONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
          [[ "$STATE" != "2" ]] &>/dev/null && nvram set ${WANPREFIX}_state_t="2"
          setwanstatus && break 1
        elif [[ "$STATE" == "2" ]] &>/dev/null && [[ "$PACKETLOSS" == "100%" ]] &>/dev/null;then
          logger -p 2 -st "$ALIAS" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss"
          [[ "$READYSTATE" == "0" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "***Verify $TARGET is a valid server for ICMP Echo Requests for ${WANPREFIX}***"
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] &>/dev/null;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
        else
          logger -p 2 -st "$ALIAS" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss"
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Status: $STATUS"
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] &>/dev/null;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
        fi
      done
      [[ -n "${PINGPATH+x}" ]] && unset PINGPATH
      [[ -n "${PACKETLOSS+x}" ]] && unset PACKETLOSS
      [[ -n "${PINGTIME+x}" ]] && unset PINGTIME
      [[ -n "${i+x}" ]] && unset i
    fi
  done
fi

# Debug Logging
debuglog || return

# Update DNS
switchdns || return

# Check IP Rules and IPTables Rules
checkiprules || return

# Set Script Ready State
if [[ "$READYSTATE" == "0" ]] &>/dev/null;then
  READYSTATE="1"
  email="0"
fi

# Set Status for Email Notification On if Unset
[[ -z "${email+x}" ]] &>/dev/null && email="1"

# Set WAN Status to DISABLED, DISCONNECTED, or CONNECTED and select function.
logger -p 6 -t "$ALIAS" "Debug - WAN0STATUS: $WAN0STATUS"
logger -p 6 -t "$ALIAS" "Debug - WAN1STATUS: $WAN1STATUS"

# Checking if WAN Disabled returned to WAN Status and resetting loop iterations if WAN Status has changed
if [[ -z "${wandisabledloop+x}" ]] &>/dev/null;then
  [[ -n "${wan0disabled+x}" ]] &>/dev/null && unset wan0disabled
  [[ -n "${wan1disabled+x}" ]] &>/dev/null && unset wan1disabled
elif [[ -n "${wandisabledloop+x}" ]] || [[ "$wandisabledloop" != "0" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Returning to WAN Disabled"
  wandisabled
fi

# Getting Active WAN Parameters
GETWANMODE="3"
getwanparameters || return

# Determine which function to go to based on Failover Mode and WAN Status
if [[ "${mode}" == "initiate" ]] &>/dev/null;then
  logger -p 4 -st "$ALIAS" "WAN Status - Initiate Completed"
  return
elif [[ "$WAN0STATUS" != "CONNECTED" ]] &>/dev/null && [[ "$WAN1STATUS" != "CONNECTED" ]] &>/dev/null;then
  wandisabled
elif [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$WAN0STATUS" == "CONNECTED" ]] &>/dev/null;then
  # Verify WAN Properties are synced with Primary WAN
  [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null && SWITCHPRIMARY="0" && switchwan && switchdns && checkiprules
  # Switch WAN to Primary WAN
  [[ "$WAN0PRIMARY" != "1" ]] &>/dev/null && { logger -p 6 -t "$ALIAS" "Debug - WAN0 is not Primary WAN" && failover ;}
  # Send Email if Enabled
  [[ "$email" == "1" ]] &>/dev/null && sendemail && email="0"
  # Determine which function to use based on Secondary WAN
  [[ "$WAN1STATUS" == "CONNECTED" ]] &>/dev/null && wan0failovermonitor
  [[ "$WAN1STATUS" == "UNPLUGGED" ]] &>/dev/null && wandisabled
  [[ "$WAN1STATUS" == "DISCONNECTED" ]] &>/dev/null && wandisabled
  [[ "$WAN1STATUS" == "DISABLED" ]] &>/dev/null && wandisabled
elif [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$WAN1STATUS" == "CONNECTED" ]] &>/dev/null;then
  # Verify WAN Properties are synced with Primary WAN
  [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null && SWITCHPRIMARY="0" && switchwan && switchdns && checkiprules
  # Switch WAN to Primary WAN
  [[ "$WAN1PRIMARY" != "1" ]] &>/dev/null && { logger -p 6 -t "$ALIAS" "Debug - WAN1 is not Primary WAN" && failover && email="0" ;}
  # Send Email if Enabled
  [[ "$email" == "1" ]] &>/dev/null && sendemail && email="0"
  # Determine which function to use based on Secondary WAN
  [[ "$WAN0STATUS" == "UNPLUGGED" ]] &>/dev/null && wandisabled
  [[ "$WAN0STATUS" == "DISCONNECTED" ]] &>/dev/null && { [[ -n "${WAN0PACKETLOSS+x}" ]] &>/dev/null && [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null && wan0failbackmonitor || wandisabled ;}
  [[ "$WAN0STATUS" == "DISABLED" ]] &>/dev/null && wandisabled
elif [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
  lbmonitor
else
  wanstatus
fi
}

# Check WAN Routing Table
checkroutingtable ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: checkroutingtable"

for WANPREFIX in ${WANPREFIXES};do
  # Getting WAN Parameters
  GETWANMODE="1"
  getwanparameters || return

  # Check if WAN is Enabled
  [[ "$ENABLE" == "0" ]] &>/dev/null && continue

  # Check if WAN is in Ready State
  [[ "$STATE" != "2" ]] &>/dev/null || [[ "$AUXSTATE" != "0" ]] &>/dev/null && continue

  # Check if WAN Gateway IP or IP Address are 0.0.0.0 or null
  logger -p 6 -t "$ALIAS" "Debug - Checking ${WANPREFIX} for null IP or Gateway"
  if { { [[ "$IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$IPADDR" ]] &>/dev/null ;} || { [[ "$GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$GATEWAY" ]] &>/dev/null ;} ;};then
    [[ "$IPADDR" == "0.0.0.0" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} IP Address: $IPADDR"
    [[ -z "$IPADDR" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} IP Address: Null"
    [[ "$IPADDR" == "0.0.0.0" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} Gateway IP Address: $GATEWAY"
    [[ -z "$GATEWAY" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} Gateway IP Address: Null"
    continue
  fi

  # Check WAN Routing Table for Default Routes
  logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
  if [[ -z "$(ip route list default table "$TABLE" | awk '{print $3" "$5}' | grep -w "$GATEWAY $GWIFNAME")" ]] &>/dev/null;then
   [[ -n "$(ip route list default table $TABLE)" ]] &>/dev/null && ip route del default table $TABLE
     logger -p 5 -t "$ALIAS" "Check Routing Table - Adding default route for ${WANPREFIX} Routing Table via "$GATEWAY" dev $GWIFNAME"
     ip route add default via $GATEWAY dev $GWIFNAME table $TABLE \
     && logger -p 4 -t "$ALIAS" "Check Routing Table - Added default route for ${WANPREFIX} Routing Table via $GATEWAY dev $GWIFNAME" \
     || logger -p 2 -t "$ALIAS" "Check Routing Table - ***Error*** Unable to add default route for ${WANPREFIX} Routing Table via $GATEWAY dev $GWIFNAME"
  fi

  # Check WAN Routing Table for Target IP Route
  logger -p 6 -t "$ALIAS" "Debug - Checking ${WANPREFIX} for route to Target IP: $TARGET for ${WANPREFIX} Routing Table via $GATEWAY dev $GWIFNAME"
  if [[ -z "$(ip route list $TARGET via $GATEWAY dev $GWIFNAME table $TABLE)" ]] &>/dev/null;then
     logger -p 5 -t "$ALIAS" "Check Routing Table - Adding route to Target IP: $TARGET for ${WANPREFIX} Routing Table via $GATEWAY dev $GWIFNAME"
     ip route add $TARGET via $GATEWAY dev $GWIFNAME table $TABLE \
     && logger -p 4 -t "$ALIAS" "Check Routing Table - Added default route to Target IP: $TARGET for ${WANPREFIX} Routing Table via $GATEWAY dev $GWIFNAME" \
     || logger -p 2 -t "$ALIAS" "Check Routing Table - ***Error*** Unable to add default route to Target IP: $TARGET for ${WANPREFIX} Routing Table via $GATEWAY dev $GWIFNAME"
  fi

done

return
}

# Check IP Rules and IPTables Rules
checkiprules ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: checkiprules"

# Get System Parameters
getsystemparameters || return

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE="2"
  getwanparameters || return
fi

for WANPREFIX in ${WANPREFIXES};do
  # Getting WAN Parameters
  GETWANMODE="1"
  getwanparameters || return

  # Check Rules if Status is Connected
  if [[ "$STATUS" == "CONNECTED" ]] &>/dev/null || { [[ "$ENABLE" == "1" ]] &>/dev/null && { [[ "$STATE" == "2" ]] &>/dev/null || [[ "$AUXSTATE" != "1" ]] &>/dev/null ;} ;};then
    # Create WAN NAT Rules
    # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
    if [[ "$HTTPENABLE" == "1" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - HTTP Web Access: "$HTTPENABLE""
      # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
      if [[ -z "$(iptables -t nat -L PREROUTING -v -n | awk '{ if( !/GAME_VSERVER/ && /VSERVER/ && /'$IPADDR'/ ) print}')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" creating VSERVER Rule for "$IPADDR""
        iptables -t nat -A PREROUTING -d $IPADDR -j VSERVER \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" created VSERVER Rule for "$IPADDR"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** "${WANPREFIX}" unable to create VSERVER Rule for "$IPADDR""
      fi
    fi
    # Create UPNP Rules if Enabled
    if [[ "$UPNPENABLE" == "1" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" UPNP Enabled: "$UPNPENABLE""
      if [[ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /PUPNP/ && /'$GWIFNAME'/ ) print}')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" creating UPNP Rule for "$GWIFNAME""
        iptables -t nat -A POSTROUTING -o $GWIFNAME -j PUPNP \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" created UPNP Rule for "$GWIFNAME"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - *** Error*** "${WANPREFIX}" unable to create UPNP Rule for "$GWIFNAME""
      fi
    fi
    # Create MASQUERADE Rules if NAT is Enabled
    if [[ "$NAT" == "1" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" NAT Enabled: "$NAT""
      if [[ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /MASQUERADE/ && /'$GWIFNAME'/ && /'$IPADDR'/ ) print}')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding iptables MASQUERADE rule for excluding "$IPADDR" via "$GWIFNAME""
        iptables -t nat -A POSTROUTING -o $GWIFNAME ! -s $IPADDR -j MASQUERADE \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added iptables MASQUERADE rule for excluding "$IPADDR" via "$GWIFNAME"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add iptables MASQUERADE rule for excluding "$IPADDR" via "$GWIFNAME""
      fi
    fi
  fi

  # Check Rules for Failover Mode
  if [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Failover Block IPv6: $FOBLOCKIPV6"
    if [[ "$FOBLOCKIPV6" == "1" ]] &>/dev/null;then
      if [[ "$PRIMARY" == "1" ]] &>/dev/null && [[ -n "$(ip -6 rule list from all oif $GWIFNAME priority $PRIORITY | grep -w "blackhole")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Removing Blackhole IPv6 Rule for ${WANPREFIX}"
        ip -6 rule del blackhole from all oif $GWIFNAME priority $PRIORITY \
          && logger -p 4 -t "$ALIAS" "Check IP Rules - Removed Blackhole IPv6 Rule for ${WANPREFIX}" \
          || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to remove Blackhole IPv6 Rule for ${WANPREFIX}"
      elif [[ "$PRIMARY" == "0" ]] &>/dev/null && [[ -z "$(ip -6 rule list from all oif $GWIFNAME priority $PRIORITY | grep -w "blackhole")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding Blackhole IPv6 Rule for ${WANPREFIX}"
        ip -6 rule add blackhole from all oif $GWIFNAME priority $PRIORITY \
          && logger -p 4 -t "$ALIAS" "Check IP Rules - Added Blackhole IPv6 Rule for ${WANPREFIX}" \
          || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add Blackhole IPv6 Rule for ${WANPREFIX}"
      fi
    fi

  # Check Rules for Load Balance Mode
  elif [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Checking IPTables Mangle Rules"
    # Check IPTables Mangle Balance Rules for PREROUTING Table
    if [[ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$LANIFNAME'/ && /state/ && /NEW/ ) print}')" ]] &>/dev/null;then
      logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables MANGLE Balance Rule for "$LANIFNAME""
      iptables -t mangle -A PREROUTING -i $LANIFNAME -m state --state NEW -j balance \
      && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables MANGLE Balance Rule for "$LANIFNAME"" \
      || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE Balance Rule for "$LANIFNAME""
    fi

    # Check Rules if Status is Connected
    if [[ "$STATUS" == "CONNECTED" ]] &>/dev/null;then
      # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
      if [[ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$LANIFNAME'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables - PREROUTING MANGLE match rule for "$LANIFNAME" marked with "$MARK""
        iptables -t mangle -A PREROUTING -i $LANIFNAME -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables - PREROUTING MANGLE match rule for "$LANIFNAME" marked with "$MARK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables - PREROUTING MANGLE match rule for "$LANIFNAME" marked with "$MARK""
      fi
      # Check IPTables Mangle Match Rule for WAN for OUTPUT Table
      if [[ -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$GWIFNAME'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$MARK""
        iptables -t mangle -A OUTPUT -o $GWIFNAME -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$MARK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$MARK""
      fi
      if [[ -n "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$GWIFNAME'/ && /connmark match/ && /'$DELETEMARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ]] &>/dev/null;then
        logger -p 6 -t "$ALIAS" "Check IP Rules - Deleting IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$DELETEMARK""
        iptables -t mangle -D OUTPUT -o $GWIFNAME -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 6 -t "$ALIAS" "Check IP Rules - Deleted IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$DELETEMARK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to delete IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$DELETEMARK""
      fi
      # Check IPTables Mangle Set XMark Rule for WAN for PREROUTING Table
      if [[ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$GWIFNAME'/ && /state/ && /NEW/ && /CONNMARK/ && /xset/ && /'$MARK'/ ) print}')" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables - PREROUTING MANGLE set xmark rule for "$GWIFNAME""
        iptables -t mangle -A PREROUTING -i $GWIFNAME -m state --state NEW -j CONNMARK --set-xmark "$MARK"/"$MASK" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables - PREROUTING MANGLE set xmark rule for "$GWIFNAME"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to delete IPTables - PREROUTING MANGLE set xmark rule for "$GWIFNAME""
      fi
      # Create WAN IP Address Rule
      if { [[ "$IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$IPADDR" ]] &>/dev/null ;} && [[ -z "$(ip rule list from $IPADDR lookup ${TABLE} priority "$FROMWANPRIORITY")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$IPADDR" lookup "${TABLE}""
        ip rule add from $IPADDR lookup ${TABLE} priority "$FROMWANPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$IPADDR" lookup "${TABLE}"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$IPADDR" lookup "${TABLE}""
      fi
      # Create WAN Gateway IP Rule
      if { [[ "$GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$GATEWAY" ]] &>/dev/null ;} && [[ -z "$(ip rule list from all to $GATEWAY lookup ${TABLE} priority "$TOWANPRIORITY")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule from all to "$GATEWAY" lookup "${TABLE}""
        ip rule add from all to $GATEWAY lookup ${TABLE} priority "$TOWANPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule from all to "$GATEWAY" lookup "${TABLE}"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$GATEWAY" lookup "${TABLE}""
      fi
      # Create WAN DNS IP Rules
      if [[ "$DNSENABLE" == "0" ]] &>/dev/null;then
        if [[ -n "$DNS1" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from "$DNS1" lookup ${TABLE} priority "$FROMWANPRIORITY")" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$DNS1" lookup "${TABLE}""
            ip rule add from $DNS1 lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$DNS1" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$DNS1" lookup "${TABLE}""
          fi
          if [[ -z "$(ip rule list from all to "$DNS1" lookup ${TABLE} priority "$TOWANPRIORITY")" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule from all to "$DNS1" lookup "${TABLE}""
            ip rule add from all to $DNS1 lookup ${TABLE} priority "$TOWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule from all to "$DNS1" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$DNS1" lookup "${TABLE}""
          fi
        fi
        if [[ -n "$DNS2" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from "$DNS2" lookup ${TABLE} priority "$FROMWANPRIORITY")" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$DNS2" lookup "${TABLE}""
            ip rule add from $DNS2 lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$DNS2" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$DNS2" lookup "${TABLE}""
          fi
          if [[ -z "$(ip rule list from all to "$DNS2" lookup ${TABLE} priority "$TOWANPRIORITY")" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule from all to "$DNS2" lookup "${TABLE}""
            ip rule add from all to $DNS2 lookup ${TABLE} priority "$TOWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule from all to "$DNS2" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$DNS2" lookup "${TABLE}""
          fi
        fi
      elif [[ "$DNSENABLE" == "1" ]] &>/dev/null;then
        if [[ -n "$AUTODNS1" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from "$AUTODNS1" lookup ${TABLE} priority "$FROMWANPRIORITY")" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$AUTODNS1" lookup "${TABLE}""
            ip rule add from $AUTODNS1 lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$AUTODNS1" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$AUTODNS1" lookup "${TABLE}""
          fi
        fi
        if [[ -n "$AUTODNS2" ]] &>/dev/null;then
          if [[ -z "$(ip rule list from "$AUTODNS2" lookup ${TABLE} priority "$FROMWANPRIORITY")" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$AUTODNS2" lookup "${TABLE}""
            ip rule add from $AUTODNS2 lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$AUTODNS2" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$AUTODNS2" lookup "${TABLE}""
          fi
        fi
      fi

      # Check Guest Network Rules for Load Balance Mode
      logger -p 6 -t "$ALIAS" "Debug - Checking Guest Networks IPTables Mangle Rules"
      i=0
      while [[ "$i" -le "10" ]] &>/dev/null;do
        i=$(($i+1))
        GUESTLANIFNAME="$(nvram get lan${i}_ifname & nvramcheck)"
        if [[ -n "$GUESTLANIFNAME" ]] &>/dev/null;then
          if [[ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$GUESTLANIFNAME'/ && /state/ && /NEW/ ) print}')" ]] &>/dev/null;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables MANGLE Balance Rule for "$GUESTLANIFNAME""
            iptables -t mangle -A PREROUTING -i $GUESTLANIFNAME -m state --state NEW -j balance \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables MANGLE Balance Rule for "$GUESTLANIFNAME"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE Balance Rule for "$GUESTLANIFNAME""
          fi
        fi
  
        # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
        if [[ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$GUESTLANIFNAME'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables MANGLE match rule for "$GUESTLANIFNAME" marked with "$MARK""
          iptables -t mangle -A PREROUTING -i $GUESTLANIFNAME -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
          && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables MANGLE match rule for "$GUESTLANIFNAME" marked with "$MARK"" \
          || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE match rule for "$GUESTLANIFNAME" marked with "$MARK""
        fi
      done
      unset GUESTLANIFNAME
      unset i

      # Create fwmark IP Rules
      logger -p 6 -t "$ALIAS" "Debug - Checking fwmark IP Rules"
      if [[ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule add from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY" \
          && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE"" \
          || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
      fi
      if [[ -n "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Removing Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule del blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY" \
          && logger -p 4 -t "$ALIAS" "Check IP Rules - Removed Blackhole IP Rule for fwmark "$MARK"/"$MASK"" \
          || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to remove Blackhole IP Rule for fwmark "$MARK"/"$MASK""
      fi

      # If OVPN Split Tunneling is Disabled in Configuration, create rules for WAN Interface.
      logger -p 6 -t "$ALIAS" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] &>/dev/null;then
        # Create IP Rules for OVPN Remote Addresses
          for REMOTEADDRESS in ${REMOTEADDRESSES};do
            REMOTEIP="$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')"
            logger -p 6 -t "$ALIAS" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
            if [[ -n "$REMOTEIP" ]] &>/dev/null;then
              logger -p 6 -t "$ALIAS" "Debug - Remote IP Address: "$REMOTEIP""
              if [[ -z "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ]] &>/dev/null;then
                logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
                ip rule add from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY" \
                && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY"" \
                || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
              fi
            else
              logger -p 6 -t "$ALIAS" "Debug - Unable to query "$REMOTEADDRESS""
            fi
          done
      fi

    # Check Rules if Status is Disconnected
    elif [[ "$STATUS" != "CONNECTED" ]] &>/dev/null;then
      # Create fwmark IP Rules
      logger -p 6 -t "$ALIAS" "Debug - Checking fwmark IP Rules"
      if [[ -n "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Removing IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule del from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Removed IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to remove IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
      fi
      if [[ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ]] &>/dev/null;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule add blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added Blackhole IP Rule for fwmark "$MARK"/"$MASK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add Blackhole IP Rule for fwmark "$MARK"/"$MASK""
      fi
      
      # If OVPN Split Tunneling is Disabled in Configuration, delete rules for down WAN Interface.
      logger -p 6 -t "$ALIAS" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] &>/dev/null;then
        # Create IP Rules for OVPN Remote Addresses
        for REMOTEADDRESS in ${REMOTEADDRESSES};do
          logger -p 6 -t "$ALIAS" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
          REMOTEIP="$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')"
          if [[ -n "$REMOTEIP" ]] &>/dev/null;then
            logger -p 6 -t "$ALIAS" "Debug - Remote IP Address: "$REMOTEIP""
            if [[ -n "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ]] &>/dev/null;then
              logger -p 5 -t "$ALIAS" "Check IP Rules - Removing IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
              ip rule del from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY" \
              && logger -p 4 -t "$ALIAS" "Check IP Rules - Removed IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY"" \
              || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to remove IP Rule from all to "$REMOTEIP" lookup "$TABLE" priority "$OVPNWANPRIORITY""
            fi
          else
            logger -p 6 -t "$ALIAS" "Debug - Unable to query "$REMOTEADDRESS""
          fi
        done
      fi
    fi
  fi
done
return
}

# Get WAN Parameters
getwanparameters ()
{
# Get WAN Parameters Mode
# Mode 1 - Retrieve WAN0 and WAN1 Parameters using WANPREFIX Variables
# Mode 2 - Retrieve Global WAN Parameters
# Mode 3 - Retrieve Active WAN Parameters for Monitoring
[[ -z "${GETWANMODE+x}" ]] &>/dev/null && GETWANMODE="1"

# Set WAN Interface Parameters
if [[ "$GETWANMODE" == "1" ]] &>/dev/null;then

  logger -p 6 -t "$ALIAS" "Debug - Setting parameters for "${WANPREFIX}""

  while [[ -z "${wansync+x}" ]] &>/dev/null || [[ "$wansync" == "0" ]] &>/dev/null;do
    wansync="0"
    sleep 1

    # ENABLE
    ENABLE="$(nvram get ${WANPREFIX}_enable & nvramcheck)" && { [[ -n "$ENABLE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set ENABLE for "${WANPREFIX}"" && unset ENABLE && continue ;} ;}

    # STATE
    STATE="$(nvram get ${WANPREFIX}_state_t & nvramcheck)" && { [[ -n "$STATE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set STATE for "${WANPREFIX}"" && unset STATE && continue ;} ;}

    # AUXSTATE
    AUXSTATE="$(nvram get ${WANPREFIX}_auxstate_t & nvramcheck)" && { [[ -n "$AUXSTATE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set AUXSTATE for "${WANPREFIX}"" && unset AUXSTATE && continue ;} ;}

    # SBSTATE
    SBSTATE="$(nvram get ${WANPREFIX}_sbstate_t & nvramcheck)" && { [[ -n "$SBSTATE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set SBSTATE for "${WANPREFIX}"" && unset SBSTATE && continue ;} ;}
  
    # IPADDR
    IPADDR="$(nvram get ${WANPREFIX}_ipaddr & nvramcheck)" && { { [[ -n "$IPADDR" ]] &>/dev/null || [[ "$AUXSTATE" != "0" ]] &>/dev/null || [[ "$STATE" != "2" ]] &>/dev/null || [[ "$ENABLE" == "0" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPADDR for "${WANPREFIX}"" && unset IPADDR && continue ;} ;}

    # GATEWAY
    GATEWAY="$(nvram get ${WANPREFIX}_gateway & nvramcheck)" && { { [[ -n "$GATEWAY" ]] &>/dev/null || [[ "$AUXSTATE" != "0" ]] &>/dev/null || [[ "$STATE" != "2" ]] &>/dev/null || [[ "$ENABLE" == "0" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set GATEWAY for "${WANPREFIX}"" && unset GATEWAY && continue ;} ;}

    # GWIFNAME
    GWIFNAME="$(nvram get ${WANPREFIX}_gw_ifname & nvramcheck)" && { { [[ -n "$GWIFNAME" ]] &>/dev/null || [[ "$AUXSTATE" != "0" ]] &>/dev/null || [[ "$STATE" != "2" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set GWIFNAME for "${WANPREFIX}"" && unset GWIFNAME && continue ;} ;}

    # IFNAME
    IFNAME="$(nvram get ${WANPREFIX}_ifname & nvramcheck)" && { { [[ -n "$IFNAME" ]] &>/dev/null || [[ "$AUXSTATE" != "0" ]] &>/dev/null || [[ -z "$(nvram get ${WANPREFIX}_ifname & nvramcheck)" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set IFNAME for "${WANPREFIX}"" && unset IFNAME && continue ;} ;}

    # REALIPSTATE
    REALIPSTATE="$(nvram get ${WANPREFIX}_realip_state & nvramcheck)" && { [[ -n "$REALIPSTATE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set REALIPSTATE for "${WANPREFIX}"" && unset REALIPSTATE && continue ;} ;}

    # REALIPADDR
    REALIPADDR="$(nvram get ${WANPREFIX}_realip_ip & nvramcheck)" && { { [[ -n "$REALIPADDR" ]] &>/dev/null || [[ "$REALIPSTATE" != "2" ]] &>/dev/null || [[ -z "$(nvram get ${WANPREFIX}_realip_ip & nvramcheck)" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set REALIPADDR for "${WANPREFIX}"" && unset REALIPADDR && continue ;} ;}

    # PRIMARY
    PRIMARY="$(nvram get ${WANPREFIX}_primary & nvramcheck)" && { [[ -n "$PRIMARY" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set PRIMARY for "${WANPREFIX}"" && unset PRIMARY && continue ;} ;}

    # USBMODEMREADY
    USBMODEMREADY="$(nvram get ${WANPREFIX}_is_usb_modem_ready & nvramcheck)" && { { [[ -n "$USBMODEMREADY" ]] &>/dev/null || [[ -z "$(echo $WANSCAP | grep -o "usb")" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set USBMODEMREADY for "${WANPREFIX}"" && unset USBMODEMREADY && continue ;} ;}

    # DNSENABLE
    DNSENABLE="$(nvram get ${WANPREFIX}_dnsenable_x & nvramcheck)" && { [[ -n "$DNSENABLE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set DNSENABLE for "${WANPREFIX}"" && unset DNSENABLE && continue ;} ;}

    # DNS
    DNS="$(nvram get ${WANPREFIX}_dns & nvramcheck)" && { { [[ -n "$DNS" ]] &>/dev/null || [[ "$DNSENABLE" == "0" ]] &>/dev/null || [[ "$AUXSTATE" != "0" ]] &>/dev/null || [[ "$STATE" != "2" ]] &>/dev/null || [[ -z "$(nvram get ${WANPREFIX}_dns & nvramcheck)" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set DNS for "${WANPREFIX}"" && unset DNS && continue ;} ;}

    # AUTODNS1
    AUTODNS1="$(echo $DNS | awk '{print $1}')" && { { [[ -n "$AUTODNS1" ]] &>/dev/null || [[ -z "$DNS" ]] &>/dev/null || [[ -z "$(echo $DNS | awk '{print $1}')" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set AUTODNS1 for "${WANPREFIX}"" && unset AUTODNS1 && continue ;} ;}

    # AUTODNS2
    AUTODNS2="$(echo $DNS | awk '{print $2}')" && { { [[ -n "$AUTODNS2" ]] &>/dev/null || [[ -z "$DNS" ]] &>/dev/null || [[ -z "$(echo $DNS | awk '{print $2}')" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set AUTODNS2 for "${WANPREFIX}"" && unset AUTODNS2DNS && continue ;} ;}

    # DNS1
    DNS1="$(nvram get ${WANPREFIX}_dns1_x & nvramcheck)" && { { [[ -n "$DNS1" ]] &>/dev/null || [[ "$DNSENABLE" == "1" ]] &>/dev/null || [[ -z "$(nvram get ${WANPREFIX}_dns1_x & nvramcheck)" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set DNS1 for "${WANPREFIX}"" && unset DNS1 && continue ;} ;}

    # DNS2
    DNS2="$(nvram get ${WANPREFIX}_dns2_x & nvramcheck)" && { { [[ -n "$DNS2" ]] &>/dev/null || [[ "$DNSENABLE" == "1" ]] &>/dev/null || [[ -z "$(nvram get ${WANPREFIX}_dns2_x & nvramcheck)" ]] &>/dev/null ;} || { logger -p 6 -t "$ALIAS" "Debug - failed to set DNS2 for "${WANPREFIX}"" && unset DNS2 && continue ;} ;}

    # UPNPENABLE
    UPNPENABLE="$(nvram get ${WANPREFIX}_upnp_enable & nvramcheck)" && { [[ -n "$UPNPENABLE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set UPNPENABLE for "${WANPREFIX}"" && unset UPNPENABLE && continue ;} ;}

    # NAT
    NAT="$(nvram get ${WANPREFIX}_nat_x & nvramcheck)" && { [[ -n "$NAT" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set NAT for "${WANPREFIX}"" && unset NAT && continue ;} ;}

    if [[ "${WANPREFIX}" == "$WAN0" ]] &>/dev/null;then

      # DUALWANDEV
      if [[ -n "${WAN0DUALWANDEV+x}" ]] &>/dev/null;then
        DUALWANDEV="$WAN0DUALWANDEV"
      else
        DUALWANDEV="$(nvram get wans_dualwan | awk '{print $1}' & nvramcheck)" && { [[ -n "$DUALWANDEV" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set DUALWANDEV for "${WANPREFIX}"" && unset DUALWANDEV && continue ;} ;}
      fi

      # LINKWAN
      LINKWAN="$(nvram get link_wan & nvramcheck)" && { [[ -n "$LINKWAN" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set LINKWAN for "${WANPREFIX}"" && unset LINKWAN && continue ;} ;}

      # PINGPATH
      if [[ -n "${WAN0PINGPATH+x}" ]] &>/dev/null;then
        PINGPATH="$WAN0PINGPATH"
      else
        PINGPATH="0"
      fi

      # TARGET
      if [[ -n "${WAN0TARGET+x}" ]] &>/dev/null;then
        TARGET="$WAN0TARGET"
      else
        setvariables || return
        TARGET="$WAN0TARGET"
      fi

      # TABLE
      if [[ -n "${WAN0ROUTETABLE+x}" ]] &>/dev/null;then
        TABLE="$WAN0ROUTETABLE"
      else
        setvariables || return
        TABLE="$WAN0ROUTETABLE"
      fi

      # PRIORITY
      if [[ -n "${WAN0TARGETRULEPRIORITY+x}" ]] &>/dev/null;then
        PRIORITY="$WAN0TARGETRULEPRIORITY"
      else
        setvariables || return
        PRIORITY="$WAN0TARGETRULEPRIORITY"
      fi

      # MARK
      if [[ -n "${WAN0MARK+x}" ]] &>/dev/null;then
        MARK="$WAN0MARK"
      else
        setvariables || return
        MARK="$WAN0MARK"
      fi

      # DELETEMARK
      if [[ -n "${WAN1MARK+x}" ]] &>/dev/null;then
        DELETEMARK="$WAN1MARK"
      else
        setvariables || return
        DELETEMARK="$WAN1MARK"
      fi

      # MASK
      if [[ -n "${WAN0MASK+x}" ]] &>/dev/null;then
        MASK="$WAN0MASK"
      else
        setvariables || return
        MASK="$WAN0MASK"
      fi

      # FROMWANPRIORITY
      if [[ -n "${FROMWAN0PRIORITY+x}" ]] &>/dev/null;then
        FROMWANPRIORITY="$FROMWAN0PRIORITY"
      else
        setvariables || return
        FROMWANPRIORITY="$FROMWAN0PRIORITY"
      fi

      # TOWANPRIORITY
      if [[ -n "${TOWAN0PRIORITY+x}" ]] &>/dev/null;then
        TOWANPRIORITY="$TOWAN0PRIORITY"
      else
        setvariables || return
        TOWANPRIORITY="$TOWAN0PRIORITY"
      fi

      # OVPNWANPRIORITY
      if [[ -n "${OVPNWAN0PRIORITY+x}" ]] &>/dev/null;then
        OVPNWANPRIORITY="$OVPNWAN0PRIORITY"
      else
        setvariables || return
        OVPNWANPRIORITY="$OVPNWAN0PRIORITY"
      fi

      # WAN_QOS_ENABLE
      if [[ -n "${WAN0_QOS_ENABLE+x}" ]] &>/dev/null;then
        WAN_QOS_ENABLE="$WAN0_QOS_ENABLE"
      else
        setvariables || return
        WAN_QOS_ENABLE="$WAN0_QOS_ENABLE"
      fi

      # WAN_QOS_OBW
      if [[ -n "${WAN0_QOS_OBW+x}" ]] &>/dev/null;then
        WAN_QOS_OBW="$WAN0_QOS_OBW"
      else
        setvariables || return
        WAN_QOS_OBW="$WAN0_QOS_OBW"
      fi

      # WAN_QOS_IBW
      if [[ -n "${WAN0_QOS_IBW+x}" ]] &>/dev/null;then
        WAN_QOS_IBW="$WAN0_QOS_IBW"
      else
        setvariables || return
        WAN_QOS_IBW="$WAN0_QOS_IBW"
      fi

      # WAN_QOS_OVERHEAD
      if [[ -n "${WAN0_QOS_OVERHEAD+x}" ]] &>/dev/null;then
        WAN_QOS_OVERHEAD="$WAN0_QOS_OVERHEAD"
      else
        setvariables || return
        WAN_QOS_OVERHEAD="$WAN0_QOS_OVERHEAD"
      fi

      # WAN_QOS_ATM
      if [[ -n "${WAN0_QOS_ATM+x}" ]] &>/dev/null;then
        WAN_QOS_ATM="$WAN0_QOS_ATM"
      else
        setvariables || return
        WAN_QOS_ATM="$WAN0_QOS_ATM"
      fi

      # WANSUFFIX
      if [[ -n "${WAN0SUFFIX+x}" ]] &>/dev/null;then
        WANSUFFIX="$WAN0SUFFIX"
      else
        WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
        WAN0SUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
      fi

      # STATUS
      if [[ -n "${WAN0STATUS+x}" ]] &>/dev/null;then
        STATUS="$WAN0STATUS"
      elif [[ -z "${WAN0STATUS+x}" ]] &>/dev/null;then
        if [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
          [[ "$PRIMARY" == "1" ]] &>/dev/null && WAN0STATUS="CONNECTED"
          [[ "$PRIMARY" == "0" ]] &>/dev/null && WAN0STATUS="DISCONNECTED"
          [[ "$PRIMARY" == "0" ]] &>/dev/null && [[ "$AUXSTATE" == "1" ]] &>/dev/null && WAN0STATUS="UNPLUGGED"
        elif [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
          [[ "$STATE" == "2" ]] &>/dev/null && WAN0STATUS="CONNECTED"
          [[ "$STATE" != "2" ]] &>/dev/null && WAN0STATUS="DISCONNECTED"
          [[ "$AUXSTATE" == "1" ]] &>/dev/null && WAN0STATUS="UNPLUGGED"
        fi
      fi

    elif [[ "${WANPREFIX}" == "$WAN1" ]] &>/dev/null;then

      # DUALWANDEV
      if [[ -n "${WAN1DUALWANDEV+x}" ]] &>/dev/null;then
        DUALWANDEV="$WAN1DUALWANDEV"
      else
        DUALWANDEV="$(nvram get wans_dualwan | awk '{print $2}' & nvramcheck)" && { [[ -n "$DUALWANDEV" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set DUALWANDEV for "${WANPREFIX}"" && unset DUALWANDEV && continue ;} ;}
      fi

      # LINKWAN
      LINKWAN="$(nvram get link_wan1 & nvramcheck)" && { [[ -n "$LINKWAN" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set LINKWAN for "${WANPREFIX}"" && unset LINKWAN && continue ;} ;}

      # TARGET
      if [[ -n "${WAN1TARGET+x}" ]] &>/dev/null;then
        TARGET="$WAN1TARGET"
      else
        setvariables || return
        TARGET="$WAN1TARGET"
      fi

      # TABLE
      if [[ -n "${WAN1ROUTETABLE+x}" ]] &>/dev/null;then
        TABLE="$WAN1ROUTETABLE"
      else
        setvariables || return
        TABLE="$WAN1ROUTETABLE"
      fi

      # PRIORITY
      if [[ -n "${WAN1TARGETRULEPRIORITY+x}" ]] &>/dev/null;then
        PRIORITY="$WAN1TARGETRULEPRIORITY"
      else
        setvariables || return
        PRIORITY="$WAN1TARGETRULEPRIORITY"
      fi

      # MARK
      if [[ -n "${WAN1MARK+x}" ]] &>/dev/null;then
        MARK="$WAN1MARK"
      else
        setvariables || return
        MARK="$WAN1MARK"
      fi

      # DELETEMARK
      if [[ -n "${WAN0MARK+x}" ]] &>/dev/null;then
        DELETEMARK="$WAN0MARK"
      else
        setvariables || return
        DELETEMARK="$WAN0MARK"
      fi

      # MASK
      if [[ -n "${WAN1MASK+x}" ]] &>/dev/null;then
        MASK="$WAN1MASK"
      else
        setvariables || return
        MASK="$WAN1MASK"
      fi

      # FROMWANPRIORITY
      if [[ -n "${FROMWAN1PRIORITY+x}" ]] &>/dev/null;then
        FROMWANPRIORITY="$FROMWAN1PRIORITY"
      else
        setvariables || return
        FROMWANPRIORITY="$FROMWAN1PRIORITY"
      fi

      # TOWANPRIORITY
      if [[ -n "${TOWAN1PRIORITY+x}" ]] &>/dev/null;then
        TOWANPRIORITY="$TOWAN1PRIORITY"
      else
        setvariables || return
        TOWANPRIORITY="$TOWAN1PRIORITY"
      fi

      # OVPNWANPRIORITY
      if [[ -n "${OVPNWAN1PRIORITY+x}" ]] &>/dev/null;then
        OVPNWANPRIORITY="$OVPNWAN1PRIORITY"
      else
        setvariables || return
        OVPNWANPRIORITY="$OVPNWAN1PRIORITY"
      fi

      # WAN_QOS_ENABLE
      if [[ -n "${WAN1_QOS_ENABLE+x}" ]] &>/dev/null;then
        WAN_QOS_ENABLE="$WAN1_QOS_ENABLE"
      else
        setvariables || return
        WAN_QOS_ENABLE="$WAN1_QOS_ENABLE"
      fi

      # WAN_QOS_OBW
      if [[ -n "${WAN1_QOS_OBW+x}" ]] &>/dev/null;then
        WAN_QOS_OBW="$WAN1_QOS_OBW"
      else
        setvariables || return
        WAN_QOS_OBW="$WAN1_QOS_OBW"
      fi

      # WAN_QOS_IBW
      if [[ -n "${WAN1_QOS_IBW+x}" ]] &>/dev/null;then
        WAN_QOS_IBW="$WAN1_QOS_IBW"
      else
        setvariables || return
        WAN_QOS_IBW="$WAN1_QOS_IBW"
      fi

      # WAN_QOS_OVERHEAD
      if [[ -n "${WAN1_QOS_OVERHEAD+x}" ]] &>/dev/null;then
        WAN_QOS_OVERHEAD="$WAN1_QOS_OVERHEAD"
      else
        setvariables || return
        WAN_QOS_OVERHEAD="$WAN1_QOS_OVERHEAD"
      fi

      # WAN_QOS_ATM
      if [[ -n "${WAN1_QOS_ATM+x}" ]] &>/dev/null;then
        WAN_QOS_ATM="$WAN1_QOS_ATM"
      else
        setvariables || return
        WAN_QOS_ATM="$WAN1_QOS_ATM"
      fi

      # WANSUFFIX
      if [[ -n "${WAN1SUFFIX+x}" ]] &>/dev/null;then
        WANSUFFIX="$WAN1SUFFIX"
      else
        WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
        WAN1SUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
      fi

      # STATUS
      if [[ -n "${WAN1STATUS+x}" ]] &>/dev/null;then
        STATUS="$WAN1STATUS"
      elif [[ -z "${WAN1STATUS+x}" ]] &>/dev/null;then
        if [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
          [[ "$PRIMARY" == "1" ]] &>/dev/null && WAN1STATUS="CONNECTED"
          [[ "$PRIMARY" == "0" ]] &>/dev/null && WAN1STATUS="DISCONNECTED"
          [[ "$PRIMARY" == "0" ]] &>/dev/null && [[ "$AUXSTATE" == "1" ]] &>/dev/null && WAN1STATUS="UNPLUGGED"
        elif [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
          [[ "$STATE" == "2" ]] &>/dev/null && WAN1STATUS="CONNECTED"
          [[ "$STATE" != "2" ]] &>/dev/null && WAN1STATUS="DISCONNECTED"
          [[ "$AUXSTATE" == "1" ]] &>/dev/null && WAN1STATUS="UNPLUGGED"
        fi
      fi

    fi
    wansync="1"
  done
  unset wansync

# Get Global WAN Parameters
elif [[ "$GETWANMODE" == "2" ]] &>/dev/null;then
  while [[ -z "${globalwansync+x}" ]] &>/dev/null || [[ "$globalwansync" == "0" ]] &>/dev/null;do
    [[ -z "${globalwansync+x}" ]] &>/dev/null && globalwansync="0"
    [[ "$globalwansync" == "1" ]] && break
    sleep 1
    
    # WANSDUALWAN
    if [[ -z "${WANSDUALWAN+x}" ]] &>/dev/null;then
      WANSDUALWAN="$(nvram get wans_dualwan & nvramcheck)"
      [[ -n "$WANSDUALWAN" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WANSDUALWAN" && unset WANSDUALWAN && continue ;}
    fi

    # WANSDUALWANENABLE
    if [[ -z "${WANSDUALWANENABLE+x}" ]] &>/dev/null;then
      { [[ -n "$(nvram get wans_dualwan | awk '{print $2}' & nvramcheck)" ]] && [[ "$(nvram get wans_dualwan | awk '{print $2}' & nvramcheck)" == "none" ]] &>/dev/null ;} && WANSDUALWANENABLE="0" || WANSDUALWANENABLE="1"
      [[ -n "$WANSDUALWANENABLE" ]] &>/dev/null || { unset logger -p 6 -t "$ALIAS" "Debug - failed to set WANSDUALWANENABLE" && WANSDUALWANENABLE && continue ;}
    fi

    # WANSMODE
    if [[ -z "${WANSMODE+x}" ]] &>/dev/null;then
      WANSMODE="$(nvram get wans_mode & nvramcheck)"
      [[ -n "$WANSMODE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WANSMODE" && unset WANSMODE && continue ;}
    fi

    # WANDOGENABLE
    if [[ -z "${WANDOGENABLE+x}" ]] &>/dev/null;then
      WANDOGENABLE="$(nvram get wandog_enable & nvramcheck)"
      [[ -n "$WANDOGENABLE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WANDOGENABLE" && unset WANDOGENABLE && continue ;}
    fi

    # WANSLBRATIO
    if [[ -z "${WANSLBRATIO+x}" ]] &>/dev/null;then
      WANSLBRATIO="$(nvram get wans_lb_ratio & nvramcheck)"
      [[ -n "$WANSLBRATIO" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WANSLBRATIO" && unset WANSLBRATIO && continue ;}
    fi

    # WAN0LBRATIO
    if [[ -z "${WAN0LBRATIO+x}" ]] &>/dev/null;then
      WAN0LBRATIO="$(echo $WANSLBRATIO | awk -F ":" '{print $1}')"
      [[ -n "$WAN0LBRATIO" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0LBRATIO" && unset WAN0LBRATIO && continue ;}
    fi

    # WAN1LBRATIO
    if [[ -z "${WAN1LBRATIO+x}" ]] &>/dev/null;then
      WAN1LBRATIO="$(echo $WANSLBRATIO | awk -F ":" '{print $2}')"
      [[ -n "$WAN1LBRATIO" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1LBRATIO" && unset WAN1LBRATIO && continue ;}
    fi

    # WANSCAP
    if [[ -z "${WANSCAP+x}" ]] &>/dev/null;then
      WANSCAP="$(nvram get wans_cap & nvramcheck)"
      [[ -n "$WANSCAP" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WANSCAP" && unset WANSCAP && continue ;}
    fi

    # WAN0DUALWANDEV
    if [[ -z "${WAN0DUALWANDEV+x}" ]] &>/dev/null;then
      WAN0DUALWANDEV="$(nvram get nvram get wans_dualwan | awk '{print $1}' & nvramcheck)"
      [[ -n "$WAN0DUALWANDEV" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0DUALWANDEV" && unset WAN0DUALWANDEV && continue ;}
    fi

    # WAN0IFNAME
    if [[ -z "${WAN0IFNAME+x}" ]] &>/dev/null;then
      WAN0IFNAME="$(nvram get wan0_ifname & nvramcheck)"
      { [[ -n "$WAN0IFNAME" ]] &>/dev/null || { [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$(nvram get wan0_is_usb_modem_ready & nvramcheck)" == "0" ]] &>/dev/null ;} || [[ "$(nvram get link_wan & nvramcheck)" == "0" ]] &>/dev/null || [[ -z "$(nvram get wan0_ifname & nvramcheck)" ]] &>/dev/null ;} \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0IFNAME" && unset WAN0IFNAME && continue ;}
    fi

    # WAN1DUALWANDEV
    if [[ -z "${WAN1DUALWANDEV+x}" ]] &>/dev/null;then
      WAN1DUALWANDEV="$(nvram get nvram get wans_dualwan | awk '{print $2}' & nvramcheck)"
      [[ -n "$WAN1DUALWANDEV" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1DUALWANDEV" && unset WAN1DUALWANDEV && continue ;}
    fi

    # WAN1IFNAME
    if [[ -z "${WAN1IFNAME+x}" ]] &>/dev/null;then
      WAN1IFNAME="$(nvram get wan1_ifname & nvramcheck)"
      { [[ -n "$WAN1IFNAME" ]] &>/dev/null || { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$(nvram get wan1_is_usb_modem_ready & nvramcheck)" == "0" ]] &>/dev/null ;} || [[ "$(nvram get link_wan1 & nvramcheck)" == "0" ]] &>/dev/null || [[ -z "$(nvram get wan1_ifname & nvramcheck)" ]] &>/dev/null ;} \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1IFNAME" && unset WAN1IFNAME && continue ;}
    fi

    # IPV6SERVICE
    if [[ -z "${IPV6SERVICE+x}" ]] &>/dev/null;then
      IPV6SERVICE="$(nvram get ipv6_service & nvramcheck)"
      [[ -n "$IPV6SERVICE" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPV6SERVICE" && unset IPV6SERVICE && continue ;}
    fi

    # LANIFNAME
    if [[ -z "${LANIFNAME+x}" ]] &>/dev/null;then
      LANIFNAME="$(nvram get lan_ifname & nvramcheck)"
      [[ -n "$LANIFNAME" ]] &>/dev/null || { logger -p 6 -t "$ALIAS" "Debug - failed to set LANIFNAME" && unset LANIFNAME && continue ;}
    fi

    globalwansync="1"
  done

# Get Active WAN Parameters
elif [[ "$GETWANMODE" == "3" ]] &>/dev/null;then
  while [[ -z "${activewansync+x}" ]] &>/dev/null || [[ "$activewansync" == "0" ]] &>/dev/null;do
    activewansync="0"

    # Get WAN0 Active Parameters
    # WAN0ENABLE
    if [[ -z "${WAN0ENABLE+x}" ]] &>/dev/null || [[ -z "${zWAN0ENABLE+x}" ]] &>/dev/null;then
      WAN0ENABLE="$(nvram get wan0_enable & nvramcheck)"
      [[ -n "$WAN0ENABLE" ]] &>/dev/null \
      && zWAN0ENABLE="$WAN0ENABLE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0ENABLE" && unset WAN0ENABLE ; unset zWAN0ENABLE && continue ;}
    else
      [[ "$zWAN0ENABLE" != "$WAN0ENABLE" ]] &>/dev/null && zWAN0ENABLE="$WAN0ENABLE"
      WAN0ENABLE="$(nvram get wan0_enable & nvramcheck)"
      [[ -n "$WAN0ENABLE" ]] &>/dev/null || WAN0ENABLE="$zWAN0ENABLE"
    fi

    # WAN0STATE
    if [[ -z "${WAN0STATE+x}" ]] &>/dev/null || [[ -z "${zWAN0STATE+x}" ]] &>/dev/null;then
      WAN0STATE="$(nvram get wan0_state_t & nvramcheck)"
      [[ -n "$WAN0STATE" ]] &>/dev/null \
      && zWAN0STATE="$WAN0STATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0STATE" && unset WAN0STATE ; unset zWAN0STATE && continue ;}
    else
      [[ "$zWAN0STATE" != "$WAN0STATE" ]] &>/dev/null && zWAN0STATE="$WAN0STATE"
      WAN0STATE="$(nvram get wan0_state_t & nvramcheck)"
      [[ -n "$WAN0STATE" ]] &>/dev/null || WAN0STATE="$zWAN0STATE"
    fi

    # WAN0AUXSTATE
    if [[ -z "${WAN0AUXSTATE+x}" ]] &>/dev/null || [[ -z "${zWAN0AUXSTATE+x}" ]] &>/dev/null;then
      WAN0AUXSTATE="$(nvram get wan0_auxstate_t & nvramcheck)"
      [[ -n "$WAN0AUXSTATE" ]] &>/dev/null \
      && zWAN0AUXSTATE="$WAN0AUXSTATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0AUXSTATE" && unset WAN0AUXSTATE ; unset zWAN0AUXSTATE && continue ;}
    else
      [[ "$zWAN0AUXSTATE" != "$WAN0AUXSTATE" ]] &>/dev/null && zWAN0AUXSTATE="$WAN0AUXSTATE"
      WAN0AUXSTATE="$(nvram get wan0_auxstate_t & nvramcheck)"
      [[ -n "$WAN0AUXSTATE" ]] &>/dev/null || WAN0AUXSTATE="$zWAN0AUXSTATE"
    fi

    # WAN0SBSTATE
    if [[ -z "${WAN0SBSTATE+x}" ]] &>/dev/null || [[ -z "${zWAN0SBSTATE+x}" ]] &>/dev/null;then
      WAN0SBSTATE="$(nvram get wan0_sbstate_t & nvramcheck)"
      [[ -n "$WAN0SBSTATE" ]] &>/dev/null \
      && zWAN0SBSTATE="$WAN0SBSTATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0SBSTATE" && unset WAN0SBSTATE ; unset zWAN0SBSTATE && continue ;}
    else
      [[ "$zWAN0SBSTATE" != "$WAN0SBSTATE" ]] &>/dev/null && zWAN0SBSTATE="$WAN0SBSTATE"
      WAN0SBSTATE="$(nvram get wan0_sbstate_t & nvramcheck)"
      [[ -n "$WAN0SBSTATE" ]] &>/dev/null || WAN0SBSTATE="$zWAN0SBSTATE"
    fi

    # WAN0REALIPSTATE
    if [[ -z "${WAN0REALIPSTATE+x}" ]] &>/dev/null || [[ -z "${zWAN0REALIPSTATE+x}" ]] &>/dev/null;then
      WAN0REALIPSTATE="$(nvram get wan0_realip_state & nvramcheck)"
      [[ -n "$WAN0REALIPSTATE" ]] &>/dev/null \
      && zWAN0REALIPSTATE="$WAN0REALIPSTATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0REALIPSTATE" && unset WAN0REALIPSTATE ; unset zWAN0REALIPSTATE && continue ;}
    else
      [[ "$zWAN0REALIPSTATE" != "$WAN0REALIPSTATE" ]] &>/dev/null && zWAN0REALIPSTATE="$WAN0REALIPSTATE"
      WAN0REALIPSTATE="$(nvram get wan0_realip_state & nvramcheck)"
      [[ -n "$WAN0REALIPSTATE" ]] &>/dev/null || WAN0REALIPSTATE="$zWAN0REALIPSTATE"
    fi

    # WAN0LINKWAN
    if [[ -z "${WAN0LINKWAN+x}" ]] &>/dev/null || [[ -z "${zWAN0LINKWAN+x}" ]] &>/dev/null;then
      WAN0LINKWAN="$(nvram get link_wan & nvramcheck)"
      [[ -n "$WAN0LINKWAN" ]] &>/dev/null \
      && zWAN0LINKWAN="$WAN0LINKWAN" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0LINKWAN" && unset WAN0LINKWAN ; unset zWAN0LINKWAN && continue ;}
    else
      [[ "$zWAN0LINKWAN" != "$WAN0LINKWAN" ]] &>/dev/null && zWAN0LINKWAN="$WAN0LINKWAN"
      WAN0LINKWAN="$(nvram get link_wan & nvramcheck)"
      [[ -n "$WAN0LINKWAN" ]] &>/dev/null || WAN0LINKWAN="$zWAN0LINKWAN"
    fi

    # WAN0USBMODEMREADY
    if [[ -z "${WAN0USBMODEMREADY+x}" ]] &>/dev/null || [[ -z "${zWAN0USBMODEMREADY+x}" ]] &>/dev/null;then
      WAN0USBMODEMREADY="$(nvram get wan0_is_usb_modem_ready & nvramcheck)"
      [[ -n "$WAN0USBMODEMREADY" ]] &>/dev/null \
      && zWAN0USBMODEMREADY="$WAN0USBMODEMREADY" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0USBMODEMREADY" && unset WAN0USBMODEMREADY ; unset zWAN0USBMODEMREADY && continue ;}
    elif [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null;then
      [[ "$zWAN0USBMODEMREADY" != "$WAN0USBMODEMREADY" ]] &>/dev/null && zWAN0USBMODEMREADY="$WAN0USBMODEMREADY"
      WAN0USBMODEMREADY="$(nvram get wan0_is_usb_modem_ready & nvramcheck)"
      [[ -n "$WAN0USBMODEMREADY" ]] &>/dev/null || WAN0USBMODEMREADY="$zWAN0USBMODEMREADY"
    fi

    # WAN0IFNAME
    if [[ -z "${WAN0IFNAME+x}" ]] &>/dev/null || [[ -z "${zWAN0IFNAME+x}" ]] &>/dev/null;then
      WAN0IFNAME="$(nvram get wan0_ifname & nvramcheck)"
      { [[ -n "$WAN0IFNAME" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$WAN0USBMODEMREADY" == "0" ]] &>/dev/null ;} || [[ "$WAN0LINKWAN" == "0" ]] &>/dev/null || [[ -z "$(nvram get wan0_ifname & nvramcheck)" ]] &>/dev/null ;} \
      && zWAN0IFNAME="$WAN0IFNAME" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0IFNAME" && unset WAN0IFNAME ; unset zWAN0IFNAME && continue ;}
    else
      [[ "$zWAN0IFNAME" != "$WAN0IFNAME" ]] &>/dev/null && zWAN0IFNAME="$WAN0IFNAME"
      WAN0IFNAME="$(nvram get wan0_ifname & nvramcheck)"
      { [[ -n "$WAN0IFNAME" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && { [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$WAN0USBMODEMREADY" == "1" ]] &>/dev/null ;} && [[ "$WAN0LINKWAN" == "1" ]] &>/dev/null ;} || WAN0IFNAME="$zWAN0IFNAME"
    fi

    # WAN0GWIFNAME
    if [[ -z "${WAN0GWIFNAME+x}" ]] &>/dev/null || [[ -z "${zWAN0GWIFNAME+x}" ]] &>/dev/null;then
      WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
      { [[ -n "$WAN0GWIFNAME" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null ;} \
      && zWAN0GWIFNAME="$WAN0GWIFNAME" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0GWIFNAME" && unset WAN0GWIFNAME ; unset zWAN0GWIFNAME && continue ;}
    elif { [[ -z "$WAN0GWIFNAME" ]] &>/dev/null || [[ -z "$zWAN0GWIFNAME" ]] &>/dev/null ;} && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null;then
      { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0GWIFNAME" && unset WAN0GWIFNAME ; unset zWAN0GWIFNAME ;} && continue
    else
      [[ "$zWAN0GWIFNAME" != "$WAN0GWIFNAME" ]] &>/dev/null && zWAN0GWIFNAME="$WAN0GWIFNAME"
      WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
      [[ -n "$WAN0GWIFNAME" ]] &>/dev/null || WAN0GWIFNAME="$zWAN0GWIFNAME"
    fi

    # WAN0GWMAC
    if [[ -z "${WAN0GWMAC+x}" ]] &>/dev/null || [[ -z "${zWAN0GWMAC+x}" ]] &>/dev/null;then
      if [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "1" ]] &>/dev/null;then
        WAN0GWMAC=""
      elif [[ -n "$(nvram get wan0_gw_mac & nvramcheck)" ]] &>/dev/null;then
        WAN0GWMAC="$(nvram get wan0_gw_mac & nvramcheck)"
      elif [[ -n "$WAN0GWIFNAME" ]] &>/dev/null && [[ -n "$(arp -i $WAN0GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")" ]] &>/dev/null;then
        WAN0GWMAC="$(arp -i $WAN0GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")"
      else
        WAN0GWMAC=""
      fi
      zWAN0GWMAC="$WAN0GWMAC"
    else
      [[ "$zWAN0GWMAC" != "$WAN0GWMAC" ]] &>/dev/null && zWAN0GWMAC="$WAN0GWMAC"
      if [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "1" ]] &>/dev/null;then
        WAN0GWMAC=""
      elif [[ -n "$(nvram get wan0_gw_mac & nvramcheck)" ]] &>/dev/null;then
        WAN0GWMAC="$(nvram get wan0_gw_mac & nvramcheck)"
        { [[ -z "$WAN0GWMAC" ]] &>/dev/null && [[ -n "$zWAN0GWMAC" ]] &>/dev/null ;} && WAN0GWMAC="$zWAN0GWMAC"
      elif [[ -n "$WAN0GWIFNAME" ]] &>/dev/null && [[ -n "$(arp -i $WAN0GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")" ]] &>/dev/null;then
        WAN0GWMAC="$(arp -i $WAN0GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")"
        { [[ -z "$WAN0GWMAC" ]] &>/dev/null && [[ -n "$zWAN0GWMAC" ]] &>/dev/null ;} && WAN0GWMAC="$zWAN0GWMAC"
      else
        WAN0GWMAC=""
      fi
    fi

    # WAN0PRIMARY
    if [[ -z "${WAN0PRIMARY+x}" ]] &>/dev/null || [[ -z "${zWAN0PRIMARY+x}" ]] &>/dev/null;then
      WAN0PRIMARY="$(nvram get wan0_primary & nvramcheck)"
      [[ -n "$WAN0PRIMARY" ]] &>/dev/null \
      && zWAN0PRIMARY="$WAN0PRIMARY" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0PRIMARY" && unset WAN0PRIMARY ; unset zWAN0PRIMARY && continue ;}
    elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
      [[ "$zWAN0PRIMARY" != "$WAN0PRIMARY" ]] &>/dev/null && zWAN0PRIMARY="$WAN0PRIMARY"
      WAN0PRIMARY="$(nvram get wan0_primary & nvramcheck)"
      [[ -n "$WAN0PRIMARY" ]] &>/dev/null || WAN0PRIMARY="$zWAN0PRIMARY"
    fi

    # WAN0IPADDR
    if [[ -z "${WAN0IPADDR+x}" ]] &>/dev/null || [[ -z "${zWAN0IPADDR+x}" ]] &>/dev/null;then
      WAN0IPADDR="$(nvram get wan0_ipaddr & nvramcheck)"
      { [[ -n "$WAN0IPADDR" ]] &>/dev/null || [[ "$WAN0STATE" != "2" ]] &>/dev/null ;} \
      && zWAN0IPADDR="$WAN0IPADDR" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0IPADDR" && unset WAN0IPADDR ; unset zWAN0IPADDR && continue ;}
    else
      [[ "$zWAN0IPADDR" != "$WAN0IPADDR" ]] &>/dev/null && zWAN0IPADDR="$WAN0IPADDR"
      WAN0IPADDR="$(nvram get wan0_ipaddr & nvramcheck)"
      [[ -n "$WAN0IPADDR" ]] &>/dev/null || WAN0IPADDR="$zWAN0IPADDR"
    fi

    # WAN0GATEWAY
    if [[ -z "${WAN0GATEWAY+x}" ]] &>/dev/null || [[ -z "${zWAN0GATEWAY+x}" ]] &>/dev/null;then
      WAN0GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
      { [[ -n "$WAN0GATEWAY" ]] &>/dev/null || [[ "$WAN0STATE" != "2" ]] &>/dev/null ;} \
      && zWAN0GATEWAY="$WAN0GATEWAY" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0GATEWAY" && unset WAN0GATEWAY ; unset zWAN0GATEWAY && continue ;}
    else
      [[ "$zWAN0GATEWAY" != "$WAN0GATEWAY" ]] &>/dev/null && zWAN0GATEWAY="$WAN0GATEWAY"
      WAN0GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
      [[ -n "$WAN0GATEWAY" ]] &>/dev/null || WAN0GATEWAY="$zWAN0GATEWAY"
    fi

    # WAN0REALIPADDR
    if [[ -z "${WAN0REALIPADDR+x}" ]] &>/dev/null || [[ -z "${zWAN0REALIPADDR+x}" ]] &>/dev/null;then
      WAN0REALIPADDR="$(nvram get wan0_realip_ip & nvramcheck)"
      { [[ -n "$WAN0REALIPADDR" ]] &>/dev/null || [[ "$WAN0REALIPSTATE" != "2" ]] &>/dev/null ;} \
      && zWAN0REALIPADDR="$WAN0REALIPADDR" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN0REALIPADDR" && unset WAN0REALIPADDR ; unset zWAN0REALIPADDR && continue ;}
    elif [[ "$WAN0REALIPSTATE" != "0" ]] &>/dev/null;then
      [[ "$zWAN0REALIPADDR" != "$WAN0REALIPADDR" ]] &>/dev/null && zWAN0REALIPADDR="$WAN0REALIPADDR"
      WAN0REALIPADDR="$(nvram get wan0_realip_ip & nvramcheck)"
      [[ -n "$WAN0REALIPADDR" ]] &>/dev/null || WAN0REALIPADDR="$zWAN0REALIPADDR"
    fi

    # Get WAN1 Active Parameters
    # WAN1ENABLE
    if [[ -z "${WAN1ENABLE+x}" ]] &>/dev/null || [[ -z "${zWAN1ENABLE+x}" ]] &>/dev/null;then
      WAN1ENABLE="$(nvram get wan1_enable & nvramcheck)"
      [[ -n "$WAN1ENABLE" ]] &>/dev/null \
      && zWAN1ENABLE="$WAN1ENABLE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WANENABLE" && unset WAN1ENABLE ; unset zWAN1ENABLE && continue ;}
    else
      [[ "$zWAN1ENABLE" != "$WAN1ENABLE" ]] &>/dev/null && zWAN1ENABLE="$WAN1ENABLE"
      WAN1ENABLE="$(nvram get wan1_enable & nvramcheck)"
      [[ -n "$WAN1ENABLE" ]] &>/dev/null || WAN1ENABLE="$zWAN1ENABLE"
    fi

    # WAN1STATE
    if [[ -z "${WAN1STATE+x}" ]] &>/dev/null || [[ -z "${zWAN1STATE+x}" ]] &>/dev/null;then
      WAN1STATE="$(nvram get wan1_state_t & nvramcheck)"
      [[ -n "$WAN1STATE" ]] &>/dev/null \
      && zWAN1STATE="$WAN1STATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1STATE" && unset WAN1STATE ; unset zWAN1STATE && continue ;}
    else
      [[ "$zWAN1STATE" != "$WAN1STATE" ]] &>/dev/null && zWAN1STATE="$WAN1STATE"
      WAN1STATE="$(nvram get wan1_state_t & nvramcheck)"
      [[ -n "$WAN1STATE" ]] &>/dev/null || WAN1STATE="$zWAN1STATE"
    fi

    # WAN1AUXSTATE
    if [[ -z "${WAN1AUXSTATE+x}" ]] &>/dev/null || [[ -z "${zWAN1AUXSTATE+x}" ]] &>/dev/null;then
      WAN1AUXSTATE="$(nvram get wan1_auxstate_t & nvramcheck)"
      [[ -n "$WAN1AUXSTATE" ]] &>/dev/null \
      && zWAN1AUXSTATE="$WAN1AUXSTATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1AUXSTATE" && unset WAN1AUXSTATE ; unset zWAN1AUXSTATE && continue ;}
    else
      [[ "$zWAN1AUXSTATE" != "$WAN1AUXSTATE" ]] &>/dev/null && zWAN1AUXSTATE="$WAN1AUXSTATE"
      WAN1AUXSTATE="$(nvram get wan1_auxstate_t & nvramcheck)"
      [[ -n "$WAN1AUXSTATE" ]] &>/dev/null || WAN1AUXSTATE="$zWAN1AUXSTATE"
    fi

    # WAN1SBSTATE
    if [[ -z "${WAN1SBSTATE+x}" ]] &>/dev/null || [[ -z "${zWAN1SBSTATE+x}" ]] &>/dev/null;then
      WAN1SBSTATE="$(nvram get wan1_sbstate_t & nvramcheck)"
      [[ -n "$WAN1SBSTATE" ]] &>/dev/null \
      && zWAN1SBSTATE="$WAN1SBSTATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1SBSTATE" && unset WAN1SBSTATE ; unset zWAN1SBSTATE && continue ;}
    else
      [[ "$zWAN1SBSTATE" != "$WAN1SBSTATE" ]] &>/dev/null && zWAN1SBSTATE="$WAN1SBSTATE"
      WAN1SBSTATE="$(nvram get wan1_sbstate_t & nvramcheck)"
      [[ -n "$WAN1SBSTATE" ]] &>/dev/null || WAN1SBSTATE="$zWAN1SBSTATE"
    fi

    # WAN1REALIPSTATE
    if [[ -z "${WAN1REALIPSTATE+x}" ]] &>/dev/null || [[ -z "${zWAN1REALIPSTATE+x}" ]] &>/dev/null;then
      WAN1REALIPSTATE="$(nvram get wan1_realip_state & nvramcheck)"
      [[ -n "$WAN1REALIPSTATE" ]] &>/dev/null \
      && zWAN1REALIPSTATE="$WAN1REALIPSTATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1REALIPSTATE" && unset WAN1REALIPSTATE ; unset zWAN1REALIPSTATE && continue ;}
    else
      [[ "$zWAN1REALIPSTATE" != "$WAN1REALIPSTATE" ]] &>/dev/null && zWAN1REALIPSTATE="$WAN1REALIPSTATE"
      WAN1REALIPSTATE="$(nvram get wan1_realip_state & nvramcheck)"
      [[ -n "$WAN1REALIPSTATE" ]] &>/dev/null || WAN1REALIPSTATE="$zWAN1REALIPSTATE"
    fi

    # WAN1LINKWAN
    if [[ -z "${WAN1LINKWAN+x}" ]] &>/dev/null || [[ -z "${zWAN1LINKWAN+x}" ]] &>/dev/null;then
      WAN1LINKWAN="$(nvram get link_wan1 & nvramcheck)"
      [[ -n "$WAN1LINKWAN" ]] &>/dev/null \
      && zWAN1LINKWAN="$WAN1LINKWAN" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1LINKWAN" && unset WAN1LINKWAN ; unset zWAN1LINKWAN && continue ;}
    else
      [[ "$zWAN1LINKWAN" != "$WAN1LINKWAN" ]] &>/dev/null && zWAN1LINKWAN="$WAN1LINKWAN"
      WAN1LINKWAN="$(nvram get link_wan1 & nvramcheck)"
      [[ -n "$WAN1LINKWAN" ]] &>/dev/null || WAN1LINKWAN="$zWAN1LINKWAN"
    fi

    # WAN1USBMODEMREADY
    if [[ -z "${WAN1USBMODEMREADY+x}" ]] &>/dev/null || [[ -z "${zWAN1USBMODEMREADY+x}" ]] &>/dev/null;then
      WAN1USBMODEMREADY="$(nvram get wan1_is_usb_modem_ready & nvramcheck)"
      [[ -n "$WAN1USBMODEMREADY" ]] &>/dev/null \
      && zWAN1USBMODEMREADY="$WAN1USBMODEMREADY" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1USBMODEMREADY" && unset WAN1USBMODEMREADY ; unset zWAN1USBMODEMREADY && continue ;}
    elif [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null;then
      [[ "$zWAN1USBMODEMREADY" != "$WAN1USBMODEMREADY" ]] &>/dev/null && zWAN1USBMODEMREADY="$WAN1USBMODEMREADY"
      WAN1USBMODEMREADY="$(nvram get wan1_is_usb_modem_ready & nvramcheck)"
      [[ -n "$WAN1USBMODEMREADY" ]] &>/dev/null || WAN1USBMODEMREADY="$zWAN1USBMODEMREADY"
    fi

    # WAN1IFNAME
    if [[ -z "${WAN1IFNAME+x}" ]] &>/dev/null || [[ -z "${zWAN1IFNAME+x}" ]] &>/dev/null;then
      WAN1IFNAME="$(nvram get wan1_ifname & nvramcheck)"
      { [[ -n "$WAN1IFNAME" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$WAN1USBMODEMREADY" == "0" ]] &>/dev/null ;} || [[ "$WAN1LINKWAN" == "0" ]] &>/dev/null || [[ -z "$(nvram get wan0_ifname & nvramcheck)" ]] &>/dev/null ;} \
      && zWAN1IFNAME="$WAN1IFNAME" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1IFNAME" && unset WAN1IFNAME ; unset zWAN1IFNAME && continue ;}
    else
      [[ "$zWAN1IFNAME" != "$WAN1IFNAME" ]] &>/dev/null && zWAN1IFNAME="$WAN1IFNAME"
      WAN1IFNAME="$(nvram get wan1_ifname & nvramcheck)"
      { [[ -n "$WAN1IFNAME" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$WAN1USBMODEMREADY" == "1" ]] &>/dev/null ;} && [[ "$WAN1LINKWAN" == "1" ]] &>/dev/null ;} || WAN1IFNAME="$zWAN1IFNAME"
    fi

    # WAN1GWIFNAME
    if [[ -z "${WAN1GWIFNAME+x}" ]] &>/dev/null || [[ -z "${zWAN1GWIFNAME+x}" ]] &>/dev/null;then
      WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
      { [[ -n "$WAN1GWIFNAME" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null ;} \
      && zWAN1GWIFNAME="$WAN1GWIFNAME" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1GWIFNAME" && unset WAN1GWIFNAME ; unset zWAN1GWIFNAME && continue ;}
    elif { [[ -z "$WAN1GWIFNAME" ]] &>/dev/null || [[ -z "$zWAN1GWIFNAME" ]] &>/dev/null ;} && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null;then
      { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1GWIFNAME" && unset WAN1GWIFNAME ; unset zWAN1GWIFNAME ;} && continue
    else
      [[ "$zWAN1GWIFNAME" != "$WAN1GWIFNAME" ]] &>/dev/null && zWAN1GWIFNAME="$WAN1GWIFNAME"
      WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
      [[ -n "$WAN1GWIFNAME" ]] &>/dev/null || WAN1GWIFNAME="$zWAN1GWIFNAME"
    fi

    # WAN1GWMAC
    if [[ -z "${WAN1GWMAC+x}" ]] &>/dev/null || [[ -z "${zWAN1GWMAC+x}" ]] &>/dev/null;then
      if [[ "$WAN1ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "1" ]] &>/dev/null;then
        WAN1GWMAC=""
      elif [[ -n "$(nvram get wan1_gw_mac & nvramcheck)" ]] &>/dev/null;then
        WAN1GWMAC="$(nvram get wan1_gw_mac & nvramcheck)"
      elif [[ -n "$WAN1GWIFNAME" ]] &>/dev/null && [[ -n "$(arp -i $WAN1GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")" ]] &>/dev/null;then
        WAN1GWMAC="$(arp -i $WAN1GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")"
      else
        WAN1GWMAC=""
      fi
      zWAN1GWMAC="$WAN1GWMAC"
    else
      [[ "$zWAN1GWMAC" != "$WAN1GWMAC" ]] &>/dev/null && zWAN1GWMAC="$WAN1GWMAC"
      if [[ "$WAN1ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "1" ]] &>/dev/null;then
        WAN1GWMAC=""
      elif [[ -n "$(nvram get wan1_gw_mac & nvramcheck)" ]] &>/dev/null;then
        WAN1GWMAC="$(nvram get wan1_gw_mac & nvramcheck)"
        { [[ -z "$WAN1GWMAC" ]] &>/dev/null && [[ -n "$zWAN1GWMAC" ]] &>/dev/null ;} && WAN1GWMAC="$zWAN1GWMAC"
      elif [[ -n "$WAN1GWIFNAME" ]] &>/dev/null && [[ -n "$(arp -i $WAN1GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")" ]] &>/dev/null;then
        WAN1GWMAC="$(arp -i $WAN1GWIFNAME | grep -m1 -oE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")"
        { [[ -z "$WAN1GWMAC" ]] &>/dev/null && [[ -n "$zWAN1GWMAC" ]] &>/dev/null ;} && WAN1GWMAC="$zWAN1GWMAC"
      else
        WAN1GWMAC=""
      fi
    fi

    # WAN1PRIMARY
    if [[ -z "${WAN1PRIMARY+x}" ]] &>/dev/null || [[ -z "${zWAN1PRIMARY+x}" ]] &>/dev/null;then
      WAN1PRIMARY="$(nvram get wan1_primary & nvramcheck)"
      [[ -n "$WAN1PRIMARY" ]] &>/dev/null \
      && zWAN1PRIMARY="$WAN1PRIMARY" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1PRIMARY" && unset WAN1PRIMARY ; unset zWAN1PRIMARY && continue ;}
    elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
      [[ "$zWAN1PRIMARY" != "$WAN1PRIMARY" ]] &>/dev/null && zWAN1PRIMARY="$WAN1PRIMARY"
      WAN1PRIMARY="$(nvram get wan1_primary & nvramcheck)"
      [[ -n "$WAN1PRIMARY" ]] &>/dev/null || WAN1PRIMARY="$zWAN1PRIMARY"
    fi

    # WAN1IPADDR
    if [[ -z "${WAN1IPADDR+x}" ]] &>/dev/null || [[ -z "${zWAN1IPADDR+x}" ]] &>/dev/null;then
      WAN1IPADDR="$(nvram get wan1_ipaddr & nvramcheck)"
      { [[ -n "$WAN1IPADDR" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null ;} \
      && zWAN1IPADDR="$WAN1IPADDR" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1IPADDR" && unset WAN1IPADDR ; unset zWAN1IPADDR && continue ;}
    else
      [[ "$zWAN1IPADDR" != "$WAN1IPADDR" ]] &>/dev/null && zWAN1IPADDR="$WAN1IPADDR"
      WAN1IPADDR="$(nvram get wan1_ipaddr & nvramcheck)"
      [[ -n "$WAN1IPADDR" ]] &>/dev/null || WAN1IPADDR="$zWAN1IPADDR"
    fi

    # WAN1GATEWAY
    if [[ -z "${WAN1GATEWAY+x}" ]] &>/dev/null || [[ -z "${zWAN1GATEWAY+x}" ]] &>/dev/null;then
      WAN1GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
      { [[ -n "$WAN1GATEWAY" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null ;} \
      && zWAN1GATEWAY="$WAN1GATEWAY" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1GATEWAY" && unset WAN1GATEWAY ; unset zWAN1GATEWAY && continue ;}
    else
      [[ "$zWAN1GATEWAY" != "$WAN1GATEWAY" ]] &>/dev/null && zWAN1GATEWAY="$WAN1GATEWAY"
      WAN1GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
      [[ -n "$WAN1GATEWAY" ]] &>/dev/null || WAN1GATEWAY="$zWAN1GATEWAY"
    fi

    # WAN1REALIPADDR
    if [[ -z "${WAN1REALIPADDR+x}" ]] &>/dev/null || [[ -z "${zWAN1REALIPADDR+x}" ]] &>/dev/null;then
      WAN1REALIPADDR="$(nvram get wan1_realip_ip & nvramcheck)"
      { [[ -n "$WAN1REALIPADDR" ]] &>/dev/null || [[ "$WAN1REALIPSTATE" != "2" ]] &>/dev/null ;} \
      && zWAN1REALIPADDR="$WAN1REALIPADDR" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set WAN1REALIPADDR" && unset WAN1REALIPADDR ; unset zWAN1REALIPADDR && continue ;}
    elif [[ "$WAN1REALIPSTATE" != "0" ]] &>/dev/null;then
      [[ "$zWAN1REALIPADDR" != "$WAN1REALIPADDR" ]] &>/dev/null && zWAN1REALIPADDR="$WAN1REALIPADDR"
      WAN1REALIPADDR="$(nvram get wan1_realip_ip & nvramcheck)"
      [[ -n "$WAN1REALIPADDR" ]] &>/dev/null || WAN1REALIPADDR="$zWAN1REALIPADDR"
    fi

    # Get IPv6 Active Parameters
    # IPV6STATE
    if [[ -z "${IPV6STATE+x}" ]] &>/dev/null || [[ -z "${zIPV6STATE+x}" ]] &>/dev/null;then
      IPV6STATE="$(nvram get ipv6_state_t & nvramcheck)"
      [[ -n "$IPV6STATE" ]] &>/dev/null \
      && zIPV6STATE="$IPV6STATE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPV6STATE" && unset IPV6STATE ; unset zIPV6STATE && continue ;}
    elif [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null;then
      [[ "$zIPV6STATE" != "$IPV6STATE" ]] &>/dev/null && zIPV6STATE="$IPV6STATE"
      IPV6STATE="$(nvram get ipv6_state_t & nvramcheck)"
      [[ -n "$IPV6STATE" ]] &>/dev/null || IPV6STATE="$zIPV6STATE"
    fi

    # IPV6IPADDR
    if [[ -z "${IPV6IPADDR+x}" ]] &>/dev/null || [[ -z "${zIPV6IPADDR+x}" ]] &>/dev/null;then
      IPV6IPADDR="$(nvram get ipv6_wan_addr & nvramcheck)"
      { [[ -n "$IPV6IPADDR" ]] &>/dev/null || [[ "$IPV6SERVICE" == "disabled" ]] || [[ -z "$(nvram get ipv6_wan_addr & nvramcheck)" ]] &>/dev/null ;} \
      && zIPV6IPADDR="$IPV6IPADDR" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set IPV6IPADDR" && unset IPV6IPADDR ; unset zIPV6IPADDR && continue ;}
    elif [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null;then
      [[ "$zIPV6IPADDR" != "$IPV6IPADDR" ]] &>/dev/null && zIPV6IPADDR="$IPV6IPADDR"
      IPV6IPADDR="$(nvram get ipv6_wan_addr & nvramcheck)"
      [[ -n "$IPV6IPADDR" ]] &>/dev/null || IPV6IPADDR="$zIPV6IPADDR"
    fi

    # Get QoS Active Parameters
    # QOSENABLE
    if [[ -z "${QOSENABLE+x}" ]] &>/dev/null || [[ -z "${zQOSENABLE+x}" ]] &>/dev/null;then
      QOSENABLE="$(nvram get qos_enable & nvramcheck)"
      [[ -n "$QOSENABLE" ]] &>/dev/null \
      && zQOSENABLE="$QOSENABLE" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set QOSENABLE" && unset QOSENABLE ; unset zQOSENABLE && continue ;}
    elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
      [[ "$zQOSENABLE" != "$QOSENABLE" ]] &>/dev/null && zQOSENABLE="$QOSENABLE"
      QOSENABLE="$(nvram get qos_enable & nvramcheck)"
      [[ -n "$QOSENABLE" ]] &>/dev/null || QOSENABLE="$zQOSENABLE"
    fi

    # QOS_OBW
    if [[ -z "${QOS_OBW+x}" ]] &>/dev/null || [[ -z "${zQOS_OBW+x}" ]] &>/dev/null;then
      QOS_OBW="$(nvram get qos_obw & nvramcheck)"
      { [[ -n "$QOS_OBW" ]] || [[ "$QOSENABLE" == "0" ]] ;} &>/dev/null \
      && zQOS_OBW="$QOS_OBW" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set QOS_OBW" && unset QOS_OBW ; unset zQOS_OBW && continue ;}
    elif [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
      [[ "$zQOS_OBW" != "$QOS_OBW" ]] &>/dev/null && zQOS_OBW="$QOS_OBW"
      QOS_OBW="$(nvram get qos_obw & nvramcheck)"
      [[ -n "$QOS_OBW" ]] &>/dev/null || QOS_OBW="$zQOS_OBW"
    fi

    # QOS_IBW
    if [[ -z "${QOS_IBW+x}" ]] &>/dev/null || [[ -z "${zQOS_IBW+x}" ]] &>/dev/null;then
      QOS_IBW="$(nvram get qos_ibw & nvramcheck)"
      { [[ -n "$QOS_IBW" ]] || [[ "$QOSENABLE" == "0" ]] ;} &>/dev/null \
      && zQOS_IBW="$QOS_IBW" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set QOS_IBW" && unset QOS_IBW ; unset zQOS_IBW && continue ;}
    elif [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
      [[ "$zQOS_IBW" != "$QOS_IBW" ]] &>/dev/null && zQOS_IBW="$QOS_IBW"
      QOS_IBW="$(nvram get qos_ibw & nvramcheck)"
      [[ -n "$QOS_IBW" ]] &>/dev/null || QOS_IBW="$zQOS_IBW"
    fi

    # QOSOVERHEAD
    if [[ -z "${QOSOVERHEAD+x}" ]] &>/dev/null || [[ -z "${zQOSOVERHEAD+x}" ]] &>/dev/null;then
      QOSOVERHEAD="$(nvram get qos_overhead & nvramcheck)"
      { [[ -n "$QOSOVERHEAD" ]] || [[ "$QOSENABLE" == "0" ]] ;} &>/dev/null \
      && zQOSOVERHEAD="$QOSOVERHEAD" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set QOSOVERHEAD" && unset QOSOVERHEAD ; unset zQOSOVERHEAD && continue ;}
    elif [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
      [[ "$zQOSOVERHEAD" != "$QOSOVERHEAD" ]] &>/dev/null && zQOSOVERHEAD="$QOSOVERHEAD"
      QOSOVERHEAD="$(nvram get qos_overhead & nvramcheck)"
      [[ -n "$QOSOVERHEAD" ]] &>/dev/null || QOSOVERHEAD="$zQOSOVERHEAD"
    fi

    # QOSATM
    if [[ -z "${QOSATM+x}" ]] &>/dev/null || [[ -z "${zQOSATM+x}" ]] &>/dev/null;then
      QOSATM="$(nvram get qos_atm & nvramcheck)"
      { [[ -n "$QOSATM" ]] || [[ "$QOSENABLE" == "0" ]] ;} &>/dev/null \
      && zQOSATM="$QOSATM" \
      || { logger -p 6 -t "$ALIAS" "Debug - failed to set QOSATM" && unset QOSATM ; unset zQOSATM && continue ;}
    elif [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
      [[ "$zQOSATM" != "$QOSATM" ]] &>/dev/null && zQOSATM="$QOSATM"
      QOSATM="$(nvram get qos_atm & nvramcheck)"
      [[ -n "$QOSATM" ]] &>/dev/null || QOSATM="$zQOSATM"
    fi

    activewansync="1"
  done
  unset activewansync
fi

unset GETWANMODE

return
}

# Set WAN Status
setwanstatus ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: setwanstatus"

# Set WANS Status Mode
[[ -z "${WANSTATUSMODE+x}" ]] &>/dev/null && WANSTATUSMODE="1"
logger -p 6 -t "$ALIAS" "Debug - WAN Status Mode: "$WANSTATUSMODE""

if [[ "$WANSTATUSMODE" == "1" ]] &>/dev/null;then
  if [[ "${WANPREFIX}" == "$WAN0" ]] &>/dev/null;then
    { [[ -n "${READYSTATE+x}" ]] &>/dev/null && [[ -n "${WAN0STATUS+x}" ]] &>/dev/null && [[ -n "${STATUS+x}" ]] &>/dev/null ;} && { [[ "$READYSTATE" != "0" ]] &>/dev/null && [[ "$WAN0STATUS" != "$STATUS" ]] &>/dev/null && { [[ "$email" != "1" ]] &>/dev/null && email=1 ;} ;}
    [[ -n "${STATUS+x}" ]] &>/dev/null && WAN0STATUS="$STATUS"
    [[ -n "${PINGPATH+x}" ]] &>/dev/null && WAN0PINGPATH="$PINGPATH"
    [[ -n "${PACKETLOSS+x}" ]] &>/dev/null && WAN0PACKETLOSS="$PACKETLOSS"
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: "$WAN0STATUS""
  elif [[ "${WANPREFIX}" == "$WAN1" ]] &>/dev/null;then
    { [[ -n "${READYSTATE+x}" ]] &>/dev/null && [[ -n "${WAN1STATUS+x}" ]] &>/dev/null && [[ -n "${STATUS+x}" ]] &>/dev/null ;} && { [[ "$READYSTATE" != "0" ]] &>/dev/null && [[ "$WAN1STATUS" != "$STATUS" ]] &>/dev/null && { [[ "$email" != "1" ]] &>/dev/null && email=1 ;} ;}
    [[ -n "${STATUS+x}" ]] &>/dev/null && WAN1STATUS="$STATUS"
    [[ -n "${PINGPATH+x}" ]] &>/dev/null && WAN1PINGPATH="$PINGPATH"
    [[ -n "${PACKETLOSS+x}" ]] &>/dev/null && WAN1PACKETLOSS="$PACKETLOSS"
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: "$WAN1STATUS""
  fi
  unset STATUS
elif [[ "$WANSTATUSMODE" == "2" ]] &>/dev/null;then
  [[ "$(nvram get wan0_enable & nvramcheck)" == "1" ]] &>/dev/null && [[ "$(nvram get wan0_auxstate_t & nvramcheck)" == "0" ]] &>/dev/null && { [[ "$(nvram get wan0_state_t & nvramcheck)" != "2" ]] &>/dev/null || [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null ;} && WAN0STATUS=DISCONNECTED && email=1
  [[ "$(nvram get wan0_enable & nvramcheck)" == "1" ]] &>/dev/null && [[ "$(nvram get wan0_auxstate_t & nvramcheck)" != "0" ]] &>/dev/null && WAN0STATUS=UNPLUGGED && email=1
  [[ "$(nvram get wan0_enable & nvramcheck)" == "0" ]] &>/dev/null && WAN0STATUS=DISABLED && email=1
  [[ "$(nvram get wan1_enable & nvramcheck)" == "1" ]] &>/dev/null && [[ "$(nvram get wan1_auxstate_t & nvramcheck)" == "0" ]] &>/dev/null && { [[ "$(nvram get wan1_state_t & nvramcheck)" != "2" ]] &>/dev/null || [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null ;} && WAN1STATUS=DISCONNECTED && email=1
  [[ "$(nvram get wan1_enable & nvramcheck)" == "1" ]] &>/dev/null && [[ "$(nvram get wan1_auxstate_t & nvramcheck)" != "0" ]] &>/dev/null && WAN1STATUS=UNPLUGGED && email=1
  [[ "$(nvram get wan1_enable & nvramcheck)" == "0" ]] &>/dev/null && WAN1STATUS=DISABLED && email=1
fi

unset WANSTATUSMODE
return
}

# Restart WAN0
restartwan0 ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: restartwan0"

# WAN States
# 0 - Initializing
# 1 - Connecting
# 2 - Connected
# 3 - Disconnected
# 4 - Stopped
# 5 - Disabled
# 6 - Stopping

# Restart WAN0 Interface
wan0state="$(nvram get "$WAN0"_state_t & nvramcheck)"
if [[ "$wan0state" == "5" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Not Restarting "$WAN0" because it is not Enabled"
  return
elif [[ "$wan0state" == "4" ]] &>/dev/null;then
  logger -p 1 -st "$ALIAS" "Restart WAN0 - Starting "$WAN0""
  service "start_wan_if 0" &
else
  logger -p 1 -st "$ALIAS" "Restart WAN0 - Restarting "$WAN0""
  service "restart_wan_if 0" &
fi
restartwan0pid=$!

# Set Timeout for WAN interface to restart to a max of 30 seconds and while WAN Interface is State 6
restartwan0timeout="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$restartwan0timeout" ]] &>/dev/null && [[ -n "$(ps | awk '{print $1}' | grep -o "$restartwan0pid")" ]] &>/dev/null;do
  wait $restartwan0pid
  wan0state="$(nvram get "$WAN0"_state_t & nvramcheck)"
  if [[ "$wan0state" == "0" ]] &>/dev/null || [[ "$wan0state" == "4" ]] &>/dev/null || [[ "$wan0state" == "6" ]] &>/dev/null;then
    sleep 1
    continue
  elif  [[ "$wan0state" == "1" ]] &>/dev/null;then
    sleep 1
    break
  elif [[ "$wan0state" == "2" ]] &>/dev/null;then
    break
  elif  [[ "$wan0state" == "3" ]] &>/dev/null;then
    nvram set "$WAN0"_state_t="2"
    sleep 1
    break
  elif [[ "$wan0state" == "5" ]] &>/dev/null;then
    break
  else
    sleep 1
  fi
  sleep 1
done

logger -p 6 -t "$ALIAS" "Debug - WAN0 Post-Restart State: "$wan0state""

# Check WAN Routing Table for Default Routes if WAN0 is Connected
if [[ "$wan0state" == "2" ]] &>/dev/null;then
  checkroutingtable &
  CHECKROUTINGTABLEPID=$!
  wait $CHECKROUTINGTABLEPID
  unset CHECKROUTINGTABLEPID
fi

# Unset Variables
[[ -n "${wan0state+x}" ]]  &>/dev/null && unset wan0state
[[ -n "${restartwan0pid+x}" ]]  &>/dev/null && unset restartwan0pid
[[ -n "${restartwan0timeout+x}" ]]  &>/dev/null && unset restartwan0timeout

return
}

# Restart WAN1
restartwan1 ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: restartwan1"

# WAN States
# 0 - Initializing
# 1 - Connecting
# 2 - Connected
# 3 - Disconnected
# 4 - Stopped
# 5 - Disabled
# 6 - Stopping

# Restart WAN1 Interface
wan1state="$(nvram get wan1_state_t & nvramcheck)"
if [[ "$wan1state" == "5" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Not Restarting "$WAN1" because it is not Enabled"
  return
elif [[ "$wan1state" == "4" ]] &>/dev/null;then
  logger -p 1 -st "$ALIAS" "Restart WAN1 - Starting "$WAN1""
  service "start_wan_if 1" &
else
  logger -p 1 -st "$ALIAS" "Restart WAN1 - Restarting "$WAN1""
  service "restart_wan_if 1" &
fi
restartwan1pid=$!

# Set Timeout for WAN interface to restart to a max of 30 seconds and while WAN Interface is State 6
restartwan1timeout="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$restartwan1timeout" ]] &>/dev/null && [[ -n "$(ps | awk '{print $1}' | grep -o "$restartwan1pid")" ]] &>/dev/null;do
  wait $restartwan1pid
  wan1state="$(nvram get "$WAN1"_state_t & nvramcheck)"
  if [[ "$wan1state" == "0" ]] &>/dev/null || [[ "$wan1state" == "4" ]] &>/dev/null || [[ "$wan1state" == "6" ]] &>/dev/null;then
    sleep 1
    continue
  elif  [[ "$wan1state" == "1" ]] &>/dev/null;then
    sleep 1
    break
  elif [[ "$wan1state" == "2" ]] &>/dev/null;then
    break
  elif  [[ "$wan1state" == "3" ]] &>/dev/null;then
    nvram set "$WAN1"_state_t="2"
    sleep 1
    break
  elif [[ "$wan1state" == "5" ]] &>/dev/null;then
    break
  else
    sleep 1
  fi
  sleep 1
done

logger -p 6 -t "$ALIAS" "Debug - WAN1 Post-Restart State: "$wan1state""

# Check WAN Routing Table for Default Routes if WAN1 is Connected
if [[ "$wan1state" == "2" ]] &>/dev/null;then
  checkroutingtable &
  CHECKROUTINGTABLEPID=$!
  wait $CHECKROUTINGTABLEPID
  unset CHECKROUTINGTABLEPID
fi

# Unset Variables
[[ -n "${wan1state+x}" ]]  &>/dev/null && unset wan1state
[[ -n "${restartwan1pid+x}" ]]  &>/dev/null && unset restartwan1pid
[[ -n "${restartwan1timeout+x}" ]]  &>/dev/null && unset restartwan1timeout

return
}


# Ping WAN0Target
pingwan0target ()
{
# Capture Gateway Interface If Missing
[[ -z "${WAN0GWIFNAME+x}" ]] &>/dev/null && WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"

# Create Packet Loss File If Missing
if [[ ! -f "$WAN0PACKETLOSSFILE" ]] &>/dev/null;then
  touch -a $WAN0PACKETLOSSFILE
  echo "" >> "$WAN0PACKETLOSSFILE"
  echo "" >> "$WAN0PACKETLOSSFILE"
fi

# Capture Packet Loss
PINGWAN0TARGETOUTPUT="$(ping -I $WAN0GWIFNAME $WAN0TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE 2>/dev/null)" \
&& WAN0PACKETLOSS="$(echo $PINGWAN0TARGETOUTPUT | awk '/packet loss/ {print $18}')" \
|| WAN0PACKETLOSS="100%"
if [[ "$WAN0PACKETLOSS" != "100%" ]] &>/dev/null;then
  WAN0PINGTIME="$(echo $PINGWAN0TARGETOUTPUT | awk '/packet loss/ {print $24}' | awk -F "/" '{print $3}' | cut -f 1 -d ".")"
else
  WAN0PINGTIME="N\/A"
fi

# Update Packet Loss File
sed -i '1s/.*/'$WAN0PACKETLOSS'/' "$WAN0PACKETLOSSFILE"
sed -i '2s/.*/'$WAN0PINGTIME'/' "$WAN0PACKETLOSSFILE"

return
}

# Ping WAN1Target
pingwan1target ()
{
# Capture Gateway Interface If Missing
[[ -z "${WAN1GWIFNAME+x}" ]] &>/dev/null && WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"

# Create Packet Loss File If Missing
if [[ ! -f "$WAN1PACKETLOSSFILE" ]] &>/dev/null;then
  touch -a $WAN1PACKETLOSSFILE
  echo "" >> "$WAN1PACKETLOSSFILE"
  echo "" >> "$WAN1PACKETLOSSFILE"
fi

# Capture Packet Loss
PINGWAN1TARGETOUTPUT="$(ping -I $WAN1GWIFNAME $WAN1TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE 2>/dev/null)" \
&& WAN1PACKETLOSS="$(echo $PINGWAN1TARGETOUTPUT | awk '/packet loss/ {print $18}')" \
|| WAN1PACKETLOSS="100%"
if [[ "$WAN1PACKETLOSS" != "100%" ]] &>/dev/null;then
  WAN1PINGTIME="$(echo $PINGWAN1TARGETOUTPUT | awk '/packet loss/ {print $24}' | awk -F "/" '{print $3}' | cut -f 1 -d ".")"
else
  WAN1PINGTIME="N\/A"
fi

# Update Packet Loss File
sed -i '1s/.*/'$WAN1PACKETLOSS'/' "$WAN1PACKETLOSSFILE"
sed -i '2s/.*/'$WAN1PINGTIME'/' "$WAN1PACKETLOSSFILE"

return
}

# Ping Targets
pingtargets ()
{
# Set Ping Status Variables and Loop Iteration
[[ -z "${pingfailure0+x}" ]] &>/dev/null && pingfailure0="0"
[[ -z "${pingfailure1+x}" ]] &>/dev/null && pingfailure1="0"
[[ -z "${pingtimefailure0+x}" ]] &>/dev/null && pingtimefailure0="0"
[[ -z "${pingtimefailure1+x}" ]] &>/dev/null && pingtimefailure1="0"

i=1
while [[ "$i" -le "$RECURSIVEPINGCHECK" ]] &>/dev/null;do
  pingwan0target &
  PINGWAN0PID=$!
  pingwan1target &
  PINGWAN1PID=$!
  wait $PINGWAN0PID $PINGWAN1PID
  [[ -z "${audiblealarm+x}" ]] &>/dev/null && audiblealarm=0
  [[ -z "${loopaction+x}" ]] &>/dev/null && loopaction=""
  { [[ -z "$WAN0IFNAME" ]] &>/dev/null || [[ -z "$WAN0GWIFNAME" ]] &>/dev/null ;} && WAN0PACKETLOSS="100%" || WAN0PACKETLOSS="$(sed -n 1p "$WAN0PACKETLOSSFILE")"
  { [[ -z "$WAN1IFNAME" ]] &>/dev/null || [[ -z "$WAN1GWIFNAME" ]] &>/dev/null ;} && WAN1PACKETLOSS="100%" || WAN1PACKETLOSS="$(sed -n 1p "$WAN1PACKETLOSSFILE")"
  [[ -f "$WAN0PACKETLOSSFILE" ]] &>/dev/null || WAN0PINGTIME="N/A" && { WAN0PINGTIME="$(sed -n 2p "$WAN0PACKETLOSSFILE")" && [[ -z "$WAN0PINGTIME" ]] &>/dev/null && WAN0PINGTIME="N/A" ;}
  [[ -f "$WAN1PACKETLOSSFILE" ]] &>/dev/null || WAN1PINGTIME="N/A" && { WAN1PINGTIME="$(sed -n 2p "$WAN1PACKETLOSSFILE")" && [[ -z "$WAN1PINGTIME" ]] &>/dev/null && WAN1PINGTIME="N/A" ;}

  # Logging for WAN0 Ping Times
  if [[ "$WAN0PINGTIME" != "N/A" ]] &>/dev/null && [[ "$WAN0PINGTIME" -ge "$PINGTIMEMAX" ]] &>/dev/null;then
    [[ "$pingtimefailure0" == "0" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Ping Time Above Maximum Threshold: "$PINGTIMEMAX"ms - WAN0 Ping Time: "$WAN0PINGTIME"ms" && pingtimefailure0=1
  elif [[ "$WAN0PINGTIME" != "N/A" ]] &>/dev/null && [[ "$WAN0PINGTIME" -lt "$PINGTIMEMAX" ]] &>/dev/null;then
    [[ "$pingtimefailure0" != "0" ]] &>/dev/null && logger -p 4 -st "$ALIAS" "Ping Time Below Maximum Threshold: "$PINGTIMEMAX"ms - WAN0 Ping Time: "$WAN0PINGTIME"ms" && pingtimefailure0=0
  fi
  # Logging for WAN1 Ping Times
  if [[ "$WAN1PINGTIME" != "N/A" ]] &>/dev/null && [[ "$WAN1PINGTIME" -ge "$PINGTIMEMAX" ]] &>/dev/null;then
    [[ "$pingtimefailure1" == "0" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Ping Time Above Maximum Threshold: "$PINGTIMEMAX"ms - WAN1 Ping Time: "$WAN1PINGTIME"ms" && pingtimefailure1=1
  elif [[ "$WAN1PINGTIME" != "N/A" ]] &>/dev/null && [[ "$WAN1PINGTIME" -lt "$PINGTIMEMAX" ]] &>/dev/null;then
    [[ "$pingtimefailure1" != "0" ]] &>/dev/null && logger -p 4 -st "$ALIAS" "Ping Time Below Maximum Threshold: "$PINGTIMEMAX"ms - WAN1 Ping Time: "$WAN1PINGTIME"ms" && pingtimefailure1=0
  fi

  # Logging for Packet Loss
  if [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null && [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null;then
    WAN0PACKETLOSSCOLOR="${GREEN}"
    WAN1PACKETLOSSCOLOR="${GREEN}"
    [[ "$audiblealarm" != "0" ]] &>/dev/null && audiblealarm=0
    [[ "$pingfailure0" != "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=0
    [[ "$pingfailure1" != "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=0
    loopaction="break 1"
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null && [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null;then
    WAN0PACKETLOSSCOLOR="${RED}"
    WAN1PACKETLOSSCOLOR="${GREEN}"
    [[ -n "$(ip route show default | grep -w "$WAN0GATEWAY")" ]] &>/dev/null && audiblealarm=1
    [[ "$pingfailure0" == "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && email=1 && pingfailure0=1
    [[ "$pingfailure1" != "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=0
    i=$(($i+1))
    loopaction="continue"
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null && [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    WAN0PACKETLOSSCOLOR="${GREEN}"
    WAN1PACKETLOSSCOLOR="${RED}"
    [[ -n "$(ip route show default | grep -w "$WAN1GATEWAY")" ]] &>/dev/null && audiblealarm=1
    [[ "$pingfailure0" != "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=0
    [[ "$pingfailure1" == "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Failure Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=1
    i=$(($i+1))
    loopaction="continue"
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null && [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    WAN0PACKETLOSSCOLOR="${RED}"
    WAN1PACKETLOSSCOLOR="${RED}"
    { [[ -n "$(ip route show default | grep -w "$WAN0GATEWAY")" ]] &>/dev/null && [[ -n "$(ip route show default | grep -w "$WAN1GATEWAY")" ]] &>/dev/null ;} && audiblealarm=1
    [[ "$pingfailure0" == "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=1
    [[ "$pingfailure1" == "0" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "Failure Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=1
    i=$(($i+1))
    loopaction="continue"
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] &>/dev/null && [[ -n "$WAN0PACKETLOSS" ]] &>/dev/null ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] &>/dev/null && [[ -n "$WAN1PACKETLOSS" ]] &>/dev/null ;};then
    WAN0PACKETLOSSCOLOR="${YELLOW}"
    WAN1PACKETLOSSCOLOR="${YELLOW}"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure0" == "0" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure0" == "1" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure1" == "0" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure1" == "1" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    i=$(($i+1))
    loopaction="continue"
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] &>/dev/null && [[ -n "$WAN0PACKETLOSS" ]] &>/dev/null ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null;then
    WAN0PACKETLOSSCOLOR="${YELLOW}"
    WAN1PACKETLOSSCOLOR="${GREEN}"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure0" == "0" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure0" == "1" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    i=$(($i+1))
    loopaction="continue"
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null && { [[ "$WAN1PACKETLOSS" != "0%" ]] &>/dev/null && [[ -n "$WAN1PACKETLOSS" ]] &>/dev/null ;};then
    WAN0PACKETLOSSCOLOR="${GREEN}"
    WAN1PACKETLOSSCOLOR="${YELLOW}"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure1" == "0" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] &>/dev/null && [[ "$pingfailure1" == "1" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    i=$(($i+1))
    loopaction="continue"
  fi
  # Display Current Status
  if tty &>/dev/null;then
    output="$(
    clear
    printf '\033[K%b\r' "${BOLD}WAN Failover Status:${NOCOLOR}\n"
    printf "\n"
    printf '\033[K%b\r' "${BOLD}Last Update: $(date "+%D @ %T")${NOCOLOR}\n"
    printf "\n"
    printf '\033[K%b\r' "${BOLD}WAN0 Target: ${LIGHTBLUE}"$WAN0TARGET"${NOCOLOR}\n"
    printf '\033[K%b\r' "${BOLD}Packet Loss: ${WAN0PACKETLOSSCOLOR}"$WAN0PACKETLOSS"${NOCOLOR}\n"
    printf "\n"
    printf '\033[K%b\r' "${BOLD}WAN1 Target: ${LIGHTBLUE}"$WAN1TARGET"${NOCOLOR}\n"
    printf '\033[K%b\r' "${BOLD}Packet Loss: ${WAN1PACKETLOSSCOLOR}"$WAN1PACKETLOSS"${NOCOLOR}\n"
    )"
    if [[ "$audiblealarm" == "1" ]] &>/dev/null;then
      printf '\a'
      audiblealarm=0
    fi
    echo "$output"
  fi

  # Execute Loop Action
  $loopaction

done
# Unset Variables
[[ -n "${i+x}" ]] &>/dev/null && unset i
[[ -n "${output+x}" ]] &>/dev/null && unset output
[[ -n "${loopaction+x}" ]] &>/dev/null && unset loopaction
return
}

# Failover
failover ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: failover"

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE="2"
  getwanparameters || return
fi

# Disable Email Notification if Mode is Switch WAN
[[ "${mode}" == "switchwan" ]] &>/dev/null && email="0"

# Set Status for Email Notification On if Unset
[[ -z "${email+x}" ]] &>/dev/null && email="1"

[[ "$WANSMODE" != "lb" ]] &>/dev/null && switchwan || return
switchdns || return
restartservices || return
checkiprules || return
[[ "$email" == "1" ]] &>/dev/null && { sendemail && email="0" ;} || return
return
}

# Load Balance Monitor
lbmonitor ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: lbmonitor"

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE="2"
  getwanparameters || return
fi

# Get Active WAN Parameters
GETWANMODE="3"
getwanparameters || return

# Begin LB Monitor Loop
[[ -z "${lbmonitorloop+x}" ]] &>/dev/null && lbmonitorloop="1"

# Default Check IP Rules Interval
[[ -z "${CHECKIPRULESINTERVAL+x}" ]] &>/dev/null && CHECKIPRULESINTERVAL="900"

if [[ "$lbmonitorloop" == "1" ]] &>/dev/null;then
  if [[ "$WAN0STATUS" == "CONNECTED" ]] &>/dev/null;then
    logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
  elif [[ "$WAN0STATUS" != "CONNECTED" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
  elif [[ "$WAN1STATUS" == "CONNECTED" ]] &>/dev/null;then
    logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
  elif [[ "$WAN1STATUS" != "CONNECTED" ]] &>/dev/null;then
    logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
  fi
fi
LBMONITORSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
while { [[ "$WANSMODE" == "lb" ]] &>/dev/null && [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null ;};do
  # Reset Loop Iterations if greater than interval and Check IP Rules
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -ge "$(($LBMONITORSTARTLOOPTIME+$CHECKIPRULESINTERVAL))" ]] &>/dev/null;then
    checkiprules || return
    lbmonitorloop=1
    LBMONITORSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
  fi

  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # Ping WAN Targets
  pingtargets || wanstatus

  if { { [[ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ]] &>/dev/null && [[ "$WAN0STATE" == "2" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0IPADDR" ]] &>/dev/null ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0GATEWAY" ]] &>/dev/null ;} ;} ;} \
  || { { [[ "$WAN0STATE" == "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} && { [[ "$WAN0GATEWAY" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] &>/dev/null && [[ "$WAN0GWIFNAME" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] &>/dev/null ;} ;};then
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    break
  elif { { [[ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ]] &>/dev/null && [[ "$WAN1STATE" == "2" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1IPADDR" ]] &>/dev/null ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1GATEWAY" ]] &>/dev/null ;} ;} ;} \
  || { { [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} && { [[ "$WAN1GATEWAY" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] &>/dev/null && [[ "$WAN1GWIFNAME" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] &>/dev/null ;} ;};then
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    break
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null && [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null;then
    if [[ -n "$(ip route show default | grep -w "$WAN0GATEWAY")" ]] &>/dev/null && [[ -n "$(ip route show default | grep -w "$WAN1GATEWAY")" ]] &>/dev/null;then
      [[ "$WAN0STATE" != "2" ]] &>/dev/null && nvram set wan0_state_t=2
      [[ "$WAN1STATE" != "2" ]] &>/dev/null && nvram set wan1_state_t=2
      lbmonitorloop=$(($lbmonitorloop+1))
      continue
    else
      logger -p 4 -st "$ALIAS" "Load Balance Monitor - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -p 6 -t "$ALIAS" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to delete default route"
      logger -p 5 -st "$ALIAS" "Load Balance Monitor - Adding nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO"
      logger -p 5 -st "$ALIAS" "Load Balance Monitor - Adding nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO"
      ip route add default scope global \
      nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO \
      nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO \
      && { logger -p 4 -st "$ALIAS" "Load Balance Monitor - Added nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO" \
      && logger -p 4 -st "$ALIAS" "Load Balance Monitor - Added nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO" ;} \
      || { logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to add nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO" \
      && logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to add nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO" ;}

      # Set WAN Status and Failover
      WAN0STATUS=CONNECTED
      WAN1STATUS=CONNECTED
      logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: "$WAN1STATUS""
      [[ "$email" == "0" ]] &>/dev/null && email=1
      failover && email=0 || return
      logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
      logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
      lbmonitorloop=$(($lbmonitorloop+1))
      continue
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN0STATE" != "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null;then
    if [[ -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ]] &>/dev/null && [[ -n "$(ip route show default | grep -w "$WAN1GATEWAY")" ]] &>/dev/null;then
      lbmonitorloop=$(($lbmonitorloop+1))
      continue
    else
      logger -p 5 -st "$ALIAS" "Load Balance Monitor - Removing nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO"
      logger -p 6 -t "$ALIAS" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to delete default route"
      logger -p 6 -t "$ALIAS" "Debug - Adding nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO"
      ip route add default scope global \
      nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO \
      && logger -p 4 -st "$ALIAS" "Load Balance Monitor - Removed nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO" \
      || logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to remove nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO"

      # Set WAN Status and Failover
      WAN0STATUS=DISCONNECTED
      WAN1STATUS=CONNECTED
      logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: "$WAN1STATUS""
      [[ "$email" == "0" ]] &>/dev/null && email=1
      failover && email=0 || return
      if [[ "$WAN0ENABLE" == "0" ]] &>/dev/null;then
        wandisabled
      else
        logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
        logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
        lbmonitorloop=$(($lbmonitorloop+1))
        continue
      fi
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null && { [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null ;};then
    if [[ -n "$(ip route show default | grep -w "$WAN0GATEWAY")" ]] &>/dev/null && [[ -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ]] &>/dev/null;then
      lbmonitorloop=$(($lbmonitorloop+1))
      continue
    else
      logger -p 5 -st "$ALIAS" "Load Balance Monitor - Removing nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO"
      logger -p 6 -t "$ALIAS" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to delete default route"
      logger -p 6 -t "$ALIAS" "Debug - Adding nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN1LBRATIO"
      ip route add default scope global \
      nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO \
      && logger -p 4 -st "$ALIAS" "Load Balance Monitor - Removed nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO" \
      || logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to remove nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO"

      # Set WAN Status and Failover
      WAN0STATUS=CONNECTED
      WAN1STATUS=DISCONNECTED
      logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: "$WAN1STATUS""
      [[ "$email" == "0" ]] &>/dev/null && email=1
      failover && email=0 || return
      if [[ "$WAN1ENABLE" == "0" ]] &>/dev/null;then
        wandisabled
      else
        logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
        logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
        lbmonitorloop=$(($lbmonitorloop+1))
        continue
      fi
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN0STATE" != "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null ;};then
    if [[ -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ]] &>/dev/null && [[ -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ]] &>/dev/null;then
      lbmonitorloop=$(($lbmonitorloop+1))
      continue
    else
      logger -p 5 -st "$ALIAS" "Load Balance Monitor - Removing nexthop via $WAN0GATEWAY dev $WAN0GWIFNAME weight $WAN0LBRATIO"
      logger -p 5 -st "$ALIAS" "Load Balance Monitor - Removing nexthop via $WAN1GATEWAY dev $WAN1GWIFNAME weight $WAN1LBRATIO"
      logger -p 6 -t "$ALIAS" "Debug - Deleting Default Route"
      ip route del default \
      || logger -p 2 -st "$ALIAS" "Load Balance Monitor - ***Error*** Unable to delete default route"

      # Set WAN Status and Check Rules
      checkiprules || return
      if [[ "$WAN0ENABLE" == "0" ]] &>/dev/null && [[ "$WAN1ENABLE" == "0" ]] &>/dev/null;then
        wandisabled
      else
        logger -p 1 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
        logger -p 1 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
        lbmonitorloop=$(($lbmonitorloop+1))
        continue
      fi
    fi
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] &>/dev/null || [[ "$WAN1PACKETLOSS" != "0%" ]] &>/dev/null;then
    lbmonitorloop=$(($lbmonitorloop+1))
    continue
  fi
done

# Reset LB Monitor Loop Iterations
[[ -n "${lbmonitorloop+x}" ]] &>/dev/null && unset lbmonitorloop

# Debug Logging
logger -p 6 -t "$ALIAS" "Debug - ***Load Balance Monitor Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# WAN0 Failover Monitor
wan0failovermonitor ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: wan0failovermonitor"

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE=2
  getwanparameters || return
fi

# Get Active WAN Parameters
GETWANMODE=3
getwanparameters || return

logger -p 4 -st "$ALIAS" "WAN0 Failover Monitor - Monitoring "$WAN0" via $WAN0TARGET for Failure"
logger -p 4 -st "$ALIAS" "WAN0 Failover Monitor - Monitoring "$WAN1" via $WAN1TARGET for Failure"
while [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null;do

  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # Ping WAN Targets
  pingtargets || wanstatus
  if { { [[ "$WAN0PINGPATH" -le "2" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ]] &>/dev/null && [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN0STATE" == "2" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0IPADDR" ]] &>/dev/null ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0GATEWAY" ]] &>/dev/null ;} ;} ;} \
  || { { [[ "$WAN0STATE" == "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} && { [[ "$WAN0GATEWAY" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] &>/dev/null && [[ "$WAN0GWIFNAME" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] &>/dev/null && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0IPADDR" ]] &>/dev/null ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0GATEWAY" ]] &>/dev/null ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null || { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN0STATE" == "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} ;};then
      break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null || { [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;};then
      [[ "$email" == "0" ]] &>/dev/null && email=1
      failover && email=0 || return
      wanstatus || return && break
    else
      break
    fi
  elif { { [[ "$WAN1PINGPATH" -le "2" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ]] &>/dev/null && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1STATE" == "2" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1IPADDR" ]] &>/dev/null ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1GATEWAY" ]] &>/dev/null ;} ;} ;} \
  || { { [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} && { [[ "$WAN1GATEWAY" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] &>/dev/null && [[ "$WAN1GWIFNAME" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] &>/dev/null && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1IPADDR" ]] &>/dev/null ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1GATEWAY" ]] &>/dev/null ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null || { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN0STATE" == "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} ;};then
      break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null || { [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;};then
      [[ "$email" == "0" ]] &>/dev/null && email=1
      failover && email=0 || return
      wanstatus || return && break
    else
      break
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null && [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null;then
    [[ "$WAN0STATE" != "2" ]] &>/dev/null && nvram set wan0_state_t=2
    [[ "$WAN1STATE" != "2" ]] &>/dev/null && nvram set wan1_state_t=2
    [[ "$email" == "1" ]] &>/dev/null && email=0
    continue
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN0STATE" != "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$WAN0USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$WAN0IFNAME" ]] &>/dev/null || [[ "$WAN0LINKWAN" == "0" ]] &>/dev/null ;} ;} ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null || [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} ;};then
    WANSTATUSMODE=2 && setwanstatus
    WAN1STATUS=CONNECTED
    logger -p 6 -t "$ALIAS" "Debug - WAN0: $WAN0STATUS"
    logger -p 6 -t "$ALIAS" "Debug - WAN1: $WAN1STATUS"
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    wanstatus || return && break
  elif { [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null || [[ "$WAN0STATE" == "2" ]] &>/dev/null ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN1ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$WAN1USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$WAN1IFNAME" ]] &>/dev/null || [[ "$WAN1LINKWAN" == "0" ]] &>/dev/null ;} ;} ;} ;then
    [[ "$email" == "0" ]] &>/dev/null && email=1
    break
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN0STATE" != "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$WAN0USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$WAN0IFNAME" ]] &>/dev/null || [[ "$WAN0LINKWAN" == "0" ]] &>/dev/null ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN1ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$WAN1USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$WAN1IFNAME" ]] &>/dev/null || [[ "$WAN1LINKWAN" == "0" ]] &>/dev/null ;} ;} ;} ;then
    [[ "$email" == "1" ]] &>/dev/null && email=0
    break
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] &>/dev/null || [[ "$WAN0PACKETLOSS" != "100%" ]] &>/dev/null ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] &>/dev/null || [[ "$WAN1PACKETLOSS" != "100%" ]] &>/dev/null ;};then
    [[ "$email" == "1" ]] &>/dev/null && email=0
    continue
  fi
done

# Debug Logging
logger -p 6 -t "$ALIAS" "Debug - ***WAN0 Failover Monitor Loop Ended***"
debuglog || return

# Complete Failover if Primary WAN was changed by Router
if [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Router switched "$WAN1" to Primary WAN"
  WAN0STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] &>/dev/null && email=1 ;} \
  && failover \
  && { [[ "$email" != "0" ]] &>/dev/null && email=0 ;}
# Send Email if Connection Loss breaks Failover Monitor Loop
elif [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null;then
  WAN1STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] &>/dev/null && email=1 ;} \
  && RESTARTSERVICESMODE=0 \
  && failover \
  && { [[ "$email" != "0" ]] &>/dev/null && email=0 ;}
fi

# Return to WAN Status
wanstatus || return
}

# WAN0 Failback Monitor
wan0failbackmonitor ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: wan0failbackmonitor"

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE=2
  getwanparameters || return
fi

# Get Active WAN Parameters
GETWANMODE=3
getwanparameters || return

logger -p 4 -st "$ALIAS" "WAN0 Failback Monitor - Monitoring "$WAN1" via $WAN1TARGET for Failure"
logger -p 3 -st "$ALIAS" "WAN0 Failback Monitor - Monitoring "$WAN0" via $WAN0TARGET for Restoration"
while [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null;do

  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # Ping WAN Targets
  pingtargets || wanstatus
  if { { [[ "$WAN0PINGPATH" -le "2" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ]] &>/dev/null && [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN0STATE" == "2" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0IPADDR" ]] &>/dev/null ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0GATEWAY" ]] &>/dev/null ;} ;} ;} \
  || { { [[ "$WAN0STATE" == "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} && { [[ "$WAN0GATEWAY" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] &>/dev/null && [[ "$WAN0GWIFNAME" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] &>/dev/null && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0IPADDR" ]] &>/dev/null ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0GATEWAY" ]] &>/dev/null ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null;then
      [[ "$email" == "0" ]] &>/dev/null && email=1
      failover && email=0 || return
      wanstatus || return && break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null || { [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;};then
      break
    else
      break
    fi
  elif { { [[ "$WAN1PINGPATH" -le "2" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ]] &>/dev/null && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1STATE" == "2" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1IPADDR" ]] &>/dev/null ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1GATEWAY" ]] &>/dev/null ;} ;} ;} \
  || { { [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} && { [[ "$WAN1GATEWAY" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] &>/dev/null && [[ "$WAN1GWIFNAME" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] &>/dev/null && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1IPADDR" ]] &>/dev/null ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1GATEWAY" ]] &>/dev/null ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null;then
      [[ "$email" == "0" ]] &>/dev/null && email=1
      failover && email=0 || return
      wanstatus || return && break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null || { [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;};then
      break
    else
      break
    fi
  elif { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null ;} ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null || [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} ;};then
    [[ "$WAN1STATE" != "2" ]] &>/dev/null && nvram set wan1_state_t=2
    [[ "$email" == "1" ]] &>/dev/null && email=0
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] \
  || { { [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null || [[ "$WAN0ENABLE" == "1" ]] &>/dev/null || [[ "$WAN0STATE" == "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null || { [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$WAN0USBMODEMREADY" == "1" ]] &>/dev/null || [[ -n "$WAN0IFNAME" ]] &>/dev/null || [[ "$WAN0LINKWAN" == "1" ]] &>/dev/null ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN1ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$WAN1USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$WAN1IFNAME" ]] &>/dev/null || [[ "$WAN1LINKWAN" == "0" ]] &>/dev/null ;} ;} ;} ;} ;then
    WANSTATUSMODE=2 && setwanstatus
    logger -p 6 -t "$ALIAS" "Debug - WAN0: $WAN0STATUS"
    logger -p 6 -t "$ALIAS" "Debug - WAN1: $WAN1STATUS"
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    wanstatus || return && break
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN0STATE" != "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN0USBMODEMREADY" == "usb" ]] &>/dev/null && { [[ "$WAN0USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$WAN0IFNAME" ]] &>/dev/null || [[ "$WAN0LINKWAN" == "0" ]] &>/dev/null ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null || [[ "$WAN1ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1STATE" != "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null || { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$WAN1USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$WAN1IFNAME" ]] &>/dev/null || [[ "$WAN1LINKWAN" == "0" ]] &>/dev/null ;} ;} ;} ;then
    [[ "$email" == "1" ]] &>/dev/null && email=0
    break
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] &>/dev/null || [[ "$WAN0PACKETLOSS" != "100%" ]] &>/dev/null ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] &>/dev/null || [[ "$WAN1PACKETLOSS" != "100%" ]] &>/dev/null ;};then
    [[ "$email" == "1" ]] &>/dev/null && email=0
    continue
  fi
done

# Debug Logging
logger -p 6 -t "$ALIAS" "Debug - ***WAN0 Failback Monitor Loop Ended***"
debuglog || return

# Complete Failover if Primary WAN was changed by Router
if [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Router switched "$WAN0" to Primary WAN"
  WAN1STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] &>/dev/null && email=1 ;} \
  && failover \
  && { [[ "$email" != "0" ]] &>/dev/null && email=0 ;}
# Send Email if Connection Loss breaks Failover Monitor Loop
elif [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null;then
  WAN0STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] &>/dev/null && email=1 ;} \
  && RESTARTSERVICESMODE=0 \
  && failover \
  && { [[ "$email" != "0" ]] &>/dev/null && email=0 ;}
fi

# Return to WAN Status
wanstatus || return
}

# WAN Disabled
wandisabled ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: wandisabled"

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE=2
  getwanparameters || return
fi

# Start WAN Disabled Loop Iteration
if [[ -z "${wandisabledloop+x}" ]] &>/dev/null || [[ "$wandisabledloop" == "1" ]] &>/dev/null;then
  [[ -z "${wandisabledloop+x}" ]] &>/dev/null && wandisabledloop=1
  logger -p 2 -st "$ALIAS" "WAN Failover Disabled - WAN Failover is currently disabled.  ***Review Logs***"
fi

DISABLEDSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
while \
  # Reset Loop Iterations if greater than 5 minutes for logging
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -ge "$(($DISABLEDSTARTLOOPTIME+900))" ]] &>/dev/null;then
    [[ "$wandisabledloop" != "1" ]] &>/dev/null && wandisabledloop=1
    DISABLEDSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
  fi
  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # WAN Disabled if both interfaces are Enabled and do not have an IP Address or are unplugged
  if { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN0AUXSTATE" == "1" ]] &>/dev/null || [[ "$WAN0IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0IPADDR" ]] &>/dev/null || [[ "$WAN0GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0GATEWAY" ]] &>/dev/null ;} ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN1AUXSTATE" == "1" ]] &>/dev/null || [[ "$WAN1IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1IPADDR" ]] &>/dev/null || [[ "$WAN1GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1GATEWAY" ]] &>/dev/null ;} ;};then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is unplugged"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN0IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0IPADDR" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid IP Address: "$WAN0IPADDR""
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN0GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0GATEWAY" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid Gateway IP Address: "$WAN0GATEWAY""
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is unplugged"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN1IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1IPADDR" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid IP Address: "$WAN1IPADDR""
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN1GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1GATEWAY" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid Gateway IP Address: "$WAN1GATEWAY""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if an interface is Disabled - Load Balance Mode
  elif [[ "$WANSMODE" == "lb" ]] &>/dev/null && { [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1ENABLE" == "0" ]] &>/dev/null ;};then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Load Balance Mode: "$WAN0" or "$WAN1" is not Enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # Return to WAN Status if WAN0 or WAN1 is a USB Device and is in Ready State but in Cold Standby
  elif { [[ "$WAN0DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$WAN0STATE" != "2" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN0USBMODEMREADY" == "1" ]] &>/dev/null && [[ "$WAN0LINKWAN" == "1" ]] &>/dev/null && [[ -n "$WAN0IFNAME" ]] &>/dev/null ;} \
  || { [[ "$WAN1DUALWANDEV" == "usb" ]] &>/dev/null && [[ "$WAN1STATE" != "2" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN1USBMODEMREADY" == "1" ]] &>/dev/null && [[ "$WAN1LINKWAN" == "1" ]] &>/dev/null && [[ -n "$WAN1IFNAME" ]] &>/dev/null ;};then
    [[ "$WAN0USBMODEMREADY" == "1" ]] &>/dev/null && [[ "$WAN0STATE" != "2" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - USB Device for "$WAN0" is in Ready State but in Cold Standby"
    [[ "$WAN1USBMODEMREADY" == "1" ]] &>/dev/null && [[ "$WAN1STATE" != "2" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - USB Device for "$WAN1" is in Ready State but in Cold Standby"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    break
  # WAN Disabled if WAN0 does not have have an IP and WAN1 is Primary - Failover Mode
  elif { [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null ;} \
  && { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN0AUXSTATE" == "1" ]] &>/dev/null || [[ "$WAN0IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0IPADDR" ]] &>/dev/null || [[ "$WAN0GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0GATEWAY" ]] &>/dev/null ;} ;};then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN1" is Primary"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is unplugged"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN0IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0IPADDR" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid IP Address: "$WAN0IPADDR""
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN0GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN0GATEWAY" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid Gateway IP Address: "$WAN0GATEWAY""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if WAN1 does not have have an IP and WAN0 is Primary - Failover Mode
  elif { [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && { [[ "$WAN1AUXSTATE" == "1" ]] &>/dev/null || [[ "$WAN1IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1IPADDR" ]] &>/dev/null || [[ "$WAN1GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1GATEWAY" ]] &>/dev/null ;} ;};then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN0" is Primary"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is unplugged"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN1IPADDR" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1IPADDR" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid IP Address: "$WAN1IPADDR""
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN1GATEWAY" == "0.0.0.0" ]] &>/dev/null || [[ -z "$WAN1GATEWAY" ]] &>/dev/null ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid Gateway IP Address: "$WAN1GATEWAY""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # Return to WAN Status if interface is connected but no IP / Gateway
  elif { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN0STATE" == "3" ]] &>/dev/null ;} \
  || { [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1STATE" == "3" ]] &>/dev/null ;};then
    [[ "$WAN0STATE" == "3" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is connected with State: $WAN0STATE"
    [[ "$WAN1STATE" == "3" ]] &>/dev/null && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is connected with State: $WAN1STATE"
      unset wandisabledloop
      wanstatus
  # Return to WAN Status if both interfaces are Enabled and Connected
  elif { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null ;} \
  && { { [[ "$WAN0STATE" == "2" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && { [[ "$WAN0IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0IPADDR" ]] &>/dev/null ;} && { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN0GATEWAY" ]] &>/dev/null ;} ;} \
  && { [[ "$WAN1STATE" == "2" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && { [[ "$WAN1IPADDR" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1IPADDR" ]] &>/dev/null ;} && { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] &>/dev/null && [[ -n "$WAN1GATEWAY" ]] &>/dev/null ;} ;} ;} ;then
    [[ -z "$(ip route list default table "$WAN0ROUTETABLE" | grep -w "$WAN0GWIFNAME")" ]] &>/dev/null && wanstatus
    [[ -z "$(ip route list default table "$WAN1ROUTETABLE" | grep -w "$WAN1GWIFNAME")" ]] &>/dev/null && wanstatus
    [[ "$WAN0PINGPATH" == "1" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN0TARGET" oif "$WAN0GWIFNAME" lookup "$WAN0ROUTETABLE" priority "$WAN0TARGETRULEPRIORITY")" ]] &>/dev/null && wanstatus
    [[ "$WAN0PINGPATH" == "2" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE" priority "$WAN0TARGETRULEPRIORITY")" ]] &>/dev/null && wanstatus
    [[ "$WAN0PINGPATH" == "3" ]] &>/dev/null && [[ -z "$(ip route list "$WAN0TARGET" via "$WAN0GATEWAY" dev "$WAN0GWIFNAME")" ]] &>/dev/null && wanstatus
    [[ "$WAN1PINGPATH" == "1" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN1TARGET" oif "$WAN1GWIFNAME" lookup "$WAN1ROUTETABLE" priority "$WAN1TARGETRULEPRIORITY")" ]] &>/dev/null && wanstatus
    [[ "$WAN1PINGPATH" == "2" ]] &>/dev/null && [[ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE" priority "$WAN1TARGETRULEPRIORITY")" ]] &>/dev/null && wanstatus
    [[ "$WAN1PINGPATH" == "3" ]] &>/dev/null && [[ -z "$(ip route list "$WAN1TARGET" via "$WAN1GATEWAY" dev "$WAN1GWIFNAME")" ]] &>/dev/null && wanstatus
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && { [[ "$WAN0PINGPATH" == "0" ]] &>/dev/null || [[ "$WAN1PINGPATH" == "0" ]] &>/dev/null ;} && wanstatus
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && logger -p 5 -st "$ALIAS" "WAN Failover Disabled - Pinging "$WAN0TARGET" and "$WAN1TARGET""
    pingtargets || wanstatus
    [[ -z "${wan0disabled+x}" ]] &>/dev/null && wan0disabled="$pingfailure0"
    [[ -z "${wan1disabled+x}" ]] &>/dev/null && wan1disabled="$pingfailure1"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$pingfailure0" == "1" ]] &>/dev/null && restartwan0
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$pingfailure1" == "1" ]] &>/dev/null && restartwan1
    if { [[ "$pingfailure0" != "$wan0disabled" ]] &>/dev/null || [[ "$pingfailure1" != "$wan1disabled" ]] &>/dev/null ;} || { [[ "$pingfailure0" == "0" ]] &>/dev/null && [[ "$pingfailure1" == "0" ]] &>/dev/null ;};then
      [[ "$email" == "0" ]] &>/dev/null && email=1
      [[ "$pingfailure0" == "0" ]] &>/dev/null && logger -p 4 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is enabled and connected"
      [[ "$pingfailure1" == "0" ]] &>/dev/null && logger -p 4 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is enabled and connected"
      [[ "$pingfailure0" != "$wan0disabled" ]] &>/dev/null && unset wandisabledloop && unset wan0disabled
      [[ "$pingfailure1" != "$wan1disabled" ]] &>/dev/null && unset wandisabledloop && unset wan1disabled
      [[ "$pingfailure0" == "0" ]] &>/dev/null && unset wan0disabled
      [[ "$pingfailure1" == "0" ]] &>/dev/null && unset wan1disabled
      [[ "$pingfailure0" == "0" ]] &>/dev/null && [[ "$pingfailure1" == "0" ]] &>/dev/null && unset wandisabledloop
      wanstatus
    elif [[ "$wandisabledloop" == "1" ]] &>/dev/null;then
      wandisabledloop=$(($wandisabledloop+1))
      wanstatus
    else
      [[ "$email" == "1" ]] &>/dev/null && email=0
      wandisabledloop=$(($wandisabledloop+1))
      sleep $WANDISABLEDSLEEPTIMER
    fi
  # Return to WAN Status if only WAN0 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null \
  && { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1ENABLE" == "0" ]] \
  && { [[ "$WAN0STATE" == "2" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null ;} && [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN0" is the only enabled WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if only WAN1 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null \
  && { [[ "$WAN0ENABLE" == "0" ]] &>/dev/null && [[ "$WAN1ENABLE" == "1" ]] \
  && { [[ "$WAN1STATE" == "2" ]] &>/dev/null &&  [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null ;} && [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN1" is the only enabled WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 is Connected and is not Primary WAN. - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null \
  && { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null ;} \
  && { { [[ "$WAN0STATE" == "2" ]] &>/dev/null || [[ "$WAN0REALIPSTATE" == "2" ]] &>/dev/null ;} && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN0PRIMARY" == "0" ]] &>/dev/null ;} \
  && { [[ "$WAN1STATE" != "2" ]] &>/dev/null || [[ "$WAN1AUXSTATE" != "0" ]] &>/dev/null ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN0" is the only connected WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 is Connected and is not Primary WAN. - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null \
  && { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null ;} \
  && { { [[ "$WAN1STATE" == "2" ]] &>/dev/null || [[ "$WAN1REALIPSTATE" == "2" ]] &>/dev/null ;} && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN1PRIMARY" == "0" ]] &>/dev/null ;} \
  && { [[ "$WAN0STATE" != "2" ]] &>/dev/null || [[ "$WAN0AUXSTATE" != "0" ]] &>/dev/null ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN1" is the only connected WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are pinging both Target IP Addresses.
  elif { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && [[ "$(ping -I $WAN0GWIFNAME $WAN0TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && [[ "$(ping -I $WAN1GWIFNAME $WAN1TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] &>/dev/null ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" and "$WAN1" have 0% packet loss"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    break
  # Return to WAN Status if WAN0 is pinging the Target IP Address and WAN1 is Primary and not pinging the Target IP Address.
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null \
  && [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && [[ "$(ping -I $WAN0GWIFNAME $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && { [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null && [[ "$(ping -I $WAN1GWIFNAME $WAN1TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "100%" ]] &>/dev/null ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN1 is pinging the Target IP Address and WAN0 is Primary and not pinging the Target IP Address.
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null \
  && [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && [[ "$(ping -I $WAN1GWIFNAME $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null && [[ "$(ping -I $WAN0GWIFNAME $WAN0TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "100%" ]] &>/dev/null ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] &>/dev/null && email=1
    failover && email=0 || return
    break
  # WAN Disabled if WAN0 or WAN1 is not Enabled
  elif [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1ENABLE" == "0" ]] &>/dev/null;then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN0ENABLE" == "0" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is Disabled"
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN1ENABLE" == "0" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is Disabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Failover Disabled if not in Dual WAN Mode Failover Mode or if ASUS Factory Failover is Enabled
  elif [[ "$WANSDUALWANENABLE" == "0" ]] &>/dev/null;then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Dual WAN is not Enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  elif [[ "$WANDOGENABLE" != "0" ]] &>/dev/null;then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - ASUS Factory WAN Failover is enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  elif { [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ "$WAN0AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN0STATE" != "2" ]] &>/dev/null ;} \
  || { [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ "$WAN1AUXSTATE" == "0" ]] &>/dev/null && [[ "$WAN1STATE" != "2" ]] &>/dev/null ;};then
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN0STATE" != "2" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "WAN Failover Disabled - Restarting "$WAN0"" && restartwan0
    [[ "$wandisabledloop" == "1" ]] &>/dev/null && [[ "$WAN1STATE" != "2" ]] &>/dev/null && logger -p 1 -st "$ALIAS" "WAN Failover Disabled - Restarting "$WAN1"" && restartwan1
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  else
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  fi
&>/dev/null;do
  wandisabledloop=$(($wandisabledloop+1))
  sleep $WANDISABLEDSLEEPTIMER
done
[[ -n "$wandisabledloop" ]] &>/dev/null && unset wandisabledloop
# Return to WAN Status
logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Returning to check WAN Status"

# Debug Logging
logger -p 6 -t "$ALIAS" "Debug - ***WAN Disabled Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# Switch WAN
switchwan ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: switchwan"

[[ -z "${SWITCHPRIMARY+x}" ]] &>/dev/null && SWITCHPRIMARY="1"

# Determine Primary WAN and determine if it was switched automatically by Router Firmware
for WANPREFIX in ${WANPREFIXES};do

  # Getting WAN Parameters
  GETWANMODE=1
  getwanparameters || return

  # Determine if Router Switched WAN from being Unplugged
  if [[ "$PRIMARY" == "0" ]] &>/dev/null && { [[ "$AUXSTATE" == "1" ]] &>/dev/null || [[ -z "$GWIFNAME" ]] &>/dev/null || { [[ "$DUALWANDEV" == "usb" ]] &>/dev/null && { [[ "$USBMODEMREADY" == "0" ]] &>/dev/null || [[ -z "$IFNAME" ]] &>/dev/null ;} ;} ;};then
    [[ "$SWITCHPRIMARY" != "0" ]] &>/dev/null && SWITCHPRIMARY=0
  fi

  # Determine ACTIVEWAN and INACTIVEWAN
  if [[ "$(nvram get ${WANPREFIX}_primary & nvramcheck)" == "1" ]] &>/dev/null;then
    [[ "$SWITCHPRIMARY" == "1" ]] &>/dev/null && INACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Inactive WAN: "${WANPREFIX}""
    [[ "$SWITCHPRIMARY" == "0" ]] &>/dev/null && ACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Active WAN: "${WANPREFIX}""
    continue
  elif [[ "$(nvram get ${WANPREFIX}_primary & nvramcheck)" == "0" ]] &>/dev/null;then
    [[ "$SWITCHPRIMARY" == "0" ]] &>/dev/null && INACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Inactive WAN: "${WANPREFIX}""
    [[ "$SWITCHPRIMARY" == "1" ]] &>/dev/null && ACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Active WAN: "${WANPREFIX}""
    continue
  fi
done

# Determine if Failover or Failback
if [[ "$ACTIVEWAN" == "$WAN0" ]] &>/dev/null;then
  SWITCHWANMODE="Failback"
elif [[ "$ACTIVEWAN" == "$WAN1" ]] &>/dev/null;then
  SWITCHWANMODE="Failover"
fi

# Verify new Active WAN is Enabled
if [[ "$(nvram get "$ACTIVEWAN"_enable & nvramcheck)" == "0" ]] &>/dev/null;then
  logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** "$ACTIVEWAN" is disabled"
  return
fi

# Verify new Active WAN Gateway IP or IP Address are not 0.0.0.0
if { { [[ "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" == "0.0.0.0" ]] &>/dev/null || [[ -z "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" ]] &>/dev/null ;} || { [[ "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" == "0.0.0.0" ]] &>/dev/null || [[ -z "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" ]] &>/dev/null ;} ;};then
  logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - "$ACTIVEWAN" is disconnected.  IP Address: "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" Gateway IP Address: "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)""
  return
fi
# Perform switch until new WAN is Primary
[[ -z "${SWITCHCOMPLETE+x}" ]] &>/dev/null && SWITCHCOMPLETE="0"
SWITCHTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
[[ "$SWITCHCOMPLETE" != "0" ]] &>/dev/null && SWITCHCOMPLETE=0
until { [[ "$(nvram get "$INACTIVEWAN"_primary & nvramcheck)" == "0" ]] &>/dev/null && [[ "$(nvram get "$ACTIVEWAN"_primary & nvramcheck)" == "1" ]] &>/dev/null && [[ "$SWITCHCOMPLETE" == "1" ]] &>/dev/null ;} \
&& { [[ "$(echo $(ip route show default | awk '{print $3}'))" == "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" ]] &>/dev/null && [[ "$(echo $(ip route show default | awk '{print $5}'))" == "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" ]] &>/dev/null ;} \
&& { [[ "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" == "$(nvram get wan_ipaddr & nvramcheck)" ]] &>/dev/null && [[ "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" == "$(nvram get wan_gateway & nvramcheck)" ]] &>/dev/null && [[ "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" == "$(nvram get wan_gw_ifname & nvramcheck)" ]] &>/dev/null ;};do
  # Check for Timeout
  if [[ "$SWITCHTIMEOUT" -gt "$(awk -F "." '{print $1}' "/proc/uptime")" ]] &>/dev/null;then
    [[ "$SWITCHCOMPLETE" != "1" ]] &>/dev/null && SWITCHCOMPLETE=1
  fi

  # Change Primary WAN
  if [[ "$(nvram get "$ACTIVEWAN"_primary & nvramcheck)" != "1" ]] &>/dev/null && [[ "$(nvram get "$INACTIVEWAN"_primary & nvramcheck)" != "0" ]] &>/dev/null;then
    [[ "$SWITCHPRIMARY" == "1" ]] &>/dev/null && logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - Switching $ACTIVEWAN to Primary WAN"
    nvram set "$ACTIVEWAN"_primary=1 ; nvram set "$INACTIVEWAN"_primary=0
  fi
  # Change WAN IP Address
  if [[ "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" != "$(nvram get wan_ipaddr & nvramcheck)" ]] &>/dev/null;then
    logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)"
    nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)
  fi

  # Change WAN Gateway
  if [[ "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" != "$(nvram get wan_gateway & nvramcheck)" ]] &>/dev/null;then
    logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN Gateway IP: $(nvram get "$ACTIVEWAN"_gateway & nvramcheck)"
    nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)
  fi
  # Change WAN Gateway Interface
  if [[ "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" != "$(nvram get wan_gw_ifname & nvramcheck)" ]] &>/dev/null;then
    logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN Gateway Interface: $(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)"
    nvram set wan_gw_ifname=$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)
  fi
  # Change WAN Interface
  if [[ "$(nvram get "$ACTIVEWAN"_ifname & nvramcheck)" != "$(nvram get wan_ifname & nvramcheck)" ]] &>/dev/null;then
    if [[ "$(nvram get "$ACTIVEWAN"_ifname & nvramcheck)" != "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" ]] &>/dev/null;then
      logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN Interface: $(nvram get "$ACTIVEWAN"_ifname & nvramcheck)"
    fi
    nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname & nvramcheck)
  fi
  
  # Delete Old Default Route
  if [[ -n "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)" ]] &>/dev/null && [[ -n "$(ip route list default via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)")" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Deleting default route via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)""
    ip route del default \
    && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Deleted default route via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)"" \
    || logger -p 2 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** Unable to delete default route via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)""
  fi

  # Add New Default Route
  if [[ -n "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" ]] &>/dev/null && [[ -z "$(ip route list default via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)")" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Adding default route via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)""
    ip route add default via $(nvram get "$ACTIVEWAN"_gateway & nvramcheck) dev $(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck) \
    && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Added default route via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)"" \
    || logger -p 2 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** Unable to delete default route via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)""
  fi

  # Change QoS Settings
  for WANPREFIX in ${WANPREFIXES};do
    if [[ "$ACTIVEWAN" != "${WANPREFIX}" ]] &>/dev/null;then
      continue
    elif [[ "$ACTIVEWAN" == "${WANPREFIX}" ]] &>/dev/null;then
      GETWANMODE="1"
      getwanparameters || return
      [[ -z "${QOSAPPLIED+x}" ]] &>/dev/null && QOSAPPLIED="0"
      [[ -z "${STOPQOS+x}" ]] &>/dev/null && STOPQOS="0"
      if [[ "$WAN_QOS_ENABLE" == "1" ]] &>/dev/null;then
        [[ -z "${RESTARTSERVICESMODE+x}" ]] &>/dev/null && RESTARTSERVICESMODE="0"
        if [[ "$(nvram get qos_enable & nvramcheck)" != "1" ]] \
        || [[ "$(nvram get qos_obw & nvramcheck)" != "$WAN_QOS_OBW" ]] &>/dev/null || [[ "$(nvram get qos_ibw & nvramcheck)" != "$WAN_QOS_IBW" ]] \
        || [[ "$(nvram get qos_overhead & nvramcheck)" != "$WAN_QOS_OVERHEAD" ]] &>/dev/null || [[ "$(nvram get qos_atm & nvramcheck)" != "$WAN_QOS_ATM" ]] &>/dev/null;then
          [[ "$QOSAPPLIED" == "0" ]] &>/dev/null && QOSAPPLIED="1"
          logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Applying QoS Bandwidth Settings"
          [[ "$(nvram get qos_enable & nvramcheck)" != "1" ]] &>/dev/null && { nvram set qos_enable="1" && QOSENABLE="1" && RESTARTSERVICESMODE="3" && logger -p 6 -t "$ALIAS" "Debug - QoS is Enabled" ;}
          [[ "$(nvram get qos_obw & nvramcheck)" != "$WAN_QOS_OBW" ]] &>/dev/null && nvram set qos_obw="$WAN_QOS_OBW"
          [[ "$(nvram get qos_ibw & nvramcheck)" != "$WAN_QOS_IBW" ]] &>/dev/null && nvram set qos_ibw="$WAN_QOS_IBW"
          [[ "$(nvram get qos_overhead & nvramcheck)" != "$WAN_QOS_OVERHEAD" ]] &>/dev/null && nvram set qos_overhead="$WAN_QOS_OVERHEAD"
          [[ "$(nvram get qos_atm & nvramcheck)" != "$WAN_QOS_ATM" ]] &>/dev/null && nvram set qos_atm="$WAN_QOS_ATM"
          # Determine if Restart Mode
          if [[ "$SWITCHPRIMARY" != "1" ]] &>/dev/null && [[ "$QOSAPPLIED" != "0" ]] &>/dev/null;then
            RESTARTSERVICESMODE=3
            restartservices || return
          fi
        fi
      elif [[ "$WAN_QOS_ENABLE" == "0" ]] &>/dev/null;then
        if [[ "$(nvram get qos_enable & nvramcheck)" != "0" ]] &>/dev/null;then
          logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Disabling QoS Bandwidth Settings"
          nvram set qos_enable="0" && QOSENABLE="0" && logger -p 6 -t "$ALIAS" "Debug - QoS is Disabled"
          [[ "$STOPQOS" == "0" ]] &>/dev/null && STOPQOS="1"
        fi
        if [[ "$STOPQOS" == "1" ]] &>/dev/null;then
          logger -p 5 -t "$ALIAS" ""$SWITCHWANMODE" - Stopping qos service"
          service stop_qos &>/dev/null \
          && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Stopped qos service" \
          || logger -p 2 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** Unable to stop qos service"
        fi
      fi
      logger -p 6 -t "$ALIAS" "Debug - Outbound Bandwidth: "$(nvram get qos_obw & nvramcheck)""
      logger -p 6 -t "$ALIAS" "Debug - Inbound Bandwidth: "$(nvram get qos_ibw & nvramcheck)""
      logger -p 6 -t "$ALIAS" "Debug - QoS Overhead: "$(nvram get qos_overhead & nvramcheck)""
      logger -p 6 -t "$ALIAS" "Debug - QoS ATM: "$(nvram get qos_atm & nvramcheck)""
      if [[ "$(nvram get qos_enable & nvramcheck)" == "1" ]] &>/dev/null && [[ "$QOSAPPLIED" != "0" ]] &>/dev/null;then
        { [[ "$(nvram get qos_obw & nvramcheck)" != "0" ]] &>/dev/null && [[ "$(nvram get qos_ibw & nvramcheck)" != "0" ]] &>/dev/null ;} && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Applied Manual QoS Bandwidth Settings"
        [[ "$(nvram get qos_obw & nvramcheck)" -ge "1024" ]] &>/dev/null && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Upload Bandwidth: $(($(nvram get qos_obw & nvramcheck)/1024))Mbps" \
        || { [[ "$(nvram get qos_obw & nvramcheck)" != "0" ]] &>/dev/null && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Upload Bandwidth: $(nvram get qos_obw & nvramcheck)Kbps" ;}
        [[ "$(nvram get qos_ibw & nvramcheck)" -ge "1024" ]] &>/dev/null && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Download Bandwidth: $(($(nvram get qos_ibw & nvramcheck)/1024))Mbps" \
        || { [[ "$(nvram get qos_ibw & nvramcheck)" != "0" ]] &>/dev/null && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Download Bandwidth: $(nvram get qos_ibw & nvramcheck)Kbps" ;}
        { [[ "$(nvram get qos_obw & nvramcheck)" == "0" ]] &>/dev/null && [[ "$(nvram get qos_ibw & nvramcheck)" == "0" ]] &>/dev/null ;} && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Automatic Settings"
      elif [[ "$(nvram get qos_enable & nvramcheck)" == "0" ]] &>/dev/null;then
        logger -p 6 -t "$ALIAS" "Debug - QoS is Disabled"
      fi
      break 1
    fi
  done
  sleep 1
  [[ "$SWITCHCOMPLETE" != "1" ]] &>/dev/null && SWITCHCOMPLETE=1
done
if [[ "$(nvram get "$ACTIVEWAN"_primary & nvramcheck)" == "1" ]] &>/dev/null && [[ "$(nvram get "$INACTIVEWAN"_primary & nvramcheck)" == "0" ]] &>/dev/null;then
  [[ "$SWITCHPRIMARY" == "1" ]] &>/dev/null && logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - Switched $ACTIVEWAN to Primary WAN"
else
  debuglog || return
fi

# Unset Variables
[[ -n "${SWITCHCOMPLETE+x}" ]] &>/dev/null && unset SWITCHCOMPLETE
[[ -n "${SWITCHPRIMARY+x}" ]] &>/dev/null && unset SWITCHPRIMARY
[[ -n "${SWITCHWANMODE+x}" ]] &>/dev/null && unset SWITCHWANMODE
[[ -n "${ACTIVEWAN+x}" ]] &>/dev/null && unset ACTIVEWAN
[[ -n "${INACTIVEWAN+x}" ]] &>/dev/null && unset INACTIVEWAN
[[ -n "${RESTARTSERVICESMODE+x}" ]] &>/dev/null && unset RESTARTSERVICESMODE
[[ -n "${QOSAPPLIED+x}" ]] &>/dev/null && unset QOSAPPLIED
[[ -n "${STOPQOS+x}" ]] &>/dev/null && unset STOPQOS

return
}

# Switch DNS
switchdns ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: switchdns"

# Check if AdGuard is Running or AdGuard Local is Enabled
if [[ -n "$(pidof AdGuardHome)" ]] &>/dev/null || { [[ -f "/opt/etc/AdGuardHome/.config" ]] &>/dev/null && [[ -n "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ]] &>/dev/null ;};then
  logger -p 4 -st "$ALIAS" "DNS Switch - DNS is being managed by AdGuard"
  return
fi

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE=2
  getwanparameters || return
fi

for WANPREFIX in ${WANPREFIXES};do
  # Getting WAN Parameters
  GETWANMODE=1
  getwanparameters || return

  # Switch DNS
  # Check DNS if Status is Connected or Primary WAN
  if { [[ "$STATUS" == "CONNECTED" ]] &>/dev/null && [[ "$WANSMODE" == "lb" ]] &>/dev/null ;} || { [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$PRIMARY" == "1" ]] &>/dev/null ;};then
    # Change Manual DNS Settings
    if [[ "$DNSENABLE" == "0" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Manual DNS Settings for ${WANPREFIX}"
      # Change Manual DNS1 Server
      if [[ -n "$DNS1" ]] &>/dev/null;then
        if [[ "$DNS1" != "$(nvram get wan_dns1_x & nvramcheck)" ]] &>/dev/null && [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Updating WAN DNS1 Server in NVRAM: "$DNS1""
          nvram set wan_dns1_x=$DNS1 \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Updated WAN DNS1 Server in NVRAM: "$DNS1"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to update WAN DNS1 Server in NVRAM: "$DNS1""
        fi
        if [[ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS1")" ]] &>/dev/null;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS1 Server: "$DNS1""
          sed -i '1i nameserver '$DNS1'' $DNSRESOLVFILE \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS1 Server: "$DNS1"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS1 Server: "$DNS1""
        fi
      fi
      # Change Manual DNS2 Server
      if [[ -n "$DNS2" ]] &>/dev/null;then
        if [[ "$DNS2" != "$(nvram get wan_dns2_x & nvramcheck)" ]] &>/dev/null && [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Updating WAN DNS2 Server in NVRAM: "$DNS2""
          nvram set wan_dns2_x=$DNS2 \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Updated WAN DNS2 Server in NVRAM: "$DNS2"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to update WAN DNS2 Server in NVRAM: "$DNS2""
        fi
        if [[ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS2")" ]] &>/dev/null;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS2 Server: "$DNS2""
          sed -i '2i nameserver '$DNS2'' $DNSRESOLVFILE \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS2 Server: "$DNS2"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS2 Server: "$DNS2""
        fi
      fi

    # Change Automatic ISP DNS Settings
    elif [[ "$DNSENABLE" == "1" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - Automatic DNS Settings from ${WANPREFIX} ISP: "$DNS""
      if [[ "$DNS" != "$DNS" ]] &>/dev/null && { [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$PRIMARY" == "1" ]] &>/dev/null ;};then
        logger -p 5 -st "$ALIAS" "DNS Switch - Updating WAN DNS Servers in NVRAM: "$DNS""
        nvram set wan_dns="$DNS" \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Updated WAN DNS Servers in NVRAM: "$DNS"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to update WAN DNS Servers in NVRAM: "$DNS""
      fi
      # Change Automatic DNS1 Server
      if [[ -n "$AUTODNS1" ]] &>/dev/null && [[ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS1")" ]] &>/dev/null;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS1 Server: "$AUTODNS1""
        sed -i '1i nameserver '$AUTODNS1'' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS1 Server: "$AUTODNS1"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS1 Server: "$AUTODNS1""

      fi
      # Change Automatic DNS2 Server
      if [[ -n "$AUTODNS2" ]] &>/dev/null && [[ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS2")" ]] &>/dev/null;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS2 Server: "$AUTODNS2""
        sed -i '2i nameserver '$AUTODNS2'' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS2 Server: "$AUTODNS2"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS2 Server: "$AUTODNS2""
      fi
    fi
  # Check DNS if Status is Disconnected or not Primary WAN
  elif { [[ "$STATUS" != "CONNECTED" ]] &>/dev/null && [[ "$WANSMODE" == "lb" ]] &>/dev/null ;} || { [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$PRIMARY" == "0" ]] &>/dev/null ;};then
    # Remove Manual DNS Settings
    if [[ "$DNSENABLE" == "0" ]] &>/dev/null;then
      # Remove Manual DNS1 Server
      if [[ -n "$DNS1" ]] &>/dev/null && [[ -n "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS1")" ]] &>/dev/null;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Removing ${WANPREFIX} DNS1 Server: "$DNS1""
        sed -i '/nameserver '$DNS1'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Removed ${WANPREFIX} DNS1 Server: "$DNS1"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS1 Server: "$DNS1""
      fi
      # Change Manual DNS2 Server
      if [[ -n "$DNS2" ]] &>/dev/null && [[ -n "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS2")" ]] &>/dev/null;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Removing ${WANPREFIX} DNS2 Server: "$DNS2""
        sed -i '/nameserver '$DNS2'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Removed ${WANPREFIX} DNS2 Server: "$DNS2"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS2 Server: "$DNS2""
      fi

    # Remove Automatic ISP DNS Settings
    elif [[ "$DNSENABLE" == "1" ]] &>/dev/null;then
      # Remove Automatic DNS1 Server
      if [[ -n "$AUTODNS1" ]] &>/dev/null && [[ -n "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS1")" ]] &>/dev/null;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Removing ${WANPREFIX} DNS1 Server: "$AUTODNS1""
        sed -i '/nameserver '$AUTODNS1'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Removed ${WANPREFIX} DNS1 Server: "$AUTODNS1"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS1 Server: "$AUTODNS1""
      fi
      # Remove Automatic DNS2 Server
      if [[ -n "$AUTODNS2" ]] &>/dev/null && [[ -n "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS2")" ]] &>/dev/null;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Removing ${WANPREFIX} DNS2 Server: "$AUTODNS2""
        sed -i '/nameserver '$AUTODNS2'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Removed ${WANPREFIX} DNS2 Server: "$AUTODNS2"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS2 Server: "$AUTODNS2""
      fi
    fi
  fi
done
return
}

# Restart Services
restartservices ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: restartservices"

# Get System Parameters
getsystemparameters || return

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE=2
  getwanparameters || return
fi

# Set Restart Services Mode to Default if not Specified
# Restart Mode 0: Do Not Restart Services
# Restart Mode 1: Default
# Restart Mode 2: OVPN Server Instances Only
# Restart Mode 3: QoS Engine Only
[[ -z "${RESTARTSERVICESMODE+x}" ]] &>/dev/null && RESTARTSERVICESMODE="1"
# Return if Restart Services Mode is 0
if [[ "$RESTARTSERVICESMODE" == "0" ]] &>/dev/null;then
  unset RESTARTSERVICESMODE
  return
fi
logger -p 6 -t "$ALIAS" "Debug - Restart Services Mode: "$RESTARTSERVICESMODE""

# Check for services that need to be restarted:
logger -p 6 -t "$ALIAS" "Debug - Checking which services need to be restarted"
SERVICES=""
SERVICESSTOP=""
SERVICERESTARTPIDS=""
# Check if dnsmasq is running
if [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null && [[ -n "$(pidof dnsmasq)" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Dnsmasq is running"
  SERVICE="dnsmasq"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if Firewall is Enabled
if [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null && [[ "$FIREWALLENABLE" == "1" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Firewall is enabled"
  SERVICE="firewall"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if LEDs are Disabled
if [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null && [[ "$LEDDISABLE" == "0" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - LEDs are enabled"
  SERVICE="leds"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if QoS is Enabled or Disabled
if { [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null || [[ "$RESTARTSERVICESMODE" == "3" ]] &>/dev/null ;} && [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - QoS is enabled"
  SERVICE="qos"
  SERVICES="${SERVICES} ${SERVICE}"
elif { [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null || [[ "$RESTARTSERVICESMODE" == "3" ]] &>/dev/null ;} && [[ "$WANSMODE" != "lb" ]] &>/dev/null && [[ "$QOSENABLE" == "0" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - QoS is disabled"
  SERVICESTOP="qos"
  SERVICESSTOP="${SERVICESSTOP} ${SERVICESTOP}"
fi
# Check if IPv6 is using a 6in4 tunnel
if [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null && [[ "$IPV6SERVICE" == "6in4" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - IPv6 6in4 is enabled"
  SERVICE="wan6"
  SERVICES="${SERVICES} ${SERVICE}"
fi

# Restart Services
if [[ -n "$SERVICES" ]] &>/dev/null;then
  for SERVICE in ${SERVICES};do
    logger -p 5 -st "$ALIAS" "Service Restart - Restarting "$SERVICE" service"
    service restart_"$SERVICE" &>/dev/null &
    SERVICERESTARTPID=$!
    SERVICERESTARTPIDS="${SERVICERESTARTPIDS} ${SERVICERESTARTPID}"
  done
fi

# Stop Services
# Restart Services
if [[ -n "$SERVICESSTOP" ]] &>/dev/null;then
  for SERVICESTOP in ${SERVICESSTOP};do
    logger -p 5 -st "$ALIAS" "Service Restart - Stopping "$SERVICESTOP" service"
    service stop_"$SERVICESTOP" &>/dev/null &
  done
fi

# Execute YazFi Check
logger -p 6 -t "$ALIAS" "Debug - Checking if YazFi is installed and scheduled in Cron Jobs"
if [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null && [[ -n "$(cru l | grep -w "YazFi")" ]] &>/dev/null && [[ -f "/jffs/scripts/YazFi" ]] &>/dev/null;then
  logger -p 5 -st "$ALIAS" "Service Restart - Executing YazFi Check"
  sh /jffs/scripts/YazFi check &>/dev/null \
  && logger -p 4 -st "$ALIAS" "Service Restart - Executed YazFi Check" \
  || logger -p 2 -st "$ALIAS" "Service Restart - ***Error*** Unable to execute YazFi Check"
fi

# Restart OpenVPN Server Instances
if [[ "$RESTARTSERVICESMODE" == "1" ]] &>/dev/null || [[ "$RESTARTSERVICESMODE" == "2" ]] &>/dev/null;then
OVPNSERVERS="
1
2
"

  logger -p 6 -t "$ALIAS" "Debug - Checking if OpenVPN Server instances exist and are enabled"
  for OVPNSERVER in ${OVPNSERVERS};do
    if [[ -n "$(echo $OVPNSERVERINSTANCES | grep -o "$OVPNSERVER")" ]] &>/dev/null;then
      # Restart OVPN Server Instance
      logger -p 5 -st "$ALIAS" "Service Restart - Restarting OpenVPN Server "$OVPNSERVER""
      service restart_vpnserver"$OVPNSERVER" &>/dev/null &
      SERVICERESTARTPID=$!
      SERVICERESTARTPIDS="${SERVICERESTARTPIDS} ${SERVICERESTARTPID}"
      sleep 1
    fi
  done

  # Wait for Services to Restart
  if [[ -n "${SERVICERESTARTPIDS+x}" ]] &>/dev/null;then
    logger -p 5 -st "$ALIAS" "Service Restart - Waiting on services to finish restarting"
    for SERVICERESTARTPID in ${SERVICERESTARTPIDS};do
      if [[ -z "$(ps | awk '{print $1}' | grep -o "${SERVICERESTARTPID}")" ]] &>/dev/null;then
        logger -p 6 -t "$ALIAS" "Debug - PID: ${SERVICERESTARTPID} completed"
        continue
      else
        logger -p 6 -t "$ALIAS" "Debug - Waiting on PID: ${SERVICERESTARTPID}"
        wait ${SERVICERESTARTPID}
        logger -p 6 -t "$ALIAS" "Debug - PID: ${SERVICERESTARTPID} completed"
      fi
    done
    logger -p 5 -st "$ALIAS" "Service Restart - Services have been restarted"
  fi
fi

# Unset Variables
[[ -n "${RESTARTSERVICESMODE+x}" ]] &>/dev/null && unset RESTARTSERVICESMODE
[[ -n "${SERVICES+x}" ]] &>/dev/null && unset SERVICES
[[ -n "${SERVICE+x}" ]] &>/dev/null && unset SERVICE
[[ -n "${SERVICESSTOP+x}" ]] &>/dev/null && unset SERVICESSTOP
[[ -n "${SERVICESTOP+x}" ]] &>/dev/null && unset SERVICESTOP
[[ -n "${SERVICERESTARTPID+x}" ]] &>/dev/null && unset SERVICERESTARTPID
[[ -n "${SERVICERESTARTPIDS+x}" ]] &>/dev/null && unset SERVICERESTARTPIDS

return
}

# Send Email
sendemail ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: sendemail"

# Check if Email Notifications are Enabled
if [[ -z "${SENDEMAIL+x}" ]] &>/dev/null || [[ -z "${SKIPEMAILSYSTEMUPTIME+x}" ]] &>/dev/null || [[ -z "${BOOTDELAYTIMER+x}" ]] &>/dev/null;then
  setvariables || return
fi

# Send email notification if Alert Preferences are configured if System Uptime is more than Boot Delay Timer + Variable SKIPEMAILSYSEMUPTIME seconds.
if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Email suppressed because System Uptime is less than "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))" seconds"
  return
elif [[ "$SENDEMAIL" == "0" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Email Notifications are disabled"
  return
fi

# Get System Parameters
getsystemparameters || return

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE="2"
  getwanparameters || return
fi

# Getting Active WAN Parameters
GETWANMODE="3"
getwanparameters || return

# Check email notification state
EMAILSTATUS="$WAN0STATUS'_'$WAN1STATUS"
if [[ -z "${zEMAILSTATUS+x}" ]] &>/dev/null;then
  zEMAILSTATUS="$EMAILSTATUS"
elif [[ "$EMAILSTATUS" == "$zEMAILSTATUS" ]] &>/dev/null;then
  return
fi

# Set Certificate Path
if [[ -z "${CAFILE+x}" ]] &>/dev/null && [[ -f "/rom/etc/ssl/cert.pem" ]] &>/dev/null;then
  CAFILE="/rom/etc/ssl/cert.pem"
elif [[ -z "${CAFILE+x}" ]] &>/dev/null && [[ ! -f "/rom/etc/ssl/cert.pem" ]] &>/dev/null;then
  logger -p 2 -st "$ALIAS" "Email Notification - Email notification failed to send because a Certificate was not found"
  return
fi

# Email Variables
[[ -z "${AIPROTECTION_EMAILCONFIG+x}" ]] &>/dev/null && AIPROTECTION_EMAILCONFIG="/etc/email/email.conf"
[[ -z "${AMTM_EMAILCONFIG+x}" ]] &>/dev/null && AMTM_EMAILCONFIG="/jffs/addons/amtm/mail/email.conf"
[[ -z "${AMTM_EMAIL_DIR+x}" ]] &>/dev/null && AMTM_EMAIL_DIR="/jffs/addons/amtm/mail"
[[ -z "${TMPEMAILFILE+x}" ]] &>/dev/null && TMPEMAILFILE=/tmp/wan-failover-mail

# Read AIProtection Email Configuration
if [[ -f "$AIPROTECTION_EMAILCONFIG" ]] &>/dev/null;then
  SMTP_SERVER="$(awk -F "'" '/SMTP_SERVER/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
  SMTP_PORT="$(awk -F "'" '/SMTP_PORT/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
  MY_NAME="$(awk -F "'" '/MY_NAME/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
  MY_EMAIL="$(awk -F "'" '/MY_EMAIL/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
  SMTP_AUTH_USER="$(awk -F "'" '/SMTP_AUTH_USER/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
  SMTP_AUTH_PASS="$(awk -F "'" '/SMTP_AUTH_PASS/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
fi

# Read AMTM Email Configuration
if [[ -f "$AMTM_EMAILCONFIG" ]] &>/dev/null;then
  . "$AMTM_EMAILCONFIG"
fi

# Send email notification if AIProtection or AMTM Email Notifications are Configured
if [[ -f "$AIPROTECTION_EMAILCONFIG" ]] &>/dev/null || [[ -f "$AMTM_EMAILCONFIG" ]] &>/dev/null;then

  # Check for old mail temp file and delete it or create file and set permissions
  logger -p 6 -t "$ALIAS" "Debug - Checking if "$TMPEMAILFILE" exists"
  if [[ -f "$TMPEMAILFILE" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - Deleting "$TMPEMAILFILE""
    rm "$TMPEMAILFILE"
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  elif [[ ! -f "$TMPEMAILFILE" ]] &>/dev/null;then
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  fi
  
  # Determine Subject Name
  logger -p 6 -t "$ALIAS" "Debug - Selecting Subject Name"
  if [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
    echo "Subject: WAN Load Balance Failover Notification" >"$TMPEMAILFILE"
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
    echo "Subject: WAN Failover Notification" >"$TMPEMAILFILE"
  fi

  # Determine From Name
  logger -p 6 -t "$ALIAS" "Debug - Selecting From Name"
  if [[ -f "$AMTM_EMAILCONFIG" ]] &>/dev/null;then
    echo "From: \"$TO_NAME\"<$FROM_ADDRESS>" >>"$TMPEMAILFILE"
  elif [[ -f "$AIPROTECTION_EMAILCONFIG" ]] &>/dev/null;then
    echo "From: \"$MY_NAME\"<$MY_EMAIL>" >>"$TMPEMAILFILE"
  fi
  echo "Date: $(date -R)" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine Email Header
  logger -p 6 -t "$ALIAS" "Debug - Selecting Email Header"
  if [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
    echo "***WAN Load Balance Failover Notification***" >>"$TMPEMAILFILE"
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
    echo "***WAN Failover Notification***" >>"$TMPEMAILFILE"
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"

  # Determine Hostname
  logger -p 6 -t "$ALIAS" "Debug - Selecting Hostname"
  if [[ "$DDNSENABLE" == "1" ]] &>/dev/null && [[ -n "$DDNSHOSTNAME" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - DDNS Hostname: $DDNSHOSTNAME"
    echo "Hostname: $DDNSHOSTNAME" >>"$TMPEMAILFILE"
  elif [[ -n "$LANHOSTNAME" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - LAN Hostname: $LANHOSTNAME"
    echo "Hostname: $LANHOSTNAME" >>"$TMPEMAILFILE"
  fi
  echo "Event Time: $(date | awk '{print $2,$3,$4}')" >>"$TMPEMAILFILE"

  # Determine Parameters to send based on Dual WAN Mode
  logger -p 6 -t "$ALIAS" "Debug - Selecting Parameters based on Dual WAN Mode: "$WANSMODE""
  if [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
    # Capture WAN Status and WAN IP Addresses for Load Balance Mode
    logger -p 6 -t "$ALIAS" "Debug - WAN0 IP Address: $WAN0IPADDR"
    echo "WAN0 IPv4 Address: $WAN0IPADDR" >>"$TMPEMAILFILE"
    [[ -n "$WAN0STATUS" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: $WAN0STATUS" && echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    logger -p 6 -t "$ALIAS" "Debug - WAN1 IP Address: $WAN1IPADDR"
    echo "WAN1 IPv4 Address: $WAN1IPADDR" >>"$TMPEMAILFILE"
    [[ -n "$WAN1STATUS" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: $WAN1STATUS" && echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"
    [[ -n "${IPV6IPADDR+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - IPv6 IP Address: $IPV6IPADDR"
    [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null && [[ -n "${IPV6IPADDR+x}" ]] &>/dev/null && echo "WAN IPv6 Address: "$IPV6IPADDR"" >>"$TMPEMAILFILE"
  elif [[ "$WANSMODE" != "lb" ]] &>/dev/null;then
    # Capture WAN Status
    [[ -n "$WAN0STATUS" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: $WAN0STATUS" && echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    [[ -n "$WAN1STATUS" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: $WAN1STATUS" && echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"

    # Determine Active ISP
    logger -p 6 -t "$ALIAS" "Debug - Connecting to ipinfo.io for Active ISP"
    ACTIVEISP="$(/usr/sbin/curl --connect-timeout $EMAILTIMEOUT --max-time $EMAILTIMEOUT ipinfo.io 2>/dev/null | grep -w '"org":' | awk -F " " '{$1=$2=""; print $0}' | cut -c 3- | cut -f 1 -d '"')"
    [[ -n "${ACTIVEISP+x}" ]] &>/dev/null && echo "Active ISP: "$ACTIVEISP"" >>"$TMPEMAILFILE" || echo "Active ISP: Unavailable" >>"$TMPEMAILFILE"

    # Determine Primary WAN for WAN IP Address, Gateway IP Address and Interface
    for WANPREFIX in ${WANPREFIXES};do
      # Getting WAN Parameters
      GETWANMODE=1
      getwanparameters || return

      [[ "$PRIMARY" != "1" ]] &>/dev/null && continue
      logger -p 6 -t "$ALIAS" "Debug - Primary WAN: "$PRIMARY""
      echo "Primary WAN: ${WANPREFIX}" >>"$TMPEMAILFILE"
      logger -p 6 -t "$ALIAS" "Debug - WAN IPv4 Address: "$IPADDR""
      echo "WAN IPv4 Address: $IPADDR" >>"$TMPEMAILFILE"
      logger -p 6 -t "$ALIAS" "Debug - WAN Gateway IP Address: "$GATEWAY""
      echo "WAN Gateway IP Address: $GATEWAY" >>"$TMPEMAILFILE"
      logger -p 6 -t "$ALIAS" "Debug - WAN Interface: "$GWIFNAME""
      echo "WAN Interface: $GWIFNAME" >>"$TMPEMAILFILE"
      [[ "$PRIMARY" == "1" ]] &>/dev/null && break
    done
    if [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null;then
      [[ -n "${IPV6IPADDR+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - IPv6 IP Address: "$IPV6IPADDR""
      [[ -n "${IPV6IPADDR+x}" ]] &>/dev/null && echo "WAN IPv6 Address: "$IPV6IPADDR"" >>"$TMPEMAILFILE"
    fi

    # Check if AdGuard is Running or if AdGuard Local is Enabled or Capture WAN DNS Servers
    logger -p 6 -t "$ALIAS" "Debug - Checking if AdGuardHome is running"
    if [[ -n "$(pidof AdGuardHome)" ]] &>/dev/null || { [[ -f "/opt/etc/AdGuardHome/.config" ]] &>/dev/null && [[ -n "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ]] &>/dev/null ;};then
      echo "DNS: Managed by AdGuardHome" >>"$TMPEMAILFILE"
    else
      for WANPREFIX in ${WANPREFIXES};do
        # Getting WAN Parameters
        GETWANMODE=1
        getwanparameters || return

        [[ "$PRIMARY" != "1" ]] &>/dev/null && continue
        logger -p 6 -t "$ALIAS" "Debug - Checking for Automatic or Manual DNS Settings. WAN DNS Enable: $DNSENABLE"
        if [[ "$DNSENABLE" == "0" ]] &>/dev/null;then
          logger -p 6 -t "$ALIAS" "Debug - Manual DNS Server 1: "$DNS1""
          [[ -n "$DNS1" ]] &>/dev/null && echo "DNS Server 1: $DNS1" >>"$TMPEMAILFILE"
          logger -p 6 -t "$ALIAS" "Debug - Manual DNS Server 2: "$DNS2""
          [[ -n "$DNS2" ]] &>/dev/null && echo "DNS Server 2: $DNS2" >>"$TMPEMAILFILE"
        elif [[ "$DNSENABLE" == "1" ]] &>/dev/null;then
          logger -p 6 -t "$ALIAS" "Debug - Automatic DNS Servers: $DNS"
          [[ -n "$AUTODNS1" ]] &>/dev/null && echo "DNS Server 1: $AUTODNS1" >>"$TMPEMAILFILE"
          [[ -n "$AUTODNS2" ]] &>/dev/null && echo "DNS Server 2: $AUTODNS2" >>"$TMPEMAILFILE"
        fi
        [[ "$PRIMARY" == "1" ]] &>/dev/null && break
      done
    fi
    logger -p 6 -t "$ALIAS" "Debug - QoS Enabled Status: $QOSENABLE"
    if [[ "$QOSENABLE" == "1" ]] &>/dev/null;then
      echo "QoS Status: Enabled" >>"$TMPEMAILFILE"
      if [[ -n "$QOS_OBW" ]] &>/dev/null && [[ -n "$QOS_IBW" ]] &>/dev/null;then
        logger -p 6 -t "$ALIAS" "Debug - QoS Outbound Bandwidth: $QOS_OBW"
        logger -p 6 -t "$ALIAS" "Debug - QoS Inbound Bandwidth: $QOS_IBW"
        if [[ "$QOS_OBW" == "0" ]] &>/dev/null && [[ "$QOS_IBW" == "0" ]] &>/dev/null;then
          echo "QoS Mode: Automatic Settings" >>"$TMPEMAILFILE"
        else
          echo "QoS Mode: Manual Settings" >>"$TMPEMAILFILE"
          [[ "$QOS_IBW" -gt "1024" ]] &>/dev/null && echo "QoS Download Bandwidth: $(($QOS_IBW/1024))Mbps" >>"$TMPEMAILFILE" || echo "QoS Download Bandwidth: "$QOS_IBW"Kbps" >>"$TMPEMAILFILE"
          [[ "$QOS_OBW" -gt "1024" ]] &>/dev/null && echo "QoS Upload Bandwidth: $(($QOS_OBW/1024))Mbps" >>"$TMPEMAILFILE" || echo "QoS Upload Bandwidth: "$QOS_OBW"Kbps" >>"$TMPEMAILFILE"
          logger -p 6 -t "$ALIAS" "Debug - QoS WAN Packet Overhead: $QOSOVERHEAD"
          echo "QoS WAN Packet Overhead: $QOSOVERHEAD" >>"$TMPEMAILFILE"
          if [[ "$QOSATM" != "0" ]] &>/dev/null;then
            echo "QoS ATM: Enabled" >>"$TMPEMAILFILE"
          fi
        fi
      fi
    elif [[ "$QOSENABLE" == "0" ]] &>/dev/null;then
      echo "QoS Status: Disabled" >>"$TMPEMAILFILE"
    fi
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine whether to use AMTM or AIProtection Email Configuration
  logger -p 6 -t "$ALIAS" "Debug - Selecting AMTM or AIProtection for Email Notification"
  e=0
  if [[ -f "$AMTM_EMAILCONFIG" ]] &>/dev/null && [[ "$e" == "0" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - AMTM Email Configuration Detected"
    if [[ -z "$FROM_ADDRESS" ]] &>/dev/null || [[ -z "$TO_NAME" ]] &>/dev/null || [[ -z "$TO_ADDRESS" ]] &>/dev/null || [[ -z "$USERNAME" ]] &>/dev/null || [[ ! -f "$AMTM_EMAIL_DIR/emailpw.enc" ]] &>/dev/null || [[ -z "$SMTP" ]] &>/dev/null || [[ -z "$PORT" ]] &>/dev/null || [[ -z "$PROTOCOL" ]] &>/dev/null;then
      logger -p 2 -st "$ALIAS" "Email Notification - AMTM Email Configuration Incomplete"
    else
	$(/usr/sbin/curl --connect-timeout $EMAILTIMEOUT --max-time $EMAILTIMEOUT --url $PROTOCOL://$SMTP:$PORT \
		--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
		--upload-file "$TMPEMAILFILE" \
		--ssl-reqd \
		--user "$USERNAME:$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$AMTM_EMAIL_DIR/emailpw.enc" -pass pass:ditbabot,isoi)" $SSL_FLAG 2>/dev/null) \
		&& $(rm -f "$TMPEMAILFILE" && logger -p 4 -st "$ALIAS" "Email Notification - Email Notification via amtm Sent") && e=$(($e+1)) \
                || $(rm -f "$TMPEMAILFILE" && logger -p 2 -st "$ALIAS" "Email Notification - Email Notification via amtm Failed")
    fi
  fi
  if [[ -f "$AIPROTECTION_EMAILCONFIG" ]] &>/dev/null && [[ "$e" == "0" ]] &>/dev/null;then
    logger -p 6 -t "$ALIAS" "Debug - AIProtection Alerts Email Configuration Detected"
    if [[ -n "$SMTP_SERVER" ]] &>/dev/null && [[ -n "$SMTP_PORT" ]] &>/dev/null && [[ -n "$MY_NAME" ]] &>/dev/null && [[ -n "$MY_EMAIL" ]] &>/dev/null && [[ -n "$SMTP_AUTH_USER" ]] &>/dev/null && [[ -n "$SMTP_AUTH_PASS" ]] &>/dev/null;then
      $(cat "$TMPEMAILFILE" | sendmail -w $EMAILTIMEOUT -H "exec openssl s_client -quiet -CAfile $CAFILE -connect $SMTP_SERVER:$SMTP_PORT -tls1_3 -starttls smtp" -f"$MY_EMAIL" -au"$SMTP_AUTH_USER" -ap"$SMTP_AUTH_PASS" "$MY_EMAIL") \
      && $(rm -f "$TMPEMAILFILE" && logger -p 4 -st "$ALIAS" "Email Notification - Email Notification via AIProtection Alerts Sent") && e=$(($e+1)) \
      || $(rm -f "$TMPEMAILFILE" && logger -p 2 -st "$ALIAS" "Email Notification - Email Notification via AIProtection Alerts Failed")
    else
      logger -p 2 -st "$ALIAS" "Email Notification - AIProtection Alerts Email Configuration Incomplete"
    fi
  fi
  if [[ "$e" != "0" ]] &>/dev/null;then
    zEMAILSTATUS="$EMAILSTATUS"
  fi
  unset e
elif [[ ! -f "$AIPROTECTION_EMAILCONFIG" ]] &>/dev/null || [[ ! -f "$AMTM_EMAILCONFIG" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Email Notifications are not configured"
fi
return
}

# Status Console
statusconsole ()
{
# Check for configuration and load configuration
if [[ -f "$CONFIGFILE" ]] &>/dev/null;then
  setvariables || return
else
  printf "${RED}***WAN Failover is not Installed***${NOCOLOR}\n"
  printf "\n  (r)  return      Return to Main Menu"
  printf "\nMake a selection: "

  read -r input
  case $input in
    'e'|'E'|'exit'|'menu'|'r'|'R'|'return'|'Return' )
    clear
    menu
    break
    ;;
    * ) continue;;
  esac
fi

# Get Global WAN Parameters
if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
  GETWANMODE="2"
  getwanparameters || return
fi

# Check for Update
# Get Current Epoch Time
lastupdatecheck="$(date +%s)"
passiveupdate="1"
update && unset passiveupdate || return

while true &>/dev/null;do
  # Get System Parameters
  getsystemparameters || return

  # Get Active Variables
  # Determine binary to use for detecting PIDs
  if [[ -f "/usr/bin/pstree" ]] &>/dev/null;then
    [[ -n "$(pstree -s "$0" | grep -v "grep" | grep -w "run\|manual" | grep -o '[0-9]*' &)" ]] &>/dev/null && RUNNING="1" || RUNNING="0"
  else
    [[ -n "$(ps | grep -v "grep" | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}' &)" ]] &>/dev/null && RUNNING="1" || RUNNING="0"
  fi

  # Get Current Epoch Time
  currenttime="$(date +%s)"

  # Check for Update
  # Get Current Epoch Time
  [[ -z "${lastupdatecheck+x}" ]] &>/dev/null && lastupdatecheck="$(date +%s)"
  if [[ "$(($currenttime))" -ge "$(($lastupdatecheck+14400))" ]] &>/dev/null;then
    lastupdatecheck="$(date +%s)"
    passiveupdate="1"
    update && unset passiveupdate || return
  fi

  # Set Display Version Color and Notification
  if [[ "$updateneeded" == "0" ]] &>/dev/null;then
    DISPLAYVERSION="${LIGHTGRAY}$VERSION${NOCOLOR}"
  elif [[ "$updateneeded" == "1" ]] &>/dev/null;then
    DISPLAYVERSION="${LIGHTGRAY}$VERSION${NOCOLOR}  ${LIGHTYELLOW}(Update Available: "$REMOTEVERSION")${NOCOLOR}"
  elif [[ "$updateneeded" == "2" ]] &>/dev/null;then
    DISPLAYVERSION="${LIGHTGRAY}$VERSION${NOCOLOR}  ${RED}(Checksum Failure: Check For Updates to Repair)${NOCOLOR}"
  elif [[ "$updateneeded" == "3" ]] &>/dev/null;then
    DISPLAYVERSION="${LIGHTGRAY}$VERSION${NOCOLOR}  ${LIGHTCYAN}(Developer Version)${NOCOLOR}"
  fi

  # Get Active WAN Parameters
  GETWANMODE="3"
  getwanparameters || return

  # Set WAN0 Status and Color
  if [[ "$WAN0STATE" == "0" ]] &>/dev/null;then
    WAN0DISPLAYSTATUS="${LIGHTMAGENTA}Initializing${NOCOLOR}"
  elif [[ "$WAN0STATE" == "1" ]] &>/dev/null;then
    WAN0DISPLAYSTATUS="${LIGHTCYAN}Connecting${NOCOLOR}"
  elif [[ "$WAN0STATE" == "2" ]] &>/dev/null;then
    WAN0DISPLAYSTATUS="${GREEN}Connected${NOCOLOR}"
  elif [[ "$WAN0STATE" == "3" ]] &>/dev/null;then
    WAN0DISPLAYSTATUS="${LIGHTRED}Disconnected${NOCOLOR}"
  elif [[ "$WAN0STATE" == "4" ]] &>/dev/null;then
    WAN0DISPLAYSTATUS="${LIGHTRED}Stopped${NOCOLOR}"
  elif [[ "$WAN0STATE" == "5" ]] &>/dev/null;then
    WAN0DISPLAYSTATUS="${LIGHTGRAY}Disabled${NOCOLOR}"
  elif [[ "$WAN0STATE" == "6" ]] &>/dev/null;then
    WAN0DISPLAYSTATUS="${LIGHTYELLOW}Stopping${NOCOLOR}"
  fi

  # Set WAN1 Status and Color
  if [[ "$WAN1STATE" == "0" ]] &>/dev/null;then
    WAN1DISPLAYSTATUS="${LIGHTMAGENTA}Initializing${NOCOLOR}"
  elif [[ "$WAN1STATE" == "1" ]] &>/dev/null;then
    WAN1DISPLAYSTATUS="${LIGHTCYAN}Connecting${NOCOLOR}"
  elif [[ "$WAN1STATE" == "2" ]] &>/dev/null;then
    WAN1DISPLAYSTATUS="${GREEN}Connected${NOCOLOR}"
  elif [[ "$WAN1STATE" == "3" ]] &>/dev/null;then
    WAN1DISPLAYSTATUS="${LIGHTRED}Disconnected${NOCOLOR}"
  elif [[ "$WAN1STATE" == "4" ]] &>/dev/null;then
    WAN1DISPLAYSTATUS="${LIGHTRED}Stopped${NOCOLOR}"
  elif [[ "$WAN1STATE" == "5" ]] &>/dev/null;then
    WAN1DISPLAYSTATUS="${LIGHTGRAY}Disabled${NOCOLOR}"
  elif [[ "$WAN1STATE" == "6" ]] &>/dev/null;then
    WAN1DISPLAYSTATUS="${LIGHTYELLOW}Stopping${NOCOLOR}"
  fi

  # Determine Host Name
  if [[ "$DDNSENABLE" == "1" ]] &>/dev/null;then
    DISPLAYHOSTNAME="$DDNSHOSTNAME"
  else
    DISPLAYHOSTNAME="$LANHOSTNAME"
  fi

  # Check Packet Loss
  if [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && [[ -f "$WAN0PACKETLOSSFILE" ]] &>/dev/null;then
    WAN0PACKETLOSS="$(sed -n 1p "$WAN0PACKETLOSSFILE")"
    WAN0PINGTIME="$(sed -n 2p "$WAN0PACKETLOSSFILE")"
    WAN0LASTUPDATE="$(date -r "$WAN0PACKETLOSSFILE")"
    # Get Last WAN0 Update Epoch Time
    wan0lastupdatetime="$(date -r "$WAN0PACKETLOSSFILE" +%s)"
    # Determine Packet Loss Color
    if [[ "$WAN0PACKETLOSS" == "0%" ]] &>/dev/null;then
      WAN0PACKETLOSSCOLOR="${CYAN}"
    elif [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
      WAN0PACKETLOSSCOLOR="${RED}"
    else
      WAN0PACKETLOSSCOLOR="${LIGHTYELLOW}"
    fi
    # Determine Ping Time Color
    if [[ "$WAN0PINGTIME" -le "$PINGTIMEMIN" ]] &>/dev/null;then
      WAN0PINGTIMECOLOR="${CYAN}"
    elif [[ "$WAN0PINGTIME" -gt "$PINGTIMEMIN" ]] &>/dev/null && [[ "$WAN0PINGTIME" -le "$PINGTIMEMAX" ]] &>/dev/null;then
      WAN0PINGTIMECOLOR="${LIGHTYELLOW}"
    elif [[ "$WAN0PINGTIME" -gt "$PINGTIMEMAX" ]] &>/dev/null;then
      WAN0PINGTIMECOLOR="${RED}"
    else
      WAN0PINGTIMECOLOR="${NOCOLOR}"   
    fi
    # Append Ping Time If Necessary
    if [[ -n "${WAN0PACKETLOSS+x}" ]] &>/dev/null && [[ "$WAN0PACKETLOSS" != "100%" ]] &>/dev/null && [[ -n "$(sed -n 2p "$WAN0PACKETLOSSFILE")" ]] &>/dev/null;then
      WAN0PINGTIME="$(sed -n 2p "$WAN0PACKETLOSSFILE")ms"
    else
      WAN0PINGTIME="$(sed -n 2p "$WAN0PACKETLOSSFILE")"
    fi
  else
    WAN0PACKETLOSS="N/A"
    WAN0PINGTIME="N/A"
    WAN0LASTUPDATE="N/A"
    wan0lastupdatetime=""
    WAN0PACKETLOSSCOLOR="${NOCOLOR}"
    WAN0PINGTIMECOLOR="${NOCOLOR}" 
  fi
  if [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && [[ -f "$WAN1PACKETLOSSFILE" ]] &>/dev/null;then
    WAN1PACKETLOSS="$(sed -n 1p "$WAN1PACKETLOSSFILE")"
    WAN1PINGTIME="$(sed -n 2p "$WAN1PACKETLOSSFILE")"
    WAN1LASTUPDATE="$(date -r "$WAN1PACKETLOSSFILE")"
    # Get Last WAN1 Update Epoch Time
    wan1lastupdatetime="$(date -r "$WAN1PACKETLOSSFILE" +%s)"
    # Determine Packet Loss Color
    if [[ "$WAN1PACKETLOSS" == "0%" ]] &>/dev/null;then
      WAN1PACKETLOSSCOLOR="${CYAN}"
    elif [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
      WAN1PACKETLOSSCOLOR="${RED}"
    else
      WAN1PACKETLOSSCOLOR="${LIGHTYELLOW}"
    fi
    # Determine Ping Time Color
    if [[ "$WAN1PINGTIME" -le "$PINGTIMEMIN" ]] &>/dev/null;then
      WAN1PINGTIMECOLOR="${CYAN}"
    elif [[ "$WAN1PINGTIME" -gt "$PINGTIMEMIN" ]] &>/dev/null && [[ "$WAN1PINGTIME" -le "$PINGTIMEMAX" ]] &>/dev/null;then
      WAN1PINGTIMECOLOR="${LIGHTYELLOW}"
    elif [[ "$WAN1PINGTIME" -gt "$PINGTIMEMAX" ]] &>/dev/null;then
      WAN1PINGTIMECOLOR="${RED}"
    else
      WAN1PINGTIMECOLOR="${NOCOLOR}"   
    fi
    # Append Ping Time If Necessary
    if [[ -n "${WAN1PACKETLOSS+x}" ]] &>/dev/null && [[ "$WAN1PACKETLOSS" != "100%" ]] &>/dev/null && [[ -n "$(sed -n 2p "$WAN1PACKETLOSSFILE")" ]] &>/dev/null;then
      WAN1PINGTIME="$(sed -n 2p "$WAN1PACKETLOSSFILE")ms"
    else
      WAN1PINGTIME="$(sed -n 2p "$WAN1PACKETLOSSFILE")"
    fi
  else
    WAN1PACKETLOSS="N/A"
    WAN1PINGTIME="N/A"
    WAN1LASTUPDATE="N/A"
    wan1lastupdatetime=""
    WAN1PACKETLOSSCOLOR="${NOCOLOR}"
    WAN1PINGTIMECOLOR="${NOCOLOR}" 
  fi

  # Update Status
  if [[ "$RUNNING" == "1" ]] &>/dev/null;then
    if [[ -f "$PIDFILE" ]] &>/dev/null && { [[ ! -f "$WAN0PACKETLOSSFILE" ]] &>/dev/null || [[ ! -f "$WAN1PACKETLOSSFILE" ]] &>/dev/null ;};then
      [[ -z "${bootdelay+x}" ]] &>/dev/null && bootdelay=""
      if [[ "$bootdelay" != "0" ]] &>/dev/null;then
        [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] &>/dev/null && bootdelay="$(($BOOTDELAYTIMER-$(awk -F "." '{print $1}' "/proc/uptime")))"
        [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -gt "$BOOTDELAYTIMER" ]] &>/dev/null && bootdelay="0"
      fi
      [[ "$(($(date -r "$PIDFILE" +%s)+$bootdelay+((($PINGCOUNT*$PINGTIMEOUT)*$RECURSIVEPINGCHECK)*2)+30))" -ge "$(($(date +%s)))" ]] &>/dev/null && RUNNING="4"
    elif [[ "$WAN0ENABLE" == "0" ]] &>/dev/null || [[ "$WAN1ENABLE" == "0" ]] &>/dev/null;then
      RUNNING="3"
    elif [[ -n "${currenttime+x}" ]] &>/dev/null && [[ -n "${wan0lastupdatetime+x}" ]] &>/dev/null && [[ -n "${wan1lastupdatetime+x}" ]] &>/dev/null;then
      [[ -n "${wan0lastupdatetime+x}" ]] &>/dev/null && wan0checktime="$(echo $(($wan0lastupdatetime+(($PINGCOUNT*$PINGTIMEOUT)*$RECURSIVEPINGCHECK)+($STATUSCHECK*3))))"
      [[ -n "${wan1lastupdatetime+x}" ]] &>/dev/null && wan1checktime="$(echo $(($wan1lastupdatetime+(($PINGCOUNT*$PINGTIMEOUT)*$RECURSIVEPINGCHECK)+($STATUSCHECK*3))))"
      [[ "$WAN0ENABLE" == "1" ]] &>/dev/null && { [[ "$currenttime" -gt "$wan0checktime" ]] &>/dev/null && RUNNING="2" ;}
      [[ "$WAN1ENABLE" == "1" ]] &>/dev/null && { [[ "$currenttime" -gt "$wan1checktime" ]] &>/dev/null && RUNNING="2" ;}
    else
      RUNNING="2"
    fi
  fi

  # Set Status Color and Message
  if [[ "$RUNNING" == "0" ]] &>/dev/null;then
    DISPLAYSTATUS="${LIGHTRED}Not Running${NOCOLOR}"
  elif [[ "$RUNNING" == "1" ]] &>/dev/null;then
    DISPLAYSTATUS="${LIGHTCYAN}Failover Monitoring${NOCOLOR}"
  elif [[ "$RUNNING" == "2" ]] &>/dev/null;then
    DISPLAYSTATUS="${LIGHTYELLOW}Unresponsive${NOCOLOR}"
  elif [[ "$RUNNING" == "3" ]] &>/dev/null;then
    DISPLAYSTATUS="${LIGHTRED}Failover Disabled${NOCOLOR}"
  elif [[ "$RUNNING" == "4" ]] &>/dev/null;then
    DISPLAYSTATUS="${LIGHTBLUE}Initializing${NOCOLOR}"
  fi

  # Buffer Status Output
  output="$(
  clear
  printf "${BOLD}${UNDERLINE}WAN Failover Status:${NOCOLOR}\n"
  echo -e "${BOLD}Model: ${NOCOLOR}${LIGHTGRAY}"$PRODUCTID"${NOCOLOR}"
  echo -e "${BOLD}Host Name: ${NOCOLOR}${LIGHTGRAY}"$DISPLAYHOSTNAME"${NOCOLOR}"
  echo -e "${BOLD}Firmware Version: ${NOCOLOR}${LIGHTGRAY}"$BUILDNO"${NOCOLOR}"
  [[ "$JFFSSCRIPTS" == "1" ]] &>/dev/null && echo -e "${BOLD}JFFS Scripts:${NOCOLOR} ${GREEN}Enabled${NOCOLOR}" || echo -e "${BOLD}JFFS Scripts:${NOCOLOR} ${RED}Disabled${NOCOLOR}"
  [[ "$WANSDUALWANENABLE" == "1" ]] &>/dev/null && echo -e "${BOLD}Dual WAN:${NOCOLOR} ${GREEN}Enabled${NOCOLOR}" || echo -e "${BOLD}Dual WAN:${NOCOLOR} ${RED}Disabled${NOCOLOR}"
  if [[ "$WANSMODE" == "lb" ]] &>/dev/null;then
    echo -e "${BOLD}Mode: ${NOCOLOR}${LIGHTGRAY}Load Balance Mode${NOCOLOR}"
    echo -e "${BOLD}Load Balance Ratio: ${NOCOLOR}${LIGHTGRAY}"$WANSLBRATIO"${NOCOLOR}"
  else
    echo -e "${BOLD}Mode: ${NOCOLOR}${LIGHTGRAY}Failover Mode${NOCOLOR}"
  fi
  echo -e "${BOLD}WAN Failover Version: ${NOCOLOR}"$DISPLAYVERSION""
  [[ "$DEVMODE" == "1" ]] &>/dev/null && echo -e "${BOLD}Checksum: ${NOCOLOR}${LIGHTGRAY}"$CHECKSUM"${NOCOLOR}"
  echo -e "${BOLD}Status: ${NOCOLOR}"$DISPLAYSTATUS""
  echo -e "${BOLD}Last Update: ${NOCOLOR}${NOCOLOR}$(date)${NOCOLOR}"
  printf "\n"
  echo -e "${BOLD}${UNDERLINE}WAN0:${NOCOLOR}"
  echo -e "${BOLD}Status: ${NOCOLOR}"$WAN0DISPLAYSTATUS""
  [[ "$WANSMODE" != "lb" ]] &>/dev/null && { [[ "$WAN0PRIMARY" == "1" ]] &>/dev/null && echo -e "${BOLD}Primary: ${NOCOLOR}${LIGHTCYAN}Yes${NOCOLOR}" || echo -e "${BOLD}Primary: ${LIGHTRED}No${NOCOLOR}" ;}
  echo -e "${BOLD}IP Address: ${NOCOLOR}${LIGHTGRAY}"$WAN0IPADDR"${NOCOLOR}"
  echo -e "${BOLD}Gateway: ${NOCOLOR}${LIGHTGRAY}"$WAN0GATEWAY"${NOCOLOR}"
  echo -e "${BOLD}Interface: ${NOCOLOR}${LIGHTGRAY}"$WAN0GWIFNAME"${NOCOLOR}"
  echo -e "${BOLD}MAC Address: ${NOCOLOR}${LIGHTGRAY}"$WAN0GWMAC"${NOCOLOR}"
  echo -e "${BOLD}WAN0 Target: ${NOCOLOR}${LIGHTGRAY}"$WAN0TARGET"${NOCOLOR}"
  [[ -n "$WAN0PACKETLOSS" ]] &>/dev/null && echo -e "${BOLD}Packet Loss: ${NOCOLOR}${WAN0PACKETLOSSCOLOR}"$WAN0PACKETLOSS"${NOCOLOR}" || echo -e "${BOLD}Packet Loss: ${NOCOLOR}"
  [[ -n "$WAN0PINGTIME" ]] &>/dev/null && echo -e "${BOLD}Ping Time: ${NOCOLOR}${WAN0PINGTIMECOLOR}"$WAN0PINGTIME"${NOCOLOR}" || echo -e "${BOLD}Ping Time: ${NOCOLOR}"
  [[ -n "$WAN0LASTUPDATE" ]] &>/dev/null && echo -e "${BOLD}Last Update: ${NOCOLOR}${NOCOLOR}"$WAN0LASTUPDATE"${NOCOLOR}" || echo -e "${BOLD}Last Update: ${NOCOLOR}"

  printf "\n"
  echo -e "${BOLD}${UNDERLINE}WAN1:${NOCOLOR}"
  echo -e "${BOLD}Status: ${NOCOLOR}"$WAN1DISPLAYSTATUS""
  [[ "$WANSMODE" != "lb" ]] &>/dev/null && { [[ "$WAN1PRIMARY" == "1" ]] &>/dev/null && echo -e "${BOLD}Primary: ${NOCOLOR}${LIGHTCYAN}Yes${NOCOLOR}" || echo -e "${BOLD}Primary: ${LIGHTRED}No${NOCOLOR}" ;}
  echo -e "${BOLD}IP Address: ${NOCOLOR}${LIGHTGRAY}"$WAN1IPADDR"${NOCOLOR}"
  echo -e "${BOLD}Gateway: ${NOCOLOR}${LIGHTGRAY}"$WAN1GATEWAY"${NOCOLOR}"
  echo -e "${BOLD}Interface: ${NOCOLOR}${LIGHTGRAY}"$WAN1GWIFNAME"${NOCOLOR}"
  echo -e "${BOLD}MAC Address: ${NOCOLOR}${LIGHTGRAY}"$WAN1GWMAC"${NOCOLOR}"
  echo -e "${BOLD}WAN1 Target: ${NOCOLOR}${LIGHTGRAY}"$WAN1TARGET"${NOCOLOR}"
  [[ -n "$WAN1PACKETLOSS" ]] &>/dev/null && echo -e "${BOLD}Packet Loss: ${NOCOLOR}${WAN1PACKETLOSSCOLOR}"$WAN1PACKETLOSS"${NOCOLOR}" || echo -e "${BOLD}Packet Loss: ${NOCOLOR}"
  [[ -n "$WAN1PINGTIME" ]] &>/dev/null && echo -e "${BOLD}Ping Time: ${NOCOLOR}${WAN1PINGTIMECOLOR}"$WAN1PINGTIME"${NOCOLOR}" || echo -e "${BOLD}Ping Time: ${NOCOLOR}"
  [[ -n "$WAN1LASTUPDATE" ]] &>/dev/null && echo -e "${BOLD}Last Update: ${NOCOLOR}${NOCOLOR}"$WAN1LASTUPDATE"${NOCOLOR}" || echo -e "${BOLD}Last Update: ${NOCOLOR}"

  printf "\n"

  # Check if AdGuard is Running or AdGuard Local is Enabled
  if [[ -n "$(pidof AdGuardHome)" ]] &>/dev/null || { [[ -f "/opt/etc/AdGuardHome/.config" ]] &>/dev/null && [[ -n "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ]] &>/dev/null ;};then
    printf "${BOLD}${UNDERLINE}Active DNS Servers:${NOCOLOR}\n"
    printf "${LIGHTGRAY}DNS is being managed by AdGuard${NOCOLOR}\n"
  else
    ACTIVEDNSSERVERS="$(cat $DNSRESOLVFILE | grep -v "127.0.1.1" | awk '{print $2}')"
    if [[ -n "$ACTIVEDNSSERVERS" ]] &>/dev/null || [[ "$DEVMODE" == "1" ]] &>/dev/null;then
      printf "${BOLD}${UNDERLINE}Active DNS Servers:${NOCOLOR}\n"
      for ACTIVEDNSSERVER in ${ACTIVEDNSSERVERS};do
        echo -e "${LIGHTGRAY}$ACTIVEDNSSERVER${NOCOLOR}"
      done
    fi
  fi

  if [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null || [[ "$DEVMODE" == "1" ]] &>/dev/null;then
    printf "\n"
    printf "${BOLD}${UNDERLINE}IPV6:${NOCOLOR}\n"
    if [[ "$IPV6SERVICE" == "disabled" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"Disabled"${NOCOLOR}"
    elif [[ "$IPV6SERVICE" == "dhcp6" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"Native"${NOCOLOR}"
    elif [[ "$IPV6SERVICE" == "static6" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"Static IPv6"${NOCOLOR}"
    elif [[ "$IPV6SERVICE" == "ipv6pt" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"Passthrough"${NOCOLOR}"
    elif [[ "$IPV6SERVICE" == "flets" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"FLET\'s IPv6 Service"${NOCOLOR}"
    elif [[ "$IPV6SERVICE" == "6to4" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"Tunnel 6to4"${NOCOLOR}"
    elif [[ "$IPV6SERVICE" == "6in4" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"Tunnel 6in4"${NOCOLOR}"
    elif [[ "$IPV6SERVICE" == "6rd" ]] &>/dev/null;then
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"Tunnel 6rd"${NOCOLOR}"
    else
      echo -e "${BOLD}Type: ${NOCOLOR}${LIGHTGRAY}"$IPV6SERVICE"${NOCOLOR}"
    fi
    if [[ "$IPV6SERVICE" != "disabled" ]] &>/dev/null;then
      echo -e "${BOLD}IP Address: ${NOCOLOR}${LIGHTGRAY}"$IPV6IPADDR"${NOCOLOR}" || echo -e "${BOLD}IP Address: ${NOCOLOR}${RED}N/A${NOCOLOR}"
    fi
  fi

  printf "\n  (r)  refresh     Refresh WAN Failover Status"
  printf "\n  (e)  exit        Exit WAN Failover Status\n"
  printf "\nMake a selection: "
  )"
  echo "$output"
  # Wait on Input
  read -t $STATUSCHECK -r input
  # Refresh Menu if No Input
  if [[ -z "${input+x}" ]] &>/dev/null;then
    continue
  # Commit Action based on Input
  else
    case $input in
      'r'|'R'|'refresh' ) continue;;
      'e'|'E'|'exit'|'menu' )
      if [[ "$mode" == "menu" ]] &>/dev/null;then
        clear
        menu
        break
      else
        clear
        break && return
      fi
      ;;
      * ) continue;;
    esac
  fi
done
# Unset Variables
[[ -z "${RUNNING+x}" ]] &>/dev/null && unset RUNNING
[[ -z "${DISPLAYHOSTNAME+x}" ]] &>/dev/null && unset DISPLAYHOSTNAME
[[ -n "${input+x}" ]] &>/dev/null && unset input
[[ -n "${output+x}" ]] &>/dev/null && unset output
[[ -n "${currenttime+x}" ]] &>/dev/null && unset currenttime
[[ -n "${currentdate+x}" ]] &>/dev/null && unset currentdate
[[ -n "${wan0lastupdatetime+x}" ]] &>/dev/null && unset wan0lastupdatetime
[[ -n "${wan0lastupdatedate+x}" ]] &>/dev/null && unset wan0lastupdatedate
[[ -n "${wan0checktime+x}" ]] &>/dev/null && unset wan0checktime
[[ -n "${wan1lastupdatetime+x}" ]] &>/dev/null && unset wan1lastupdatetime
[[ -n "${wan1lastupdatedate+x}" ]] &>/dev/null && unset wan1lastupdatedate
[[ -n "${wan1checktime+x}" ]] &>/dev/null && unset wan1checktime
[[ -n "${bootdelay+x}" ]] &>/dev/null && unset bootdelay

return
}

# Check if NVRAM Background Process is Stuck if CHECKNVRAM is Enabled
nvramcheck ()
{
# Return if CHECKNVRAM is Disabled
if [[ -z "${CHECKNVRAM+x}" ]] || [[ "$CHECKNVRAM" == "0" ]] &>/dev/null;then
    return
fi

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

# Debug Logging
debuglog ()
{

if { [[ "$mode" == "manual" ]] &>/dev/null || [[ "$mode" == "run" ]] &>/dev/null ;} && [[ "$(nvram get log_level & nvramcheck)" -ge "7" ]] &>/dev/null;then
  logger -p 6 -t "$ALIAS" "Debug - Function: debuglog"

  # Get System Parameters
  getsystemparameters || return

  # Get Global WAN Parameters
  if [[ -z "${globalwansync+x}" ]] &>/dev/null;then
    GETWANMODE=2
    getwanparameters || return
  fi

  # Getting Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  [[ -n "${MODEL+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Model: $MODEL"
  [[ -n "${PRODUCTID+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Product ID: $PRODUCTID"
  [[ -n "${BUILDNAME+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Build Name: $BUILDNAME"
  [[ -n "${BUILDNO+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Firmware: $BUILDNO"
  [[ -n "${IPVERSION+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - IPRoute Version: $IPVERSION"
  [[ -n "${WANSCAP+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - WAN Capability: $WANSCAP"
  [[ -n "${WANSMODE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Dual WAN Mode: $WANSMODE"
  [[ -n "${WANSLBRATIO+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Load Balance Ratio: $WANSLBRATIO"
  [[ -n "${WANSDUALWAN+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Dual WAN Interfaces: $WANSDUALWAN"
  [[ -n "${WANDOGENABLE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - ASUS Factory Watchdog: $WANDOGENABLE"
  [[ -n "${JFFSSCRIPTS+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - JFFS custom scripts and configs: $JFFSSCRIPTS"
  [[ -n "${HTTPENABLE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - HTTP Web Access: $HTTPENABLE""
  [[ -n "${FIREWALLENABLE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Firewall Enabled: $FIREWALLENABLE""
  [[ -n "${IPV6FIREWALLENABLE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - IPv6 Firewall Enabled: $IPV6FIREWALLENABLE"
  [[ -n "${LEDDISABLE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - LEDs Disabled: $LEDDISABLE"
  [[ -n "${QOSENABLE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - QoS Enabled: $QOSENABLE"
  [[ -n "${DDNSENABLE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - DDNS Enabled: $DDNSENABLE"
  [[ -n "${DDNSHOSTNAME+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - DDNS Hostname: $DDNSHOSTNAME"
  [[ -n "${LANHOSTNAME+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - LAN Hostname: $LANHOSTNAME"
  [[ -n "${IPV6SERVICE+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - WAN IPv6 Service: $IPV6SERVICE"
  [[ -n "${IPV6IPADDR+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - WAN IPv6 Address: $IPV6IPADDR"
  [[ -n "${PROCESSPRIORITY+x}" ]] &>/dev/null && logger -p 6 -t "$ALIAS" "Debug - Process Priority: $PROCESSPRIORITY"

  logger -p 6 -t "$ALIAS" "Debug - Default Route: $(ip route list default table main)"
  logger -p 6 -t "$ALIAS" "Debug - OpenVPN Server Instances Enabled: $OVPNSERVERINSTANCES"
  for WANPREFIX in ${WANPREFIXES};do
    # Getting WAN Parameters
    GETWANMODE="1"
    getwanparameters || return

    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Enabled: $ENABLE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Routing Table Default Route: $(ip route list default table $TABLE)"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Ping Path: $PINGPATH"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Target IP Rule: $(ip rule list from all iif lo to $TARGET lookup $TABLE)"
    if [[ "$PINGPATH" == "0" ]] &>/dev/null || [[ "$PINGPATH" == "3" ]] &>/dev/null;then
      logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Target IP Route: $(ip route list $TARGET via $GATEWAY dev $GWIFNAME table main)"
    else
      logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Default IP Route: $(ip route list default table $TABLE)"
      logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Target IP Route: $(ip route list $TARGET via $GATEWAY dev $GWIFNAME table $TABLE)"
    fi
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} IP Address: $IPADDR"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Real IP Address: $REALIPADDR"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Real IP Address State: $REALIPSTATE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Gateway IP: $GATEWAY"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Gateway Interface: $GWIFNAME"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Interface: $IFNAME"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Automatic ISP DNS Enabled: $DNSENABLE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Automatic ISP DNS Servers: $DNS"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Manual DNS Server 1: $DNS1"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Manual DNS Server 2: $DNS2"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} State: $STATE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Aux State: $AUXSTATE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Sb State: $SBSTATE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Primary Status: $PRIMARY"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} USB Modem Status: $USBMODEMREADY"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} UPnP Enabled: $UPNPENABLE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} NAT Enabled: $NAT"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Target IP Address: $TARGET"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Routing Table: $TABLE"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} IP Rule Priority: $PRIORITY"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Mark: $MARK"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} Mask: $MASK"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} From WAN Priority: $FROMWANPRIORITY"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} To WAN Priority: $TOWANPRIORITY"
    logger -p 6 -t "$ALIAS" "Debug - ${WANPREFIX} OVPN WAN Priority: $OVPNWANPRIORITY"
  done
fi
return
}
scriptmode
