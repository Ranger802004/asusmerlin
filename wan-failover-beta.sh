#!/bin/sh

# WAN Failover for ASUS Routers using ASUS Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 2/21/2023
# Version: v2.0.0-beta1

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
ALIAS="wan-failover"
VERSION="v2.0.0-beta1"
CHECKSUM="$(md5sum $0 | awk '{print $1}')"
REPO="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/"
CONFIGFILE="/jffs/configs/wan-failover.conf"
DNSRESOLVFILE="/tmp/resolv.conf"
LOCKFILE="/var/lock/wan-failover.lock"
WAN0PACKETLOSSFILE="/tmp/wan0packetloss.tmp"
WAN1PACKETLOSSFILE="/tmp/wan1packetloss.tmp"
WANPREFIXES="wan0 wan1"
WAN0="wan0"
WAN1="wan1"
NOCOLOR="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[94m"
WHITE="\033[37m"

if [[ "$(dirname "$0")" == "." ]] >/dev/null 2>&1;then
  if [ ! -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}***WARNING*** Execute using Alias: ${BLUE}$ALIAS${RED}${NOCOLOR}.${NOCOLOR}"
  else
    SCRIPTPATH="/jffs/scripts/"${0##*/}""
    echo -e ""${BOLD}"${RED}***WARNING*** Execute using full script path ${BLUE}"$SCRIPTPATH"${NOCOLOR}.${NOCOLOR}"
  fi
  exit
fi

# Set Script Mode
if [ "$#" == "0" ] >/dev/null 2>&1;then
  # Default to Menu Mode if no argument specified
  [ -z "${mode+x}" ] >/dev/null 2>&1 && mode=menu
elif [ "$#" != "0" ] >/dev/null 2>&1;then
  [ -z "${mode+x}" ] >/dev/null 2>&1 && mode="${1#}"
fi
scriptmode ()
{
if [[ "${mode}" == "menu" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    trap 'return' EXIT HUP INT QUIT TERM
    systembinaries || return
    [ -f "$CONFIGFILE" ] >/dev/null 2>&1 && { setvariables || return ;}
    menu || return
  else
    return
  fi
elif [[ "${mode}" == "install" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${BLUE}$ALIAS - Install Mode${NOCOLOR}"
  fi
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  install
elif [[ "${mode}" == "run" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${GREEN}$ALIAS - Run Mode${NOCOLOR}"
  fi
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { if tty >/dev/null 2>&1;then echo -e "${RED}***$ALIAS is already running***${NOCOLOR}";fi && exit ;}
  logger -p 6 -t "$ALIAS" "Debug - Locked File: "$LOCKFILE""
  trap 'cleanup && kill -9 "$$"' EXIT HUP INT QUIT TERM STOP
  logger -p 6 -t "$ALIAS" "Debug - Trap set to remove "$LOCKFILE" on exit"
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  systemcheck || return
  setvariables || return
  wanstatus || return
elif [[ "${mode}" == "manual" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${GREEN}$ALIAS - Manual Mode${NOCOLOR}"
  fi
  exec 100>"$LOCKFILE" || return
  flock -x -n 100 || { if tty >/dev/null 2>&1;then echo -e "${RED}***$ALIAS is already running***${NOCOLOR}";fi && exit ;}
  logger -p 6 -t "$ALIAS" "Debug - Locked File: "$LOCKFILE""
  trap 'cleanup && kill -9 "$$"' EXIT HUP INT QUIT TERM STOP
  logger -p 6 -t "$ALIAS" "Debug - Trap set to remove "$LOCKFILE" on exit"
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  systemcheck || return
  setvariables || return
  wanstatus || return
elif [[ "${mode}" == "initiate" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${GREEN}$ALIAS - Initiate Mode${NOCOLOR}"
  fi
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  systemcheck || return
  setvariables || return
  wanstatus || return
elif [[ "${mode}" == "restart" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  fi
  killscript
elif [[ "${mode}" == "monitor" ]] >/dev/null 2>&1 || [[ "${mode}" == "capture" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    [[ "${mode}" == "monitor" ]] >/dev/null 2>&1 && echo -e ""${BOLD}"${GREEN}$ALIAS - Monitor Mode${NOCOLOR}"
    [[ "${mode}" == "capture" ]] >/dev/null 2>&1 && echo -e ""${BOLD}"${GREEN}$ALIAS - Capture Mode${NOCOLOR}"
  fi
  trap 'exit' EXIT HUP INT QUIT TERM
  logger -p 6 -t "$ALIAS" "Debug - Trap set to kill background process on exit"
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  monitor
elif [[ "${mode}" == "kill" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}$ALIAS - Kill Mode${NOCOLOR}"
  fi
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  killscript
elif [[ "${mode}" == "uninstall" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}$ALIAS - Uninstall Mode${NOCOLOR}"
  fi
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  uninstall
elif [[ "${mode}" == "cron" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${YELLOW}$ALIAS - Cron Job Mode${NOCOLOR}"
  fi
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  setvariables || return
  cronjob
elif [[ "${mode}" == "switchwan" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${YELLOW}$ALIAS - Switch WAN Mode${NOCOLOR}"
  fi
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  # Get Global WAN Parameters
  if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
    GETWANMODE=2
    getwanparameters || return
  fi
  if [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
    echo -e ""${BOLD}"${RED}***Switch WAN Mode is only available in Failover Mode***${NOCOLOR}"
    return
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
    while [[ "${mode}" == "switchwan" ]] >/dev/null 2>&1;do
      if tty >/dev/null 2>&1;then
        read -p "Are you sure you want to switch Primary WAN? ***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
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
elif [[ "${mode}" == "update" ]] >/dev/null 2>&1;then
  if tty >/dev/null 2>&1;then
    echo -e ""${BOLD}"${YELLOW}$ALIAS - Update Mode${NOCOLOR}"
  fi
  logger -p 6 -t "$ALIAS" "Debug - Script Mode: "${mode}""
  update
fi
}

# Menu
menu ()
{
        # Get Global WAN Parameters
        if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
          GETWANMODE=2
          getwanparameters || return
        fi
	clear
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
        [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && printf "  (14) switchwan   Manually switch Primary WAN.  ${RED}***Failover Mode Only***${NOCOLOR}\n"


	printf "\n  (e)  exit        Exit WAN Failover Menu\n"
	printf "\nMake a selection: "
	read -r input
	case "${input}" in
		'')
                        return
		;;
		'1')    # status
                        # Check for configuration and load configuration
                        if [ -f "$CONFIGFILE" ] >/dev/null 2>&1;then
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
                        if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
                          GETWANMODE=2
                          getwanparameters || return
                        fi

                        # Get System Parameters
                        if [ -z "${JFFSSCRIPTS+x}" ] >/dev/null 2>&1 || [ -z "${PRODUCTID+x}" ] >/dev/null 2>&1 || [ -z "${BUILDNO+x}" ] >/dev/null 2>&1 || [ -z "${LANHOSTNAME+x}" ] >/dev/null 2>&1;then
                          # Get System Parameters
                          getsystemparameters || return
                        fi

                        while true >/dev/null 2>&1;do
                          # Get Active Variables
                          [ ! -z "$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}' &)" ] >/dev/null 2>&1 && RUNNING="1" || RUNNING="0"
                          currenttime="$(date +%d%H%M%S)"
                          currentdate="$(date +%-m%d%y)"

                          # Get Active WAN Parameters
                          GETWANMODE=3
                          getwanparameters || return

                          # Check Packet Loss
                          if [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [ -f "$WAN0PACKETLOSSFILE" ] >/dev/null 2>&1;then
                            WAN0PACKETLOSS="$(sed -n 1p "$WAN0PACKETLOSSFILE")"
                            WAN0PINGTIME="$(sed -n 2p "$WAN0PACKETLOSSFILE")"
                            WAN0LASTUPDATE="$(date -r "$WAN0PACKETLOSSFILE")"
                            wan0lastupdatetime="$(date -r "$WAN0PACKETLOSSFILE" +%d%H%M%S)"
                            wan0lastupdatedate="$(date -r "$WAN0PACKETLOSSFILE" +%-m%d%y)"
                            # Determine Packet Loss Color
                            if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
                              WAN0PACKETLOSSCOLOR="${GREEN}"
                            elif [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
                              WAN0PACKETLOSSCOLOR="${RED}"
                            else
                              WAN0PACKETLOSSCOLOR="${YELLOW}"
                            fi
                            # Determine Ping Time Color
                            if [[ "$WAN0PINGTIME" -le "$PINGTIMEMIN" ]] >/dev/null 2>&1;then
                              WAN0PINGTIMECOLOR="${GREEN}"
                            elif [[ "$WAN0PINGTIME" -gt "$PINGTIMEMIN" ]] >/dev/null 2>&1 && [[ "$WAN0PINGTIME" -le "$PINGTIMEMAX" ]] >/dev/null 2>&1;then
                              WAN0PINGTIMECOLOR="${YELLOW}"
                            elif [[ "$WAN0PINGTIME" -gt "$PINGTIMEMAX" ]] >/dev/null 2>&1;then
                              WAN0PINGTIMECOLOR="${RED}"
                            else
                              WAN0PINGTIMECOLOR="${NOCOLOR}"   
                            fi
                            # Append Ping Time If Necessary
                            if [[ "$WAN0PACKETLOSS" != "100%" ]] >/dev/null 2>&1;then
                              WAN0PINGTIME="$(sed -n 2p "$WAN0PACKETLOSSFILE")ms"
                            else
                              WAN0PINGTIME="$(sed -n 2p "$WAN0PACKETLOSSFILE")"
                            fi
                          else
                            WAN0PACKETLOSS="N/A"
                            WAN0PINGTIME="N/A"
                            WAN0LASTUPDATE=""
                            wan0lastupdatetime=""
                            wan0lastupdatedate=""
                            WAN0PACKETLOSSCOLOR="${NOCOLOR}"
                            WAN0PINGTIMECOLOR="${NOCOLOR}" 
                          fi
                          if [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [ -f "$WAN1PACKETLOSSFILE" ] >/dev/null 2>&1;then
                            WAN1PACKETLOSS="$(sed -n 1p "$WAN1PACKETLOSSFILE")"
                            WAN1PINGTIME="$(sed -n 2p "$WAN1PACKETLOSSFILE")"
                            WAN1LASTUPDATE="$(date -r "$WAN1PACKETLOSSFILE")"
                            wan1lastupdatetime="$(date -r "$WAN1PACKETLOSSFILE" +%d%H%M%S)"
                            wan1lastupdatedate="$(date -r "$WAN1PACKETLOSSFILE" +%-m%d%y)"
                            # Determine Packet Loss Color
                            if [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
                              WAN1PACKETLOSSCOLOR="${GREEN}"
                            elif [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
                              WAN1PACKETLOSSCOLOR="${RED}"
                            else
                              WAN1PACKETLOSSCOLOR="${YELLOW}"
                            fi
                            # Determine Ping Time Color
                            if [[ "$WAN1PINGTIME" -le "$PINGTIMEMIN" ]] >/dev/null 2>&1;then
                              WAN1PINGTIMECOLOR="${GREEN}"
                            elif [[ "$WAN1PINGTIME" -gt "$PINGTIMEMIN" ]] >/dev/null 2>&1 && [[ "$WAN1PINGTIME" -le "$PINGTIMEMAX" ]] >/dev/null 2>&1;then
                              WAN1PINGTIMECOLOR="${YELLOW}"
                            elif [[ "$WAN1PINGTIME" -gt "$PINGTIMEMAX" ]] >/dev/null 2>&1;then
                              WAN1PINGTIMECOLOR="${RED}"
                            else
                              WAN1PINGTIMECOLOR="${NOCOLOR}"   
                            fi
                            # Append Ping Time If Necessary
                            if [[ "$WAN1PACKETLOSS" != "100%" ]] >/dev/null 2>&1;then
                              WAN1PINGTIME="$(sed -n 2p "$WAN1PACKETLOSSFILE")ms"
                            else
                              WAN1PINGTIME="$(sed -n 2p "$WAN1PACKETLOSSFILE")"
                            fi
                          else
                            WAN1PACKETLOSS="N/A"
                            WAN1PINGTIME="N/A"
                            WAN1LASTUPDATE=""
                            wan1lastupdate=""
                            WAN1PACKETLOSSCOLOR="${NOCOLOR}"
                            WAN1PINGTIMECOLOR="${NOCOLOR}" 
                          fi
                          # Update Status
                          if [[ "$RUNNING" == "1" ]] >/dev/null 2>&1;then
                            if [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1;then
                              RUNNING=3
                            elif [ ! -z "${currenttime+x}" ] >/dev/null 2>&1 && [ ! -z "${wan0lastupdatetime+x}" ] >/dev/null 2>&1 && [ ! -z "${wan1lastupdatetime+x}" ] >/dev/null 2>&1 && [ ! -z "${currentdate+x}" ] >/dev/null 2>&1 && [ ! -z "${wan0lastupdatedate+x}" ] >/dev/null 2>&1 && [ ! -z "${wan1lastupdatedate+x}" ] >/dev/null 2>&1;then
                              [ ! -z "${wan0lastupdatetime+x}" ] >/dev/null 2>&1 && wan0checktime="$(echo $(($wan0lastupdatetime+(($PINGCOUNT*$PINGTIMEOUT)*$RECURSIVEPINGCHECK)+($STATUSCHECK*2))))"
                              [ ! -z "${wan1lastupdatetime+x}" ] >/dev/null 2>&1 && wan1checktime="$(echo $(($wan1lastupdatetime+(($PINGCOUNT*$PINGTIMEOUT)*$RECURSIVEPINGCHECK)+($STATUSCHECK*2))))"
                              [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$currentdate" == "$wan0lastupdatedate" ]] >/dev/null 2>&1 && { [[ "$currenttime" -gt "$wan0checktime" ]] >/dev/null 2>&1 && RUNNING=2 ;}
                              [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$currentdate" == "$wan1lastupdatedate" ]] >/dev/null 2>&1 && { [[ "$currenttime" -gt "$wan1checktime" ]] >/dev/null 2>&1 && RUNNING=2 ;}
                            else
                              RUNNING=2
                            fi
                          fi

                          # Buffer Status Output
                          output="$(
                          clear
                          printf "${BOLD}***WAN Failover Status***${NOCOLOR}\n"
                          echo -e "${BOLD}Model: ${NOCOLOR}${BLUE}"$PRODUCTID"${NOCOLOR}"
                          echo -e "${BOLD}Firmware Version: ${NOCOLOR}${BLUE}"$BUILDNO"${NOCOLOR}"
                          echo -e "${BOLD}Host Name: ${NOCOLOR}${BLUE}"$LANHOSTNAME"${NOCOLOR}"
                          echo -e "${BOLD}WAN Failover Version: ${NOCOLOR}${BLUE}"$VERSION"${NOCOLOR}"
                          [[ "$JFFSSCRIPTS" == "1" ]] >/dev/null 2>&1 && echo -e "${BOLD}JFFS Scripts:${NOCOLOR} ${GREEN}Enabled${NOCOLOR}" || echo -e "${BOLD}JFFS Scripts:${NOCOLOR} ${RED}Disabled${NOCOLOR}"
                          [[ "$WANSDUALWANENABLE" == "1" ]] >/dev/null 2>&1 && echo -e "${BOLD}Dual WAN:${NOCOLOR} ${GREEN}Enabled${NOCOLOR}" || echo -e "${BOLD}Dual WAN:${NOCOLOR} ${RED}Disabled${NOCOLOR}"
                          if [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
                            echo -e "${BOLD}Mode: ${NOCOLOR}${BLUE}Load Balance Mode${NOCOLOR}"
                            echo -e "${BOLD}Load Balance Ratio: ${NOCOLOR}${BLUE}"$WANSLBRATIO"${NOCOLOR}"
                          else
                            echo -e "${BOLD}Mode: ${NOCOLOR}${BLUE}Failover Mode${NOCOLOR}"
                          fi
                          if [[ "$RUNNING" == "0" ]] >/dev/null 2>&1;then
                            echo -e "${BOLD}Status:${NOCOLOR} ${NOCOLOR}Not Running${NOCOLOR}"
                          elif [[ "$RUNNING" == "1" ]] >/dev/null 2>&1;then
                            echo -e "${BOLD}Status:${NOCOLOR} ${GREEN}Monitoring${NOCOLOR}"
                          elif [[ "$RUNNING" == "2" ]] >/dev/null 2>&1;then
                            echo -e "${BOLD}Status:${NOCOLOR} ${YELLOW}Unresponsive${NOCOLOR}"
                          elif [[ "$RUNNING" == "3" ]] >/dev/null 2>&1;then
                            echo -e "${BOLD}Status:${NOCOLOR} ${RED}Failover Disabled${NOCOLOR}"
                          fi
                          echo -e "${BOLD}Last Update: ${NOCOLOR}${NOCOLOR}$(date)${NOCOLOR}"
                          printf "\n"
                          echo -e "${BOLD}***WAN0***${NOCOLOR}"
                          [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && echo -e "${BOLD}Status: ${NOCOLOR}${GREEN}Enabled${NOCOLOR}" || echo -e "${BOLD}Status: ${NOCOLOR}${RED}Disabled${NOCOLOR}"
                          [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && { [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 && echo -e "${BOLD}Primary: ${NOCOLOR}${GREEN}Yes${NOCOLOR}" || echo -e "${BOLD}Primary: ${NOCOLOR}${RED}No${NOCOLOR}" ;}
                          echo -e "${BOLD}IP Address: ${NOCOLOR}${BLUE}"$WAN0IPADDR"${NOCOLOR}"
                          echo -e "${BOLD}Gateway: ${NOCOLOR}${BLUE}"$WAN0GATEWAY"${NOCOLOR}"
                          echo -e "${BOLD}Interface: ${NOCOLOR}${BLUE}"$WAN0GWIFNAME"${NOCOLOR}"
                          echo -e "${BOLD}MAC Address: ${NOCOLOR}${BLUE}"$WAN0GWMAC"${NOCOLOR}"
                          echo -e "${BOLD}WAN0 Target: ${NOCOLOR}${BLUE}"$WAN0TARGET"${NOCOLOR}"
                          [ ! -z "$WAN0PACKETLOSS" ] >/dev/null 2>&1 && echo -e "${BOLD}Packet Loss: ${NOCOLOR}${WAN0PACKETLOSSCOLOR}"$WAN0PACKETLOSS"${NOCOLOR}"
                          [ ! -z "$WAN0PINGTIME" ] >/dev/null 2>&1 && echo -e "${BOLD}Ping Time: ${NOCOLOR}${WAN0PINGTIMECOLOR}"$WAN0PINGTIME"${NOCOLOR}"
                          [ ! -z "$WAN0LASTUPDATE" ] >/dev/null 2>&1 && echo -e "${BOLD}Last Update: ${NOCOLOR}${NOCOLOR}"$WAN0LASTUPDATE"${NOCOLOR}"

                          printf "\n"
                          echo -e "${BOLD}***WAN1***${NOCOLOR}"
                          [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && echo -e "${BOLD}Status: ${NOCOLOR}${GREEN}Enabled${NOCOLOR}" || echo -e "${BOLD}Status: ${NOCOLOR}${RED}Disabled${NOCOLOR}"
                          [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && { [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 && echo -e "${BOLD}Primary: ${NOCOLOR}${GREEN}Yes${NOCOLOR}" || echo -e "${BOLD}Primary: ${NOCOLOR}${RED}No${NOCOLOR}" ;}
                          echo -e "${BOLD}IP Address: ${NOCOLOR}${BLUE}"$WAN1IPADDR"${NOCOLOR}"
                          echo -e "${BOLD}Gateway: ${NOCOLOR}${BLUE}"$WAN1GATEWAY"${NOCOLOR}"
                          echo -e "${BOLD}Interface: ${NOCOLOR}${BLUE}"$WAN1GWIFNAME"${NOCOLOR}"
                          echo -e "${BOLD}MAC Address: ${NOCOLOR}${BLUE}"$WAN1GWMAC"${NOCOLOR}"
                          echo -e "${BOLD}WAN1 Target: ${NOCOLOR}${BLUE}"$WAN1TARGET"${NOCOLOR}"
                          [ ! -z "$WAN1PACKETLOSS" ] >/dev/null 2>&1 && echo -e "${BOLD}Packet Loss: ${NOCOLOR}${WAN1PACKETLOSSCOLOR}"$WAN1PACKETLOSS"${NOCOLOR}"
                          [ ! -z "$WAN1PINGTIME" ] >/dev/null 2>&1 && echo -e "${BOLD}Ping Time: ${NOCOLOR}${WAN1PINGTIMECOLOR}"$WAN1PINGTIME"${NOCOLOR}"
                          [ ! -z "$WAN1LASTUPDATE" ] >/dev/null 2>&1 && echo -e "${BOLD}Last Update: ${NOCOLOR}${NOCOLOR}"$WAN1LASTUPDATE"${NOCOLOR}"


                          if [[ "$IPV6SERVICE" != "disabled" ]] >/dev/null 2>&1;then
                            printf "\n"
                            printf "${BOLD}***IPV6***${NOCOLOR}\n"
                            if [[ "$IPV6SERVICE" == "dhcp6" ]] >/dev/null 2>&1;then
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"Native"${NOCOLOR}"
                            elif [[ "$IPV6SERVICE" == "static6" ]] >/dev/null 2>&1;then
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"Static IPv6"${NOCOLOR}"
                            elif [[ "$IPV6SERVICE" == "ipv6pt" ]] >/dev/null 2>&1;then
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"Passthrough"${NOCOLOR}"
                            elif [[ "$IPV6SERVICE" == "flets" ]] >/dev/null 2>&1;then
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"FLET\'s IPv6 Service"${NOCOLOR}"
                            elif [[ "$IPV6SERVICE" == "6to4" ]] >/dev/null 2>&1;then
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"Tunnel 6to4"${NOCOLOR}"
                            elif [[ "$IPV6SERVICE" == "6in4" ]] >/dev/null 2>&1;then
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"Tunnel 6in4"${NOCOLOR}"
                            elif [[ "$IPV6SERVICE" == "6rd" ]] >/dev/null 2>&1;then
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"Tunnel 6rd"${NOCOLOR}"
                            else
                              echo -e "${BOLD}Type: ${NOCOLOR}${BLUE}"$IPV6SERVICE"${NOCOLOR}"
                            fi
                            echo -e "${BOLD}IP Address: ${NOCOLOR}${BLUE}"$IPV6IPADDR"${NOCOLOR}" || echo -e "${BOLD}IP Address: ${NOCOLOR}${RED}N/A${NOCOLOR}"
                          fi

                          printf "\n"
                          printf "${BOLD}***Active DNS Servers***${NOCOLOR}\n"
                          ACTIVEDNSSERVERS="$(cat $DNSRESOLVFILE | grep -v "127.0.1.1" | awk '{print $2}')"
                          for ACTIVEDNSSERVER in ${ACTIVEDNSSERVERS};do
                            echo -e "${BLUE}$ACTIVEDNSSERVER${NOCOLOR}"
                          done

	                  printf "\n  (r)  refresh     Refresh WAN Failover Status"
	                  printf "\n  (e)  exit        Exit WAN Failover Status\n"
	                  printf "\nMake a selection: "
                          )"
                          echo "$output"
                          read -t $STATUSCHECK -r input
                          case $input in
	      	            'r'|'R'|'refresh' ) continue;;
	      	            'e'|'E'|'exit'|'menu' )
                            clear
		            menu
                            break
		            ;;
                            * ) continue;;
                          esac
                        done
                        # Unset Variables
                        [ -z "${RUNNING+x}" ] >/dev/null 2>&1 && unset RUNNING
                        [ ! -z "${input+x}" ] >/dev/null 2>&1 && unset input
                        [ ! -z "${output+x}" ] >/dev/null 2>&1 && unset output
                        [ ! -z "${currenttime+x}" ] >/dev/null 2>&1 && unset currenttime
                        [ ! -z "${currentdate+x}" ] >/dev/null 2>&1 && unset currentdate
                        [ ! -z "${wan0lastupdatetime+x}" ] >/dev/null 2>&1 && unset wan0lastupdatetime
                        [ ! -z "${wan0lastupdatedate+x}" ] >/dev/null 2>&1 && unset wan0lastupdatedate
                        [ ! -z "${wan0checktime+x}" ] >/dev/null 2>&1 && unset wan0checktime
                        [ ! -z "${wan1lastupdatetime+x}" ] >/dev/null 2>&1 && unset wan1lastupdatetime
                        [ ! -z "${wan1lastupdatedate+x}" ] >/dev/null 2>&1 && unset wan1lastupdatedate
                        [ ! -z "${wan1checktime+x}" ] >/dev/null 2>&1 && unset wan1checktime
		;;
		'2')    # readme
                        # Check for configuration and load configuration
                        if [ ! -f "$CONFIGFILE" ] >/dev/null 2>&1;then
                          echo -e "${RED}WAN Failover currently has no configuration file present{$NOCOLOR}"
                        elif [ -f "$CONFIGFILE" ] >/dev/null 2>&1;then
                          setvariables || return
                        fi
                        # Determine if readme source is prod or beta
                        if [[ "$DEVMODE" == "1" ]] >/dev/null 2>&1;then
                          README=""$REPO"wan-failover-readme-beta.txt"
                        else
                          README=""$REPO"wan-failover-readme.txt"
                        fi
                        /usr/sbin/curl --connect-timeout 30 --max-time 30 --url $README --ssl-reqd || echo -e "${RED}***Unable to access Readme***${NOCOLOR}"
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
                        # Check for configuration and load configuration
                        if [ ! -f "$CONFIGFILE" ] >/dev/null 2>&1;then
                          echo -e "${RED}WAN Failover currently has no configuration file present{$NOCOLOR}"
                        elif [ -f "$CONFIGFILE" ] >/dev/null 2>&1;then
                          setvariables || return
                        fi
                        printf "\n  ${BOLD}Failover Monitoring Settings:${NOCOLOR}\n"
                        option=1
                        printf "  ($option)  Configure WAN0 Target           WAN0 Target: ${BLUE}$WAN0TARGET${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option)  Configure WAN1 Target           WAN1 Target: ${BLUE}$WAN1TARGET${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option)  Configure Ping Count            Ping Count: ${BLUE}$PINGCOUNT${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option)  Configure Ping Timeout          Ping Timeout: ${BLUE}$PINGTIMEOUT${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option)  Configure Ping Time Min         Ping Time Minimum: ${GREEN}"$PINGTIMEMIN"ms${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option)  Configure Ping Time Max         Ping Time Maximum: ${RED}"$PINGTIMEMAX"ms${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "\n  ${BOLD}QoS Settings:${NOCOLOR}\n"
                        printf "  ($option)  Configure WAN0                  WAN0 QoS: " && { [[ "$WAN0_QOS_ENABLE" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "  ($option)  Configure WAN1                  WAN1 QoS: " && { [[ "$WAN1_QOS_ENABLE" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "\n  ${BOLD}Optional Settings:${NOCOLOR}\n"
                        printf "  ($option)  Configure Packet Loss Logging   Packet Loss Logging: " && { [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Boot Delay Timer      Boot Delay Timer: ${BLUE}$BOOTDELAYTIMER Seconds${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Email Notifications   Email Notifications: " && { [[ "$SENDEMAIL" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN0 Packet Size      WAN0 Packet Size: ${BLUE}$WAN0PACKETSIZE Bytes${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN1 Packet Size      WAN1 Packet Size: ${BLUE}$WAN1PACKETSIZE Bytes${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure NVRAM Checks          NVRAM Checks: " && { [[ "$CHECKNVRAM" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Dev Mode              Dev Mode: " && { [[ "$DEVMODE" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "Disabled" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Custom Log Path       Custom Log Path: " && { [ ! -z "$CUSTOMLOGPATH" ] >/dev/null 2>&1 && printf "${BLUE}$CUSTOMLOGPATH${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "\n  ${BOLD}Advanced Settings:${NOCOLOR}  ${RED}***Recommended to leave default unless necessary to change***${NOCOLOR}\n"
                        printf "  ($option) Configure WAN0 Route Table      WAN0 Route Table: ${BLUE}$WAN0ROUTETABLE${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN1 Route Table      WAN1 Route Table: ${BLUE}$WAN1ROUTETABLE${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN0 Target Priority  WAN0 Target Priority: ${BLUE}$WAN0TARGETRULEPRIORITY${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN1 Target Priority  WAN1 Target Priority: ${BLUE}$WAN1TARGETRULEPRIORITY${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Recursive Ping Check  Recursive Ping Check: ${BLUE}$RECURSIVEPINGCHECK${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN Disabled Timer    WAN Disabled Timer: ${BLUE}$WANDISABLEDSLEEPTIMER Seconds${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Email Boot Delay      Email Boot Delay: ${BLUE}$SKIPEMAILSYSTEMUPTIME Seconds${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Email Timeout         Email Timeout: ${BLUE}$EMAILTIMEOUT Seconds${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Cron Job              Cron Job: " && { [[ "$SCHEDULECRONJOB" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure Status Check          Status Check Interval: ${BLUE}$STATUSCHECK Seconds${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "\n  ${BOLD}Load Balance Mode Settings:${NOCOLOR}\n"
                        printf "  ($option) Configure LB Rule Priority      Load Balance Rule Priority: ${BLUE}$LBRULEPRIORITY${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure OpenVPN Split Tunnel  OpenVPN Split Tunneling: " && { [[ "$OVPNSPLITTUNNEL" == "1" ]] >/dev/null 2>&1 && printf "${GREEN}Enabled${NOCOLOR}" || printf "${RED}Disabled${NOCOLOR}" ;} && printf "\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN0 OVPN Priority    WAN0 OVPN Priority: ${BLUE}$OVPNWAN0PRIORITY${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN1 OVPN Priority    WAN1 OVPN Priority: ${BLUE}$OVPNWAN1PRIORITY${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN0 FWMark           WAN0 FWMark: ${BLUE}$WAN0MARK${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN1 FWMark           WAN1 FWMark: ${BLUE}$WAN1MARK${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN0 Mask             WAN0 Mask: ${BLUE}$WAN0MASK${NOCOLOR}\n"
                        option="$(($option+1))"
                        printf "  ($option) Configure WAN1 Mask             WAN1 Mask: ${BLUE}$WAN1MASK${NOCOLOR}\n"

	                printf "\n  (e)  Main Menu                       Return to Main Menu\n"
                        printf "\nMake a selection: "

                        # Set Variables for Configuration Menu
                        [ -z "${NEWVARIABLES+x}" ] >/dev/null 2>&1 && NEWVARIABLES=""
                        [ -z "${RESTARTREQUIRED+x}" ] >/dev/null 2>&1 && RESTARTREQUIRED="0"
	                read -r configinput
	                case "${configinput}" in
		                 '1')      # WAN0TARGET
                                           while true >/dev/null 2>&1;do  
                                           read -p "Configure WAN0 Target IP Address - Will be routed via "$(nvram get wan0_gateway & nvramcheck)" dev "$(nvram get wan0_gw_ifname & nvramcheck)": " ip
                                           if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null 2>&1;then
                                             for i in 1 2 3 4;do
                                               if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null 2>&1;then
                                                 echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
                                                 logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Address: "$ip" is an Invalid IP Address"
                                                 break 1
                                               elif [[ "$(nvram get wan0_gateway & nvramcheck)" == "$ip" ]] >/dev/null 2>&1;then
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
                                         [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '2')      # WAN1TARGET
                                           while true >/dev/null 2>&1;do  
                                           read -p "Configure WAN1 Target IP Address - Will be routed via "$(nvram get wan1_gateway & nvramcheck)" dev "$(nvram get wan1_gw_ifname & nvramcheck)": " ip
                                           if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null 2>&1;then
                                             for i in 1 2 3 4;do
                                               if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null 2>&1;then
                                                 echo -e "${RED}***"$ip" is an Invalid IP Address***${NOCOLOR}"
                                                 logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Address: "$ip" is an Invalid IP Address"
                                                 break 1
                                               elif [[ "$(nvram get wan1_gateway & nvramcheck)" == "$ip" ]] >/dev/null 2>&1;then
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
                                         [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '3')      # PINGCOUNT
                                           while true >/dev/null 2>&1;do  
                                             read -p "Configure Ping Count - This is how many consecutive times a ping will fail before a WAN connection is considered disconnected: " value
                                             case $value in
                                               [0123456789]* ) SETPINGCOUNT=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter a valid number***${NOCOLOR}"
                                             esac
                                           done
                                         NEWVARIABLES="${NEWVARIABLES} PINGCOUNT=|$SETPINGCOUNT"
                                         [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '4')      # PINGTIMEOUT
                                           while true >/dev/null 2>&1;do  
                                             read -p "Configure Ping Timeout - Value is in seconds: " value
                                             case $value in
                                               [0123456789]* ) SETPINGTIMEOUT=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                         NEWVARIABLES="${NEWVARIABLES} PINGTIMEOUT=|$SETPINGTIMEOUT"
                                         [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '5')      # PINGTIMEMIN
                                           while true >/dev/null 2>&1;do  
                                             read -p "Configure Minimum Ping Time - Value is in milliseconds: " value
                                             case $value in
                                               [0123456789]* ) SETPINGTIMEMIN=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in milliseconds***${NOCOLOR}"
                                             esac
                                           done
                                         NEWVARIABLES="${NEWVARIABLES} PINGTIMEMIN=|$SETPINGTIMEMIN"
                                 ;;
		                 '6')      # PINGTIMEMAX
                                           while true >/dev/null 2>&1;do  
                                             read -p "Configure Maximum Ping Time - Value is in milliseconds: " value
                                             case $value in
                                               [0123456789]* ) SETPINGTIMEMAX=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in milliseconds***${NOCOLOR}"
                                             esac
                                           done
                                         NEWVARIABLES="${NEWVARIABLES} PINGTIMEMAX=|$SETPINGTIMEMAX"
                                 ;;
		                 '7')      # WAN0_QOS_ENABLE

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable QoS for WAN0? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETWAN0_QOS_ENABLE=1;;
                                               [Nn]* ) SETWAN0_QOS_ENABLE=0;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                             [[ "$SETWAN0_QOS_ENABLE" == "0" ]] >/dev/null 2>&1 && { SETWAN0_QOS_IBW=0 ; SETWAN0_QOS_OBW=0 ;} && break 1
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
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '8')      # WAN1_QOS_ENABLE

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable QoS for WAN1? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETWAN1_QOS_ENABLE=1;;
                                               [Nn]* ) SETWAN1_QOS_ENABLE=0;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                             [[ "$SETWAN1_QOS_ENABLE" == "0" ]] >/dev/null 2>&1 && { SETWAN1_QOS_IBW=0 ; SETWAN1_QOS_OBW=0 ;} && break 1
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
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '9')      # PACKETLOSSLOGGING

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable Packet Loss Logging? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETPACKETLOSSLOGGING=1; break;;
                                               [Nn]* ) SETPACKETLOSSLOGGING=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} PACKETLOSSLOGGING=|$SETPACKETLOSSLOGGING"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '10')      # BOOTDELAYTIMER

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Boot Delay Timer - This will delay the script from executing until System Uptime reaches this time (seconds): " value
                                             case $value in
                                               [0123456789]* ) SETBOOTDELAYTIMER=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} BOOTDELAYTIMER=|$SETBOOTDELAYTIMER"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '11')      # SENDEMAIL

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable Email Notifications? ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETSENDEMAIL=1; break;;
                                               [Nn]* ) SETSENDEMAIL=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} SENDEMAIL=|$SETSENDEMAIL"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '12')      # WAN0PACKETSIZE

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Packet Size - This defines the Packet Size (Bytes) for pinging the WAN0 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0PACKETSIZE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0PACKETSIZE=|$SETWAN0PACKETSIZE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '13')      # WAN1PACKETSIZE

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Packet Size - This defines the Packet Size (Bytes) for pinging the WAN1 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1PACKETSIZE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1PACKETSIZE=|$SETWAN1PACKETSIZE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '14')      # CHECKNVRAM

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable NVRAM Checks? This defines if the Script is set to perform NVRAM checks before peforming key functions: ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETCHECKNVRAM=1; break;;
                                               [Nn]* ) SETCHECKNVRAM=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} CHECKNVRAM=|$SETCHECKNVRAM"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '15')      # DEVMODE

                                           while true >/dev/null 2>&1;do
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

                                           while true >/dev/null 2>&1;do
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

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Route Table - This defines the Routing Table for WAN0, it is recommended to leave this default unless necessary to change: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0ROUTETABLE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0ROUTETABLE=|$SETWAN0ROUTETABLE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '18')      # WAN1ROUTETABLE

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Route Table - This defines the Routing Table for WAN1, it is recommended to leave this default unless necessary to change: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1ROUTETABLE=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1ROUTETABLE=|$SETWAN1ROUTETABLE"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '19')      # WAN0TARGETRULEPRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Target Rule Priority - This defines the IP Rule Priority for the WAN0 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN0TARGETRULEPRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0TARGETRULEPRIORITY=|$SETWAN0TARGETRULEPRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '20')      # WAN1TARGETRULEPRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Target Rule Priority - This defines the IP Rule Priority for the WAN1 Target IP Address: " value
                                             case $value in
                                               [0123456789]* ) SETWAN1TARGETRULEPRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1TARGETRULEPRIORITY=|$SETWAN1TARGETRULEPRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '21')      # RECURSIVEPINGCHECK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Recursive Ping Check - This defines how many times a WAN Interface has to fail target pings to be considered failed (Ping Count x RECURSIVEPINGCHECK), this setting is for circumstances where ICMP Echo / Response can be disrupted by ISP DDoS Prevention or other factors.  It is recommended to leave this setting default: " value
                                             case $value in
                                               [0123456789]* ) SETRECURSIVEPINGCHECK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} RECURSIVEPINGCHECK=|$SETRECURSIVEPINGCHECK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '22')      # WANDISABLEDSLEEPTIMER

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN Disabled Sleep Timer - This is how many seconds the WAN Failover pauses and checks again if Dual WAN, Failover/Load Balance Mode, or WAN links are disabled/disconnected: " value
                                             case $value in
                                               [0123456789]* ) SETWANDISABLEDSLEEPTIMER=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WANDISABLEDSLEEPTIMER=|$SETWANDISABLEDSLEEPTIMER"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '23')      # SKIPEMAILSYSTEMUPTIME

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Email Boot Delay Timer - This will delay sending emails while System Uptime is less than this time: " value
                                             case $value in
                                               [0123456789]* ) SETSKIPEMAILSYSTEMUPTIME=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} SKIPEMAILSYSTEMUPTIME=|$SETSKIPEMAILSYSTEMUPTIME"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '24')      # EMAILTIMEOUT

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Email Timeout - This defines the timeout for sending an email after a Failover event: " value
                                             case $value in
                                               [0123456789]* ) SETEMAILTIMEOUT=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} EMAILTIMEOUT=|$SETEMAILTIMEOUT"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '25')      # SCHEDULECRONJOB

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable Cron Job? This defines if the script will create the Cron Job: ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SCHEDULECRONJOB=1; break;;
                                               [Nn]* ) SCHEDULECRONJOB=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} SCHEDULECRONJOB=|$SCHEDULECRONJOB"
                                 ;;
		                 '26')      # STATUSCHECK
                                           while true >/dev/null 2>&1;do  
                                             read -p "Configure Status Check Interval - Value is in seconds: " value
                                             case $value in
                                               [0123456789]* ) SETSTATUSCHECK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
                                             esac
                                           done
                                         NEWVARIABLES="${NEWVARIABLES} STATUSCHECK=|$SETSTATUSCHECK"
                                 ;;
		                 '26')      # LBRULEPRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure Load Balance Rule Priority - This defines the IP Rule priority for Load Balance Mode, it is recommended to leave this default unless necessary to change: " value
                                             case $value in
                                               [0123456789]* ) SETLBRULEPRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} LBRULEPRIORITY=|$SETLBRULEPRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '27')      # OVPNSPLITTUNNEL

                                           while true >/dev/null 2>&1;do
                                             read -p "Do you want to enable OpenVPN Split Tunneling? This will enable or disable OpenVPN Split Tunneling while in Load Balance Mode: ***Enter Y for Yes or N for No***" yn
                                             case $yn in
                                               [Yy]* ) SETOVPNSPLITTUNNEL=1; break;;
                                               [Nn]* ) SETOVPNSPLITTUNNEL=0; break;;
                                               * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} OVPNSPLITTUNNEL=|$SETOVPNSPLITTUNNEL"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '28')      # OVPNWAN0PRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure OpenVPN WAN0 Priority - This defines the OpenVPN Tunnel Priority for WAN0 if OVPNSPLITTUNNEL is Disabled: " value
                                             case $value in
                                               [0123456789]* ) SETOVPNWAN0PRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} OVPNWAN0PRIORITY=|$SETOVPNWAN0PRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '29')      # OVPNWAN1PRIORITY

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure OpenVPN WAN1 Priority - This defines the OpenVPN Tunnel Priority for WAN1 if OVPNSPLITTUNNEL is Disabled: " value
                                             case $value in
                                               [0123456789]* ) SETOVPNWAN1PRIORITY=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} OVPNWAN1PRIORITY=|$SETOVPNWAN1PRIORITY"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '30')      # WAN0MARK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 FWMark - This defines the WAN0 FWMark for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN0MARK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0MARK=|$SETWAN0MARK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '31')      # WAN1MARK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 FWMark - This defines the WAN1 FWMark for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN1MARK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1MARK=|$SETWAN1MARK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '32')      # WAN0MASK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN0 Mask - This defines the WAN0 Mask for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN0MASK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN0MASK=|$SETWAN0MASK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;
		                 '33')      # WAN1MASK

                                           while true >/dev/null 2>&1;do
                                             read -p "Configure WAN1 Mask - This defines the WAN1 Mask for Load Balance Mode: " value
                                             case $value in
                                               [0123456789xf]* ) SETWAN1MASK=$value; break;;
                                               * ) echo -e "${RED}Invalid Selection!!!***${NOCOLOR}"
                                             esac
                                           done
                                           NEWVARIABLES="${NEWVARIABLES} WAN1MASK=|$SETWAN1MASK"
                                           [[ "$RESTARTREQUIRED" == "0" ]] >/dev/null 2>&1 && RESTARTREQUIRED=1
                                 ;;


	      	                 'e'|'E'|'exit'|'menu')
                                 clear
		                 menu
                                 break
		                 ;;


                        esac

                        # Configure Changed Setting in Configuration File
                        if [ ! -z "$NEWVARIABLES" ] >/dev/null 2>&1;then
                          for NEWVARIABLE in ${NEWVARIABLES};do
                            if [ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] >/dev/null 2>&1 && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] >/dev/null 2>&1;then
                              echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
                              sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
                            elif [ ! -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] >/dev/null 2>&1 && [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" != "CUSTOMLOGPATH=" ]] >/dev/null 2>&1;then
                              sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
                            elif [[ "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" == "CUSTOMLOGPATH=" ]] >/dev/null 2>&1;then
                              [ ! -z "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1 && sed -i '/CUSTOMLOGPATH=/d' $CONFIGFILE
                              echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')" >> $CONFIGFILE
                            fi
                          done
                          [[ "$RESTARTREQUIRED" == "1" ]] >/dev/null 2>&1 && echo -e "${RED}***This change will require WAN Failover to restart to take effect***${NOCOLOR}"
                        fi
                        # Unset Variables
                        [ ! -z "${NEWVARIABLES+x}" ] >/dev/null 2>&1 && unset NEWVARIABLES
                        [ ! -z "${configinput+x}" ] >/dev/null 2>&1 && unset configinput
                        [ ! -z "${value+x}" ] >/dev/null 2>&1 && unset value
                        [ ! -z "${RESTARTREQUIRED+x}" ] >/dev/null 2>&1 && unset RESTARTREQUIRED
	                PressEnter
	                menu
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
                        echo -e ""${BOLD}"${GREEN}$ALIAS - Monitor Mode${NOCOLOR}"
                        trap 'menu' EXIT HUP INT QUIT TERM
			monitor
		;;
		'11')   # capture
			mode="capture"
                        echo -e ""${BOLD}"${GREEN}$ALIAS - Capture Mode${NOCOLOR}"
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
			Red "$input is not a valid option!"
		;;
	esac
	PressEnter
	menu

}

PressEnter()
{
	printf "\n"
	while true >/dev/null 2>&1; do
		printf "Press Enter to continue..."
		read -r "key"
		case "${key}" in
			*)
				break
			;;
		esac
	done
        [[ "$mode" != "menu" ]] >/dev/null 2>&1 && mode=menu
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
'

# Firmware Version Check
logger -p 6 -t "$ALIAS" "Debug - Firmware: "$(nvram get buildno & nvramcheck)""
for FWVERSION in ${FWVERSIONS};do
  if [[ "$FIRMWARE" == "merlin" ]] >/dev/null 2>&1 && [[ "$BUILDNO" == "$FWVERSION" ]] >/dev/null 2>&1;then
    break
  elif [[ "$FIRMWARE" == "merlin" ]] >/dev/null 2>&1 && [ ! -z "$(echo "${FWVERSIONS}" | grep -w "$BUILDNO")" ] >/dev/null 2>&1;then
    continue
  else
    logger -p 3 -st "$ALIAS" "System Check - ***"$BUILDNO" is not supported, issues may occur from running this version***"
  fi
done

# IPRoute Version Check
logger -p 5 -t "$ALIAS" "System Check - IP Version: "$IPVERSION""

# JFFS Custom Scripts Enabled Check
logger -p 6 -t "$ALIAS" "Debug - JFFS custom scripts and configs: "$JFFSSCRIPTS""
if [[ "$JFFSSCRIPTS" != "1" ]] >/dev/null 2>&1;then
  logger -p 3 -st "$ALIAS" "System Check - ***JFFS custom scripts and configs not Enabled***"
fi

# Check Alias
logger -p 6 -t "$ALIAS" "Debug - Checking Alias in /jffs/configs/profile.add"
if [ ! -f "/jffs/configs/profile.add" ] >/dev/null 2>&1;then
  logger -p 5 -st "$ALIAS" "System Check - Creating /jffs/configs/profile.add"
  touch -a /jffs/configs/profile.add \
  && chmod 666 /jffs/configs/profile.add \
  && logger -p 4 -st "$ALIAS" "System Check - Created /jffs/configs/profile.add" \
  || logger -p 2 -st "$ALIAS" "System Check - ***Error*** Unable to create /jffs/configs/profile.add"
fi
if [ -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
  logger -p 5 -st "$ALIAS" "System Check - Creating Alias for "$0" as wan-failover"
  echo -e "alias wan-failover=\"sh $0\" # Wan-Failover" >> /jffs/configs/profile.add \
  && source /jffs/configs/profile.add \
  && logger -p 4 -st "$ALIAS" "System Check - Created Alias for "$0" as wan-failover" \
  || logger -p 2 -st "$ALIAS" "System Check - ***Error*** Unable to create Alias for "$0" as wan-failover"
fi

# Check Configuration File
logger -p 6 -t "$ALIAS" "Debug - Checking for Configuration File: "$CONFIGFILE""
if [ ! -f "$CONFIGFILE" ] >/dev/null 2>&1;then
  echo -e ""${BOLD}"${RED}$ALIAS - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  logger -p 2 -t "$ALIAS" "System Check - ***No Configuration File Detected - Run Install Mode***"
  exit
fi

# Turn off email notification for initial load of WAN Failover
if [ -z "${email+x}" ] >/dev/null 2>&1;then
  email=0
fi
return
}

# Get System Parameters
getsystemparameters ()
{
# Get Global System Parameters
while [ -z "${systemparameterssync+x}" ] >/dev/null 2>&1 || [[ "$systemparameterssync" == "0" ]] >/dev/null 2>&1;do
  if [ -z "${systemparameterssync+x}" ] >/dev/null 2>&1;then
    systemparameterssync=0
  elif [[ "$systemparameterssync" == "1" ]] >/dev/null 2>&1;then
    break
  fi

  # MODEL
  if [ -z "${MODEL+x}" ] >/dev/null 2>&1;then
    MODEL="$(nvram get model & nvramcheck)"
    [ ! -z "$MODEL" ] >/dev/null 2>&1 || { unset MODEL && continue ;}
  fi

  # PRODUCTID
  if [ -z "${PRODUCTID+x}" ] >/dev/null 2>&1;then
    PRODUCTID="$(nvram get productid & nvramcheck)"
    [ ! -z "$PRODUCTID" ] >/dev/null 2>&1 || { unset PRODUCTID && continue ;}
  fi

  # BUILDNAME
  if [ -z "${BUILDNAME+x}" ] >/dev/null 2>&1;then
    BUILDNAME="$(nvram get build_name & nvramcheck)"
    [ ! -z "$BUILDNAME" ] >/dev/null 2>&1 || { unset BUILDNAME && continue ;}
  fi

  # FIRMWARE
  if [ -z "${FIRMWARE+x}" ] >/dev/null 2>&1;then
    FIRMWARE="$(nvram get 3rd-party & nvramcheck)"
    [ ! -z "$FIRMWARE" ] >/dev/null 2>&1 || { unset FIRMWARE && continue ;}
  fi

  # BUILDNO
  if [ -z "${BUILDNO+x}" ] >/dev/null 2>&1;then
    BUILDNO="$(nvram get buildno & nvramcheck)"
    [ ! -z "$BUILDNO" ] >/dev/null 2>&1 || { unset BUILDNO && continue ;}
  fi

  # LANHOSTNAME
  if [ -z "${LANHOSTNAME+x}" ] >/dev/null 2>&1;then
    LANHOSTNAME="$(nvram get lan_hostname & nvramcheck)"
    [ ! -z "$LANHOSTNAME" ] >/dev/null 2>&1 || { unset LANHOSTNAME && continue ;}
  fi

  # JFFSSCRIPTS
  if [ -z "${JFFSSCRIPTS+x}" ] >/dev/null 2>&1;then
    JFFSSCRIPTS="$(nvram get jffs2_scripts & nvramcheck)"
    [ ! -z "$JFFSSCRIPTS" ] >/dev/null 2>&1 || { unset JFFSSCRIPTS && continue ;}
  fi

  # IPVERSION
  if [ -z "${IPVERSION+x}" ] >/dev/null 2>&1;then
    IPVERSION="$(ip -V | awk -F "-" '{print $2}')"
    [ ! -z "$IPVERSION" ] >/dev/null 2>&1 || { unset IPVERSION && continue ;}
  fi

  systemparameterssync=1
done

# Get Active System Parameters
while [ -z "${activesystemsync+x}" ] >/dev/null 2>&1 || [[ "$activesystemsync" == "0" ]] >/dev/null 2>&1;do
  activesystemsync=0

  # HTTPENABLE
  if [ -z "${HTTPENABLE+x}" ] >/dev/null 2>&1 || [ -z "${zHTTPENABLE+x}" ] >/dev/null 2>&1;then
    HTTPENABLE="$(nvram get misc_http_x & nvramcheck)"
    [ ! -z "$HTTPENABLE" ] >/dev/null 2>&1 \
    && zHTTPENABLE="$HTTPENABLE" \
    || { unset HTTPENABLE ; unset zHTTPENABLE && continue ;}
  else
    [[ "$zHTTPENABLE" != "$HTTPENABLE" ]] >/dev/null 2>&1 && zHTTPENABLE="$HTTPENABLE"
    HTTPENABLE="$(nvram get misc_http_x & nvramcheck)"
    [ ! -z "$HTTPENABLE" ] >/dev/null 2>&1 || HTTPENABLE="$zHTTPENABLE"
  fi

  # FIREWALLENABLE
  if [ -z "${FIREWALLENABLE+x}" ] >/dev/null 2>&1 || [ -z "${zFIREWALLENABLE+x}" ] >/dev/null 2>&1;then
    FIREWALLENABLE="$(nvram get fw_enable_x & nvramcheck)"
    [ ! -z "$FIREWALLENABLE" ] >/dev/null 2>&1 \
    && zFIREWALLENABLE="$FIREWALLENABLE" \
    || { unset FIREWALLENABLE ; unset zFIREWALLENABLE && continue ;}
  else
    [[ "$zFIREWALLENABLE" != "$FIREWALLENABLE" ]] >/dev/null 2>&1 && zFIREWALLENABLE="$FIREWALLENABLE"
    FIREWALLENABLE="$(nvram get fw_enable_x & nvramcheck)"
    [ ! -z "$FIREWALLENABLE" ] >/dev/null 2>&1 || FIREWALLENABLE="$zFIREWALLENABLE"
  fi

  # IPV6FIREWALLENABLE
  if [ -z "${IPV6FIREWALLENABLE+x}" ] >/dev/null 2>&1 || [ -z "${zIPV6FIREWALLENABLE+x}" ] >/dev/null 2>&1;then
    IPV6FIREWALLENABLE="$(nvram get ipv6_fw_enable & nvramcheck)"
    [ ! -z "$IPV6FIREWALLENABLE" ] >/dev/null 2>&1 \
    && zIPV6FIREWALLENABLE="$IPV6FIREWALLENABLE" \
    || { unset IPV6FIREWALLENABLE ; unset zIPV6FIREWALLENABLE && continue ;}
  else
    [[ "$zIPV6FIREWALLENABLE" != "$IPV6FIREWALLENABLE" ]] >/dev/null 2>&1 && zIPV6FIREWALLENABLE="$IPV6FIREWALLENABLE"
    IPV6FIREWALLENABLE="$(nvram get ipv6_fw_enable & nvramcheck)"
    [ ! -z "$IPV6FIREWALLENABLE" ] >/dev/null 2>&1 || IPV6FIREWALLENABLE="$zIPV6FIREWALLENABLE"
  fi

  # LEDDISABLE
  if [ -z "${LEDDISABLE+x}" ] >/dev/null 2>&1 || [ -z "${zLEDDISABLE+x}" ] >/dev/null 2>&1;then
    LEDDISABLE="$(nvram get led_disable & nvramcheck)"
    [ ! -z "$LEDDISABLE" ] >/dev/null 2>&1 \
    && zLEDDISABLE="$LEDDISABLE" \
    || { unset LEDDISABLE ; unset zLEDDISABLE && continue ;}
  else
    [[ "$zLEDDISABLE" != "$LEDDISABLE" ]] >/dev/null 2>&1 && zLEDDISABLE="$LEDDISABLE"
    LEDDISABLE="$(nvram get led_disable & nvramcheck)"
    [ ! -z "$LEDDISABLE" ] >/dev/null 2>&1 || LEDDISABLE="$zLEDDISABLE"
  fi

  # LOGLEVEL
  if [ -z "${LOGLEVEL+x}" ] >/dev/null 2>&1 || [ -z "${zLOGLEVEL+x}" ] >/dev/null 2>&1;then
    LOGLEVEL="$(nvram get log_level & nvramcheck)"
    [ ! -z "$LOGLEVEL" ] >/dev/null 2>&1 \
    && zLOGLEVEL="$LOGLEVEL" \
    || { unset LOGLEVEL ; unset zLOGLEVEL && continue ;}
  else
    [[ "$zLOGLEVEL" != "$LOGLEVEL" ]] >/dev/null 2>&1 && zLOGLEVEL="$LOGLEVEL"
    LOGLEVEL="$(nvram get log_level & nvramcheck)"
    [ ! -z "$LOGLEVEL" ] >/dev/null 2>&1 || LOGLEVEL="$zLOGLEVEL"
  fi

  # DDNSENABLE
  if [ -z "${DDNSENABLE+x}" ] >/dev/null 2>&1 || [ -z "${zDDNSENABLE+x}" ] >/dev/null 2>&1;then
    DDNSENABLE="$(nvram get ddns_enable_x & nvramcheck)"
    [ ! -z "$DDNSENABLE" ] >/dev/null 2>&1 \
    && zDDNSENABLE="$DDNSENABLE" \
    || { unset DDNSENABLE ; unset zDDNSENABLE && continue ;}
  else
    [[ "$zDDNSENABLE" != "$DDNSENABLE" ]] >/dev/null 2>&1 && zDDNSENABLE="$DDNSENABLE"
    DDNSENABLE="$(nvram get ddns_enable_x & nvramcheck)"
    [ ! -z "$DDNSENABLE" ] >/dev/null 2>&1 || DDNSENABLE="$zDDNSENABLE"
  fi

  # DDNSHOSTNAME
  if [ -z "${DDNSHOSTNAME+x}" ] >/dev/null 2>&1 || [ -z "${zDDNSHOSTNAME+x}" ] >/dev/null 2>&1;then
    DDNSHOSTNAME="$(nvram get ddns_hostname_x & nvramcheck)"
    [ ! -z "$DDNSHOSTNAME" ] >/dev/null 2>&1 \
    && zDDNSHOSTNAME="$DDNSHOSTNAME" \
    || { unset DDNSHOSTNAME ; unset zDDNSHOSTNAME && continue ;}
  else
    [[ "$zDDNSHOSTNAME" != "$DDNSHOSTNAME" ]] >/dev/null 2>&1 && zDDNSHOSTNAME="$DDNSHOSTNAME"
    DDNSHOSTNAME="$(nvram get ddns_hostname_x & nvramcheck)"
    [ ! -z "$DDNSHOSTNAME" ] >/dev/null 2>&1 || DDNSHOSTNAME="$zDDNSHOSTNAME"
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
if [[ "$(echo $PATH | awk -F ":" '{print $1":"$2":"$3":"$4":"}')" != "/sbin:/bin:/usr/sbin:/usr/bin:" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting System Binaries Path"
  export PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH
  logger -p 6 -t "$ALIAS" "Debug - PATH: "$PATH""g
fi
return
}

# Install
install ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: Install"

# Prompt for Confirmation to Install
while [[ "${mode}" == "install" ]] >/dev/null 2>&1;do
  read -p "Do you want to install WAN Failover? ***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) return;;
    * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
  esac
done

# Get System Parameters
getsystemparameters || return

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Check for Config File
if [ ! -f $CONFIGFILE ] >/dev/null 2>&1;then
  echo -e "${BLUE}Creating $CONFIGFILE...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating $CONFIGFILE"
  { touch -a $CONFIGFILE && chmod 666 $CONFIGFILE && setvariables || return ;} \
  && { echo -e "${GREEN}$CONFIGFILE created successfully.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $CONFIGFILE created successfully" ;} \
  || { echo -e "${RED}$CONFIGFILE failed to create.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $CONFIGFILE failed to create" ;}
else
  echo -e "${YELLOW}$CONFIGFILE already exists...${NOCOLOR}" ; logger -p 4 -t "$ALIAS" "Install - $CONFIGFILE already exists"
  setvariables || return
fi

# Create Wan-Event if it doesn't exist
if [ ! -f "/jffs/scripts/wan-event" ] >/dev/null 2>&1;then
  echo -e "${BLUE}Creating wan-event script...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating wan-event script"
  { touch -a /jffs/scripts/wan-event && chmod 775 /jffs/scripts/wan-event && echo "#!/bin/sh" >> /jffs/scripts/wan-event ;} \
  && { echo -e "${GREEN}wan-event script has been created.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - wan-event script has been created" ;} \
  || { echo -e "${RED}wan-event script failed to create.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - wan-event script failed to create" ;}
else
  echo -e "${YELLOW}wan-event script already exists...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - wan-event script already exists"
fi

# Add Script to Wan-event
if [ ! -z "$(cat /jffs/scripts/wan-event | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then 
  echo -e "${GREEN}$ALIAS already added to wan-event...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $ALIAS already added to wan-event"
else
  echo -e "${BLUE}Adding $ALIAS to wan-event...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Adding $ALIAS to wan-event"
  { cmdline="sh $0 cron" && echo -e "\r\n$cmdline # Wan-Failover" >> /jffs/scripts/wan-event ;} \
  && { echo -e "${GREEN}$ALIAS added to wan-event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $ALIAS added to wan-event" ;} \
  || { echo -e "${RED}$ALIAS failed to add to wan-event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - $ALIAS failed to add to wan-event" ;}
fi

# Create /jffs/configs/profile.add if it doesn't exist
if [ ! -f "/jffs/configs/profile.add" ] >/dev/null 2>&1;then
  echo -e "${BLUE}Creating /jffs/configs/profile.add...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating /jffs/configs/profile.add"
  { touch -a /jffs/configs/profile.add && chmod 666 /jffs/configs/profile.add ;} \
  && { echo -e "${GREEN}/jffs/configs/profile.add has been created.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - /jffs/configs/profile.add has been created" ;} \
  || { echo -e "${RED}/jffs/configs/profile.add failed to be created.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - /jffs/configs/profile.add failed to be created" ;}
else
  echo -e "${GREEN}/jffs/configs/profile.add already exists...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - /jffs/configs/profile.add already exists"
fi

# Create Alias
if [ -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
  echo -e "${BLUE}${0##*/} - Install: Creating Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Creating Alias for "$0" as wan-failover"
  { echo -e "alias wan-failover=\"sh $0\" # Wan-Failover" >> /jffs/configs/profile.add && source /jffs/configs/profile.add ;} \
  && { echo -e "${GREEN}${0##*/} - Install: Created Alias for "$0" as wan-failover...${NOCOLOR}" && logger -p 5 -t "$ALIAS" "Install - Created Alias for "$0" as wan-failover" ;} \
  || { echo -e "${RED}${0##*/} - Install: Failed to create Alias for "$0" as wan-failover...${NOCOLOR}" && logger -p 5 -t "$ALIAS" "Install - Failed to create Alias for "$0" as wan-failover" ;}
fi

# Create Initial Cron Jobs
cronjob &

# Check if Dual WAN is Enabled
if [[ "$WANSDUALWANENABLE" == "0" ]] >/dev/null 2>&1;then
  echo -e "${RED}***Warning***  Dual WAN is not Enabled.${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Dual WAN is not Enabled"
elif [[ "$WANSDUALWANENABLE" == "1" ]] >/dev/null 2>&1;then
  echo -e "${GREEN}Dual WAN is Enabled.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Dual WAN is Enabled"
fi

# Check if Dual WAN is Enabled
if [[ "$WANDOGENABLE" == "1" ]] >/dev/null 2>&1;then
  echo -e "${RED}***Warning***  Factory WAN Failover Enabled.${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Factory WAN Failover Enabled"
  echo -e "${RED}***Warning***  Disable WAN > Dual WAN > Basic Config > Allow failback${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Disable WAN > Dual WAN > Basic Config > Allow failback"
  echo -e "${RED}***Warning***  Disable WAN > Dual WAN > Auto Network Detection > Network Monitoring${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Disable WAN > Dual WAN > Auto Network Detection > Network Monitoring"
elif [[ "$WANDOGENABLE" == "0" ]] >/dev/null 2>&1;then
  echo -e "${GREEN}Factory WAN Failover Disabled.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Factory WAN Failover Disabled"
fi

# Check if JFFS Custom Scripts is enabled during installation
if [[ "$JFFSSCRIPTS" == "0" ]] >/dev/null 2>&1;then
  echo -e "${RED}***Warning***  Administration > System > Enable JFFS custom scripts and configs is not enabled.${NOCOLOR}" ; logger -p 3 -t "$ALIAS" "Install - ***Warning***  Administration > System > Enable JFFS custom scripts and configs is not enabled"
elif [[ "$JFFSSCRIPTS" == "1" ]] >/dev/null 2>&1;then
  echo -e "${GREEN}Administration > System > Enable JFFS custom scripts and configs is enabled...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Install - Administration > System > Enable JFFS custom scripts and configs is enabled"
fi

return
}

# Uninstall
uninstall ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: Uninstall"
if [[ "${mode}" == "uninstall" ]] >/dev/null 2>&1;then
read -n 1 -s -r -p "Press any key to continue to uninstall..."
  # Remove Cron Job
  $(cronjob >/dev/null &)

  # Check for Configuration File
  if [ -f $CONFIGFILE ] >/dev/null 2>&1;then
    # Load Variables from Configuration first for Cleanup
    . $CONFIGFILE

    # Prompt for Deleting Config File
    while true >/dev/null 2>&1;do  
      read -p "Do you want to keep WAN Failover Configuration? ***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
      case $yn in
        [Yy]* ) deleteconfig="1" && break;;
        [Nn]* ) deleteconfig="0" && break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
    done
    [ -z "${deleteconfig+x}" ] >/dev/null 2>&1 && deleteconfig="1"
    # Delete Config File or Retain
    if [[ "$deleteconfig" == "1" ]] >/dev/null 2>&1;then
      echo -e "${BLUE}${0##*/} - Uninstall: Deleting $CONFIGFILE...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Deleting $CONFIGFILE"
      rm -f $CONFIGFILE \
      && { echo -e "${GREEN}${0##*/} - Uninstall: $CONFIGFILE deleted.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $CONFIGFILE deleted" ;} \
      || { echo -e "${RED}${0##*/} - Uninstall: $CONFIGFILE failed to delete.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $CONFIGFILE failed to delete" ;}
    elif [[ "$deleteconfig" == "0" ]] >/dev/null 2>&1;then
      echo -e "${GREEN}${0##*/} - Uninstall: Configuration file will be kept at $CONFIGFILE.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Configuration file will be kept at $CONFIGFILE"
    fi
  fi

  # Remove Script from Wan-event
  cmdline="sh $0 cron"
  if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ] >/dev/null 2>&1;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Wan-Event...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removing Cron Job from Wan-Event"
    sed -i '\~# Wan-Failover~d' /jffs/scripts/wan-event \
    && { echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Wan-Event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removed Cron Job from Wan-Event" ;} \
    || { echo -e "${RED}${0##*/} - Uninstall: Failed to remove Cron Job from Wan-Event.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Failed to remove Cron Job from Wan-Event" ;}
  fi

  # Remove Alias
  if [ ! -z "$(cat /jffs/configs/profile.add | grep -w "# Wan-Failover")" ] >/dev/null 2>&1;then
    { echo -e "${BLUE}${0##*/} - Uninstall: Removing Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removing Alias for "$0" as wan-failover" ;}
    { sed -i '\~# Wan-Failover~d' /jffs/configs/profile.add && source /jffs/configs/profile.add ;} \
    && { echo -e "${GREEN}${0##*/} - Uninstall: Removed Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Removed Alias for "$0" as wan-failover" ;} \
    || { echo -e "${RED}${0##*/} - Uninstall: Failed to remove Alias for "$0" as wan-failover...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Failed to remove Alias for "$0" as wan-failover" ;}
  fi

  # Check for Script File
  if [ -f $0 ] >/dev/null 2>&1;then
    { echo -e "${BLUE}${0##*/} - Uninstall: Deleting $0...${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - Deleting $0" ;}
    rm -f $0 \
    && { echo -e "${GREEN}${0##*/} - Uninstall: $0 deleted.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $0 deleted" ;} \
    || { echo -e "${RED}${0##*/} - Uninstall: $0 failed to delete.${NOCOLOR}" ; logger -p 5 -t "$ALIAS" "Uninstall - $0 failed to delete" ;}
  fi

  # Cleanup
  cleanup || continue

  # Kill Running Processes
  echo -e "${RED}Killing ${0##*/}...${NOCOLOR}" ; logger -p 0 -t "${0##*/}" "Uninstall - Killing ${0##*/}"
  sleep 3 && killall ${0##*/}
fi
return
}

# Cleanup
cleanup ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: cleanup"

for WANPREFIX in ${WANPREFIXES};do
  logger -p 6 -t "$ALIAS" "Debug - Setting parameters for "${WANPREFIX}""

  if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null 2>&1;then
    TARGET="$WAN0TARGET"
    TABLE="$WAN0ROUTETABLE"
    GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
    GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
  elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null 2>&1;then
    TARGET="$WAN1TARGET"
    TABLE="$WAN1ROUTETABLE"
    GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
    GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
  fi

  # Delete WAN IP Rule
  logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for IP Rule to "$TARGET""
  if [ ! -z "$(ip rule list from all to "$TARGET" lookup "$TABLE")" ] >/dev/null 2>&1;then
    logger -p 5 -t "$ALIAS" "Cleanup - Deleting IP Rule for "$TARGET" to monitor "${WANPREFIX}""
    until [ -z "$(ip rule list from all to "$TARGET" lookup "$TABLE")" ] >/dev/null 2>&1;do
      ip rule del from all to $TARGET lookup $TABLE \
      && logger -p 4 -t "$ALIAS" "Cleanup - Deleted IP Rule for "$TARGET" to monitor "${WANPREFIX}"" \
      || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete IP Rule for "$TARGET" to monitor "${WANPREFIX}""
    done
  fi

  # Delete WAN Route for Target IP
  logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
  if [ ! -z "$(ip route list "$TARGET" via "$GATEWAY" dev "$GWIFNAME")" ] >/dev/null 2>&1;then
    logger -p 5 -t "$ALIAS" "Cleanup - Deleting route for "$TARGET" via "$GATEWAY" dev "$GWIFNAME""
    ip route del $TARGET via $GATEWAY dev $GWIFNAME \
    && logger -p 4 -t "$ALIAS" "Cleanup - Deleted route for "$TARGET" via "$GATEWAY" dev "$GWIFNAME"" \
    || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete route for "$TARGET" via "$GATEWAY" dev "$GWIFNAME""
  fi
done

# Remove Lock File
logger -p 6 -t "$ALIAS" "Debug - Checking for Lock File: "$LOCKFILE""
if [ -f "$LOCKFILE" ] >/dev/null 2>&1;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting "$LOCKFILE""
  rm -f "$LOCKFILE" \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted "$LOCKFILE"" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete "$LOCKFILE""
fi

# Delete Packet Loss Temp Files
logger -p 6 -t "$ALIAS" "Debug - Checking for "$WAN0PACKETLOSSFILE""
if [ -f "$WAN0PACKETLOSSFILE" ] >/dev/null 2>&1;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting "$WAN0PACKETLOSSFILE""
  rm -f $WAN0PACKETLOSSFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted "$WAN0PACKETLOSSFILE"" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete "$WAN0PACKETLOSSFILE""
fi
logger -p 6 -t "$ALIAS" "Debug - Checking for "$WAN1PACKETLOSSFILE""
if [ -f "$WAN1PACKETLOSSFILE" ] >/dev/null 2>&1;then
  logger -p 5 -t "$ALIAS" "Cleanup - Deleting "$WAN1PACKETLOSSFILE""
  rm -f $WAN1PACKETLOSSFILE \
  && logger -p 4 -t "$ALIAS" "Cleanup - Deleted "$WAN1PACKETLOSSFILE"" \
  || logger -p 2 -t "$ALIAS" "Cleanup - ***Error*** Unable to delete "$WAN1PACKETLOSSFILE""
fi

return
}

# Kill Script
killscript ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: killscript"

if [[ "${mode}" == "restart" ]] >/dev/null 2>&1 || [[ "${mode}" == "update" ]] >/dev/null 2>&1 || [[ "${mode}" == "config" ]] >/dev/null 2>&1 || [[ "$[mode}" == "email" ]] >/dev/null 2>&1;then
  while [[ "${mode}" == "restart" ]] >/dev/null 2>&1;do
    read -p "Are you sure you want to restart WAN Failover? ***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  # Determine PIDs to kill
  logger -p 6 -t "$ALIAS" "Debug - Selecting PIDs to kill"
  PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"

  # Schedule CronJob  
  logger -p 6 -t "$ALIAS" "Debug - Calling CronJob to be rescheduled"
  $(cronjob >/dev/null &) || return

  logger -p 6 -t "$ALIAS" "Debug - ***Checking if PIDs array is null*** Process ID: "$PIDS""
  if [ ! -z "$PIDS" ] >/dev/null 2>&1;then
    # Schedule kill for Old PIDs
    logger -p 1 -st "$ALIAS" "Restart - Restarting ${0##*/} ***This can take up to approximately 1 minute***"
    logger -p 6 -t "$ALIAS" "Debug - Waiting to kill script until seconds into the minute are above 40 seconds or below 45 seconds"
    CURRENTSYSTEMUPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
    while [[ "$(date "+%S")" -lt "40" ]] >/dev/null 2>&1 || [[ "$(date "+%S")" -gt "45" ]] >/dev/null 2>&1;do
      [[ "${mode}" == "config" ]] >/dev/null 2>&1 && break 1
      [[ "${mode}" == "update" ]] >/dev/null 2>&1 && break 1
      if tty >/dev/null 2>&1;then
        WAITTIMER=$(($(awk -F "." '{print $1}' "/proc/uptime")-$CURRENTSYSTEMUPTIME))
        if [[ "$WAITTIMER" -lt "30" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting to kill ${0##*/}*** Current Wait Time: "${GREEN}""$WAITTIMER" Seconds"${NOCOLOR}""
        elif [[ "$WAITTIMER" -lt "60" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting to kill ${0##*/}*** Current Wait Time: "${YELLOW}""$WAITTIMER" Seconds"${NOCOLOR}""
        elif [[ "$WAITTIMER" -ge "60" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting to kill ${0##*/}*** Current Wait Time: "${RED}""$WAITTIMER" Seconds"${NOCOLOR}""
        fi
      fi
      sleep 1
    done
    # Kill PIDs
    until [ -z "$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')" ] >/dev/null 2>&1;do
      PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
      for PID in ${PIDS};do
        [ ! -z "$(ps | grep -m 1 -o "${PID}")" ] >/dev/null 2>&1 \
        && logger -p 1 -st "$ALIAS" "Restart - Killing ${0##*/} Process ID: "${PID}"" \
          && { kill -9 ${PID} \
          && { logger -p 1 -st "$ALIAS" "Restart - Killed ${0##*/} Process ID: "${PID}"" && continue ;} \
          || { [ -z "$(ps | grep -m 1 -o "${PID}")" ] >/dev/null 2>&1 && continue || logger -p 2 -st "$ALIAS" "Restart - ***Error*** Unable to kill ${0##*/} Process ID: "${PID}"" ;} ;} \
        || continue
      done
    done
    # Execute Cleanup
    . $CONFIGFILE
    cleanup || continue
  elif [ -z "$PIDS" ] >/dev/null 2>&1;then
    # Log no PIDs found and return
    logger -p 2 -st "$ALIAS" "Restart - ***${0##*/} is not running*** No Process ID Detected"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r\a' ""${BOLD}""${RED}"***${0##*/} is not running*** No Process ID Detected"${NOCOLOR}""
      sleep 3
      printf '\033[K'
    fi
  fi

  # Check for Restart from Cron Job
  RESTARTTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+120))"
  logger -p 5 -st "$ALIAS" "Restart - Waiting for ${0##*/} to restart from Cron Job"
  logger -p 6 -t "$ALIAS" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"
  logger -p 6 -t "$ALIAS" "Debug - Restart Timeout is in "$(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))" Seconds"
  while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$RESTARTTIMEOUT" ]] >/dev/null 2>&1;do
    PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
    if [ ! -z "$PIDS" ] >/dev/null 2>&1;then
      break
    elif [ -z "$PIDS" ] >/dev/null 2>&1;then
      if tty >/dev/null 2>&1;then
        TIMEOUTTIMER=$(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))
        if [[ "$TIMEOUTTIMER" -ge "60" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting for ${0##*/} to restart from Cron Job*** Timeout: "${GREEN}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        elif [[ "$TIMEOUTTIMER" -ge "30" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting for ${0##*/} to restart from Cron Job*** Timeout: "${YELLOW}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        elif [[ "$TIMEOUTTIMER" -ge "0" ]] >/dev/null 2>&1;then
          printf '\033[K%b\r' ""${BOLD}""${BLUE}"***Waiting for ${0##*/} to restart from Cron Job*** Timeout: "${RED}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        fi
      fi
      sleep 1
    fi
  done
  logger -p 6 -t "$ALIAS" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"

  # Check if script restarted
  logger -p 6 -t "$ALIAS" "Debug - Checking if "${0##*/}" restarted"
  PIDS="$(ps | grep -w "$0" | grep -w "run\|manual" | awk '{print $1}')"
  logger -p 6 -t "$ALIAS" "Debug - ***Checking if PIDs array is null*** Process ID(s): "$PIDS""
  if [ ! -z "$PIDS" ] >/dev/null 2>&1;then
    logger -p 1 -st "$ALIAS" "Restart - Successfully Restarted ${0##*/} Process ID(s): "$PIDS""
    if tty >/dev/null 2>&1;then
      printf '\033[K%b' ""${BOLD}""${GREEN}"Successfully Restarted ${0##*/} Process ID(s): "$(for PID in ${PIDS};do echo "${PID}\t";done)" "${NOCOLOR}"\r"
      sleep 10
      printf '\033[K'
    fi
  elif [ -z "$PIDS" ] >/dev/null 2>&1;then
    logger -p 1 -st "$ALIAS" "Restart - Failed to restart ${0##*/} ***Check Logs***"
    if tty >/dev/null 2>&1;then
      printf '\033[K%b\r\a' ""${BOLD}""${RED}"Failed to restart ${0##*/} ***Check Logs***"${NOCOLOR}""
      sleep 10
      printf '\033[K'
    fi
  fi
  return
elif [[ "${mode}" == "kill" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Calling CronJob to delete jobs"
  $(cronjob >/dev/null &)
  logger -p 0 -st "${0##*/}" "Kill - Killing ${0##*/}"
  # Execute Cleanup
  . $CONFIGFILE
  cleanup || continue
  killall ${0##*/}
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

# Determine Production or Beta Update Channel
if [[ "$DEVMODE" == "0" ]] >/dev/null 2>&1;then
  DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh"
elif [[ "$DEVMODE" == "1" ]] >/dev/null 2>&1;then
  DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover-beta.sh"
fi

# Determine if newer version is available
REMOTEVERSION="$(echo $(/usr/sbin/curl -s "$DOWNLOADPATH" | grep -v "grep" | grep -w "# Version:" | awk '{print $3}'))"
if [[ "$VERSION" != "$REMOTEVERSION" ]] >/dev/null 2>&1;then
  [[ "$DEVMODE" == "1" ]] >/dev/null 2>&1 && echo -e "${RED}***Dev Mode is Enabled***${NOCOLOR}"
  echo -e "${YELLOW}Script is out of date - Current Version: ${BLUE}"$VERSION"${YELLOW} Available Version: ${BLUE}"$REMOTEVERSION"${NOCOLOR}${NOCOLOR}"
  logger -p 3 -t "$ALIAS" "Script is out of date - Current Version: "$VERSION" Available Version: "$REMOTEVERSION""
  while true >/dev/null 2>&1;do
    if [[ "$DEVMODE" == "0" ]] >/dev/null 2>&1;then
      read -p "Do you want to update to the latest production version? "$REMOTEVERSION" ***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
    elif [[ "$DEVMODE" == "1" ]] >/dev/null 2>&1;then
      read -p "Do you want to update to the latest beta version? "$REMOTEVERSION" ***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
    fi
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  { /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" && chmod 755 $0 && killscript ;} \
  && logger -p 4 -st "$ALIAS" "Update - ${0##*/} has been updated to version: "$REMOTEVERSION"" \
  || logger -p 2 -st "$ALIAS" "Update - ***Error*** Unable to update to version: "$REMOTEVERSION""
elif [[ "$VERSION" == "$REMOTEVERSION" ]] >/dev/null 2>&1;then
  # Check Checksum of Script
  REMOTECHECKSUM="$(/usr/sbin/curl -s $DOWNLOADPATH | md5sum | awk '{print $1}')"
  if [[ "$CHECKSUM" == "$REMOTECHECKSUM" ]] >/dev/null 2>&1;then
    echo -e "${GREEN}WAN Failover is up to date - Version: "$VERSION"${NOCOLOR}"
  else
    echo -e "${RED}***WAN Failover Checksum Failed*** ${NOCOLOR}"
    echo -e "${RED}Local Checksum: "$CHECKSUM" ${NOCOLOR}"
    echo -e "${GREEN}Remote Checksum: "$REMOTECHECKSUM" ${NOCOLOR}"
  fi
  while true >/dev/null 2>&1;do  
    read -p "Do you want to reinstall "$ALIAS" Version: "$VERSION"? ***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) return;;
      * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
    esac
  done
  { /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" && chmod 755 $0 && killscript ;} \
  && logger -p 4 -st "$ALIAS" "Update - $ALIAS has reinstalled version: "$VERSION"" \
  || logger -p 2 -st "$ALIAS" "Update - ***Error*** Unable to reinstall version: "$VERSION""
  [ ! -z "${REMOTECHECKSUM+x}" ] >/dev/null 2>&1 && unset REMOTECHECKSUM
fi
}

# Cronjob
cronjob ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: cronjob"

# Lock Cron Job to ensure only one instance is ran at a time
  CRONLOCKFILE="/var/lock/wan-failover-cron.lock"
  exec 101>"$CRONLOCKFILE" || return
  flock -x -n 101 && echo  || { echo -e "${RED}${0##*/} Cron Job Mode is already running...${NOCOLOR}" && return ;}
  trap 'rm -f "$CRONLOCKFILE" || return' EXIT HUP INT QUIT TERM

# Create Cron Job
[ -z "${SCHEDULECRONJOB+x}" ] >/dev/null 2>&1 && SCHEDULECRONJOB=1
if [[ "$SCHEDULECRONJOB" == "1" ]] >/dev/null 2>&1 && { [[ "${mode}" == "cron" ]] >/dev/null 2>&1 || [[ "${mode}" == "install" ]] >/dev/null 2>&1 || [[ "${mode}" == "restart" ]] >/dev/null 2>&1 || [[ "${mode}" == "update" ]] >/dev/null 2>&1 || [[ "${mode}" == "config" ]] >/dev/null 2>&1 ;};then
  if [ -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
    logger -p 5 -st "$ALIAS" "Cron - Creating Cron Job"
    $(cru a setup_wan_failover_run "*/1 * * * *" $0 run) \
    && logger -p 4 -st "$ALIAS" "Cron - Created Cron Job" \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Unable to create Cron Job"
  elif tty >/dev/null 2>&1 && [ ! -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
    echo -e "${GREEN}Cron Job already scheduled...${NOCOLOR}"
  fi
# Remove Cron Job
elif [[ "$SCHEDULECRONJOB" == "0" ]] >/dev/null 2>&1 || [[ "${mode}" == "kill" ]] >/dev/null 2>&1 || [[ "${mode}" == "uninstall" ]] >/dev/null 2>&1;then
  if [ ! -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
    logger -p 3 -st "$ALIAS" "Cron - Removing Cron Job"
    $(cru d setup_wan_failover_run) \
    && logger -p 3 -st "$ALIAS" "Cron - Removed Cron Job" \
    || logger -p 2 -st "$ALIAS" "Cron - ***Error*** Unable to remove Cron Job"
  elif tty >/dev/null 2>&1 && [ -z "$(cru l | grep -w "$0" | grep -w "setup_wan_failover_run")" ] >/dev/null 2>&1;then
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
if [ -z "${systemlogset+x}" ] >/dev/null 2>&1;then
  systemlogset="0"
elif [[ "$systemlogset" != "0" ]] >/dev/null 2>&1;then
  systemlogset="0"
fi

# Check Custom Log Path is Specified
if [[ "$systemlogset" == "0" ]] >/dev/null 2>&1 && [ ! -z "$CUSTOMLOGPATH" ] >/dev/null 2>&1 && [ -f "$CUSTOMLOGPATH" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Checking if Custom Log Path is Specified"
  logger -p 6 -t "$ALIAS" "Debug - Custom Log Path: "$CUSTOMLOGPATH""
  SYSLOG="$CUSTOMLOGPATH" && systemlogset=1
fi

# Check if Scribe is Installed
if [[ "$systemlogset" == "0" ]] >/dev/null 2>&1 && { [ -f "/jffs/scripts/scribe" ] >/dev/null 2>&1 && [ -e "/opt/bin/scribe" ] >/dev/null 2>&1 && [ -f "/opt/var/log/messages" ] >/dev/null 2>&1 ;};then
  logger -p 6 -t "$ALIAS" "Debug - Checking if Scribe is Installed"
  logger -p 6 -t "$ALIAS" "Debug - Scribe is installed, using System Log Path: /opt/var/log/messages"
  SYSLOG="/opt/var/log/messages" && systemlogset=1
fi

# Check if Entware syslog-ng package is Installed
if [[ "$systemlogset" == "0" ]] >/dev/null 2>&1 && [ -f "/opt/var/log/messages" ] >/dev/null 2>&1 && [ -s "/opt/var/log/messages" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Checking if Entware syslog-ng package is Installed"
  logger -p 6 -t "$ALIAS" "Debug - Entware syslog-ng package is installed, using System Log Path: /opt/var/log/messages"
  SYSLOG="/opt/var/log/messages" && systemlogset=1
fi

# Check if System Log is located in TMP Directory
if [[ "$systemlogset" == "0" ]] >/dev/null 2>&1 && { [ -f "/tmp/syslog.log" ] >/dev/null 2>&1 && [ -s "/tmp/syslog.log" ] >/dev/null 2>&1 ;};then
  logger -p 6 -t "$ALIAS" "Debug - Checking if System Log is located at /tmp/syslog.log and isn't a blank file"
  logger -p 6 -t "$ALIAS" "Debug - System Log is located at /tmp/syslog.log"
  SYSLOG="/tmp/syslog.log" && systemlogset=1
fi

# Check if System Log is located in JFFS Directory
if [[ "$systemlogset" == "0" ]] >/dev/null 2>&1 && { [ -f "/jffs/syslog.log" ] >/dev/null 2>&1 && [ -s "/jffs/syslog.log" ] >/dev/null 2>&1 ;};then
  logger -p 6 -t "$ALIAS" "Debug - Checking if System Log is located at /jffs/syslog.log and isn't a blank file"
  logger -p 6 -t "$ALIAS" "Debug - System Log is located at /jffs/syslog.log"
  SYSLOG="/jffs/syslog.log" && systemlogset=1
fi

# Determine if System Log Path was located and load Monitor Mode
if [[ "$systemlogset" == "0" ]] >/dev/null 2>&1;then
  echo -e "${RED}***Unable to locate System Log Path***${NOCOLOR}"
  logger -p 2 -t "$ALIAS" "Monitor - ***Unable to locate System Log Path***"
  return
elif [[ "$systemlogset" == "1" ]] >/dev/null 2>&1;then
  if [[ "$mode" == "monitor" ]] >/dev/null 2>&1;then
    tail -1 -F $SYSLOG 2>/dev/null | awk '/'$ALIAS'/{print}' \
    && { unset systemlogset && return ;} \
    || echo -e "${RED}***Unable to load Monitor Mode***${NOCOLOR}"
  elif [[ "$mode" == "capture" ]] >/dev/null 2>&1;then
    LOGFILE="/tmp/wan-failover-$(date +"%F-%T-%Z").log"
    touch -a $LOGFILE
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
logger -p 6 -t "$ALIAS" "Debug - Checking for missing configuration options"
WANDOGTARGET="$(nvram get wandog_target & nvramcheck)"
QOSENABLE="$(nvram get qos_enable & nvramcheck)"
QOSIBW="$(nvram get qos_ibw & nvramcheck)"
QOSOBW="$(nvram get qos_obw & nvramcheck)"
if [ -z "$(sed -n '/\bWAN0TARGET=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [ ! -z "$WANDOGTARGET" ] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0TARGET Default: "$WANDOGTARGET""
    echo -e "WAN0TARGET=$WANDOGTARGET" >> $CONFIGFILE
  else
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0TARGET Default: 8.8.8.8"
    echo -e "WAN0TARGET=8.8.8.8" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1TARGET=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1TARGET Default: 8.8.4.4"
  echo -e "WAN1TARGET=8.8.4.4" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPINGCOUNT=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting PINGCOUNT Default: 3 Seconds"
  echo -e "PINGCOUNT=3" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPINGTIMEOUT=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting PINGTIMEOUT Default: 1 Second"
  echo -e "PINGTIMEOUT=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0PACKETSIZE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  [ -z "${PACKETSIZE+x}" ] >/dev/null 2>&1 && PACKETSIZE="56"
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN0PACKETSIZE Default: "$PACKETSIZE" Bytes"
  echo -e "WAN0PACKETSIZE=$PACKETSIZE" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1PACKETSIZE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  [ -z "${PACKETSIZE+x}" ] >/dev/null 2>&1 && PACKETSIZE="56"
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1PACKETSIZE Default: "$PACKETSIZE" Bytes"
  echo -e "WAN1PACKETSIZE=$PACKETSIZE" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWANDISABLEDSLEEPTIMER=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WANDISABLEDSLEEPTIMER Default: 10 Seconds"
  echo -e "WANDISABLEDSLEEPTIMER=10" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_ENABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_ENABLE Default: Enabled"
    echo -e "WAN0_QOS_ENABLE=1" >> $CONFIGFILE
  elif [[ "$QOSENABLE" == "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_ENABLE Default: Disabled"
    echo -e "WAN0_QOS_ENABLE=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1_QOS_ENABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_ENABLE Default: Enabled"
    echo -e "WAN1_QOS_ENABLE=1" >> $CONFIGFILE
  elif [[ "$QOSENABLE" == "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_ENABLE Default: Disabled"
    echo -e "WAN1_QOS_ENABLE=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN0_QOS_IBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$QOSIBW" != "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_IBW Default: "$QOSIBW" Kbps"
    echo -e "WAN0_QOS_IBW=$QOSIBW" >> $CONFIGFILE
  else
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_IBW Default: 0 Kbps"
    echo -e "WAN0_QOS_IBW=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1_QOS_IBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_IBW Default: 0 Mbps"
  echo -e "WAN1_QOS_IBW=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_OBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  if [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$QOSOBW" != "0" ]] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_OBW Default: "$QOSOBW" Kbps"
    echo -e "WAN0_QOS_OBW=$QOSOBW" >> $CONFIGFILE
  else
    logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_IBW Default: 0 Kbps"
    echo -e "WAN0_QOS_IBW=0" >> $CONFIGFILE
  fi
fi
if [ -z "$(sed -n '/\bWAN1_QOS_OBW=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_OBW Default: 0 Mbps"
  echo -e "WAN1_QOS_OBW=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_OVERHEAD=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_OVERHEAD Default: 0 Bytes"
  echo -e "WAN0_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1_QOS_OVERHEAD=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_OVERHEAD Default: 0 Bytes"
  echo -e "WAN1_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0_QOS_ATM=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN0_QOS_ATM Default: Disabled"
  echo -e "WAN0_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1_QOS_ATM=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1_QOS_ATM Default: Disabled"
  echo -e "WAN1_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPACKETLOSSLOGGING=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting PACKETLOSSLOGGING Default: Enabled"
  echo -e "PACKETLOSSLOGGING=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bSENDEMAIL=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting SENDEMAIL Default: Enabled"
  echo -e "SENDEMAIL=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bSKIPEMAILSYSTEMUPTIME=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting SKIPEMAILSYSTEMUPTIME Default: 180 Seconds"
  echo -e "SKIPEMAILSYSTEMUPTIME=180" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bEMAILTIMEOUT=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
  echo -e "EMAILTIMEOUT=30" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bBOOTDELAYTIMER=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting BOOTDELAYTIMER Default: 0 Seconds"
  echo -e "BOOTDELAYTIMER=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bOVPNSPLITTUNNEL=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting OVPNSPLITTUNNEL Default: Enabled"
  echo -e "OVPNSPLITTUNNEL=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0ROUTETABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN0ROUTETABLE Default: Table 100"
  echo -e "WAN0ROUTETABLE=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1ROUTETABLE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1ROUTETABLE Default: Table 200"
  echo -e "WAN1ROUTETABLE=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0TARGETRULEPRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN0TARGETRULEPRIORITY Default: Priority 100"
  echo -e "WAN0TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1TARGETRULEPRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1TARGETRULEPRIORITY Default: Priority 100"
  echo -e "WAN1TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0MARK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN0MARK Default: 0x80000000"
  echo -e "WAN0MARK=0x80000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1MARK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1MARK Default: 0x90000000"
  echo -e "WAN1MARK=0x90000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN0MASK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN0MASK Default: 0xf0000000"
  echo -e "WAN0MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bWAN1MASK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting WAN1MASK Default: 0xf0000000"
  echo -e "WAN1MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bLBRULEPRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting LBRULEPRIORITY Default: Priority 150"
  echo -e "LBRULEPRIORITY=150" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bFROMWAN0PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting FROMWAN0PRIORITY Default: Priority 200"
  echo -e "FROMWAN0PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bTOWAN0PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting TOWAN0PRIORITY Default: Priority 400"
  echo -e "TOWAN0PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bFROMWAN1PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting FROMWAN1PRIORITY Default: Priority 200"
  echo -e "FROMWAN1PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bTOWAN1PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting TOWAN1PRIORITY Default: Priority 400"
  echo -e "TOWAN1PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bOVPNWAN0PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting OVPNWAN0PRIORITY Default: Priority 100"
  echo -e "OVPNWAN0PRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bOVPNWAN1PRIORITY=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
  echo -e "OVPNWAN1PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bRECURSIVEPINGCHECK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting RECURSIVEPINGCHECK Default: 1 Iteration"
  echo -e "RECURSIVEPINGCHECK=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bDEVMODE=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Creating DEVMODE Default: Disabled"
  echo -e "DEVMODE=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bCHECKNVRAM=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Creating CHECKNVRAM Default: Disabled"
  echo -e "CHECKNVRAM=0" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bCUSTOMLOGPATH\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Creating CUSTOMLOGPATH Default: N/A"
  echo -e "CUSTOMLOGPATH=" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bSCHEDULECRONJOB=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Creating SCHEDULECRONJOB Default: Enabled"
  echo -e "SCHEDULECRONJOB=1" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bSTATUSCHECK=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Creating STATUSCHECK Default: 30"
  echo -e "STATUSCHECK=30" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPINGTIMEMIN=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Creating PINGTIMEMIN Default: 40"
  echo -e "PINGTIMEMIN=40" >> $CONFIGFILE
fi
if [ -z "$(sed -n '/\bPINGTIMEMAX=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Creating PINGTIMEMAX Default: 80"
  echo -e "PINGTIMEMAX=80" >> $CONFIGFILE
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
if [ ! -z "$(sed -n '/\b'${DEPRECATEDOPTION}'=\b/p' "$CONFIGFILE")" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Removing deprecated option: "${DEPRECATEDOPTION}" from "$CONFIGFILE""
  sed -i '/\b'${DEPRECATEDOPTION}'=\b/d' $CONFIGFILE
fi
done

logger -p 6 -t "$ALIAS" "Debug - Reading "$CONFIGFILE""
. $CONFIGFILE

if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null 2>&1;then
OVPNCONFIGFILES='
/etc/openvpn/client1/config.ovpn
/etc/openvpn/client2/config.ovpn
/etc/openvpn/client3/config.ovpn
/etc/openvpn/client4/config.ovpn
/etc/openvpn/client5/config.ovpn
'

  # Create Array for OVPN Remote Addresses
  [ -z "${REMOTEADDRESSES+x}" ] >/dev/null 2>&1 && REMOTEADDRESSES=""  
  for OVPNCONFIGFILE in ${OVPNCONFIGFILES};do
    if [ -f "${OVPNCONFIGFILE}" ] >/dev/null 2>&1;then
      REMOTEADDRESS="$(awk -F " " '/remote/ {print $2}' "$OVPNCONFIGFILE")"
      logger -p 6 -t "$ALIAS" "Debug - Added $REMOTEADDRESS to OVPN Remote Addresses"
      REMOTEADDRESSES="${REMOTEADDRESSES} ${REMOTEADDRESS}"
    fi
  done
fi

# Debug Logging
debuglog || return

return
}

# WAN Status
wanstatus ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: wanstatus"

# Check if script has been loaded and is already in a Ready State
[ -z "${READYSTATE+x}" ] >/dev/null 2>&1 && READYSTATE=0

# Boot Delay Timer
logger -p 6 -t "$ALIAS" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"
logger -p 6 -t "$ALIAS" "Debug - Boot Delay Timer: "$BOOTDELAYTIMER" Seconds"
if [ ! -z "$BOOTDELAYTIMER" ] >/dev/null 2>&1;then
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] >/dev/null 2>&1;then
    logger -p 4 -st "$ALIAS" "Boot Delay - Waiting for System Uptime to reach $BOOTDELAYTIMER seconds"
    while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] >/dev/null 2>&1;do
      sleep 1
    done
    logger -p 5 -st "$ALIAS" "Boot Delay - System Uptime is $(awk -F "." '{print $1}' "/proc/uptime") seconds"
  fi
fi

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Check Current Status of Dual WAN Mode
if [[ "$WANSDUALWANENABLE" == "0" ]] >/dev/null 2>&1;then
  logger -p 2 -st "$ALIAS" "WAN Status - Dual WAN: Disabled"
  wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$WANDOGENABLE" != "0" ]] >/dev/null 2>&1;then
  logger -p 2 -st "$ALIAS" "WAN Status - ASUS Factory Watchdog: Enabled"
  wandisabled
# Check if WAN Interfaces are Enabled and Connected
else
  for WANPREFIX in ${WANPREFIXES};do
    # Getting WAN Parameters
    GETWANMODE=1
    getwanparameters || return

    # Check if WAN Interfaces are Disabled
    if [[ "$ENABLE" == "0" ]] >/dev/null 2>&1;then
      logger -p 1 -st "$ALIAS" "WAN Status - ${WANPREFIX} disabled"
      STATUS=DISABLED
      logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
      setwanstatus && continue
    # Check if WAN is Enabled
    elif [[ "$ENABLE" == "1" ]] >/dev/null 2>&1;then
      logger -p 5 -t "$ALIAS" "WAN Status - ${WANPREFIX} enabled"
      # Check WAN Connection
      logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" State"
      if [[ "$AUXSTATE" == "1" ]] >/dev/null 2>&1 || [ -z "$GWIFNAME" ] >/dev/null 2>&1 || { [[ "$WANUSB" == "usb" ]] >/dev/null 2>&1 && { [[ "$USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$IFNAME" ] >/dev/null 2>&1 ;} ;};then
        [[ "$WANUSB" != "usb" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "WAN Status - "${WANPREFIX}": Cable Unplugged"
        [[ "$WANUSB" == "usb" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "WAN Status - "${WANPREFIX}": USB Unplugged" && RESTARTSERVICESMODE=2 && restartservices
        STATUS=UNPLUGGED
        logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
        setwanstatus && continue
      elif [[ "$AUXSTATE" != "1" ]] >/dev/null 2>&1 && [[ "$STATE" == "3" ]] >/dev/null 2>&1;then
        nvram set "${WANPREFIX}"_state_t=2
        sleep 3
        STATE="$(nvram get "${WANPREFIX}"_state_t & nvramcheck)"
      elif { [[ "$AUXSTATE" != "1" ]] >/dev/null 2>&1 || { [[ "$WANUSB" == "usb" ]] >/dev/null 2>&1 && { [[ "$USBMODEMREADY" == "1" ]] >/dev/null 2>&1 && [ ! -z "$IFNAME" ] >/dev/null 2>&1 ;} ;} ;} && { [[ "$STATE" != "2" ]] >/dev/null 2>&1 && [[ "$STATE" != "6" ]] >/dev/null 2>&1 ;};then
        restartwan${WANSUFFIX} &
        restartwanpid="$!"
        wait $restartwanpid && unset restartwanpid
        STATE="$(nvram get "${WANPREFIX}"_state_t & nvramcheck)"
        logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Post-Restart State: "$STATE""
        if { [[ "$AUXSTATE" != "1" ]] >/dev/null 2>&1 || { [[ "$WANUSB" == "usb" ]] >/dev/null 2>&1 && { [[ "$USBMODEMREADY" == "1" ]] >/dev/null 2>&1 && [ ! -z "$IFNAME" ] >/dev/null 2>&1 ;} ;} ;} && { [[ "$STATE" != "2" ]] >/dev/null 2>&1 && [[ "$STATE" != "6" ]] >/dev/null 2>&1 ;};then
          logger -p 1 -st "$ALIAS" "WAN Status - "${WANPREFIX}": Disconnected"
          STATUS=DISCONNECTED
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
          setwanstatus && continue
        elif [[ "$STATE" == "2" ]] >/dev/null 2>&1;then
          logger -p 4 -st "$ALIAS" "WAN Status - Successfully Restarted "${WANPREFIX}""
          [[ "$WANUSB" == "usb" ]] >/dev/null 2>&1 && [[ "$USBMODEMREADY" == "1" ]] >/dev/null 2>&1 && RESTARTSERVICESMODE=2 && restartservices
          sleep 5
        else
          wanstatus
        fi
      fi

      # Check if WAN Gateway IP or IP Address are 0.0.0.0 or null
      logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for null IP or Gateway"
      if { { [[ "$IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$GATEWAY" ] >/dev/null 2>&1 ;} ;};then
        [[ "$IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} IP Address: "$IPADDR""
        [ -z "$IPADDR" ] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} IP Address: Null"
        [[ "$IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} Gateway IP Address: "$GATEWAY""
        [ -z "$GATEWAY" ] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Status - ***Error*** ${WANPREFIX} Gateway IP Address: Null"
        STATUS=DISCONNECTED
        logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
        setwanstatus && continue
      fi

      # Check WAN Routing Table for Default Routes
      checkroutingtable &
      CHECKROUTINGTABLEPID=$!
      wait $CHECKROUTINGTABLEPID
      unset CHECKROUTINGTABLEPID

      # Check WAN Packet Loss
      logger -p 6 -t "$ALIAS" "Debug - Recursive Ping Check: "$RECURSIVEPINGCHECK""
      i=1
      PACKETLOSS=""
      while [ "$i" -le "$RECURSIVEPINGCHECK" ] >/dev/null 2>&1;do
        # Determine IP Rule or Route for successful ping
        [ -z "${PINGPATH+x}" ] >/dev/null 2>&1 && PINGPATH=0
        # Check WAN Target IP Rule specifying Outbound Interface
        logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for IP Rule to "$TARGET""
        if [[ "$PINGPATH" == "0" ]] >/dev/null 2>&1 || [[ "$PINGPATH" == "1" ]] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from all iif lo to $TARGET oif "$GWIFNAME" lookup ${TABLE} priority "$PRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "WAN Status - Adding IP Rule for "$TARGET" to monitor "${WANPREFIX}""
            ip rule add from all iif lo to $TARGET oif $GWIFNAME table $TABLE priority $PRIORITY \
            && logger -p 4 -t "$ALIAS" "WAN Status - Added IP Rule for "$TARGET" to monitor "${WANPREFIX}"" \
            || { logger -p 2 -t "$ALIAS" "WAN Status - ***Error*** Unable to add IP Rule for "$TARGET" to monitor "${WANPREFIX}"" && sleep 1 && wanstatus ;}
          fi
          logger -p 6 -t "$ALIAS" "Debug - "Checking ${WANPREFIX}" for packet loss via $TARGET - Attempt: "$i""
          ping${WANPREFIX}target &
          PINGWANPID=$!
          wait $PINGWANPID
          PACKETLOSS="$(sed -n 1p /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Packet Loss: "$PACKETLOSS""
          if [[ "$READYSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$PINGPATH" == "1" ]] >/dev/null 2>&1 && [[ "$PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
            restartwan${WANSUFFIX} &
            restartwanpid="$!"
            wait $restartwanpid && unset restartwanpid
            STATE="$(nvram get "${WANPREFIX}"_state_t & nvramcheck)"
          fi
          [[ "$PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && [[ "$PINGPATH" != "1" ]] >/dev/null 2>&1 && PINGPATH=1 && setwanstatus
          [[ "$PINGPATH" != "1" ]] >/dev/null 2>&1 && [[ "$PACKETLOSS" == "100%" ]] >/dev/null 2>&1 && ip rule del from all iif lo to $TARGET oif $GWIFNAME table $TABLE priority "$PRIORITY"
        fi

        # Check WAN Target IP Rule without specifying Outbound Interface
        if [[ "$PINGPATH" == "0" ]] >/dev/null 2>&1 || [[ "$PINGPATH" == "2" ]] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from all iif lo to $TARGET lookup ${TABLE} priority "$PRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "WAN Status - Adding IP Rule for "$TARGET" to monitor "${WANPREFIX}" without specifying Outbound Interface"
            ip rule add from all iif lo to $TARGET table $TABLE priority $PRIORITY \
            && logger -p 4 -t "$ALIAS" "WAN Status - Added IP Rule for "$TARGET" to monitor "${WANPREFIX}" without specifying Outbound Interface" \
            || { logger -p 2 -t "$ALIAS" "WAN Status - ***Error*** Unable to add IP Rule for "$TARGET" to monitor "${WANPREFIX}" without specifying Outbound Interface" && sleep 1 && wanstatus ;}
          fi
          ping${WANPREFIX}target &
          PINGWANPID=$!
          wait $PINGWANPID
          PACKETLOSS="$(sed -n 1p /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Packet Loss: "$PACKETLOSS""
          [[ "$PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && [[ "$PINGPATH" != "2" ]] >/dev/null 2>&1 && PINGPATH=2 && setwanstatus
          [[ "$READYSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$PINGPATH" == "2" ]] >/dev/null 2>&1 && logger -p 3 -t "$ALIAS" "WAN Status - ***Warning*** Compatibility issues with "$TARGET" may occur without specifying Outbound Interface"
          [[ "$PINGPATH" != "2" ]] >/dev/null 2>&1 && [[ "$PACKETLOSS" == "100%" ]] >/dev/null 2>&1 && ip rule del from all iif lo to $TARGET table $TABLE priority $PRIORITY
        fi

        # Check WAN Route for Target IP
        logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
        if [[ "$PINGPATH" == "0" ]] >/dev/null 2>&1 || [[ "$PINGPATH" == "3" ]] >/dev/null 2>&1;then
         if [ -z "$(ip route list "$TARGET" via "$GATEWAY" dev "$GWIFNAME" table main)" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "WAN Status - Adding route for "$TARGET" via "$GATEWAY" dev "$GWIFNAME""
            ip route add $TARGET via $GATEWAY dev $GWIFNAME table main \
            && logger -p 4 -t "$ALIAS" "WAN Status - Added route for "$TARGET" via "$GATEWAY" dev "$GWIFNAME"" \
            || { logger -p 2 -t "$ALIAS" "WAN Status - ***Error*** Unable to add route for "$TARGET" via "$GATEWAY" dev "$GWIFNAME"" && sleep 1 && wanstatus ;}
          fi
          ping${WANPREFIX}target &
          PINGWANPID=$!
          wait $PINGWANPID
          PACKETLOSS="$(sed -n 1p /tmp/${WANPREFIX}packetloss.tmp)"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Packet Loss: "$PACKETLOSS""
          [[ "$PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && [[ "$PINGPATH" != "3" ]] >/dev/null 2>&1 && PINGPATH=3 && setwanstatus
          [[ "$READYSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$PINGPATH" == "3" ]] >/dev/null 2>&1 && logger -p 3 -t "$ALIAS" "WAN Status - ***Warning*** Compatibility issues with "$TARGET" may occur with adding route via "$GATEWAY" dev "$GWIFNAME""
          [[ "$PINGPATH" != "3" ]] >/dev/null 2>&1 && [[ "$PACKETLOSS" == "100%" ]] >/dev/null 2>&1 && ip route del $TARGET via $GATEWAY dev $GWIFNAME table main
        fi
        logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Ping Path: "$PINGPATH""
        if [[ "$PINGPATH" == "0" ]] >/dev/null 2>&1;then
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] >/dev/null 2>&1;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
          restartwan${WANSUFFIX} &
          restartwanpid="$!"
          wait $restartwanpid && unset restartwanpid
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] >/dev/null 2>&1;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Post-Restart State: "$STATE""
        fi

        # Determine WAN Status based on Packet Loss
        if { [[ "$PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || [[ "$PACKETLOSS" != "100%" ]] >/dev/null 2>&1 ;} && [ ! -z "$PACKETLOSS" ] >/dev/null 2>&1;then
          logger -p 5 -t "$ALIAS" "WAN Status - "${WANPREFIX}" has "$PACKETLOSS" packet loss"
          STATUS="CONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
          [[ "$STATE" != "2" ]] >/dev/null 2>&1 && nvram set ${WANPREFIX}_state_t=2
          setwanstatus && break 1
        elif [[ "$STATE" == "2" ]] >/dev/null 2>&1 && [[ "$PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
          logger -p 2 -st "$ALIAS" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss"
          [[ "$READYSTATE" == "0" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "***Verify $TARGET is a valid server for ICMP Echo Requests for ${WANPREFIX}***"
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] >/dev/null 2>&1;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
        else
          logger -p 2 -st "$ALIAS" "WAN Status - "${WANPREFIX}" has "$PACKETLOSS" packet loss"
          STATUS="DISCONNECTED"
          logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Status: "$STATUS""
          if [[ "$i" -le "$RECURSIVEPINGCHECK" ]] >/dev/null 2>&1;then
            i=$(($i+1))
            setwanstatus && continue
          else
            setwanstatus && break 1
          fi
        fi
      done
      unset PINGPATH
      unset i
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
if [[ "$READYSTATE" == "0" ]] >/dev/null 2>&1;then
  READYSTATE=1
  email=0
fi

# Set Status for Email Notification On if Unset
[ -z "${email+x}" ] >/dev/null 2>&1 && email="1"

# Set WAN Status to DISABLED, DISCONNECTED, or CONNECTED and select function.
logger -p 6 -t "$ALIAS" "Debug - WAN0STATUS: "$WAN0STATUS""
logger -p 6 -t "$ALIAS" "Debug - WAN1STATUS: "$WAN1STATUS""

# Checking if WAN Disabled returned to WAN Status and resetting loop iterations if WAN Status has changed
if [ -z "${wandisabledloop+x}" ] >/dev/null 2>&1;then
  [ ! -z "${wan0disabled+x}" ] >/dev/null 2>&1 && unset wan0disabled
  [ ! -z "${wan1disabled+x}" ] >/dev/null 2>&1 && unset wan1disabled
elif [ ! -z "${wandisabledloop+x}" ] || [[ "$wandisabledloop" != "0" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Returning to WAN Disabled"
  wandisabled
fi

# Getting Active WAN Parameters
GETWANMODE=3
getwanparameters || return

# Determine which function to go to based on Failover Mode and WAN Status
if [[ "${mode}" == "initiate" ]] >/dev/null 2>&1;then
  logger -p 4 -st "$ALIAS" "WAN Status - Initiate Completed"
  return
elif [[ "$WAN0STATUS" != "CONNECTED" ]] >/dev/null 2>&1 && [[ "$WAN1STATUS" != "CONNECTED" ]] >/dev/null 2>&1;then
  wandisabled
elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$WAN0STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
  # Verify WAN Properties are synced with Primary WAN
  [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 && SWITCHPRIMARY=0 && switchwan && switchdns && checkiprules
  # Switch WAN to Primary WAN
  [[ "$WAN0PRIMARY" != "1" ]] >/dev/null 2>&1 && { logger -p 6 -t "$ALIAS" "Debug - WAN0 is not Primary WAN" && failover ;}
  # Send Email if Enabled
  [[ "$email" == "1" ]] >/dev/null 2>&1 && sendemail && email=0
  # Determine which function to use based on Secondary WAN
  [[ "$WAN1STATUS" == "CONNECTED" ]] >/dev/null 2>&1 && wan0failovermonitor
  [[ "$WAN1STATUS" == "UNPLUGGED" ]] >/dev/null 2>&1 && wandisabled
  [[ "$WAN1STATUS" == "DISCONNECTED" ]] >/dev/null 2>&1 && wandisabled
  [[ "$WAN1STATUS" == "DISABLED" ]] >/dev/null 2>&1 && wandisabled
elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$WAN1STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
  # Verify WAN Properties are synced with Primary WAN
  [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 && SWITCHPRIMARY=0 && switchwan && switchdns && checkiprules
  # Switch WAN to Primary WAN
  [[ "$WAN1PRIMARY" != "1" ]] >/dev/null 2>&1 && { logger -p 6 -t "$ALIAS" "Debug - WAN1 is not Primary WAN" && failover && email=0 ;}
  # Send Email if Enabled
  [[ "$email" == "1" ]] >/dev/null 2>&1 && sendemail && email=0
  # Determine which function to use based on Secondary WAN
  [[ "$WAN0STATUS" == "UNPLUGGED" ]] >/dev/null 2>&1 && wandisabled
  [[ "$WAN0STATUS" == "DISCONNECTED" ]] >/dev/null 2>&1 && { [ ! -z "${WAN0PACKETLOSS+x}" ] >/dev/null 2>&1 && [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 && wan0failbackmonitor || wandisabled ;}
  [[ "$WAN0STATUS" == "DISABLED" ]] >/dev/null 2>&1 && wandisabled
elif [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
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
  GETWANMODE=1
  getwanparameters || return

  # Check if WAN is Enabled
  [[ "$ENABLE" == "0" ]] >/dev/null 2>&1 && continue

  # Check if WAN is in Ready State
  [[ "$STATE" != "2" ]] >/dev/null 2>&1 || [[ "$AUXSTATE" != "0" ]] >/dev/null 2>&1 && continue

  # Check if WAN Gateway IP or IP Address are 0.0.0.0 or null
  logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for null IP or Gateway"
  if { { [[ "$IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$GATEWAY" ] >/dev/null 2>&1 ;} ;};then
    [[ "$IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} IP Address: "$IPADDR""
    [ -z "$IPADDR" ] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} IP Address: Null"
    [[ "$IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} Gateway IP Address: "$GATEWAY""
    [ -z "$GATEWAY" ] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "Check Routing Table - ***Error*** ${WANPREFIX} Gateway IP Address: Null"
    continue
  fi

  # Check WAN Routing Table for Default Routes
  logger -p 6 -t "$ALIAS" "Debug - Checking "${WANPREFIX}" for Default Route in "$TABLE""
  if [ -z "$(ip route list default table "$TABLE" | awk '{print $3" "$5}' | grep -w "$GATEWAY $GWIFNAME")" ] >/dev/null 2>&1;then
   [ ! -z "$(ip route list default table "$TABLE")" ] >/dev/null 2>&1 && ip route del default table "$TABLE"
     logger -p 5 -t "$ALIAS" "Check Routing Table - Adding default route for ${WANPREFIX} Routing Table via "$GATEWAY" dev "$GWIFNAME""
     ip route add default via $GATEWAY dev $GWIFNAME table "$TABLE" \
     && logger -p 4 -t "$ALIAS" "Check Routing Table - Added default route for ${WANPREFIX} Routing Table via "$GATEWAY" dev "$GWIFNAME"" \
     || logger -p 2 -t "$ALIAS" "Check Routing Table - ***Error*** Unable to add default route for ${WANPREFIX} Routing Table via "$GATEWAY" dev "$GWIFNAME""
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
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

for WANPREFIX in ${WANPREFIXES};do
  # Getting WAN Parameters
  GETWANMODE=1
  getwanparameters || return

  # Check Rules if Status is Connected
  if [[ "$STATUS" == "CONNECTED" ]] >/dev/null 2>&1 || { [[ "$ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$STATE" == "2" ]] >/dev/null 2>&1 || [[ "$AUXSTATE" != "1" ]] >/dev/null 2>&1 ;} ;};then
    # Create WAN NAT Rules
    # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
    if [[ "$HTTPENABLE" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "$ALIAS" "Debug - HTTP Web Access: "$HTTPENABLE""
      # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
      if [ -z "$(iptables -t nat -L PREROUTING -v -n | awk '{ if( !/GAME_VSERVER/ && /VSERVER/ && /'$IPADDR'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" creating VSERVER Rule for "$IPADDR""
        iptables -t nat -A PREROUTING -d $IPADDR -j VSERVER \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" created VSERVER Rule for "$IPADDR"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** "${WANPREFIX}" unable to create VSERVER Rule for "$IPADDR""
      fi
    fi
    # Create UPNP Rules if Enabled
    if [[ "$UPNPENABLE" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" UPNP Enabled: "$UPNPENABLE""
      if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /PUPNP/ && /'$GWIFNAME'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" creating UPNP Rule for "$GWIFNAME""
        iptables -t nat -A POSTROUTING -o $GWIFNAME -j PUPNP \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - "${WANPREFIX}" created UPNP Rule for "$GWIFNAME"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - *** Error*** "${WANPREFIX}" unable to create UPNP Rule for "$GWIFNAME""
      fi
    fi
    # Create MASQUERADE Rules if NAT is Enabled
    if [[ "$NAT" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" NAT Enabled: "$NAT""
      if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /MASQUERADE/ && /'$GWIFNAME'/ && /'$IPADDR'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding iptables MASQUERADE rule for excluding "$IPADDR" via "$GWIFNAME""
        iptables -t nat -A POSTROUTING -o $GWIFNAME ! -s $IPADDR -j MASQUERADE \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added iptables MASQUERADE rule for excluding "$IPADDR" via "$GWIFNAME"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add iptables MASQUERADE rule for excluding "$IPADDR" via "$GWIFNAME""
      fi
    fi
  fi

  # Check Rules for Load Balance Mode
  if [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Checking IPTables Mangle Rules"
    # Check IPTables Mangle Balance Rules for PREROUTING Table
    if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$LANIFNAME'/ && /state/ && /NEW/ ) print}')" ] >/dev/null 2>&1;then
      logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables MANGLE Balance Rule for "$LANIFNAME""
      iptables -t mangle -A PREROUTING -i $LANIFNAME -m state --state NEW -j balance \
      && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables MANGLE Balance Rule for "$LANIFNAME"" \
      || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE Balance Rule for "$LANIFNAME""
    fi

    # Check Rules if Status is Connected
    if [[ "$STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
      # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
      if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$LANIFNAME'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables - PREROUTING MANGLE match rule for "$LANIFNAME" marked with "$MARK""
        iptables -t mangle -A PREROUTING -i $LANIFNAME -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables - PREROUTING MANGLE match rule for "$LANIFNAME" marked with "$MARK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables - PREROUTING MANGLE match rule for "$LANIFNAME" marked with "$MARK""
      fi
      # Check IPTables Mangle Match Rule for WAN for OUTPUT Table
      if [ -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$GWIFNAME'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$MARK""
        iptables -t mangle -A OUTPUT -o $GWIFNAME -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$MARK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$MARK""
      fi
      if [ ! -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$GWIFNAME'/ && /connmark match/ && /'$DELETEMARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 6 -t "$ALIAS" "Check IP Rules - Deleting IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$DELETEMARK""
        iptables -t mangle -D OUTPUT -o $GWIFNAME -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK" \
        && logger -p 6 -t "$ALIAS" "Check IP Rules - Deleted IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$DELETEMARK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to delete IPTables - OUTPUT MANGLE match rule for "$GWIFNAME" marked with "$DELETEMARK""
      fi
      # Check IPTables Mangle Set XMark Rule for WAN for PREROUTING Table
      if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$GWIFNAME'/ && /state/ && /NEW/ && /CONNMARK/ && /xset/ && /'$MARK'/ ) print}')" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables - PREROUTING MANGLE set xmark rule for "$GWIFNAME""
        iptables -t mangle -A PREROUTING -i $GWIFNAME -m state --state NEW -j CONNMARK --set-xmark "$MARK"/"$MASK" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables - PREROUTING MANGLE set xmark rule for "$GWIFNAME"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to delete IPTables - PREROUTING MANGLE set xmark rule for "$GWIFNAME""
      fi
      # Create WAN IP Address Rule
      if { [[ "$IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$IPADDR" ] >/dev/null 2>&1 ;} && [ -z "$(ip rule list from $IPADDR lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$IPADDR" lookup "${TABLE}""
        ip rule add from $IPADDR lookup ${TABLE} priority "$FROMWANPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$IPADDR" lookup "${TABLE}"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$IPADDR" lookup "${TABLE}""
      fi
      # Create WAN Gateway IP Rule
      if { [[ "$GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$GATEWAY" ] >/dev/null 2>&1 ;} && [ -z "$(ip rule list from all to $GATEWAY lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule from all to "$GATEWAY" lookup "${TABLE}""
        ip rule add from all to $GATEWAY lookup ${TABLE} priority "$TOWANPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule from all to "$GATEWAY" lookup "${TABLE}"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$GATEWAY" lookup "${TABLE}""
      fi
      # Create WAN DNS IP Rules
      if [[ "$DNSENABLE" == "0" ]] >/dev/null 2>&1;then
        if [ ! -z "$DNS1" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$DNS1" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$DNS1" lookup "${TABLE}""
            ip rule add from $DNS1 lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$DNS1" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$DNS1" lookup "${TABLE}""
          fi
          if [ -z "$(ip rule list from all to "$DNS1" lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule from all to "$DNS1" lookup "${TABLE}""
            ip rule add from all to $DNS1 lookup ${TABLE} priority "$TOWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule from all to "$DNS1" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$DNS1" lookup "${TABLE}""
          fi
        fi
        if [ ! -z "$DNS2" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$DNS2" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$DNS2" lookup "${TABLE}""
            ip rule add from $DNS2 lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$DNS2" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$DNS2" lookup "${TABLE}""
          fi
          if [ -z "$(ip rule list from all to "$DNS2" lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule from all to "$DNS2" lookup "${TABLE}""
            ip rule add from all to $DNS2 lookup ${TABLE} priority "$TOWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule from all to "$DNS2" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule from all to "$DNS2" lookup "${TABLE}""
          fi
        fi
      elif [[ "$DNSENABLE" == "1" ]] >/dev/null 2>&1;then
        if [ ! -z "$AUTODNS1" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$AUTODNS1" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for "$AUTODNS1" lookup "${TABLE}""
            ip rule add from $AUTODNS1 lookup ${TABLE} priority "$FROMWANPRIORITY" \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for "$AUTODNS1" lookup "${TABLE}"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for "$AUTODNS1" lookup "${TABLE}""
          fi
        fi
        if [ ! -z "$AUTODNS2" ] >/dev/null 2>&1;then
          if [ -z "$(ip rule list from "$AUTODNS2" lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null 2>&1;then
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
      while [ "$i" -le "10" ] >/dev/null 2>&1;do
        i=$(($i+1))
        GUESTLANIFNAME="$(nvram get lan${i}_ifname & nvramcheck)"
        if [ ! -z "$GUESTLANIFNAME" ] >/dev/null 2>&1;then
          if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$GUESTLANIFNAME'/ && /state/ && /NEW/ ) print}')" ] >/dev/null 2>&1;then
            logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IPTables MANGLE Balance Rule for "$GUESTLANIFNAME""
            iptables -t mangle -A PREROUTING -i $GUESTLANIFNAME -m state --state NEW -j balance \
            && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IPTables MANGLE Balance Rule for "$GUESTLANIFNAME"" \
            || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IPTables MANGLE Balance Rule for "$GUESTLANIFNAME""
          fi
        fi
  
        # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
        if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$GUESTLANIFNAME'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null 2>&1;then
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
      if [ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule add from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY" \
          && logger -p 4 -t "$ALIAS" "Check IP Rules - Added IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE"" \
          || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
      fi
      if [ ! -z "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Removing Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule del blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY" \
          && logger -p 4 -t "$ALIAS" "Check IP Rules - Removed Blackhole IP Rule for fwmark "$MARK"/"$MASK"" \
          || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to remove Blackhole IP Rule for fwmark "$MARK"/"$MASK""
      fi

      # If OVPN Split Tunneling is Disabled in Configuration, create rules for WAN Interface.
      logger -p 6 -t "$ALIAS" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null 2>&1;then
        # Create IP Rules for OVPN Remote Addresses
          for REMOTEADDRESS in ${REMOTEADDRESSES};do
            REMOTEIP="$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')"
            logger -p 6 -t "$ALIAS" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
            if [ ! -z "$REMOTEIP" ] >/dev/null 2>&1;then
              logger -p 6 -t "$ALIAS" "Debug - Remote IP Address: "$REMOTEIP""
              if [ -z "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ] >/dev/null 2>&1;then
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
    elif [[ "$STATUS" != "CONNECTED" ]] >/dev/null 2>&1;then
      # Create fwmark IP Rules
      logger -p 6 -t "$ALIAS" "Debug - Checking fwmark IP Rules"
      if [ ! -z "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Removing IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule del from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Removed IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to remove IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
      fi
      if [ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ] >/dev/null 2>&1;then
        logger -p 5 -t "$ALIAS" "Check IP Rules - Adding Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule add blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY" \
        && logger -p 4 -t "$ALIAS" "Check IP Rules - Added Blackhole IP Rule for fwmark "$MARK"/"$MASK"" \
        || logger -p 2 -t "$ALIAS" "Check IP Rules - ***Error*** Unable to add Blackhole IP Rule for fwmark "$MARK"/"$MASK""
      fi
      
      # If OVPN Split Tunneling is Disabled in Configuration, delete rules for down WAN Interface.
      logger -p 6 -t "$ALIAS" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null 2>&1;then
        # Create IP Rules for OVPN Remote Addresses
        for REMOTEADDRESS in ${REMOTEADDRESSES};do
          logger -p 6 -t "$ALIAS" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
          REMOTEIP="$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')"
          if [ ! -z "$REMOTEIP" ] >/dev/null 2>&1;then
            logger -p 6 -t "$ALIAS" "Debug - Remote IP Address: "$REMOTEIP""
            if [ ! -z "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ] >/dev/null 2>&1;then
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
[ -z "${GETWANMODE+x}" ] >/dev/null 2>&1 && GETWANMODE="1"

# Set WAN Interface Parameters
if [[ "$GETWANMODE" == "1" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Setting parameters for "${WANPREFIX}""
  { [ -z "${ENABLE+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_enable & nvramcheck)" ] >/dev/null 2>&1 ;} && ENABLE="$(nvram get ${WANPREFIX}_enable & nvramcheck)"
  { [ -z "${IPADDR+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_ipaddr & nvramcheck)" ] >/dev/null 2>&1 ;} && IPADDR="$(nvram get ${WANPREFIX}_ipaddr & nvramcheck)"
  { [ -z "${GATEWAY+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_gateway & nvramcheck)" ] >/dev/null 2>&1 ;} && GATEWAY="$(nvram get ${WANPREFIX}_gateway & nvramcheck)"
  { [ -z "${GWIFNAME+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_gw_ifname & nvramcheck)" ] >/dev/null 2>&1 ;} && GWIFNAME="$(nvram get ${WANPREFIX}_gw_ifname & nvramcheck)"
  { [ -z "${IFNAME+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_ifname & nvramcheck)" ] >/dev/null 2>&1 ;} && IFNAME="$(nvram get ${WANPREFIX}_ifname & nvramcheck)"
  { [ -z "${DNSENABLE+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_dnsenable_x & nvramcheck)" ] >/dev/null 2>&1 ;} && DNSENABLE="$(nvram get ${WANPREFIX}_dnsenable_x & nvramcheck)"
  { [ -z "${DNS+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_dns & nvramcheck)" ] >/dev/null 2>&1 ;} && DNS="$(nvram get ${WANPREFIX}_dns & nvramcheck)"
  [ ! -z "$DNS" ] >/dev/null 2>&1 && AUTODNS1="$(echo $DNS | awk '{print $1}')" || AUTODNS1=""
  [ ! -z "$DNS" ] >/dev/null 2>&1 && AUTODNS2="$(echo $DNS | awk '{print $2}')" || AUTODNS2=""
  { [ -z "${DNS1+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_dns1_x & nvramcheck)" ] >/dev/null 2>&1 ;} && DNS1="$(nvram get ${WANPREFIX}_dns1_x & nvramcheck)"
  { [ -z "${DNS2+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_dns2_x & nvramcheck)" ] >/dev/null 2>&1 ;} && DNS2="$(nvram get ${WANPREFIX}_dns2_x & nvramcheck)"
  { [ -z "${STATE+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_state_t & nvramcheck)" ] >/dev/null 2>&1 ;} && STATE="$(nvram get ${WANPREFIX}_state_t & nvramcheck)"
  { [ -z "${AUXSTATE+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_auxstate_t & nvramcheck)" ] >/dev/null 2>&1 ;} && AUXSTATE="$(nvram get ${WANPREFIX}_auxstate_t & nvramcheck)"
  { [ -z "${SBSTATE+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_sbstate_t & nvramcheck)" ] >/dev/null 2>&1 ;} && SBSTATE="$(nvram get ${WANPREFIX}_sbstate_t & nvramcheck)"
  { [ -z "${PRIMARY+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_primary & nvramcheck)" ] >/dev/null 2>&1 ;} && PRIMARY="$(nvram get ${WANPREFIX}_primary & nvramcheck)"
  { [ -z "${USBMODEMREADY+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_is_usb_modem_ready & nvramcheck)" ] >/dev/null 2>&1 ;} && USBMODEMREADY="$(nvram get ${WANPREFIX}_is_usb_modem_ready & nvramcheck)"
  { [ -z "${UPNPENABLE+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_upnp_enable & nvramcheck)" ] >/dev/null 2>&1 ;} && UPNPENABLE="$(nvram get ${WANPREFIX}_upnp_enable & nvramcheck)"
  { [ -z "${NAT+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_nat_x & nvramcheck)" ] >/dev/null 2>&1 ;} && NAT="$(nvram get ${WANPREFIX}_nat_x & nvramcheck)"
  { [ -z "${REALIPADDR+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_realip_ip & nvramcheck)" ] >/dev/null 2>&1 ;} && REALIPADDR="$(nvram get ${WANPREFIX}_realip_ip & nvramcheck)"
  { [ -z "${REALIPSTATE+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get ${WANPREFIX}_realip_state & nvramcheck)" ] >/dev/null 2>&1 ;} && REALIPSTATE="$(nvram get ${WANPREFIX}_realip_state & nvramcheck)"
  if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null 2>&1;then
    { [ -z "${LINKWAN+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get link_wan & nvramcheck)" ] >/dev/null 2>&1 ;} && LINKWAN="$(nvram get link_wan & nvramcheck)"
    { [ -z "${DUALWANDEV+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get wans_dualwan & nvramcheck)" ] >/dev/null 2>&1 ;} && DUALWANDEV="$(nvram get wans_dualwan | awk '{print $1}' & nvramcheck)"
    TARGET="$WAN0TARGET"
    TABLE="$WAN0ROUTETABLE"
    PRIORITY="$WAN0TARGETRULEPRIORITY"
    { [ -z "${WANUSB+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get wans_dualwan & nvramcheck)" ] >/dev/null 2>&1 ;} && WANUSB="$(nvram get wans_dualwan | awk '{print $1}' & nvramcheck)"
    [ ! -z "${WAN0PINGPATH+x}" ] >/dev/null 2>&1 && PINGPATH="$WAN0PINGPATH" || PINGPATH=0
    MARK="$WAN0MARK"
    DELETEMARK="$WAN1MARK"
    MASK="$WAN0MASK"
    FROMWANPRIORITY="$FROMWAN0PRIORITY"
    TOWANPRIORITY="$TOWAN0PRIORITY"
    OVPNWANPRIORITY="$OVPNWAN0PRIORITY"
    WAN_QOS_ENABLE="$WAN0_QOS_ENABLE"
    WAN_QOS_OBW="$WAN0_QOS_OBW"
    WAN_QOS_IBW="$WAN0_QOS_IBW"
    WAN_QOS_OVERHEAD="$WAN0_QOS_OVERHEAD"
    WAN_QOS_ATM="$WAN0_QOS_ATM"
    WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
    if [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
      [[ "$PRIMARY" == "1" ]] >/dev/null 2>&1 && { [ -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && WAN0STATUS="CONNECTED" ;}
      [[ "$PRIMARY" == "0" ]] >/dev/null 2>&1 && { [ -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && WAN0STATUS="DISCONNECTED" ;}
      [[ "$PRIMARY" == "0" ]] >/dev/null 2>&1 && [[ "$AUXSTATE" == "1" ]] >/dev/null 2>&1 && { [ -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && WAN0STATUS="UNPLUGGED" ;}
    elif [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
      [[ "$STATE" == "2" ]] >/dev/null 2>&1 && { [ -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && WAN0STATUS="CONNECTED" ;}
      [[ "$STATE" != "2" ]] >/dev/null 2>&1 && { [ -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && WAN0STATUS="DISCONNECTED" ;}
      [[ "$AUXSTATE" == "1" ]] >/dev/null 2>&1 && { [ -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && WAN0STATUS="UNPLUGGED" ;}
    fi
    [ ! -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && { [ -z "${STATUS+x}" ] >/dev/null 2>&1 && STATUS="$WAN0STATUS" ;}
  elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null 2>&1;then
    { [ -z "${LINKWAN+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get link_wan1 & nvramcheck)" ] >/dev/null 2>&1 ;} && LINKWAN="$(nvram get link_wan1 & nvramcheck)"
    { [ -z "${DUALWANDEV+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get wans_dualwan & nvramcheck)" ] >/dev/null 2>&1 ;} && DUALWANDEV="$(nvram get wans_dualwan | awk '{print $2}' & nvramcheck)"
    TARGET="$WAN1TARGET"
    TABLE="$WAN1ROUTETABLE"
    PRIORITY="$WAN1TARGETRULEPRIORITY"
    { [ -z "${WANUSB+x}" ] >/dev/null 2>&1 || [ ! -z "$(nvram get wans_dualwan & nvramcheck)" ] >/dev/null 2>&1 ;} && WANUSB="$(nvram get wans_dualwan | awk '{print $2}' & nvramcheck)"
    [ ! -z "${WAN1PINGPATH+x}" ] >/dev/null 2>&1 && PINGPATH="$WAN1PINGPATH" || PINGPATH=0
    TABLE="$WAN1ROUTETABLE"
    MARK="$WAN1MARK"
    DELETEMARK="$WAN0MARK"
    MASK="$WAN1MASK"
    FROMWANPRIORITY="$FROMWAN1PRIORITY"
    TOWANPRIORITY="$TOWAN1PRIORITY"
    OVPNWANPRIORITY="$OVPNWAN1PRIORITY"
    WAN_QOS_ENABLE="$WAN1_QOS_ENABLE"
    WAN_QOS_OBW="$WAN1_QOS_OBW"
    WAN_QOS_IBW="$WAN1_QOS_IBW"
    WAN_QOS_OVERHEAD="$WAN1_QOS_OVERHEAD"
    WAN_QOS_ATM="$WAN1_QOS_ATM"
    WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
    if [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
      [[ "$PRIMARY" == "1" ]] >/dev/null 2>&1 && { [ -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && WAN1STATUS="CONNECTED" ;}
      [[ "$PRIMARY" == "0" ]] >/dev/null 2>&1 && { [ -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && WAN1STATUS="DISCONNECTED" ;}
      [[ "$PRIMARY" == "0" ]] >/dev/null 2>&1 && [[ "$AUXSTATE" == "1" ]] >/dev/null 2>&1 && { [ -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && WAN1STATUS="UNPLUGGED" ;}
    elif [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
      [[ "$STATE" == "2" ]] >/dev/null 2>&1 && { [ -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && WAN1STATUS="CONNECTED" ;}
      [[ "$STATE" != "2" ]] >/dev/null 2>&1 && { [ -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && WAN1STATUS="DISCONNECTED" ;}
      [[ "$AUXSTATE" == "1" ]] >/dev/null 2>&1 && { [ -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && WAN1STATUS="UNPLUGGED" ;}
    fi
    [ ! -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && { [ -z "${STATUS+x}" ] >/dev/null 2>&1 && STATUS="$WAN1STATUS" ;}
  fi
# Get Global WAN Parameters
elif [[ "$GETWANMODE" == "2" ]] >/dev/null 2>&1;then
  while [ -z "${globalwansync+x}" ] >/dev/null 2>&1 || [[ "$globalwansync" == "0" ]] >/dev/null 2>&1;do
    [ -z "${globalwansync+x}" ] >/dev/null 2>&1 && globalwansync=0
    [[ "$globalwansync" == "1" ]] && break
    
    # WANSDUALWAN
    if [ -z "${WANSDUALWAN+x}" ] >/dev/null 2>&1;then
      WANSDUALWAN="$(nvram get wans_dualwan & nvramcheck)"
      [ ! -z "$WANSDUALWAN" ] >/dev/null 2>&1 || { unset WANSDUALWAN && continue ;}
    fi

    # WANSDUALWANENABLE
    if [ -z "${WANSDUALWANENABLE+x}" ] >/dev/null 2>&1;then
      { [ ! -z "$(nvram get wans_dualwan | awk '{print $2}' & nvramcheck)" ] && [[ "$(nvram get wans_dualwan | awk '{print $2}' & nvramcheck)" == "none" ]] >/dev/null 2>&1 ;} && WANSDUALWANENABLE="0" || WANSDUALWANENABLE="1"
      [ ! -z "$WANSDUALWANENABLE" ] >/dev/null 2>&1 || { unset WANSDUALWANENABLE && continue ;}
    fi

    # WANSMODE
    if [ -z "${WANSMODE+x}" ] >/dev/null 2>&1;then
      WANSMODE="$(nvram get wans_mode & nvramcheck)"
      [ ! -z "$WANSMODE" ] >/dev/null 2>&1 || { unset WANSMODE && continue ;}
    fi

    # WANDOGENABLE
    if [ -z "${WANDOGENABLE+x}" ] >/dev/null 2>&1;then
      WANDOGENABLE="$(nvram get wandog_enable & nvramcheck)"
      [ ! -z "$WANDOGENABLE" ] >/dev/null 2>&1 || { unset WANDOGENABLE && continue ;}
    fi

    # WANSLBRATIO
    if [ -z "${WANSLBRATIO+x}" ] >/dev/null 2>&1;then
      WANSLBRATIO="$(nvram get wans_lb_ratio & nvramcheck)"
      [ ! -z "$WANSLBRATIO" ] >/dev/null 2>&1 || { unset WANSLBRATIO && continue ;}
    fi

    # WAN0LBRATIO
    if [ -z "${WAN0LBRATIO+x}" ] >/dev/null 2>&1;then
      WAN0LBRATIO="$(echo $WANSLBRATIO | awk -F ":" '{print $1}')"
      [ ! -z "$WAN0LBRATIO" ] >/dev/null 2>&1 || { unset WAN0LBRATIO && continue ;}
    fi

    # WAN1LBRATIO
    if [ -z "${WAN1LBRATIO+x}" ] >/dev/null 2>&1;then
      WAN1LBRATIO="$(echo $WANSLBRATIO | awk -F ":" '{print $2}')"
      [ ! -z "$WAN1LBRATIO" ] >/dev/null 2>&1 || { unset WAN1LBRATIO && continue ;}
    fi

    # WANSCAP
    if [ -z "${WANSCAP+x}" ] >/dev/null 2>&1;then
      WANSCAP="$(nvram get wans_cap & nvramcheck)"
      [ ! -z "$WANSCAP" ] >/dev/null 2>&1 || { unset WANSCAP && continue ;}
    fi

    # WAN0IFNAME
    if [ -z "${WAN0IFNAME+x}" ] >/dev/null 2>&1;then
      WAN0IFNAME="$(nvram get wan0_ifname & nvramcheck)"
      [ ! -z "$WAN0IFNAME" ] >/dev/null 2>&1 || { unset WAN0IFNAME && continue ;}
    fi

    # WAN0DUALWANDEV
    if [ -z "${WAN0DUALWANDEV+x}" ] >/dev/null 2>&1;then
      WAN0DUALWANDEV="$(nvram get nvram get wans_dualwan | awk '{print $1}' & nvramcheck)"
      [ ! -z "$WAN0DUALWANDEV" ] >/dev/null 2>&1 || { unset WAN0DUALWANDEV && continue ;}
    fi

    # WAN1IFNAME
    if [ -z "${WAN1IFNAME+x}" ] >/dev/null 2>&1;then
      WAN1IFNAME="$(nvram get wan1_ifname & nvramcheck)"
      [ ! -z "$WAN1IFNAME" ] >/dev/null 2>&1 || { unset WAN1IFNAME && continue ;}
    fi

    # WAN1DUALWANDEV
    if [ -z "${WAN1DUALWANDEV+x}" ] >/dev/null 2>&1;then
      WAN1DUALWANDEV="$(nvram get nvram get wans_dualwan | awk '{print $2}' & nvramcheck)"
      [ ! -z "$WAN1DUALWANDEV" ] >/dev/null 2>&1 || { unset WAN1DUALWANDEV && continue ;}
    fi

    # IPV6SERVICE
    if [ -z "${IPV6SERVICE+x}" ] >/dev/null 2>&1;then
      IPV6SERVICE="$(nvram get ipv6_service & nvramcheck)"
      [ ! -z "$IPV6SERVICE" ] >/dev/null 2>&1 || { unset IPV6SERVICE && continue ;}
    fi

    # LANIFNAME
    if [ -z "${LANIFNAME+x}" ] >/dev/null 2>&1;then
      LANIFNAME="$(nvram get lan_ifname & nvramcheck)"
      [ ! -z "$LANIFNAME" ] >/dev/null 2>&1 || { unset LANIFNAME && continue ;}
    fi

    globalwansync=1
  done

# Get Active WAN Parameters
elif [[ "$GETWANMODE" == "3" ]] >/dev/null 2>&1;then
  while [ -z "${activewansync+x}" ] >/dev/null 2>&1 || [[ "$activewansync" == "0" ]] >/dev/null 2>&1;do
    activewansync=0

    # Get WAN0 Active Parameters
    # WAN0ENABLE
    if [ -z "${WAN0ENABLE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0ENABLE+x}" ] >/dev/null 2>&1;then
      WAN0ENABLE="$(nvram get wan0_enable & nvramcheck)"
      [ ! -z "$WAN0ENABLE" ] >/dev/null 2>&1 \
      && zWAN0ENABLE="$WAN0ENABLE" \
      || { unset WAN0ENABLE ; unset zWAN0ENABLE && continue ;}
    else
      [[ "$zWAN0ENABLE" != "$WAN0ENABLE" ]] >/dev/null 2>&1 && zWAN0ENABLE="$WAN0ENABLE"
      WAN0ENABLE="$(nvram get wan0_enable & nvramcheck)"
      [ ! -z "$WAN0ENABLE" ] >/dev/null 2>&1 || WAN0ENABLE="$zWAN0ENABLE"
    fi

    # WAN0STATE
    if [ -z "${WAN0STATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0STATE+x}" ] >/dev/null 2>&1;then
      WAN0STATE="$(nvram get wan0_state_t & nvramcheck)"
      [ ! -z "$WAN0STATE" ] >/dev/null 2>&1 \
      && zWAN0STATE="$WAN0STATE" \
      || { unset WAN0STATE ; unset zWAN0STATE && continue ;}
    else
      [[ "$zWAN0STATE" != "$WAN0STATE" ]] >/dev/null 2>&1 && zWAN0STATE="$WAN0STATE"
      WAN0STATE="$(nvram get wan0_state_t & nvramcheck)"
      [ ! -z "$WAN0STATE" ] >/dev/null 2>&1 || WAN0STATE="$zWAN0STATE"
    fi

    # WAN0AUXSTATE
    if [ -z "${WAN0AUXSTATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0AUXSTATE+x}" ] >/dev/null 2>&1;then
      WAN0AUXSTATE="$(nvram get wan0_auxstate_t & nvramcheck)"
      [ ! -z "$WAN0AUXSTATE" ] >/dev/null 2>&1 \
      && zWAN0AUXSTATE="$WAN0AUXSTATE" \
      || { unset WAN0AUXSTATE ; unset zWAN0AUXSTATE && continue ;}
    else
      [[ "$zWAN0AUXSTATE" != "$WAN0AUXSTATE" ]] >/dev/null 2>&1 && zWAN0AUXSTATE="$WAN0AUXSTATE"
      WAN0AUXSTATE="$(nvram get wan0_auxstate_t & nvramcheck)"
      [ ! -z "$WAN0AUXSTATE" ] >/dev/null 2>&1 || WAN0AUXSTATE="$zWAN0AUXSTATE"
    fi

    # WAN0SBSTATE
    if [ -z "${WAN0SBSTATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0SBSTATE+x}" ] >/dev/null 2>&1;then
      WAN0SBSTATE="$(nvram get wan0_sbstate_t & nvramcheck)"
      [ ! -z "$WAN0SBSTATE" ] >/dev/null 2>&1 \
      && zWAN0SBSTATE="$WAN0SBSTATE" \
      || { unset WAN0SBSTATE ; unset zWAN0SBSTATE && continue ;}
    else
      [[ "$zWAN0SBSTATE" != "$WAN0SBSTATE" ]] >/dev/null 2>&1 && zWAN0SBSTATE="$WAN0SBSTATE"
      WAN0SBSTATE="$(nvram get wan0_sbstate_t & nvramcheck)"
      [ ! -z "$WAN0SBSTATE" ] >/dev/null 2>&1 || WAN0SBSTATE="$zWAN0SBSTATE"
    fi

    # WAN0REALIPSTATE
    if [ -z "${WAN0REALIPSTATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0REALIPSTATE+x}" ] >/dev/null 2>&1;then
      WAN0REALIPSTATE="$(nvram get wan0_realip_state & nvramcheck)"
      [ ! -z "$WAN0REALIPSTATE" ] >/dev/null 2>&1 \
      && zWAN0REALIPSTATE="$WAN0REALIPSTATE" \
      || { unset WAN0REALIPSTATE ; unset zWAN0REALIPSTATE && continue ;}
    else
      [[ "$zWAN0REALIPSTATE" != "$WAN0REALIPSTATE" ]] >/dev/null 2>&1 && zWAN0REALIPSTATE="$WAN0REALIPSTATE"
      WAN0REALIPSTATE="$(nvram get wan0_realip_state & nvramcheck)"
      [ ! -z "$WAN0REALIPSTATE" ] >/dev/null 2>&1 || WAN0REALIPSTATE="$zWAN0REALIPSTATE"
    fi

    # WAN0LINKWAN
    if [ -z "${WAN0LINKWAN+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0LINKWAN+x}" ] >/dev/null 2>&1;then
      WAN0LINKWAN="$(nvram get link_wan & nvramcheck)"
      [ ! -z "$WAN0LINKWAN" ] >/dev/null 2>&1 \
      && zWAN0LINKWAN="$WAN0LINKWAN" \
      || { unset WAN0LINKWAN ; unset zWAN0LINKWAN && continue ;}
    else
      [[ "$zWAN0LINKWAN" != "$WAN0LINKWAN" ]] >/dev/null 2>&1 && zWAN0LINKWAN="$WAN0LINKWAN"
      WAN0LINKWAN="$(nvram get link_wan & nvramcheck)"
      [ ! -z "$WAN0LINKWAN" ] >/dev/null 2>&1 || WAN0LINKWAN="$zWAN0LINKWAN"
    fi

    # WAN0GWIFNAME
    if [ -z "${WAN0GWIFNAME+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0GWIFNAME+x}" ] >/dev/null 2>&1;then
      WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
      { [ ! -z "$WAN0GWIFNAME" ] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 ;} \
      && zWAN0GWIFNAME="$WAN0GWIFNAME" \
      || { unset WAN0GWIFNAME ; unset zWAN0GWIFNAME && continue ;}
    elif { [ -z "$WAN0GWIFNAME" ] >/dev/null 2>&1 || [ -z "$zWAN0GWIFNAME" ] >/dev/null 2>&1 ;} && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1;then
      { unset WAN0GWIFNAME ; unset zWAN0GWIFNAME ;} && continue
    else
      [[ "$zWAN0GWIFNAME" != "$WAN0GWIFNAME" ]] >/dev/null 2>&1 && zWAN0GWIFNAME="$WAN0GWIFNAME"
      WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"
      [ ! -z "$WAN0GWIFNAME" ] >/dev/null 2>&1 || WAN0GWIFNAME="$zWAN0GWIFNAME"
    fi

    # WAN0GWMAC
    if [ -z "${WAN0GWMAC+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0GWMAC+x}" ] >/dev/null 2>&1;then
      WAN0GWMAC="$(nvram get wan0_gw_mac & nvramcheck)"
      { [ ! -z "$WAN0GWMAC" ] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 ;} \
      && zWAN0GWMAC="$WAN0GWMAC" \
      || { unset WAN0GWMAC ; unset zWAN0GWMAC && continue ;}
    elif { [ -z "$WAN0GWMAC" ] >/dev/null 2>&1 || [ -z "$zWAN0GWMAC" ] >/dev/null 2>&1 ;} && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1;then
      { unset WAN0GWMAC ; unset zWAN0GWMAC ;} && continue
    else
      [[ "$zWAN0GWMAC" != "$WAN0GWMAC" ]] >/dev/null 2>&1 && zWAN0GWMAC="$WAN0GWMAC"
      WAN0GWMAC="$(nvram get wan0_gw_mac & nvramcheck)"
      [ ! -z "$WAN0GWMAC" ] >/dev/null 2>&1 || WAN0GWMAC="$zWAN0GWMAC"
    fi

    # WAN0PRIMARY
    if [ -z "${WAN0PRIMARY+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0PRIMARY+x}" ] >/dev/null 2>&1;then
      WAN0PRIMARY="$(nvram get wan0_primary & nvramcheck)"
      [ ! -z "$WAN0PRIMARY" ] >/dev/null 2>&1 \
      && zWAN0PRIMARY="$WAN0PRIMARY" \
      || { unset WAN0PRIMARY ; unset zWAN0PRIMARY && continue ;}
    elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
      [[ "$zWAN0PRIMARY" != "$WAN0PRIMARY" ]] >/dev/null 2>&1 && zWAN0PRIMARY="$WAN0PRIMARY"
      WAN0PRIMARY="$(nvram get wan0_primary & nvramcheck)"
      [ ! -z "$WAN0PRIMARY" ] >/dev/null 2>&1 || WAN0PRIMARY="$zWAN0PRIMARY"
    fi

    # WAN0USBMODEMREADY
    if [ -z "${WAN0USBMODEMREADY+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0USBMODEMREADY+x}" ] >/dev/null 2>&1;then
      WAN0USBMODEMREADY="$(nvram get wan0_is_usb_modem_ready & nvramcheck)"
      [ ! -z "$WAN0USBMODEMREADY" ] >/dev/null 2>&1 \
      && zWAN0USBMODEMREADY="$WAN0USBMODEMREADY" \
      || { unset WAN0USBMODEMREADY ; unset zWAN0USBMODEMREADY && continue ;}
    elif [[ "$WAN0DUALWANDEV" == "usb" ]] >/dev/null 2>&1;then
      [[ "$zWAN0USBMODEMREADY" != "$WAN0USBMODEMREADY" ]] >/dev/null 2>&1 && zWAN0USBMODEMREADY="$WAN0USBMODEMREADY"
      WAN0USBMODEMREADY="$(nvram get wan0_is_usb_modem_ready & nvramcheck)"
      [ ! -z "$WAN0USBMODEMREADY" ] >/dev/null 2>&1 || WAN0USBMODEMREADY="$zWAN0USBMODEMREADY"
    fi

    # WAN0IPADDR
    if [ -z "${WAN0IPADDR+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0IPADDR+x}" ] >/dev/null 2>&1;then
      WAN0IPADDR="$(nvram get wan0_ipaddr & nvramcheck)"
      { [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 || [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 ;} \
      && zWAN0IPADDR="$WAN0IPADDR" \
      || { unset WAN0IPADDR ; unset zWAN0IPADDR && continue ;}
    else
      [[ "$zWAN0IPADDR" != "$WAN0IPADDR" ]] >/dev/null 2>&1 && zWAN0IPADDR="$WAN0IPADDR"
      WAN0IPADDR="$(nvram get wan0_ipaddr & nvramcheck)"
      [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 || WAN0IPADDR="$zWAN0IPADDR"
    fi

    # WAN0GATEWAY
    if [ -z "${WAN0GATEWAY+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0GATEWAY+x}" ] >/dev/null 2>&1;then
      WAN0GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
      { [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 || [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 ;} \
      && zWAN0GATEWAY="$WAN0GATEWAY" \
      || { unset WAN0GATEWAY ; unset zWAN0GATEWAY && continue ;}
    else
      [[ "$zWAN0GATEWAY" != "$WAN0GATEWAY" ]] >/dev/null 2>&1 && zWAN0GATEWAY="$WAN0GATEWAY"
      WAN0GATEWAY="$(nvram get wan0_gateway & nvramcheck)"
      [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 || WAN0GATEWAY="$zWAN0GATEWAY"
    fi

    # WAN0REALIPADDR
    if [ -z "${WAN0REALIPADDR+x}" ] >/dev/null 2>&1 || [ -z "${zWAN0REALIPADDR+x}" ] >/dev/null 2>&1;then
      WAN0REALIPADDR="$(nvram get wan0_realip_ip & nvramcheck)"
      { [ ! -z "$WAN0REALIPADDR" ] >/dev/null 2>&1 || [[ "$WAN0REALIPSTATE" != "2" ]] >/dev/null 2>&1 ;} \
      && zWAN0REALIPADDR="$WAN0REALIPADDR" \
      || { unset WAN0REALIPADDR ; unset zWAN0REALIPADDR && continue ;}
    elif [[ "$WAN0REALIPSTATE" != "0" ]] >/dev/null 2>&1;then
      [[ "$zWAN0REALIPADDR" != "$WAN0REALIPADDR" ]] >/dev/null 2>&1 && zWAN0REALIPADDR="$WAN0REALIPADDR"
      WAN0REALIPADDR="$(nvram get wan0_realip_ip & nvramcheck)"
      [ ! -z "$WAN0REALIPADDR" ] >/dev/null 2>&1 || WAN0REALIPADDR="$zWAN0REALIPADDR"
    fi

    # Get WAN1 Active Parameters
    # WAN1ENABLE
    if [ -z "${WAN1ENABLE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1ENABLE+x}" ] >/dev/null 2>&1;then
      WAN1ENABLE="$(nvram get wan1_enable & nvramcheck)"
      [ ! -z "$WAN1ENABLE" ] >/dev/null 2>&1 \
      && zWAN1ENABLE="$WAN1ENABLE" \
      || { unset WAN1ENABLE ; unset zWAN1ENABLE && continue ;}
    else
      [[ "$zWAN1ENABLE" != "$WAN1ENABLE" ]] >/dev/null 2>&1 && zWAN1ENABLE="$WAN1ENABLE"
      WAN1ENABLE="$(nvram get wan1_enable & nvramcheck)"
      [ ! -z "$WAN1ENABLE" ] >/dev/null 2>&1 || WAN1ENABLE="$zWAN1ENABLE"
    fi

    # WAN1STATE
    if [ -z "${WAN1STATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1STATE+x}" ] >/dev/null 2>&1;then
      WAN1STATE="$(nvram get wan1_state_t & nvramcheck)"
      [ ! -z "$WAN1STATE" ] >/dev/null 2>&1 \
      && zWAN1STATE="$WAN1STATE" \
      || { unset WAN1STATE ; unset zWAN1STATE && continue ;}
    else
      [[ "$zWAN1STATE" != "$WAN1STATE" ]] >/dev/null 2>&1 && zWAN1STATE="$WAN1STATE"
      WAN1STATE="$(nvram get wan1_state_t & nvramcheck)"
      [ ! -z "$WAN1STATE" ] >/dev/null 2>&1 || WAN1STATE="$zWAN1STATE"
    fi

    # WAN1AUXSTATE
    if [ -z "${WAN1AUXSTATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1AUXSTATE+x}" ] >/dev/null 2>&1;then
      WAN1AUXSTATE="$(nvram get wan1_auxstate_t & nvramcheck)"
      [ ! -z "$WAN1AUXSTATE" ] >/dev/null 2>&1 \
      && zWAN1AUXSTATE="$WAN1AUXSTATE" \
      || { unset WAN1AUXSTATE ; unset zWAN1AUXSTATE && continue ;}
    else
      [[ "$zWAN1AUXSTATE" != "$WAN1AUXSTATE" ]] >/dev/null 2>&1 && zWAN1AUXSTATE="$WAN1AUXSTATE"
      WAN1AUXSTATE="$(nvram get wan1_auxstate_t & nvramcheck)"
      [ ! -z "$WAN1AUXSTATE" ] >/dev/null 2>&1 || WAN1AUXSTATE="$zWAN1AUXSTATE"
    fi

    # WAN1SBSTATE
    if [ -z "${WAN1SBSTATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1SBSTATE+x}" ] >/dev/null 2>&1;then
      WAN1SBSTATE="$(nvram get wan1_sbstate_t & nvramcheck)"
      [ ! -z "$WAN1SBSTATE" ] >/dev/null 2>&1 \
      && zWAN1SBSTATE="$WAN1SBSTATE" \
      || { unset WAN1SBSTATE ; unset zWAN1SBSTATE && continue ;}
    else
      [[ "$zWAN1SBSTATE" != "$WAN1SBSTATE" ]] >/dev/null 2>&1 && zWAN1SBSTATE="$WAN1SBSTATE"
      WAN1SBSTATE="$(nvram get wan1_sbstate_t & nvramcheck)"
      [ ! -z "$WAN1SBSTATE" ] >/dev/null 2>&1 || WAN1SBSTATE="$zWAN1SBSTATE"
    fi

    # WAN1REALIPSTATE
    if [ -z "${WAN1REALIPSTATE+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1REALIPSTATE+x}" ] >/dev/null 2>&1;then
      WAN1REALIPSTATE="$(nvram get wan1_realip_state & nvramcheck)"
      [ ! -z "$WAN1REALIPSTATE" ] >/dev/null 2>&1 \
      && zWAN1REALIPSTATE="$WAN1REALIPSTATE" \
      || { unset WAN1REALIPSTATE ; unset zWAN1REALIPSTATE && continue ;}
    else
      [[ "$zWAN1REALIPSTATE" != "$WAN1REALIPSTATE" ]] >/dev/null 2>&1 && zWAN1REALIPSTATE="$WAN1REALIPSTATE"
      WAN1REALIPSTATE="$(nvram get wan1_realip_state & nvramcheck)"
      [ ! -z "$WAN1REALIPSTATE" ] >/dev/null 2>&1 || WAN1REALIPSTATE="$zWAN1REALIPSTATE"
    fi

    # WAN1LINKWAN
    if [ -z "${WAN1LINKWAN+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1LINKWAN+x}" ] >/dev/null 2>&1;then
      WAN1LINKWAN="$(nvram get link_wan1 & nvramcheck)"
      [ ! -z "$WAN1LINKWAN" ] >/dev/null 2>&1 \
      && zWAN1LINKWAN="$WAN1LINKWAN" \
      || { unset WAN1LINKWAN ; unset zWAN1LINKWAN && continue ;}
    else
      [[ "$zWAN1LINKWAN" != "$WAN1LINKWAN" ]] >/dev/null 2>&1 && zWAN1LINKWAN="$WAN1LINKWAN"
      WAN1LINKWAN="$(nvram get link_wan1 & nvramcheck)"
      [ ! -z "$WAN1LINKWAN" ] >/dev/null 2>&1 || WAN1LINKWAN="$zWAN1LINKWAN"
    fi

    # WAN1GWIFNAME
    if [ -z "${WAN1GWIFNAME+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1GWIFNAME+x}" ] >/dev/null 2>&1;then
      WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
      { [ ! -z "$WAN1GWIFNAME" ] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 ;} \
      && zWAN1GWIFNAME="$WAN1GWIFNAME" \
      || { unset WAN1GWIFNAME ; unset zWAN1GWIFNAME && continue ;}
    elif { [ -z "$WAN1GWIFNAME" ] >/dev/null 2>&1 || [ -z "$zWAN1GWIFNAME" ] >/dev/null 2>&1 ;} && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1;then
      { unset WAN1GWIFNAME ; unset zWAN1GWIFNAME ;} && continue
    else
      [[ "$zWAN1GWIFNAME" != "$WAN1GWIFNAME" ]] >/dev/null 2>&1 && zWAN1GWIFNAME="$WAN1GWIFNAME"
      WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"
      [ ! -z "$WAN1GWIFNAME" ] >/dev/null 2>&1 || WAN1GWIFNAME="$zWAN1GWIFNAME"
    fi

    # WAN1GWMAC
    if [ -z "${WAN1GWMAC+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1GWMAC+x}" ] >/dev/null 2>&1;then
      WAN1GWMAC="$(nvram get wan1_gw_mac & nvramcheck)"
      { [ ! -z "$WAN1GWMAC" ] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 ;} \
      && zWAN1GWMAC="$WAN1GWMAC" \
      || { unset WAN1GWMAC ; unset zWAN1GWMAC && continue ;}
    elif { [ -z "$WAN1GWMAC" ] >/dev/null 2>&1 || [ -z "$zWAN1GWMAC" ] >/dev/null 2>&1 ;} && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1;then
      { unset WAN1GWMAC ; unset zWAN1GWMAC ;} && continue
    else
      [[ "$zWAN1GWMAC" != "$WAN1GWMAC" ]] >/dev/null 2>&1 && zWAN1GWMAC="$WAN1GWMAC"
      WAN1GWMAC="$(nvram get wan1_gw_mac & nvramcheck)"
      [ ! -z "$WAN1GWMAC" ] >/dev/null 2>&1 || WAN1GWMAC="$zWAN1GWMAC"
    fi

    # WAN1PRIMARY
    if [ -z "${WAN1PRIMARY+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1PRIMARY+x}" ] >/dev/null 2>&1;then
      WAN1PRIMARY="$(nvram get wan1_primary & nvramcheck)"
      [ ! -z "$WAN1PRIMARY" ] >/dev/null 2>&1 \
      && zWAN1PRIMARY="$WAN1PRIMARY" \
      || { unset WAN1PRIMARY ; unset zWAN1PRIMARY && continue ;}
    elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
      [[ "$zWAN1PRIMARY" != "$WAN1PRIMARY" ]] >/dev/null 2>&1 && zWAN1PRIMARY="$WAN1PRIMARY"
      WAN1PRIMARY="$(nvram get wan1_primary & nvramcheck)"
      [ ! -z "$WAN1PRIMARY" ] >/dev/null 2>&1 || WAN1PRIMARY="$zWAN1PRIMARY"
    fi

    # WAN1USBMODEMREADY
    if [ -z "${WAN1USBMODEMREADY+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1USBMODEMREADY+x}" ] >/dev/null 2>&1;then
      WAN1USBMODEMREADY="$(nvram get wan1_is_usb_modem_ready & nvramcheck)"
      [ ! -z "$WAN1USBMODEMREADY" ] >/dev/null 2>&1 \
      && zWAN1USBMODEMREADY="$WAN1USBMODEMREADY" \
      || { unset WAN1USBMODEMREADY ; unset zWAN1USBMODEMREADY && continue ;}
    elif [[ "$WAN1DUALWANDEV" == "usb" ]] >/dev/null 2>&1;then
      [[ "$zWAN1USBMODEMREADY" != "$WAN1USBMODEMREADY" ]] >/dev/null 2>&1 && zWAN1USBMODEMREADY="$WAN1USBMODEMREADY"
      WAN1USBMODEMREADY="$(nvram get wan1_is_usb_modem_ready & nvramcheck)"
      [ ! -z "$WAN1USBMODEMREADY" ] >/dev/null 2>&1 || WAN1USBMODEMREADY="$zWAN1USBMODEMREADY"
    fi

    # WAN1IPADDR
    if [ -z "${WAN1IPADDR+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1IPADDR+x}" ] >/dev/null 2>&1;then
      WAN1IPADDR="$(nvram get wan1_ipaddr & nvramcheck)"
      { [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 ;} \
      && zWAN1IPADDR="$WAN1IPADDR" \
      || { unset WAN1IPADDR ; unset zWAN1IPADDR && continue ;}
    else
      [[ "$zWAN1IPADDR" != "$WAN1IPADDR" ]] >/dev/null 2>&1 && zWAN1IPADDR="$WAN1IPADDR"
      WAN1IPADDR="$(nvram get wan1_ipaddr & nvramcheck)"
      [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 || WAN1IPADDR="$zWAN1IPADDR"
    fi

    # WAN1GATEWAY
    if [ -z "${WAN1GATEWAY+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1GATEWAY+x}" ] >/dev/null 2>&1;then
      WAN1GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
      { [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 ;} \
      && zWAN1GATEWAY="$WAN1GATEWAY" \
      || { unset WAN1GATEWAY ; unset zWAN1GATEWAY && continue ;}
    else
      [[ "$zWAN1GATEWAY" != "$WAN1GATEWAY" ]] >/dev/null 2>&1 && zWAN1GATEWAY="$WAN1GATEWAY"
      WAN1GATEWAY="$(nvram get wan1_gateway & nvramcheck)"
      [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 || WAN1GATEWAY="$zWAN1GATEWAY"
    fi

    # WAN1REALIPADDR
    if [ -z "${WAN1REALIPADDR+x}" ] >/dev/null 2>&1 || [ -z "${zWAN1REALIPADDR+x}" ] >/dev/null 2>&1;then
      WAN1REALIPADDR="$(nvram get wan1_realip_ip & nvramcheck)"
      { [ ! -z "$WAN1REALIPADDR" ] >/dev/null 2>&1 || [[ "$WAN1REALIPSTATE" != "2" ]] >/dev/null 2>&1 ;} \
      && zWAN1REALIPADDR="$WAN1REALIPADDR" \
      || { unset WAN1REALIPADDR ; unset zWAN1REALIPADDR && continue ;}
    elif [[ "$WAN1REALIPSTATE" != "0" ]] >/dev/null 2>&1;then
      [[ "$zWAN1REALIPADDR" != "$WAN1REALIPADDR" ]] >/dev/null 2>&1 && zWAN1REALIPADDR="$WAN1REALIPADDR"
      WAN1REALIPADDR="$(nvram get wan1_realip_ip & nvramcheck)"
      [ ! -z "$WAN1REALIPADDR" ] >/dev/null 2>&1 || WAN1REALIPADDR="$zWAN1REALIPADDR"
    fi

    # Get IPv6 Active Parameters
    # IPV6STATE
    if [ -z "${IPV6STATE+x}" ] >/dev/null 2>&1 || [ -z "${zIPV6STATE+x}" ] >/dev/null 2>&1;then
      IPV6STATE="$(nvram get ipv6_state_t & nvramcheck)"
      [ ! -z "$IPV6STATE" ] >/dev/null 2>&1 \
      && zIPV6STATE="$IPV6STATE" \
      || { unset IPV6STATE ; unset zIPV6STATE && continue ;}
    elif [[ "$IPV6SERVICE" != "disabled" ]] >/dev/null 2>&1;then
      [[ "$zIPV6STATE" != "$IPV6STATE" ]] >/dev/null 2>&1 && zIPV6STATE="$IPV6STATE"
      IPV6STATE="$(nvram get ipv6_state_t & nvramcheck)"
      [ ! -z "$IPV6STATE" ] >/dev/null 2>&1 || IPV6STATE="$zIPV6STATE"
    fi

    # IPV6IPADDR
    if [ -z "${IPV6IPADDR+x}" ] >/dev/null 2>&1 || [ -z "${zIPV6IPADDR+x}" ] >/dev/null 2>&1;then
      IPV6IPADDR="$(nvram get ipv6_wan_addr & nvramcheck)"
      { [ ! -z "$IPV6IPADDR" ] >/dev/null 2>&1 || [[ "$IPV6SERVICE" == "disabled" ]] || [[ "$IPV6STATE" == "0" ]] >/dev/null 2>&1 ;} \
      && zIPV6IPADDR="$IPV6IPADDR" \
      || { unset IPV6IPADDR ; unset zIPV6IPADDR && continue ;}
    elif [[ "$IPV6SERVICE" != "disabled" ]] >/dev/null 2>&1;then
      [[ "$zIPV6IPADDR" != "$IPV6IPADDR" ]] >/dev/null 2>&1 && zIPV6IPADDR="$IPV6IPADDR"
      IPV6IPADDR="$(nvram get ipv6_wan_addr & nvramcheck)"
      [ ! -z "$IPV6IPADDR" ] >/dev/null 2>&1 || IPV6IPADDR="$zIPV6IPADDR"
    fi

    # Get QoS Active Parameters
    # QOSENABLE
    if [ -z "${QOSENABLE+x}" ] >/dev/null 2>&1 || [ -z "${zQOSENABLE+x}" ] >/dev/null 2>&1;then
      QOSENABLE="$(nvram get qos_enable & nvramcheck)"
      [ ! -z "$QOSENABLE" ] >/dev/null 2>&1 \
      && zQOSENABLE="$QOSENABLE" \
      || { unset QOSENABLE ; unset zQOSENABLE && continue ;}
    elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
      [[ "$zQOSENABLE" != "$QOSENABLE" ]] >/dev/null 2>&1 && zQOSENABLE="$QOSENABLE"
      QOSENABLE="$(nvram get qos_enable & nvramcheck)"
      [ ! -z "$QOSENABLE" ] >/dev/null 2>&1 || QOSENABLE="$zQOSENABLE"
    fi

    # QOS_OBW
    if [ -z "${QOS_OBW+x}" ] >/dev/null 2>&1 || [ -z "${zQOS_OBW+x}" ] >/dev/null 2>&1;then
      QOS_OBW="$(nvram get qos_obw & nvramcheck)"
      { [ ! -z "$QOS_OBW" ] || [[ "$QOSENABLE" == "0" ]] ;} >/dev/null 2>&1 \
      && zQOS_OBW="$QOS_OBW" \
      || { unset QOS_OBW ; unset zQOS_OBW && continue ;}
    elif [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1;then
      [[ "$zQOS_OBW" != "$QOS_OBW" ]] >/dev/null 2>&1 && zQOS_OBW="$QOS_OBW"
      QOS_OBW="$(nvram get qos_obw & nvramcheck)"
      [ ! -z "$QOS_OBW" ] >/dev/null 2>&1 || QOS_OBW="$zQOS_OBW"
    fi

    # QOS_IBW
    if [ -z "${QOS_IBW+x}" ] >/dev/null 2>&1 || [ -z "${zQOS_IBW+x}" ] >/dev/null 2>&1;then
      QOS_IBW="$(nvram get qos_ibw & nvramcheck)"
      { [ ! -z "$QOS_IBW" ] || [[ "$QOSENABLE" == "0" ]] ;} >/dev/null 2>&1 \
      && zQOS_IBW="$QOS_IBW" \
      || { unset QOS_IBW ; unset zQOS_IBW && continue ;}
    elif [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1;then
      [[ "$zQOS_IBW" != "$QOS_IBW" ]] >/dev/null 2>&1 && zQOS_IBW="$QOS_IBW"
      QOS_IBW="$(nvram get qos_ibw & nvramcheck)"
      [ ! -z "$QOS_IBW" ] >/dev/null 2>&1 || QOS_IBW="$zQOS_IBW"
    fi

    # QOSOVERHEAD
    if [ -z "${QOSOVERHEAD+x}" ] >/dev/null 2>&1 || [ -z "${zQOSOVERHEAD+x}" ] >/dev/null 2>&1;then
      QOSOVERHEAD="$(nvram get qos_ibw & nvramcheck)"
      { [ ! -z "$QOSOVERHEAD" ] || [[ "$QOSENABLE" == "0" ]] ;} >/dev/null 2>&1 \
      && zQOSOVERHEAD="$QOSOVERHEAD" \
      || { unset QOSOVERHEAD ; unset zQOSOVERHEAD && continue ;}
    elif [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1;then
      [[ "$zQOSOVERHEAD" != "$QOSOVERHEAD" ]] >/dev/null 2>&1 && zQOSOVERHEAD="$QOSOVERHEAD"
      QOSOVERHEAD="$(nvram get qos_ibw & nvramcheck)"
      [ ! -z "$QOSOVERHEAD" ] >/dev/null 2>&1 || QOSOVERHEAD="$zQOSOVERHEAD"
    fi

    activewansync=1
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
[ -z "${WANSTATUSMODE+x}" ] >/dev/null 2>&1 && WANSTATUSMODE="1"
logger -p 6 -t "$ALIAS" "Debug - WAN Status Mode: "$WANSTATUSMODE""

if [[ "$WANSTATUSMODE" == "1" ]] >/dev/null 2>&1;then
  if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null 2>&1;then
    { [ ! -z "${READYSTATE+x}" ] >/dev/null 2>&1 && [ ! -z "${WAN0STATUS+x}" ] >/dev/null 2>&1 && [ ! -z "${STATUS+x}" ] >/dev/null 2>&1 ;} && { [[ "$READYSTATE" != "0" ]] >/dev/null 2>&1 && [[ "$WAN0STATUS" != "$STATUS" ]] >/dev/null 2>&1 && { [[ "$email" != "1" ]] >/dev/null 2>&1 && email=1 ;} ;}
    [ ! -z "${STATUS+x}" ] >/dev/null 2>&1 && WAN0STATUS="$STATUS"
    [ ! -z "${PINGPATH+x}" ] >/dev/null 2>&1 && WAN0PINGPATH="$PINGPATH"
    [ ! -z "${PACKETLOSS+x}" ] >/dev/null 2>&1 && WAN0PACKETLOSS="$PACKETLOSS"
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: "$WAN0STATUS""
  elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null 2>&1;then
    { [ ! -z "${READYSTATE+x}" ] >/dev/null 2>&1 && [ ! -z "${WAN1STATUS+x}" ] >/dev/null 2>&1 && [ ! -z "${STATUS+x}" ] >/dev/null 2>&1 ;} && { [[ "$READYSTATE" != "0" ]] >/dev/null 2>&1 && [[ "$WAN1STATUS" != "$STATUS" ]] >/dev/null 2>&1 && { [[ "$email" != "1" ]] >/dev/null 2>&1 && email=1 ;} ;}
    [ ! -z "${STATUS+x}" ] >/dev/null 2>&1 && WAN1STATUS="$STATUS"
    [ ! -z "${PINGPATH+x}" ] >/dev/null 2>&1 && WAN1PINGPATH="$PINGPATH"
    [ ! -z "${PACKETLOSS+x}" ] >/dev/null 2>&1 && WAN1PACKETLOSS="$PACKETLOSS"
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: "$WAN1STATUS""
  fi
  unset STATUS
elif [[ "$WANSTATUSMODE" == "2" ]] >/dev/null 2>&1;then
  [[ "$(nvram get wan0_enable & nvramcheck)" == "1" ]] >/dev/null 2>&1 && [[ "$(nvram get wan0_auxstate_t & nvramcheck)" == "0" ]] >/dev/null 2>&1 && { [[ "$(nvram get wan0_state_t & nvramcheck)" != "2" ]] >/dev/null 2>&1 || [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 ;} && WAN0STATUS=DISCONNECTED && email=1
  [[ "$(nvram get wan0_enable & nvramcheck)" == "1" ]] >/dev/null 2>&1 && [[ "$(nvram get wan0_auxstate_t & nvramcheck)" != "0" ]] >/dev/null 2>&1 && WAN0STATUS=UNPLUGGED && email=1
  [[ "$(nvram get wan0_enable & nvramcheck)" == "0" ]] >/dev/null 2>&1 && WAN0STATUS=DISABLED && email=1
  [[ "$(nvram get wan1_enable & nvramcheck)" == "1" ]] >/dev/null 2>&1 && [[ "$(nvram get wan1_auxstate_t & nvramcheck)" == "0" ]] >/dev/null 2>&1 && { [[ "$(nvram get wan1_state_t & nvramcheck)" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1 ;} && WAN1STATUS=DISCONNECTED && email=1
  [[ "$(nvram get wan1_enable & nvramcheck)" == "1" ]] >/dev/null 2>&1 && [[ "$(nvram get wan1_auxstate_t & nvramcheck)" != "0" ]] >/dev/null 2>&1 && WAN1STATUS=UNPLUGGED && email=1
  [[ "$(nvram get wan1_enable & nvramcheck)" == "0" ]] >/dev/null 2>&1 && WAN1STATUS=DISABLED && email=1
fi

unset WANSTATUSMODE
return
}

# Restart WAN0
restartwan0 ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: restartwan0"

# Check if WAN0 is Enabled
if [[ "$(nvram get "$WAN0"_enable & nvramcheck)" == "0" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Not Restarting "$WAN0" because it is not Enabled"
  return
fi

# Restart WAN0 Interface
logger -p 1 -st "$ALIAS" "Restart WAN0 - Restarting "$WAN0""
service "restart_wan_if 0" &
restartwan0pid=$!

# Set Timeout for WAN interface to restart to a max of 30 seconds and while WAN Interface is State 6
restartwan0timeout="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$restartwan0timeout" ]] >/dev/null 2>&1 && [ ! -z "$(ps | awk '{print $1}' | grep -w "$restartwan0pid")" ] >/dev/null 2>&1;do
  wait $restartwan0pid
  wan0state="$(nvram get "$WAN0"_state_t & nvramcheck)"
  if [[ "$wan0state" == "6" ]] >/dev/null 2>&1;then
    continue
  elif  [[ "$wan0state" == "1" ]] >/dev/null 2>&1 || [[ "$wan0state" == "2" ]] >/dev/null 2>&1;then
    break
  elif  [[ "$wan0state" == "3" ]] >/dev/null 2>&1;then
    nvram set "$WAN0"_state_t="2"
  else
    sleep 1
  fi
done

# Check WAN Routing Table for Default Routes if WAN0 is Connected
if [[ "$wan0state" == "2" ]] >/dev/null 2>&1;then
  checkroutingtable &
  CHECKROUTINGTABLEPID=$!
  wait $CHECKROUTINGTABLEPID
  unset CHECKROUTINGTABLEPID
fi

# Unset Variables
[ ! -z "${wan0state+x}" ]  >/dev/null 2>&1 unset wan0state
[ ! -z "${restartwan0pid+x}" ]  >/dev/null 2>&1 unset restartwan0pid
[ ! -z "${restartwan0timeout+x}" ]  >/dev/null 2>&1 unset restartwan0timeout

return
}

# Restart WAN1
restartwan1 ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: restartwan1"

# Check if WAN1 is Enabled
if [[ "$(nvram get "$WAN1"_enable & nvramcheck)" == "0" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Not Restarting "$WAN1" because it is not Enabled"
  return
fi

# Restart WAN1 Interface
logger -p 1 -st "$ALIAS" "Restart WAN1 - Restarting "$WAN1""
service "restart_wan_if 1" &
restartwan1pid=$!

# Set Timeout for WAN interface to restart to a max of 30 seconds and while WAN Interface is State 6
restartwan1timeout="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$restartwan1timeout" ]] >/dev/null 2>&1 && [ ! -z "$(ps | awk '{print $1}' | grep -w "$restartwan1pid")" ] >/dev/null 2>&1;do
  wait $restartwan1pid
  wan1state="$(nvram get "$WAN1"_state_t & nvramcheck)"
  if [[ "$wan1state" == "6" ]] >/dev/null 2>&1;then
    continue
  elif  [[ "$wan1state" == "1" ]] >/dev/null 2>&1 || [[ "$wan1state" == "2" ]] >/dev/null 2>&1;then
    break
  elif  [[ "$wan1state" == "3" ]] >/dev/null 2>&1;then
    nvram set "$WAN1"_state_t="2"
  else
    sleep 1
  fi
done

# Check WAN Routing Table for Default Routes if WAN0 is Connected
if [[ "$wan1state" == "2" ]] >/dev/null 2>&1;then
  checkroutingtable &
  CHECKROUTINGTABLEPID=$!
  wait $CHECKROUTINGTABLEPID
  unset CHECKROUTINGTABLEPID
fi

# Unset Variables
[ ! -z "${wan1state+x}" ]  >/dev/null 2>&1 unset wan1state
[ ! -z "${restartwan1pid+x}" ]  >/dev/null 2>&1 unset restartwan1pid
[ ! -z "${restartwan1timeout+x}" ]  >/dev/null 2>&1 unset restartwan1timeout

return
}


# Ping WAN0Target
pingwan0target ()
{
# Capture Gateway Interface If Missing
[ -z "${WAN0GWIFNAME+x}" ] >/dev/null 2>&1 && WAN0GWIFNAME="$(nvram get wan0_gw_ifname & nvramcheck)"

# Create Packet Loss File If Missing
if [ ! -f "$WAN0PACKETLOSSFILE" ] >/dev/null 2>&1;then
  touch -a $WAN0PACKETLOSSFILE
  echo "" >> "$WAN0PACKETLOSSFILE"
  echo "" >> "$WAN0PACKETLOSSFILE"
fi

# Capture Packet Loss
PINGWAN0TARGETOUTPUT="$(ping -I $WAN0GWIFNAME $WAN0TARGET -q -c $PINGCOUNT -W $(($PINGCOUNT*PINGTIMEOUT)) -w $(($PINGCOUNT*PINGTIMEOUT)) -s $WAN0PACKETSIZE 2>/dev/null)" \
&& WAN0PACKETLOSS="$(echo $PINGWAN0TARGETOUTPUT | awk '/packet loss/ {print $18}')" \
|| WAN0PACKETLOSS="100%"
if [[ "$WAN0PACKETLOSS" != "100%" ]] >/dev/null 2>&1;then
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
[ -z "${WAN1GWIFNAME+x}" ] >/dev/null 2>&1 && WAN1GWIFNAME="$(nvram get wan1_gw_ifname & nvramcheck)"

# Create Packet Loss File If Missing
if [ ! -f "$WAN1PACKETLOSSFILE" ] >/dev/null 2>&1;then
  touch -a $WAN1PACKETLOSSFILE
  echo "" >> "$WAN1PACKETLOSSFILE"
  echo "" >> "$WAN1PACKETLOSSFILE"
fi

# Capture Packet Loss
PINGWAN1TARGETOUTPUT="$(ping -I $WAN1GWIFNAME $WAN1TARGET -q -c $PINGCOUNT -W $(($PINGCOUNT*PINGTIMEOUT)) -w $(($PINGCOUNT*PINGTIMEOUT)) -s $WAN1PACKETSIZE 2>/dev/null)" \
&& WAN1PACKETLOSS="$(echo $PINGWAN1TARGETOUTPUT | awk '/packet loss/ {print $18}')" \
|| WAN1PACKETLOSS="100%"
if [[ "$WAN1PACKETLOSS" != "100%" ]] >/dev/null 2>&1;then
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
[ -z "${pingfailure0+x}" ] >/dev/null 2>&1 && pingfailure0="0"
[ -z "${pingfailure1+x}" ] >/dev/null 2>&1 && pingfailure1="0"

i=1
while [ "$i" -le "$RECURSIVEPINGCHECK" ] >/dev/null 2>&1;do
  pingwan0target &
  PINGWAN0PID=$!
  pingwan1target &
  PINGWAN1PID=$!
  wait $PINGWAN0PID $PINGWAN1PID
  [ -z "${audiblealarm+x}" ] >/dev/null 2>&1 && audiblealarm=0
  [ -z "${loopaction+x}" ] >/dev/null 2>&1 && loopaction=""
  { [ -z "$WAN0IFNAME" ] >/dev/null 2>&1 || [ -z "$WAN0GWIFNAME" ] >/dev/null 2>&1 ;} && WAN0PACKETLOSS="100%" || WAN0PACKETLOSS="$(sed -n 1p "$WAN0PACKETLOSSFILE")"
  { [ -z "$WAN1IFNAME" ] >/dev/null 2>&1 || [ -z "$WAN1GWIFNAME" ] >/dev/null 2>&1 ;} && WAN1PACKETLOSS="100%" || WAN1PACKETLOSS="$(sed -n 1p "$WAN1PACKETLOSSFILE")"
  if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    WAN0PACKETLOSSCOLOR="${GREEN}"
    WAN1PACKETLOSSCOLOR="${GREEN}"
    [[ "$audiblealarm" != "0" ]] >/dev/null 2>&1 && audiblealarm=0
    [[ "$pingfailure0" != "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=0
    [[ "$pingfailure1" != "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=0
    loopaction="break 1"
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    WAN0PACKETLOSSCOLOR="${RED}"
    WAN1PACKETLOSSCOLOR="${GREEN}"
    [ ! -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ] >/dev/null 2>&1 && audiblealarm=1
    [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && email=1 && pingfailure0=1
    [[ "$pingfailure1" != "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=0
    i=$(($i+1))
    loopaction="continue"
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
    WAN0PACKETLOSSCOLOR="${GREEN}"
    WAN1PACKETLOSSCOLOR="${RED}"
    [ ! -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ] >/dev/null 2>&1 && audiblealarm=1
    [[ "$pingfailure0" != "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Restoration Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=0
    [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Failure Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=1
    i=$(($i+1))
    loopaction="continue"
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1;then
    WAN0PACKETLOSSCOLOR="${RED}"
    WAN1PACKETLOSSCOLOR="${RED}"
    { [ ! -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ] >/dev/null 2>&1 && [ ! -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ] >/dev/null 2>&1 ;} && audiblealarm=1
    [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS" && pingfailure0=1
    [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "Failure Detected - WAN1 Packet Loss: $WAN1PACKETLOSS" && pingfailure1=1
    i=$(($i+1))
    loopaction="continue"
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null 2>&1 && [ ! -z "$WAN0PACKETLOSS" ] >/dev/null 2>&1 ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null 2>&1 && [ ! -z "$WAN1PACKETLOSS" ] >/dev/null 2>&1 ;};then
    WAN0PACKETLOSSCOLOR="${YELLOW}"
    WAN1PACKETLOSSCOLOR="${YELLOW}"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure0" == "1" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure1" == "1" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    i=$(($i+1))
    loopaction="continue"
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null 2>&1 && [ ! -z "$WAN0PACKETLOSS" ] >/dev/null 2>&1 ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    WAN0PACKETLOSSCOLOR="${YELLOW}"
    WAN1PACKETLOSSCOLOR="${GREEN}"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure0" == "1" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    i=$(($i+1))
    loopaction="continue"
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && { [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null 2>&1 && [ ! -z "$WAN1PACKETLOSS" ] >/dev/null 2>&1 ;};then
    WAN0PACKETLOSSCOLOR="${GREEN}"
    WAN1PACKETLOSSCOLOR="${YELLOW}"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Packet Loss Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure1" == "1" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "Successful Packets Detected - WAN1 Packet Loss: $WAN1PACKETLOSS"
    i=$(($i+1))
    loopaction="continue"
  fi
  # Display Current Status
  if tty >/dev/null 2>&1;then
    output="$(
    clear
    printf '\033[K%b\r' "${BOLD}WAN Failover Status:${NOCOLOR}\n"
    printf "\n"
    printf '\033[K%b\r' "${BOLD}Last Update: $(date "+%D @ %T")${NOCOLOR}\n"
    printf "\n"
    printf '\033[K%b\r' "${BOLD}WAN0 Target: ${BLUE}"$WAN0TARGET"${NOCOLOR}\n"
    printf '\033[K%b\r' "${BOLD}Packet Loss: ${WAN0PACKETLOSSCOLOR}"$WAN0PACKETLOSS"${NOCOLOR}\n"
    printf "\n"
    printf '\033[K%b\r' "${BOLD}WAN1 Target: ${BLUE}"$WAN1TARGET"${NOCOLOR}\n"
    printf '\033[K%b\r' "${BOLD}Packet Loss: ${WAN1PACKETLOSSCOLOR}"$WAN1PACKETLOSS"${NOCOLOR}\n"
    )"
    if [ "$audiblealarm" == "1" ] >/dev/null 2>&1;then
      printf '\a'
      audiblealarm=0
    fi
    echo "$output"
  fi

  # Execute Loop Action
  $loopaction

done
# Unset Variables
[ ! -z "${i+x}" ] >/dev/null 2>&1 && unset i
[ ! -z "${output+x}" ] >/dev/null 2>&1 && unset output
[ ! -z "${loopaction+x}" ] >/dev/null 2>&1 && unset loopaction
return
}

# Failover
failover ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: failover"

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Disable Email Notification if Mode is Switch WAN
[[ "${mode}" == "switchwan" ]] >/dev/null 2>&1 && email="0"

# Set Status for Email Notification On if Unset
[ -z "${email+x}" ] >/dev/null 2>&1 && email="1"

[[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && switchwan || return
switchdns || return
restartservices || return
checkiprules || return
[[ "$email" == "1" ]] >/dev/null 2>&1 && { sendemail && email="0" ;} || return
return
}

# Load Balance Monitor
lbmonitor ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: lbmonitor"

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Get Active WAN Parameters
GETWANMODE=3
getwanparameters || return

# Begin LB Monitor Loop
[ -z "${lbmonitorloop+x}" ] >/dev/null 2>&1 && lbmonitorloop="1"

# Default Check IP Rules Interval
[ -z "${CHECKIPRULESINTERVAL+x}" ] >/dev/null 2>&1 && CHECKIPRULESINTERVAL="900"

if [[ "$lbmonitorloop" == "1" ]] >/dev/null 2>&1;then
  if [[ "$WAN0STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
    logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
  elif [[ "$WAN0STATUS" != "CONNECTED" ]] >/dev/null 2>&1;then
    logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
  elif [[ "$WAN1STATUS" == "CONNECTED" ]] >/dev/null 2>&1;then
    logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
  elif [[ "$WAN1STATUS" != "CONNECTED" ]] >/dev/null 2>&1;then
    logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
  fi
fi
LBMONITORSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
while { [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1 && [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 ;};do
  # Reset Loop Iterations if greater than interval and Check IP Rules
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -ge "$(($LBMONITORSTARTLOOPTIME+$CHECKIPRULESINTERVAL))" ]] >/dev/null 2>&1;then
    checkiprules || return
    lbmonitorloop=1
    LBMONITORSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
  fi

  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # Ping WAN Targets
  pingtargets || wanstatus

  if { { [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] >/dev/null 2>&1 && [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} \
  || { { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { [[ "$WAN0GATEWAY" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] >/dev/null 2>&1 && [[ "$WAN0GWIFNAME" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] >/dev/null 2>&1 ;} ;};then
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    break
  elif { { [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] >/dev/null 2>&1 && [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} \
  || { { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { [[ "$WAN1GATEWAY" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] >/dev/null 2>&1 && [[ "$WAN1GWIFNAME" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] >/dev/null 2>&1 ;} ;};then
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    break
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    if [ ! -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ] >/dev/null 2>&1 && [ ! -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ] >/dev/null 2>&1;then
      [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 && nvram set wan0_state_t=2
      [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 && nvram set wan1_state_t=2
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
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      failover && email=0 || return
      logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
      logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
      lbmonitorloop=$(($lbmonitorloop+1))
      continue
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    if [ -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ] >/dev/null 2>&1 && [ ! -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ] >/dev/null 2>&1;then
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
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      failover && email=0 || return
      if [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1;then
        wandisabled
      else
        logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
        logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
        lbmonitorloop=$(($lbmonitorloop+1))
        continue
      fi
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && { [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 ;};then
    if [ ! -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ] >/dev/null 2>&1 && [ -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ] >/dev/null 2>&1;then
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
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      failover && email=0 || return
      if [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1;then
        wandisabled
      else
        logger -p 4 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
        logger -p 3 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
        lbmonitorloop=$(($lbmonitorloop+1))
        continue
      fi
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 ;};then
    if [ -z "$(ip route show default | grep -w "$WAN0GATEWAY")" ] >/dev/null 2>&1 && [ -z "$(ip route show default | grep -w "$WAN1GATEWAY")" ] >/dev/null 2>&1;then
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
      if [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1;then
        wandisabled
      else
        logger -p 1 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
        logger -p 1 -st "$ALIAS" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
        lbmonitorloop=$(($lbmonitorloop+1))
        continue
      fi
    fi
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null 2>&1 || [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null 2>&1;then
    lbmonitorloop=$(($lbmonitorloop+1))
    continue
  fi
done

# Reset LB Monitor Loop Iterations
[ ! -z "${lbmonitorloop+x}" ] >/dev/null 2>&1 && unset lbmonitorloop

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
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Get Active WAN Parameters
GETWANMODE=3
getwanparameters || return

logger -p 4 -st "$ALIAS" "WAN0 Failover Monitor - Monitoring "$WAN0" via $WAN0TARGET for Failure"
logger -p 4 -st "$ALIAS" "WAN0 Failover Monitor - Monitoring "$WAN1" via $WAN1TARGET for Failure"
while [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1;do

  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # Ping WAN Targets
  pingtargets || wanstatus
  if { { [[ "$WAN0PINGPATH" -le "2" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] >/dev/null 2>&1 && [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} \
  || { { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { [[ "$WAN0GATEWAY" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] >/dev/null 2>&1 && [[ "$WAN0GWIFNAME" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] >/dev/null 2>&1 && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} ;};then
      break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || { [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;};then
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      failover && email=0 || return
      wanstatus || return && break
    else
      break
    fi
  elif { { [[ "$WAN1PINGPATH" -le "2" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} \
  || { { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { [[ "$WAN1GATEWAY" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] >/dev/null 2>&1 && [[ "$WAN1GWIFNAME" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] >/dev/null 2>&1 && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} ;};then
      break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || { [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;};then
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      failover && email=0 || return
      wanstatus || return && break
    else
      break
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
    [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 && nvram set wan0_state_t=2
    [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 && nvram set wan1_state_t=2
    [[ "$email" == "1" ]] >/dev/null 2>&1 && email=0
    continue
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 || { [[ "$WAN0DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN0USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$WAN0IFNAME" ] >/dev/null 2>&1 || [[ "$WAN0LINKWAN" == "0" ]] >/dev/null 2>&1 ;} ;} ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} ;};then
    WANSTATUSMODE=2 && setwanstatus
    WAN1STATUS=CONNECTED
    logger -p 6 -t "$ALIAS" "Debug - WAN0: $WAN0STATUS"
    logger -p 6 -t "$ALIAS" "Debug - WAN1: $WAN1STATUS"
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    wanstatus || return && break
  elif { [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 || { [[ "$WAN1DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN1USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$WAN1IFNAME" ] >/dev/null 2>&1 || [[ "$WAN1LINKWAN" == "0" ]] >/dev/null 2>&1 ;} ;} ;} ;then
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    break
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 || { [[ "$WAN0DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN0USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$WAN0IFNAME" ] >/dev/null 2>&1 || [[ "$WAN0LINKWAN" == "0" ]] >/dev/null 2>&1 ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 || { [[ "$WAN1DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN1USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$WAN1IFNAME" ] >/dev/null 2>&1 || [[ "$WAN1LINKWAN" == "0" ]] >/dev/null 2>&1 ;} ;} ;} ;then
    [[ "$email" == "1" ]] >/dev/null 2>&1 && email=0
    break
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null 2>&1 || [[ "$WAN0PACKETLOSS" != "100%" ]] >/dev/null 2>&1 ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null 2>&1 || [[ "$WAN1PACKETLOSS" != "100%" ]] >/dev/null 2>&1 ;};then
    [[ "$email" == "1" ]] >/dev/null 2>&1 && email=0
    continue
  fi
done

# Debug Logging
logger -p 6 -t "$ALIAS" "Debug - ***WAN0 Failover Monitor Loop Ended***"
debuglog || return

# Complete Failover if Primary WAN was changed by Router
if [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Router switched "$WAN1" to Primary WAN"
  WAN0STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] >/dev/null 2>&1 && email=1 ;} \
  && failover \
  && { [[ "$email" != "0" ]] >/dev/null 2>&1 && email=0 ;}
# Send Email if Connection Loss breaks Failover Monitor Loop
elif [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1;then
  WAN1STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] >/dev/null 2>&1 && email=1 ;} \
  && RESTARTSERVICESMODE=0 \
  && failover \
  && { [[ "$email" != "0" ]] >/dev/null 2>&1 && email=0 ;}
fi

# Return to WAN Status
wanstatus || return
}

# WAN0 Failback Monitor
wan0failbackmonitor ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: wan0failbackmonitor"

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Get Active WAN Parameters
GETWANMODE=3
getwanparameters || return

logger -p 4 -st "$ALIAS" "WAN0 Failback Monitor - Monitoring "$WAN1" via $WAN1TARGET for Failure"
logger -p 3 -st "$ALIAS" "WAN0 Failback Monitor - Monitoring "$WAN0" via $WAN0TARGET for Restoration"
while [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1;do

  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # Ping WAN Targets
  pingtargets || wanstatus
  if { { [[ "$WAN0PINGPATH" -le "2" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] >/dev/null 2>&1 && [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} \
  || { { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { [[ "$WAN0GATEWAY" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] >/dev/null 2>&1 && [[ "$WAN0GWIFNAME" != "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] >/dev/null 2>&1 && { { [[ "$WAN0IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN0 Target IP Rule Missing or Default Route for $WAN0ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      failover && email=0 || return
      wanstatus || return && break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;};then
      break
    else
      break
    fi
  elif { { [[ "$WAN1PINGPATH" -le "2" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} \
  || { { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && { [[ "$WAN1GATEWAY" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] >/dev/null 2>&1 && [[ "$WAN1GWIFNAME" != "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] >/dev/null 2>&1 && { { [[ "$WAN1IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} || { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} ;} ;then
    logger -p 6 -t "$ALIAS" "Debug - WAN1 Target IP Rule Missing or Default Route for $WAN1ROUTETABLE is invalid"
    WANSTATUSMODE=2 && setwanstatus
    [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 && email=1
    if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1;then
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      failover && email=0 || return
      wanstatus || return && break
    elif [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;};then
      break
    else
      break
    fi
  elif { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 ;} ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} ;};then
    [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 && nvram set wan1_state_t=2
    [[ "$email" == "1" ]] >/dev/null 2>&1 && email=0
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] \
  || { { [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null 2>&1 || [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 || [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 || { [[ "$WAN0DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN0USBMODEMREADY" == "1" ]] >/dev/null 2>&1 || [ ! -z "$WAN0IFNAME" ] >/dev/null 2>&1 || [[ "$WAN0LINKWAN" == "1" ]] >/dev/null 2>&1 ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 || { [[ "$WAN1DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN1USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$WAN1IFNAME" ] >/dev/null 2>&1 || [[ "$WAN1LINKWAN" == "0" ]] >/dev/null 2>&1 ;} ;} ;} ;} ;then
    WANSTATUSMODE=2 && setwanstatus
    logger -p 6 -t "$ALIAS" "Debug - WAN0: $WAN0STATUS"
    logger -p 6 -t "$ALIAS" "Debug - WAN1: $WAN1STATUS"
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    wanstatus || return && break
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 || { [[ "$WAN0USBMODEMREADY" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN0USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$WAN0IFNAME" ] >/dev/null 2>&1 || [[ "$WAN0LINKWAN" == "0" ]] >/dev/null 2>&1 ;} ;} ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null 2>&1 || [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 || { [[ "$WAN1DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && { [[ "$WAN1USBMODEMREADY" == "0" ]] >/dev/null 2>&1 || [ -z "$WAN1IFNAME" ] >/dev/null 2>&1 || [[ "$WAN1LINKWAN" == "0" ]] >/dev/null 2>&1 ;} ;} ;} ;then
    [[ "$email" == "1" ]] >/dev/null 2>&1 && email=0
    break
  elif { [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null 2>&1 || [[ "$WAN0PACKETLOSS" != "100%" ]] >/dev/null 2>&1 ;} && { [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null 2>&1 || [[ "$WAN1PACKETLOSS" != "100%" ]] >/dev/null 2>&1 ;};then
    [[ "$email" == "1" ]] >/dev/null 2>&1 && email=0
    continue
  fi
done

# Debug Logging
logger -p 6 -t "$ALIAS" "Debug - ***WAN0 Failback Monitor Loop Ended***"
debuglog || return

# Complete Failover if Primary WAN was changed by Router
if [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Router switched "$WAN0" to Primary WAN"
  WAN1STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] >/dev/null 2>&1 && email=1 ;} \
  && failover \
  && { [[ "$email" != "0" ]] >/dev/null 2>&1 && email=0 ;}
# Send Email if Connection Loss breaks Failover Monitor Loop
elif [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1;then
  WAN0STATUS=DISCONNECTED
  WANSTATUSMODE=2
  setwanstatus \
  && SWITCHPRIMARY=0 \
  && { [[ "$email" != "1" ]] >/dev/null 2>&1 && email=1 ;} \
  && RESTARTSERVICESMODE=0 \
  && failover \
  && { [[ "$email" != "0" ]] >/dev/null 2>&1 && email=0 ;}
fi

# Return to WAN Status
wanstatus || return
}

# WAN Disabled
wandisabled ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: wandisabled"

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Start WAN Disabled Loop Iteration
if [ -z "${wandisabledloop+x}" ] >/dev/null 2>&1 || [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1;then
  [ -z "${wandisabledloop+x}" ] >/dev/null 2>&1 && wandisabledloop=1
  logger -p 2 -st "$ALIAS" "WAN Failover Disabled - WAN Failover is currently disabled.  ***Review Logs***"
fi

DISABLEDSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
while \
  # Reset Loop Iterations if greater than 5 minutes for logging
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -ge "$(($DISABLEDSTARTLOOPTIME+900))" ]] >/dev/null 2>&1;then
    [[ "$wandisabledloop" != "1" ]] >/dev/null 2>&1 && wandisabledloop=1
    DISABLEDSTARTLOOPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
  fi
  # Get Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  # WAN Disabled if both interfaces are Enabled and do not have an IP Address or are unplugged
  if { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0AUXSTATE" == "1" ]] >/dev/null 2>&1 || [[ "$WAN0IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0IPADDR" ] >/dev/null 2>&1 || [[ "$WAN0GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1AUXSTATE" == "1" ]] >/dev/null 2>&1 || [[ "$WAN1IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1IPADDR" ] >/dev/null 2>&1 || [[ "$WAN1GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;};then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is unplugged"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid IP Address: "$WAN0IPADDR""
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid Gateway IP Address: "$WAN0GATEWAY""
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is unplugged"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid IP Address: "$WAN1IPADDR""
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid Gateway IP Address: "$WAN1GATEWAY""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if an interface is Disabled - Load Balance Mode
  elif [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1 && { [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1 ;};then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Load Balance Mode: "$WAN0" or "$WAN1" is not Enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # Return to WAN Status if WAN0 or WAN1 is a USB Device and is in Ready State but in Cold Standby
  elif { [[ "$WAN0DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN0USBMODEMREADY" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0LINKWAN" == "1" ]] >/dev/null 2>&1 && [ ! -z "$WAN0IFNAME" ] >/dev/null 2>&1 ;} \
  || { [[ "$WAN1DUALWANDEV" == "usb" ]] >/dev/null 2>&1 && [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN1USBMODEMREADY" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1LINKWAN" == "1" ]] >/dev/null 2>&1 && [ ! -z "$WAN1IFNAME" ] >/dev/null 2>&1 ;};then
    [[ "$WAN0USBMODEMREADY" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - USB Device for "$WAN0" is in Ready State but in Cold Standby"
    [[ "$WAN1USBMODEMREADY" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - USB Device for "$WAN1" is in Ready State but in Cold Standby"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    break
  # WAN Disabled if WAN0 does not have have an IP and WAN1 is Primary - Failover Mode
  elif { [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 ;} \
  && { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0AUXSTATE" == "1" ]] >/dev/null 2>&1 || [[ "$WAN0IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0IPADDR" ] >/dev/null 2>&1 || [[ "$WAN0GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;};then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN1" is Primary"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is unplugged"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid IP Address: "$WAN0IPADDR""
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" does not have a valid Gateway IP Address: "$WAN0GATEWAY""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if WAN1 does not have have an IP and WAN0 is Primary - Failover Mode
  elif { [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 ;} \
  && { [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1AUXSTATE" == "1" ]] >/dev/null 2>&1 || [[ "$WAN1IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1IPADDR" ] >/dev/null 2>&1 || [[ "$WAN1GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;};then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN0" is Primary"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is unplugged"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1IPADDR" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid IP Address: "$WAN1IPADDR""
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN1GATEWAY" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" does not have a valid Gateway IP Address: "$WAN1GATEWAY""
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # Return to WAN Status if interface is connected but no IP / Gateway
  elif { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0STATE" == "3" ]] >/dev/null 2>&1 ;} \
  || { [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1STATE" == "3" ]] >/dev/null 2>&1 ;};then
    [[ "$WAN0STATE" == "3" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is connected with State: $WAN0STATE"
    [[ "$WAN1STATE" == "3" ]] >/dev/null 2>&1 && logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is connected with State: $WAN1STATE"
      unset wandisabledloop
      wanstatus
  # Return to WAN Status if both interfaces are Enabled and Connected
  elif { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 ;} \
  && { { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 && { [[ "$WAN0IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0IPADDR" ] >/dev/null 2>&1 ;} && { [[ "$WAN0GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN0GATEWAY" ] >/dev/null 2>&1 ;} ;} \
  && { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 && { [[ "$WAN1IPADDR" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1IPADDR" ] >/dev/null 2>&1 ;} && { [[ "$WAN1GATEWAY" != "0.0.0.0" ]] >/dev/null 2>&1 && [ ! -z "$WAN1GATEWAY" ] >/dev/null 2>&1 ;} ;} ;} ;then
    [ -z "$(ip route list default table "$WAN0ROUTETABLE" | grep -w "$WAN0GWIFNAME")" ] >/dev/null 2>&1 && wanstatus
    [ -z "$(ip route list default table "$WAN1ROUTETABLE" | grep -w "$WAN1GWIFNAME")" ] >/dev/null 2>&1 && wanstatus
    [[ "$WAN0PINGPATH" == "1" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" oif "$WAN0GWIFNAME" lookup "$WAN0ROUTETABLE" priority "$WAN0TARGETRULEPRIORITY")" ] >/dev/null 2>&1 && wanstatus
    [[ "$WAN0PINGPATH" == "2" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE" priority "$WAN0TARGETRULEPRIORITY")" ] >/dev/null 2>&1 && wanstatus
    [[ "$WAN0PINGPATH" == "3" ]] >/dev/null 2>&1 && [ -z "$(ip route list "$WAN0TARGET" via "$WAN0GATEWAY" dev "$WAN0GWIFNAME")" ] >/dev/null 2>&1 && wanstatus
    [[ "$WAN1PINGPATH" == "1" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" oif "$WAN1GWIFNAME" lookup "$WAN1ROUTETABLE" priority "$WAN1TARGETRULEPRIORITY")" ] >/dev/null 2>&1 && wanstatus
    [[ "$WAN1PINGPATH" == "2" ]] >/dev/null 2>&1 && [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE" priority "$WAN1TARGETRULEPRIORITY")" ] >/dev/null 2>&1 && wanstatus
    [[ "$WAN1PINGPATH" == "3" ]] >/dev/null 2>&1 && [ -z "$(ip route list "$WAN1TARGET" via "$WAN1GATEWAY" dev "$WAN1GWIFNAME")" ] >/dev/null 2>&1 && wanstatus
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && { [[ "$WAN0PINGPATH" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1PINGPATH" == "0" ]] >/dev/null 2>&1 ;} && wanstatus
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && logger -p 5 -st "$ALIAS" "WAN Failover Disabled - Pinging "$WAN0TARGET" and "$WAN1TARGET""
    pingtargets || wanstatus
    [ -z "${wan0disabled+x}" ] >/dev/null 2>&1 && wan0disabled="$pingfailure0"
    [ -z "${wan1disabled+x}" ] >/dev/null 2>&1 && wan1disabled="$pingfailure1"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure0" == "1" ]] >/dev/null 2>&1 && restartwan0
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$pingfailure1" == "1" ]] >/dev/null 2>&1 && restartwan1
    if { [[ "$pingfailure0" != "$wan0disabled" ]] >/dev/null 2>&1 || [[ "$pingfailure1" != "$wan1disabled" ]] >/dev/null 2>&1 ;} || { [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 ;};then
      [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
      [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && logger -p 4 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is enabled and connected"
      [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 && logger -p 4 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is enabled and connected"
      [[ "$pingfailure0" != "$wan0disabled" ]] >/dev/null 2>&1 && unset wandisabledloop && unset wan0disabled
      [[ "$pingfailure1" != "$wan1disabled" ]] >/dev/null 2>&1 && unset wandisabledloop && unset wan1disabled
      [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && unset wan0disabled
      [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 && unset wan1disabled
      [[ "$pingfailure0" == "0" ]] >/dev/null 2>&1 && [[ "$pingfailure1" == "0" ]] >/dev/null 2>&1 && unset wandisabledloop
      wanstatus
    elif [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1;then
      wandisabledloop=$(($wandisabledloop+1))
      wanstatus
    else
      [[ "$email" == "1" ]] >/dev/null 2>&1 && email=0
      wandisabledloop=$(($wandisabledloop+1))
      sleep $WANDISABLEDSLEEPTIMER
    fi
  # Return to WAN Status if only WAN0 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 \
  && { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "0" ]] \
  && { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN0" is the only enabled WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if only WAN1 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 \
  && { [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "1" ]] \
  && { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 ;} && [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN1" is the only enabled WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 is Connected and is not Primary WAN. - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 \
  && { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 ;} \
  && { { [[ "$WAN0STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN0REALIPSTATE" == "2" ]] >/dev/null 2>&1 ;} && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN0PRIMARY" == "0" ]] >/dev/null 2>&1 ;} \
  && { [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN1AUXSTATE" != "0" ]] >/dev/null 2>&1 ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN0" is the only connected WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 is Connected and is not Primary WAN. - Failover Mode
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 \
  && { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 ;} \
  && { { [[ "$WAN1STATE" == "2" ]] >/dev/null 2>&1 || [[ "$WAN1REALIPSTATE" == "2" ]] >/dev/null 2>&1 ;} && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN1PRIMARY" == "0" ]] >/dev/null 2>&1 ;} \
  && { [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 || [[ "$WAN0AUXSTATE" != "0" ]] >/dev/null 2>&1 ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - Failover Mode: "$WAN1" is the only connected WAN interface but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN0 and WAN1 are pinging both Target IP Addresses.
  elif { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$(ping -I $WAN0GWIFNAME $WAN0TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$(ping -I $WAN1GWIFNAME $WAN1TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] >/dev/null 2>&1 ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" and "$WAN1" have 0% packet loss"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    break
  # Return to WAN Status if WAN0 is pinging the Target IP Address and WAN1 is Primary and not pinging the Target IP Address.
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 \
  && [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$(ping -I $WAN0GWIFNAME $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && { [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN1PRIMARY" == "1" ]] >/dev/null 2>&1 && [[ "$(ping -I $WAN1GWIFNAME $WAN1TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "100%" ]] >/dev/null 2>&1 ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    break
  # Return to WAN Status if WAN1 is pinging the Target IP Address and WAN0 is Primary and not pinging the Target IP Address.
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 \
  && [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$(ping -I $WAN1GWIFNAME $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN1PACKETSIZE | awk '/packet loss/ {print $7}')" == "0%" ]] \
  && { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN0PRIMARY" == "1" ]] >/dev/null 2>&1 && [[ "$(ping -I $WAN0GWIFNAME $WAN0TARGET -q -c $PINGCOUNT -W $PINGTIMEOUT -s $WAN0PACKETSIZE | awk '/packet loss/ {print $7}')" == "100%" ]] >/dev/null 2>&1 ;};then
    logger -p 3 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    unset wandisabledloop
    [[ "$email" == "0" ]] >/dev/null 2>&1 && email=1
    failover && email=0 || return
    break
  # WAN Disabled if WAN0 or WAN1 is not Enabled
  elif [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 || [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0ENABLE" == "0" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN0" is Disabled"
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1ENABLE" == "0" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - "$WAN1" is Disabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Failover Disabled if not in Dual WAN Mode Failover Mode or if ASUS Factory Failover is Enabled
  elif [[ "$WANSDUALWANENABLE" == "0" ]] >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - Dual WAN is not Enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  elif [[ "$WANDOGENABLE" != "0" ]] >/dev/null 2>&1;then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && logger -p 2 -st "$ALIAS" "WAN Failover Disabled - ASUS Factory WAN Failover is enabled"
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  elif { [[ "$WAN0ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 ;} \
  || { [[ "$WAN1ENABLE" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1AUXSTATE" == "0" ]] >/dev/null 2>&1 && [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 ;};then
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN0STATE" != "2" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "WAN Failover Disabled - Restarting "$WAN0"" && restartwan0
    [[ "$wandisabledloop" == "1" ]] >/dev/null 2>&1 && [[ "$WAN1STATE" != "2" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" "WAN Failover Disabled - Restarting "$WAN1"" && restartwan1
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  else
    wandisabledloop=$(($wandisabledloop+1))
    sleep $WANDISABLEDSLEEPTIMER
    continue
  fi
>/dev/null 2>&1;do
  wandisabledloop=$(($wandisabledloop+1))
  sleep $WANDISABLEDSLEEPTIMER
done
[ ! -z "$wandisabledloop" ] >/dev/null 2>&1 && unset wandisabledloop
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

[ -z "${SWITCHPRIMARY+x}" ] >/dev/null 2>&1 && SWITCHPRIMARY="1"

# Determine Current Primary WAN and change it to the Inactive WAN
for WANPREFIX in ${WANPREFIXES};do
  if [[ "$(nvram get ${WANPREFIX}_primary & nvramcheck)" == "1" ]] >/dev/null 2>&1;then
    [[ "$SWITCHPRIMARY" == "1" ]] >/dev/null 2>&1 && INACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Inactive WAN: "${WANPREFIX}""
    [[ "$SWITCHPRIMARY" == "0" ]] >/dev/null 2>&1 && ACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Active WAN: "${WANPREFIX}""
    continue
  elif [[ "$(nvram get ${WANPREFIX}_primary & nvramcheck)" == "0" ]] >/dev/null 2>&1;then
    [[ "$SWITCHPRIMARY" == "0" ]] >/dev/null 2>&1 && INACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Inactive WAN: "${WANPREFIX}""
    [[ "$SWITCHPRIMARY" == "1" ]] >/dev/null 2>&1 && ACTIVEWAN="${WANPREFIX}" && logger -p 6 -t "$ALIAS" "Debug - Active WAN: "${WANPREFIX}""
    continue
  fi
done

# Determine if Failover or Failback
if [[ "$ACTIVEWAN" == "$WAN0" ]] >/dev/null 2>&1;then
  SWITCHWANMODE="Failback"
elif [[ "$ACTIVEWAN" == "$WAN1" ]] >/dev/null 2>&1;then
  SWITCHWANMODE="Failover"
fi

# Verify new Active WAN is Enabled
if [[ "$(nvram get "$ACTIVEWAN"_enable & nvramcheck)" == "0" ]] >/dev/null 2>&1;then
  logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** "$ACTIVEWAN" is disabled"
  return
fi

# Verify new Active WAN Gateway IP or IP Address are not 0.0.0.0
if { { [[ "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" ] >/dev/null 2>&1 ;} || { [[ "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" == "0.0.0.0" ]] >/dev/null 2>&1 || [ -z "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" ] >/dev/null 2>&1 ;} ;};then
  logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - "$ACTIVEWAN" is disconnected.  IP Address: "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" Gateway IP Address: "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)""
  return
fi
# Perform switch until new WAN is Primary
[ -z "${SWITCHCOMPLETE+x}" ] >/dev/null 2>&1 && SWITCHCOMPLETE="0"
SWITCHTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
[[ "$SWITCHCOMPLETE" != "0" ]] >/dev/null 2>&1 && SWITCHCOMPLETE=0
until { [[ "$(nvram get "$INACTIVEWAN"_primary & nvramcheck)" == "0" ]] >/dev/null 2>&1 && [[ "$(nvram get "$ACTIVEWAN"_primary & nvramcheck)" == "1" ]] >/dev/null 2>&1 && [[ "$SWITCHCOMPLETE" == "1" ]] >/dev/null 2>&1 ;} \
&& { [[ "$(echo $(ip route show default | awk '{print $3}'))" == "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" ]] >/dev/null 2>&1 && [[ "$(echo $(ip route show default | awk '{print $5}'))" == "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" ]] >/dev/null 2>&1 ;} \
&& { [[ "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" == "$(nvram get wan_ipaddr & nvramcheck)" ]] >/dev/null 2>&1 && [[ "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" == "$(nvram get wan_gateway & nvramcheck)" ]] >/dev/null 2>&1 && [[ "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" == "$(nvram get wan_gw_ifname & nvramcheck)" ]] >/dev/null 2>&1 ;};do
  # Check for Timeout
  if [[ "$SWITCHTIMEOUT" -gt "$(awk -F "." '{print $1}' "/proc/uptime")" ]] >/dev/null 2>&1;then
    [[ "$SWITCHCOMPLETE" != "1" ]] >/dev/null 2>&1 && SWITCHCOMPLETE=1
  fi

  # Change Primary WAN
  if [[ "$(nvram get "$ACTIVEWAN"_primary & nvramcheck)" != "1" ]] >/dev/null 2>&1 && [[ "$(nvram get "$INACTIVEWAN"_primary & nvramcheck)" != "0" ]] >/dev/null 2>&1;then
    [[ "$SWITCHPRIMARY" == "1" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - Switching $ACTIVEWAN to Primary WAN"
    nvram set "$ACTIVEWAN"_primary=1 ; nvram set "$INACTIVEWAN"_primary=0
  fi
  # Change WAN IP Address
  if [[ "$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)" != "$(nvram get wan_ipaddr & nvramcheck)" ]] >/dev/null 2>&1;then
    logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)"
    nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr & nvramcheck)
  fi

  # Change WAN Gateway
  if [[ "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" != "$(nvram get wan_gateway & nvramcheck)" ]] >/dev/null 2>&1;then
    logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN Gateway IP: $(nvram get "$ACTIVEWAN"_gateway & nvramcheck)"
    nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)
  fi
  # Change WAN Gateway Interface
  if [[ "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" != "$(nvram get wan_gw_ifname & nvramcheck)" ]] >/dev/null 2>&1;then
    logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN Gateway Interface: $(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)"
    nvram set wan_gw_ifname=$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)
  fi
  # Change WAN Interface
  if [[ "$(nvram get "$ACTIVEWAN"_ifname & nvramcheck)" != "$(nvram get wan_ifname & nvramcheck)" ]] >/dev/null 2>&1;then
    if [[ "$(nvram get "$ACTIVEWAN"_ifname & nvramcheck)" != "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" ]] >/dev/null 2>&1;then
      logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - WAN Interface: $(nvram get "$ACTIVEWAN"_ifname & nvramcheck)"
    fi
    nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname & nvramcheck)
  fi
  
  # Delete Old Default Route
  if [ ! -z "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)" ] >/dev/null 2>&1 && [ ! -z "$(ip route list default via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)")" ] >/dev/null 2>&1;then
    logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Deleting default route via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)""
    ip route del default \
    && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Deleted default route via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)"" \
    || logger -p 2 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** Unable to delete default route via "$(nvram get "$INACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname & nvramcheck)""
  fi

  # Add New Default Route
  if [ ! -z "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)" ] >/dev/null 2>&1 && [ -z "$(ip route list default via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)")" ] >/dev/null 2>&1;then
    logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Adding default route via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)""
    ip route add default via $(nvram get "$ACTIVEWAN"_gateway & nvramcheck) dev $(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck) \
    && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Added default route via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)"" \
    || logger -p 2 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** Unable to delete default route via "$(nvram get "$ACTIVEWAN"_gateway & nvramcheck)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname & nvramcheck)""
  fi

  # Change QoS Settings
  for WANPREFIX in ${WANPREFIXES};do
    if [[ "$ACTIVEWAN" != "${WANPREFIX}" ]] >/dev/null 2>&1;then
      continue
    elif [[ "$ACTIVEWAN" == "${WANPREFIX}" ]] >/dev/null 2>&1;then
      GETWANMODE=1
      getwanparameters || return
      [ -z "${QOSAPPLIED+x}" ] >/dev/null 2>&1 && QOSAPPLIED="0"
      [ -z "${STOPQOS+x}" ] >/dev/null 2>&1 && STOPQOS="0"
      if [[ "$WAN_QOS_ENABLE" == "1" ]] >/dev/null 2>&1;then
        [ -z "${RESTARTSERVICESMODE+x}" ] >/dev/null 2>&1 && RESTARTSERVICESMODE="0"
        if [[ "$(nvram get qos_enable & nvramcheck)" != "1" ]] \
        || [[ "$(nvram get qos_obw & nvramcheck)" != "$WAN_QOS_OBW" ]] >/dev/null 2>&1 || [[ "$(nvram get qos_ibw & nvramcheck)" != "$WAN_QOS_IBW" ]] \
        || [[ "$(nvram get qos_overhead & nvramcheck)" != "$WAN_QOS_OVERHEAD" ]] >/dev/null 2>&1 || [[ "$(nvram get qos_atm & nvramcheck)" != "$WAN_QOS_ATM" ]] >/dev/null 2>&1;then
          [[ "$QOSAPPLIED" == "0" ]] >/dev/null 2>&1 && QOSAPPLIED=1
          logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Applying QoS Bandwidth Settings"
          [[ "$(nvram get qos_enable & nvramcheck)" != "1" ]] >/dev/null 2>&1 && { nvram set qos_enable=1 && RESTARTSERVICESMODE=3 && logger -p 6 -t "$ALIAS" "Debug - QoS is Enabled" ;}
          [[ "$(nvram get qos_obw & nvramcheck)" != "$WAN_QOS_OBW" ]] >/dev/null 2>&1 && nvram set qos_obw=$WAN_QOS_OBW
          [[ "$(nvram get qos_ibw & nvramcheck)" != "$WAN_QOS_IBW" ]] >/dev/null 2>&1 && nvram set qos_ibw=$WAN_QOS_IBW
          [[ "$(nvram get qos_overhead & nvramcheck)" != "$WAN_QOS_OVERHEAD" ]] >/dev/null 2>&1 && nvram set qos_overhead=$WAN_QOS_OVERHEAD
          [[ "$(nvram get qos_atm & nvramcheck)" != "$WAN_QOS_ATM" ]] >/dev/null 2>&1 && nvram set qos_atm=$WAN_QOS_ATM
          # Determine if Restart Mode
          if [[ "$SWITCHPRIMARY" != "1" ]] >/dev/null 2>&1 && [[ "$QOSAPPLIED" != "0" ]] >/dev/null 2>&1;then
            RESTARTSERVICESMODE=3
            restartservices || return
          fi
        fi
      elif [[ "$WAN_QOS_ENABLE" == "0" ]] >/dev/null 2>&1;then
        if [[ "$(nvram get qos_enable & nvramcheck)" != "0" ]] >/dev/null 2>&1;then
          logger -p 5 -st "$ALIAS" ""$SWITCHWANMODE" - Disabling QoS Bandwidth Settings"
          nvram set qos_enable=0 && logger -p 6 -t "$ALIAS" "Debug - QoS is Disabled"
          [[ "$STOPQOS" == "0" ]] >/dev/null 2>&1 && STOPQOS=1
        fi
        if [[ "$STOPQOS" == "1" ]] >/dev/null 2>&1;then
          logger -p 5 -t "$ALIAS" ""$SWITCHWANMODE" - Stopping qos service"
          service stop_qos \
          && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Stopped qos service" \
          || logger -p 2 -st "$ALIAS" ""$SWITCHWANMODE" - ***Error*** Unable to stop qos service"
        fi
      fi
      logger -p 6 -t "$ALIAS" "Debug - Outbound Bandwidth: "$(nvram get qos_obw & nvramcheck)""
      logger -p 6 -t "$ALIAS" "Debug - Inbound Bandwidth: "$(nvram get qos_ibw & nvramcheck)""
      logger -p 6 -t "$ALIAS" "Debug - QoS Overhead: "$(nvram get qos_overhead & nvramcheck)""
      logger -p 6 -t "$ALIAS" "Debug - QoS ATM: "$(nvram get qos_atm & nvramcheck)""
      if [[ "$(nvram get qos_enable & nvramcheck)" == "1" ]] >/dev/null 2>&1 && [[ "$QOSAPPLIED" != "0" ]] >/dev/null 2>&1;then
        { [[ "$(nvram get qos_obw & nvramcheck)" != "0" ]] >/dev/null 2>&1 && [[ "$(nvram get qos_ibw & nvramcheck)" != "0" ]] >/dev/null 2>&1 ;} && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - Applied Manual QoS Bandwidth Settings"
        [[ "$(nvram get qos_obw & nvramcheck)" -ge "1024" ]] >/dev/null 2>&1 && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Upload Bandwidth: $(($(nvram get qos_obw & nvramcheck)/1024))Mbps" \
        || { [[ "$(nvram get qos_obw & nvramcheck)" != "0" ]] >/dev/null 2>&1 && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Upload Bandwidth: $(nvram get qos_obw & nvramcheck)Kbps" ;}
        [[ "$(nvram get qos_ibw & nvramcheck)" -ge "1024" ]] >/dev/null 2>&1 && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Download Bandwidth: $(($(nvram get qos_ibw & nvramcheck)/1024))Mbps" \
        || { [[ "$(nvram get qos_ibw & nvramcheck)" != "0" ]] >/dev/null 2>&1 && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Download Bandwidth: $(nvram get qos_ibw & nvramcheck)Kbps" ;}
        { [[ "$(nvram get qos_obw & nvramcheck)" == "0" ]] >/dev/null 2>&1 && [[ "$(nvram get qos_ibw & nvramcheck)" == "0" ]] >/dev/null 2>&1 ;} && logger -p 4 -st "$ALIAS" ""$SWITCHWANMODE" - QoS - Automatic Settings"
      elif [[ "$(nvram get qos_enable & nvramcheck)" == "0" ]] >/dev/null 2>&1;then
        logger -p 6 -t "$ALIAS" "Debug - QoS is Disabled"
      fi
      break 1
    fi
  done
  sleep 1
  [[ "$SWITCHCOMPLETE" != "1" ]] >/dev/null 2>&1 && SWITCHCOMPLETE=1
done
if [[ "$(nvram get "$ACTIVEWAN"_primary & nvramcheck)" == "1" ]] >/dev/null 2>&1 && [[ "$(nvram get "$INACTIVEWAN"_primary & nvramcheck)" == "0" ]] >/dev/null 2>&1;then
  [[ "$SWITCHPRIMARY" == "1" ]] >/dev/null 2>&1 && logger -p 1 -st "$ALIAS" ""$SWITCHWANMODE" - Switched $ACTIVEWAN to Primary WAN"
else
  debuglog || return
fi

# Unset Variables
[ ! -z "${SWITCHCOMPLETE+x}" ] >/dev/null 2>&1 && unset SWITCHCOMPLETE
[ ! -z "${SWITCHPRIMARY+x}" ] >/dev/null 2>&1 && unset SWITCHPRIMARY
[ ! -z "${SWITCHWANMODE+x}" ] >/dev/null 2>&1 && unset SWITCHWANMODE
[ ! -z "${ACTIVEWAN+x}" ] >/dev/null 2>&1 && unset ACTIVEWAN
[ ! -z "${INACTIVEWAN+x}" ] >/dev/null 2>&1 && unset INACTIVEWAN
[ ! -z "${RESTARTSERVICESMODE+x}" ] >/dev/null 2>&1 && unset RESTARTSERVICESMODE
[ ! -z "${QOSAPPLIED+x}" ] >/dev/null 2>&1 && unset QOSAPPLIED
[ ! -z "${STOPQOS+x}" ] >/dev/null 2>&1 && unset STOPQOS

return
}

# Switch DNS
switchdns ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: switchdns"

# Check if AdGuard is Running or AdGuard Local is Enabled
if [ ! -z "$(pidof AdGuardHome)" ] >/dev/null 2>&1 || { [ -f "/opt/etc/AdGuardHome/.config" ] >/dev/null 2>&1 && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] >/dev/null 2>&1 ;};then
  logger -p 4 -st "$ALIAS" "DNS Switch - DNS is being managed by AdGuard"
  return
fi

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

for WANPREFIX in ${WANPREFIXES};do
  # Getting WAN Parameters
  GETWANMODE=1
  getwanparameters || return

  # Switch DNS
  # Check DNS if Status is Connected or Primary WAN
  if { [[ "$STATUS" == "CONNECTED" ]] >/dev/null 2>&1 && [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1 ;} || { [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$PRIMARY" == "1" ]] >/dev/null 2>&1 ;};then
    # Change Manual DNS Settings
    if [[ "$DNSENABLE" == "0" ]] >/dev/null 2>&1;then
      logger -p 6 -t "$ALIAS" "Debug - Manual DNS Settings for ${WANPREFIX}"
      # Change Manual DNS1 Server
      if [ ! -z "$DNS1" ] >/dev/null 2>&1;then
        if [[ "$DNS1" != "$(nvram get wan_dns1_x & nvramcheck)" ]] >/dev/null 2>&1 && [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Updating WAN DNS1 Server in NVRAM: "$DNS1""
          nvram set wan_dns1_x=$DNS1 \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Updated WAN DNS1 Server in NVRAM: "$DNS1"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to update WAN DNS1 Server in NVRAM: "$DNS1""
        fi
        if [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS1")" ] >/dev/null 2>&1;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS1 Server: "$DNS1""
          sed -i '1i nameserver '$DNS1'' $DNSRESOLVFILE \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS1 Server: "$DNS1"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS1 Server: "$DNS1""
        fi
      fi
      # Change Manual DNS2 Server
      if [ ! -z "$DNS2" ] >/dev/null 2>&1;then
        if [[ "$DNS2" != "$(nvram get wan_dns2_x & nvramcheck)" ]] >/dev/null 2>&1 && [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Updating WAN DNS2 Server in NVRAM: "$DNS2""
          nvram set wan_dns2_x=$DNS2 \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Updated WAN DNS2 Server in NVRAM: "$DNS2"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to update WAN DNS2 Server in NVRAM: "$DNS2""
        fi
        if [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS2")" ] >/dev/null 2>&1;then
          logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS2 Server: "$DNS2""
          sed -i '2i nameserver '$DNS2'' $DNSRESOLVFILE \
          && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS2 Server: "$DNS2"" \
          || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS2 Server: "$DNS2""
        fi
      fi

    # Change Automatic ISP DNS Settings
    elif [[ "$DNSENABLE" == "1" ]] >/dev/null 2>&1;then
      logger -p 6 -t "$ALIAS" "Debug - Automatic DNS Settings from ${WANPREFIX} ISP: "$DNS""
      if [[ "$DNS" != "$DNS" ]] >/dev/null 2>&1 && { [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$PRIMARY" == "1" ]] >/dev/null 2>&1 ;};then
        logger -p 5 -st "$ALIAS" "DNS Switch - Updating WAN DNS Servers in NVRAM: "$DNS""
        nvram set wan_dns="$DNS" \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Updated WAN DNS Servers in NVRAM: "$DNS"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to update WAN DNS Servers in NVRAM: "$DNS""
      fi
      # Change Automatic DNS1 Server
      if [ ! -z "$AUTODNS1" ] >/dev/null 2>&1 && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS1")" ] >/dev/null 2>&1;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS1 Server: "$AUTODNS1""
        sed -i '1i nameserver '$AUTODNS1'' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS1 Server: "$AUTODNS1"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS1 Server: "$AUTODNS1""

      fi
      # Change Automatic DNS2 Server
      if [ ! -z "$AUTODNS2" ] >/dev/null 2>&1 && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS2")" ] >/dev/null 2>&1;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Adding ${WANPREFIX} DNS2 Server: "$AUTODNS2""
        sed -i '2i nameserver '$AUTODNS2'' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Added ${WANPREFIX} DNS2 Server: "$AUTODNS2"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to add ${WANPREFIX} DNS2 Server: "$AUTODNS2""
      fi
    fi
  # Check DNS if Status is Disconnected or not Primary WAN
  elif { [[ "$STATUS" != "CONNECTED" ]] >/dev/null 2>&1 && [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1 ;} || { [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$PRIMARY" == "0" ]] >/dev/null 2>&1 ;};then
    # Remove Manual DNS Settings
    if [[ "$DNSENABLE" == "0" ]] >/dev/null 2>&1;then
      # Remove Manual DNS1 Server
      if [ ! -z "$DNS1" ] >/dev/null 2>&1 && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS1")" ] >/dev/null 2>&1;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Removing ${WANPREFIX} DNS1 Server: "$DNS1""
        sed -i '/nameserver '$DNS1'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Removed ${WANPREFIX} DNS1 Server: "$DNS1"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS1 Server: "$DNS1""
      fi
      # Change Manual DNS2 Server
      if [ ! -z "$DNS2" ] >/dev/null 2>&1 && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$DNS2")" ] >/dev/null 2>&1;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Removing ${WANPREFIX} DNS2 Server: "$DNS2""
        sed -i '/nameserver '$DNS2'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Removed ${WANPREFIX} DNS2 Server: "$DNS2"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS2 Server: "$DNS2""
      fi

    # Remove Automatic ISP DNS Settings
    elif [[ "$DNSENABLE" == "1" ]] >/dev/null 2>&1;then
      # Remove Automatic DNS1 Server
      if [ ! -z "$AUTODNS1" ] >/dev/null 2>&1 && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS1")" ] >/dev/null 2>&1;then
        logger -p 5 -st "$ALIAS" "DNS Switch - Removing ${WANPREFIX} DNS1 Server: "$AUTODNS1""
        sed -i '/nameserver '$AUTODNS1'/d' $DNSRESOLVFILE \
        && logger -p 4 -st "$ALIAS" "DNS Switch - Removed ${WANPREFIX} DNS1 Server: "$AUTODNS1"" \
        || logger -p 2 -st "$ALIAS" "DNS Switch - ***Error*** Unable to remove ${WANPREFIX} DNS1 Server: "$AUTODNS1""
      fi
      # Remove Automatic DNS2 Server
      if [ ! -z "$AUTODNS2" ] >/dev/null 2>&1 && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$AUTODNS2")" ] >/dev/null 2>&1;then
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
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Set Restart Services Mode to Default if not Specified
# Restart Mode 0: Do Not Restart Services
# Restart Mode 1: Default
# Restart Mode 2: OVPN Server Instances Only
# Restart Mode 3: QoS Engine Only
[ -z "${RESTARTSERVICESMODE+x}" ] >/dev/null 2>&1 && RESTARTSERVICESMODE="1"
# Return if Restart Services Mode is 0
if [[ "$RESTARTSERVICESMODE" == "0" ]] >/dev/null 2>&1;then
  unset RESTARTSERVICESMODE
  return
fi
logger -p 6 -t "$ALIAS" "Debug - Restart Services Mode: "$RESTARTSERVICESMODE""

# Check for services that need to be restarted:
logger -p 6 -t "$ALIAS" "Debug - Checking which services need to be restarted"
SERVICES=""
SERVICERESTARTPIDS=""
# Check if dnsmasq is running
if [[ "$RESTARTSERVICESMODE" == "1" ]] >/dev/null 2>&1 && [ ! -z "$(pidof dnsmasq)" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Dnsmasq is running"
  SERVICE="dnsmasq"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if Firewall is Enabled
if [[ "$RESTARTSERVICESMODE" == "1" ]] >/dev/null 2>&1 && [[ "$FIREWALLENABLE" == "1" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Firewall is enabled"
  SERVICE="firewall"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if LEDs are Disabled
if [[ "$RESTARTSERVICESMODE" == "1" ]] >/dev/null 2>&1 && [[ "$LEDDISABLE" == "0" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - LEDs are enabled"
  SERVICE="leds"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if QoS is Enabled
if { [[ "$RESTARTSERVICESMODE" == "1" ]] >/dev/null 2>&1 || [[ "$RESTARTSERVICESMODE" == "3" ]] >/dev/null 2>&1 ;} && [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1 && [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - QoS is enabled"
  SERVICE="qos"
  SERVICES="${SERVICES} ${SERVICE}"
fi
# Check if IPv6 is using a 6in4 tunnel
if [[ "$RESTARTSERVICESMODE" == "1" ]] >/dev/null 2>&1 && [[ "$IPV6SERVICE" == "6in4" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - IPv6 6in4 is enabled"
  SERVICE="wan6"
  SERVICES="${SERVICES} ${SERVICE}"
fi

# Restart Services
if [ ! -z "$SERVICES" ] >/dev/null 2>&1;then
  for SERVICE in ${SERVICES};do
    logger -p 5 -st "$ALIAS" "Service Restart - Restarting "$SERVICE" service"
    service restart_"$SERVICE" &
    SERVICERESTARTPID=$!
    SERVICERESTARTPIDS="${SERVICERESTARTPIDS} ${SERVICERESTARTPID}"
  done

# Unset Variables
[ ! -z "${SERVICES+x}" ] >/dev/null 2>&1 && unset SERVICES
fi

# Execute YazFi Check
logger -p 6 -t "$ALIAS" "Debug - Checking if YazFi is installed and scheduled in Cron Jobs"
if [[ "$RESTARTSERVICESMODE" == "1" ]] >/dev/null 2>&1 && [ ! -z "$(cru l | grep -w "YazFi")" ] >/dev/null 2>&1 && [ -f "/jffs/scripts/YazFi" ] >/dev/null 2>&1;then
  logger -p 5 -st "$ALIAS" "Service Restart - Executing YazFi Check"
  sh /jffs/scripts/YazFi check \
  && logger -p 4 -st "$ALIAS" "Service Restart - Executed YazFi Check" \
  || logger -p 2 -st "$ALIAS" "Service Restart - ***Error*** Unable to execute YazFi Check"
fi

# Restart OpenVPN Server Instances
if [[ "$RESTARTSERVICESMODE" == "1" ]] >/dev/null 2>&1 || [[ "$RESTARTSERVICESMODE" == "2" ]] >/dev/null 2>&1;then
OVPNSERVERS="
1
2
"

  logger -p 6 -t "$ALIAS" "Debug - Checking if OpenVPN Server instances exist and are enabled"
  for OVPNSERVER in ${OVPNSERVERS};do
    if [ ! -z "$(nvram get vpn_serverx_start | grep -o "$OVPNSERVER" & nvramcheck)" ] >/dev/null 2>&1;then
      # Restart OVPN Server Instance
      logger -p 5 -st "$ALIAS" "Service Restart - Restarting OpenVPN Server "$OVPNSERVER""
      service restart_vpnserver"$OVPNSERVER" &
      SERVICERESTARTPID=$!
      SERVICERESTARTPIDS="${SERVICERESTARTPIDS} ${SERVICERESTARTPID}"
      sleep 1
    fi
  done

  # Wait for Services to Restart
  if [ ! -z "${SERVICERESTARTPIDS+x}" ] >/dev/null 2>&1;then
    for SERVICERESTARTPID in ${SERVICERESTARTPIDS};do
      if [ -z "$(ps | grep -v "grep" | awk '{print $1}' | grep -o "${SERVICERESTARTPID}")" ] >/dev/null 2>&1;then
        logger -p 6 -t "$ALIAS" "Debug - PID: ${SERVICERESTARTPID} completed"
        continue
      else
        logger -p 6 -t "$ALIAS" "Debug - Waiting on PID: ${SERVICERESTARTPID}"
        wait ${SERVICERESTARTPID}
        logger -p 6 -t "$ALIAS" "Debug - PID: ${SERVICERESTARTPID} completed"
      fi
    done

    # Unset Variables
    [ ! -z "${SERVICERESTARTPID+x}" ] >/dev/null 2>&1 && unset SERVICERESTARTPID
    [ ! -z "${SERVICERESTARTPIDS+x}" ] >/dev/null 2>&1 && unset SERVICERESTARTPIDS
    
  fi
fi

# Unset Variables
[ ! -z "${RESTARTSERVICESMODE+x}" ] >/dev/null 2>&1 && unset RESTARTSERVICESMODE

return
}

# Send Email
sendemail ()
{
logger -p 6 -t "$ALIAS" "Debug - Function: sendemail"

# Get System Parameters
getsystemparameters || return

# Get Global WAN Parameters
if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
  GETWANMODE=2
  getwanparameters || return
fi

# Getting Active WAN Parameters
GETWANMODE=3
getwanparameters || return


#Email Variables
AIPROTECTION_EMAILCONFIG="/etc/email/email.conf"
SMTP_SERVER="$(awk -F "'" '/SMTP_SERVER/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
SMTP_PORT="$(awk -F "'" '/SMTP_PORT/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
MY_NAME="$(awk -F "'" '/MY_NAME/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
MY_EMAIL="$(awk -F "'" '/MY_EMAIL/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
SMTP_AUTH_USER="$(awk -F "'" '/SMTP_AUTH_USER/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
SMTP_AUTH_PASS="$(awk -F "'" '/SMTP_AUTH_PASS/ {print $2}' "$AIPROTECTION_EMAILCONFIG")"
CAFILE="/rom/etc/ssl/cert.pem"
AMTM_EMAILCONFIG="/jffs/addons/amtm/mail/email.conf"
AMTM_EMAIL_DIR="/jffs/addons/amtm/mail"
TMPEMAILFILE=/tmp/wan-failover-mail
if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then
  . "$AMTM_EMAILCONFIG"
fi

# Send email notification if Alert Preferences are configured if System Uptime is more than Boot Delay Timer + Variable SKIPEMAILSYSEMUPTIME seconds.
if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))" ]] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Email skipped, System Uptime is less than "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))""
  return
elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null 2>&1 || [ -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then

  # Check for old mail temp file and delete it or create file and set permissions
  logger -p 6 -t "$ALIAS" "Debug - Checking if "$TMPEMAILFILE" exists"
  if [ -f "$TMPEMAILFILE" ] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - Deleting "$TMPEMAILFILE""
    rm "$TMPEMAILFILE"
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  elif [ ! -f "$TMPEMAILFILE" ] >/dev/null 2>&1;then
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  fi
  
  # Determine Subject Name
  logger -p 6 -t "$ALIAS" "Debug - Selecting Subject Name"
  if [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
    echo "Subject: WAN Load Balance Failover Notification" >"$TMPEMAILFILE"
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
    echo "Subject: WAN Failover Notification" >"$TMPEMAILFILE"
  fi

  # Determine From Name
  logger -p 6 -t "$ALIAS" "Debug - Selecting From Name"
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then
    echo "From: \"$TO_NAME\"<$FROM_ADDRESS>" >>"$TMPEMAILFILE"
  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null 2>&1;then
    echo "From: \"$MY_NAME\"<$MY_EMAIL>" >>"$TMPEMAILFILE"
  fi
  echo "Date: $(date -R)" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine Email Header
  logger -p 6 -t "$ALIAS" "Debug - Selecting Email Header"
  if [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
    echo "***WAN Load Balance Failover Notification***" >>"$TMPEMAILFILE"
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
    echo "***WAN Failover Notification***" >>"$TMPEMAILFILE"
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"

  # Determine Hostname
  logger -p 6 -t "$ALIAS" "Debug - Selecting Hostname"
  if [[ "$DDNSENABLE" == "1" ]] >/dev/null 2>&1 && [ ! -z "$DDNSHOSTNAME" ] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - DDNS Hostname: $DDNSHOSTNAME"
    echo "Hostname: $DDNSHOSTNAME" >>"$TMPEMAILFILE"
  elif [ ! -z "$LANHOSTNAME" ] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - LAN Hostname: $LANHOSTNAME"
    echo "Hostname: $LANHOSTNAME" >>"$TMPEMAILFILE"
  fi
  echo "Event Time: $(date | awk '{print $2,$3,$4}')" >>"$TMPEMAILFILE"

  # Determine Parameters to send based on Dual WAN Mode
  logger -p 6 -t "$ALIAS" "Debug - Selecting Parameters based on Dual WAN Mode: "$WANSMODE""
  if [[ "$WANSMODE" == "lb" ]] >/dev/null 2>&1;then
    # Capture WAN Status and WAN IP Addresses for Load Balance Mode
    logger -p 6 -t "$ALIAS" "Debug - WAN0 IP Address: $WAN0IPADDR"
    echo "WAN0 IPv4 Address: $WAN0IPADDR" >>"$TMPEMAILFILE"
    [ ! -z "$WAN0STATUS" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: $WAN0STATUS" && echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    logger -p 6 -t "$ALIAS" "Debug - WAN1 IP Address: $WAN1IPADDR"
    echo "WAN1 IPv4 Address: $WAN1IPADDR" >>"$TMPEMAILFILE"
    [ ! -z "$WAN1STATUS" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: $WAN1STATUS" && echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"
    [ ! -z "${IPV6IPADDR+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - IPv6 IP Address: $IPV6IPADDR"
    [[ "$IPV6SERVICE" != "disabled" ]] >/dev/null 2>&1 && [ ! -z "${IPV6IPADDR+x}" ] >/dev/null 2>&1 && echo "WAN IPv6 Address: "$IPV6IPADDR"" >>"$TMPEMAILFILE"
  elif [[ "$WANSMODE" != "lb" ]] >/dev/null 2>&1;then
    # Capture WAN Status
    [ ! -z "$WAN0STATUS" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - WAN0 Status: $WAN0STATUS" && echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    [ ! -z "$WAN1STATUS" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - WAN1 Status: $WAN1STATUS" && echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"

    # Determine Active ISP
    logger -p 6 -t "$ALIAS" "Debug - Connecting to ipinfo.io for Active ISP"
    ACTIVEISP="$(/usr/sbin/curl --connect-timeout $EMAILTIMEOUT --max-time $EMAILTIMEOUT ipinfo.io | grep -e "org" | awk '{print $3" "$4}' | cut -f 1 -d "," | cut -f 1 -d '"')"
    [ ! -z "${ACTIVEISP+x}" ] >/dev/null 2>&1 && echo "Active ISP: "$ACTIVEISP"" >>"$TMPEMAILFILE" || echo "Active ISP: Unavailable" >>"$TMPEMAILFILE"

    # Determine Primary WAN for WAN IP Address, Gateway IP Address and Interface
    for WANPREFIX in ${WANPREFIXES};do
      # Getting WAN Parameters
      GETWANMODE=1
      getwanparameters || return

      [[ "$PRIMARY" != "1" ]] >/dev/null 2>&1 && continue
      logger -p 6 -t "$ALIAS" "Debug - Primary WAN: "$PRIMARY""
      echo "Primary WAN: ${WANPREFIX}" >>"$TMPEMAILFILE"
      logger -p 6 -t "$ALIAS" "Debug - WAN IPv4 Address: "$IPADDR""
      echo "WAN IPv4 Address: $IPADDR" >>"$TMPEMAILFILE"
      logger -p 6 -t "$ALIAS" "Debug - WAN Gateway IP Address: "$GATEWAY""
      echo "WAN Gateway IP Address: $GATEWAY" >>"$TMPEMAILFILE"
      logger -p 6 -t "$ALIAS" "Debug - WAN Interface: "$GWIFNAME""
      echo "WAN Interface: $GWIFNAME" >>"$TMPEMAILFILE"
      [[ "$PRIMARY" == "1" ]] >/dev/null 2>&1 && break
    done
    if [[ "$IPV6SERVICE" != "disabled" ]] >/dev/null 2>&1;then
      [ ! -z "${IPV6IPADDR+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - IPv6 IP Address: "$IPV6IPADDR""
      [ ! -z "${IPV6IPADDR+x}" ] >/dev/null 2>&1 && echo "WAN IPv6 Address: "$IPV6IPADDR"" >>"$TMPEMAILFILE"
    fi

    # Check if AdGuard is Running or if AdGuard Local is Enabled or Capture WAN DNS Servers
    logger -p 6 -t "$ALIAS" "Debug - Checking if AdGuardHome is running"
    if [ ! -z "$(pidof AdGuardHome)" ] >/dev/null 2>&1 || { [ -f "/opt/etc/AdGuardHome/.config" ] >/dev/null 2>&1 && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] >/dev/null 2>&1 ;};then
      echo "DNS: Managed by AdGuardHome" >>"$TMPEMAILFILE"
    else
      for WANPREFIX in ${WANPREFIXES};do
        # Getting WAN Parameters
        GETWANMODE=1
        getwanparameters || return

        [[ "$PRIMARY" != "1" ]] >/dev/null 2>&1 && continue
        logger -p 6 -t "$ALIAS" "Debug - Checking for Automatic or Manual DNS Settings. WAN DNS Enable: $DNSENABLE"
        if [[ "$DNSENABLE" == "0" ]] >/dev/null 2>&1;then
          logger -p 6 -t "$ALIAS" "Debug - Manual DNS Server 1: "$DNS1""
          [ ! -z "$DNS1" ] >/dev/null 2>&1 && echo "DNS Server 1: $DNS1" >>"$TMPEMAILFILE"
          logger -p 6 -t "$ALIAS" "Debug - Manual DNS Server 2: "$DNS2""
          [ ! -z "$DNS2" ] >/dev/null 2>&1 && echo "DNS Server 2: $DNS2" >>"$TMPEMAILFILE"
        elif [[ "$DNSENABLE" == "1" ]] >/dev/null 2>&1;then
          logger -p 6 -t "$ALIAS" "Debug - Automatic DNS Servers: $DNS"
          [ ! -z "$AUTODNS1" ] >/dev/null 2>&1 && echo "DNS Server 1: $AUTODNS1" >>"$TMPEMAILFILE"
          [ ! -z "$AUTODNS2" ] >/dev/null 2>&1 && echo "DNS Server 2: $AUTODNS2" >>"$TMPEMAILFILE"
        fi
        [[ "$PRIMARY" == "1" ]] >/dev/null 2>&1 && break
      done
    fi
    logger -p 6 -t "$ALIAS" "Debug - QoS Enabled Status: $QOSENABLE"
    if [[ "$QOSENABLE" == "1" ]] >/dev/null 2>&1;then
      echo "QoS Status: Enabled" >>"$TMPEMAILFILE"
      if [[ ! -z "$QOS_OBW" ]] >/dev/null 2>&1 && [[ ! -z "$QOS_IBW" ]] >/dev/null 2>&1;then
        logger -p 6 -t "$ALIAS" "Debug - QoS Outbound Bandwidth: $QOS_OBW"
        logger -p 6 -t "$ALIAS" "Debug - QoS Inbound Bandwidth: $QOS_IBW"
        if [[ "$QOS_OBW" == "0" ]] >/dev/null 2>&1 && [[ "$QOS_IBW" == "0" ]] >/dev/null 2>&1;then
          echo "QoS Mode: Automatic Settings" >>"$TMPEMAILFILE"
        else
          echo "QoS Mode: Manual Settings" >>"$TMPEMAILFILE"
          [[ "$QOS_IBW" -gt "1024" ]] >/dev/null 2>&1 && echo "QoS Download Bandwidth: $(($QOS_IBW/1024))Mbps" >>"$TMPEMAILFILE" || echo "QoS Download Bandwidth: "$QOS_IBW"Kbps" >>"$TMPEMAILFILE"
          [[ "$QOS_OBW" -gt "1024" ]] >/dev/null 2>&1 && echo "QoS Upload Bandwidth: $(($QOS_OBW/1024))Mbps" >>"$TMPEMAILFILE" || echo "QoS Upload Bandwidth: "$QOS_OBW"Kbps" >>"$TMPEMAILFILE"
          logger -p 6 -t "$ALIAS" "Debug - QoS WAN Packet Overhead: $QOSOVERHEAD"
          echo "QoS WAN Packet Overhead: $QOSOVERHEAD" >>"$TMPEMAILFILE"
        fi
      fi
    elif [[ "$QOSENABLE" == "0" ]] >/dev/null 2>&1;then
      echo "QoS Status: Disabled" >>"$TMPEMAILFILE"
    fi
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine whether to use AMTM or AIProtection Email Configuration
  logger -p 6 -t "$ALIAS" "Debug - Selecting AMTM or AIProtection for Email Notification"
  e=0
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1 && [ "$e" == "0" ] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - AMTM Email Configuration Detected"
    if [ -z "$FROM_ADDRESS" ] >/dev/null 2>&1 || [ -z "$TO_NAME" ] >/dev/null 2>&1 || [ -z "$TO_ADDRESS" ] >/dev/null 2>&1 || [ -z "$USERNAME" ] >/dev/null 2>&1 || [ ! -f "$AMTM_EMAIL_DIR/emailpw.enc" ] >/dev/null 2>&1 || [ -z "$SMTP" ] >/dev/null 2>&1 || [ -z "$PORT" ] >/dev/null 2>&1 || [ -z "$PROTOCOL" ] >/dev/null 2>&1;then
      logger -p 2 -st "$ALIAS" "Email Notification - AMTM Email Configuration Incomplete"
    else
	$(/usr/sbin/curl --connect-timeout $EMAILTIMEOUT --max-time $EMAILTIMEOUT --url $PROTOCOL://$SMTP:$PORT \
		--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
		--upload-file "$TMPEMAILFILE" \
		--ssl-reqd \
		--user "$USERNAME:$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$AMTM_EMAIL_DIR/emailpw.enc" -pass pass:ditbabot,isoi)" $SSL_FLAG) \
		&& $(rm "$TMPEMAILFILE" & logger -p 4 -st "$ALIAS" "Email Notification - Email Notification via amtm Sent") && e=$(($e+1)) \
                || $(rm "$TMPEMAILFILE" & logger -p 2 -st "$ALIAS" "Email Notification - Email Notification via amtm Failed")
    fi
  fi
  if [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null 2>&1 && [ "$e" == "0" ] >/dev/null 2>&1;then
    logger -p 6 -t "$ALIAS" "Debug - AIProtection Alerts Email Configuration Detected"
    if [ ! -z "$SMTP_SERVER" ] >/dev/null 2>&1 && [ ! -z "$SMTP_PORT" ] >/dev/null 2>&1 && [ ! -z "$MY_NAME" ] >/dev/null 2>&1 && [ ! -z "$MY_EMAIL" ] >/dev/null 2>&1 && [ ! -z "$SMTP_AUTH_USER" ] >/dev/null 2>&1 && [ ! -z "$SMTP_AUTH_PASS" ] >/dev/null 2>&1;then
      $(cat "$TMPEMAILFILE" | sendmail -w $EMAILTIMEOUT -H "exec openssl s_client -quiet -CAfile $CAFILE -connect $SMTP_SERVER:$SMTP_PORT -tls1_3 -starttls smtp" -f"$MY_EMAIL" -au"$SMTP_AUTH_USER" -ap"$SMTP_AUTH_PASS" "$MY_EMAIL") \
      && $(rm "$TMPEMAILFILE" & logger -p 4 -st "$ALIAS" "Email Notification - Email Notification via AIProtection Alerts Sent") && e=$(($e+1)) \
      || $(rm "$TMPEMAILFILE" & logger -p 2 -st "$ALIAS" "Email Notification - Email Notification via AIProtection Alerts Failed")
    else
      logger -p 2 -st "$ALIAS" "Email Notification - AIProtection Alerts Email Configuration Incomplete"
    fi
  fi
  e=""
elif [ ! -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null 2>&1 || [ ! -f "$AMTM_EMAILCONFIG" ] >/dev/null 2>&1;then
  logger -p 6 -t "$ALIAS" "Debug - Email Notifications are not configured"
fi
return
}

# Check if NVRAM Background Process is Stuck if CHECKNVRAM is Enabled
nvramcheck ()
{
# Disable CHECKNVRAM if no value is detected
[[ -z "${CHECKNVRAM+x}" ]] >/dev/null 2>&1 && CHECKNVRAM=0

# Return if CHECKNVRAM is Disabled
if [[ "$CHECKNVRAM" == "0" ]] >/dev/null 2>&1;then
    return
# Check if Background Process for NVRAM Call is still running
elif [[ "$CHECKNVRAM" == "1" ]] >/dev/null 2>&1;then
  lastpid="$!" ; { [ ! -z "$(ps | awk '{print $1}' | grep -o "$lastpid")" ]] >/dev/null 2>&1 && kill -9 $lastpid 2>/dev/null && logger -p 6 -t "$ALIAS" "Debug - ***NVRAM Check Failure Detected***" ;}
  unset lastpid
fi
return
}

# Debug Logging
debuglog ()
{
# Return if Mode is not Manual or Run
if [[ "$mode" != "manual" ]] >/dev/null 2>&1 || [[ "$mode" != "run" ]] >/dev/null 2>&1;then
  return
elif [[ "$(nvram get log_level & nvramcheck)" -ge "7" ]] >/dev/null 2>&1;then

  logger -p 6 -t "$ALIAS" "Debug - Function: debuglog"

  # Get System Parameters
  getsystemparameters || return

  # Get Global WAN Parameters
  if [ -z "${globalwansync+x}" ] >/dev/null 2>&1;then
    GETWANMODE=2
    getwanparameters || return
  fi

  # Getting Active WAN Parameters
  GETWANMODE=3
  getwanparameters || return

  [ ! -z "${MODEL+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Model: "$(nvram get model & nvramcheck)""
  [ ! -z "${PRODUCTID+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Product ID: "$(nvram get productid & nvramcheck)""
  [ ! -z "${BUILDNAME+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Build Name: "$(nvram get build_name & nvramcheck)""
  [ ! -z "${BUILDNO+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Firmware: "$BUILDNO""
  [ ! -z "${IPVERSION+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - IPRoute Version: "$IPVERSION""
  [ ! -z "${WANSCAP+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - WAN Capability: "$WANSCAP""
  [ ! -z "${WANSMODE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Dual WAN Mode: "$WANSMODE""
  [ ! -z "${WANSLBRATIO+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Load Balance Ratio: "$WANSLBRATIO""
  [ ! -z "${WANSDUALWAN+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Dual WAN Interfaces: "$WANSDUALWAN""
  [ ! -z "${WANDOGENABLE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - ASUS Factory Watchdog: "$WANDOGENABLE""
  [ ! -z "${JFFSSCRIPTS+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - JFFS custom scripts and configs: "$JFFSSCRIPTS""
  [ ! -z "${HTTPENABLE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - HTTP Web Access: "$(nvram get misc_http_x & nvramcheck)""
  [ ! -z "${FIREWALLENABLE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - Firewall Enabled: "$(nvram get fw_enable_x & nvramcheck)""
  [ ! -z "${IPV6FIREWALLENABLE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - IPv6 Firewall Enabled: "$(nvram get ipv6_fw_enable & nvramcheck)""
  [ ! -z "${LEDDISABLE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - LEDs Disabled: "$(nvram get led_disable & nvramcheck)""
  [ ! -z "${QOSENABLE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - QoS Enabled: "$QOSENABLE""
  [ ! -z "${DDNSENABLE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - DDNS Enabled: "$DDNSENABLE""
  [ ! -z "${DDNSHOSTNAME+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - DDNS Hostname: "$DDNSHOSTNAME""
  [ ! -z "${LANHOSTNAME+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - LAN Hostname: "$LANHOSTNAME""
  [ ! -z "${IPV6SERVICE+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - WAN IPv6 Service: "$IPV6SERVICE""
  [ ! -z "${IPV6IPADDR+x}" ] >/dev/null 2>&1 && logger -p 6 -t "$ALIAS" "Debug - WAN IPv6 Address: "$IPV6IPADDR""
  logger -p 6 -t "$ALIAS" "Debug - Default Route: "$(ip route list default table main)""
  logger -p 6 -t "$ALIAS" "Debug - OpenVPN Server Instances Enabled: "$(nvram get vpn_serverx_start & nvramcheck)""
  for WANPREFIX in ${WANPREFIXES};do
    # Getting WAN Parameters
    GETWANMODE=1
    getwanparameters || return

    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Enabled: "$ENABLE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Routing Table Default Route: "$(ip route list default table "$TABLE")""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Ping Path: "$PINGPATH""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Target IP Rule: "$(ip rule list from all iif lo to "$TARGET" lookup "$TABLE")""
    if [[ "$PINGPATH" == "0" ]] >/dev/null 2>&1;then
      logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Target IP Route: "$(ip route list $TARGET via $GATEWAY dev $GWIFNAME table main)""
    else
      logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Target IP Route: "$(ip route list default table $TABLE)""
    fi
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" IP Address: "$IPADDR""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Real IP Address: "$REALIPADDR""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Real IP Address State: "$REALIPSTATE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Gateway IP: "$GATEWAY""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Gateway Interface: "$GWIFNAME""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Interface: "$IFNAME""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Automatic ISP DNS Enabled: "$DNSENABLE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Automatic ISP DNS Servers: "$DNS""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Manual DNS Server 1: "$DNS1""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Manual DNS Server 2: "$DNS2""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" State: "$STATE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Aux State: "$AUXSTATE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Sb State: "$SBSTATE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Primary Status: "$PRIMARY""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" USB Modem Status: "$USBMODEMREADY""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" UPnP Enabled: "$UPNPENABLE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" NAT Enabled: "$NAT""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Target IP Address: "$TARGET""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Routing Table: "$TABLE""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" IP Rule Priority: "$PRIORITY""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Mark: "$MARK""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" Mask: "$MASK""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" From WAN Priority: "$FROMWANPRIORITY""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" To WAN Priority: "$TOWANPRIORITY""
    logger -p 6 -t "$ALIAS" "Debug - "${WANPREFIX}" OVPN WAN Priority: "$OVPNWANPRIORITY""
  done
fi
return
}
scriptmode
