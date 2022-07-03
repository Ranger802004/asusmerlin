#!/bin/sh

# WAN Failover for ASUS Routers using Merlin Firmware v386.7
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 07/03/2022
# Version: v1.5.5-beta2

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh"
VERSION="v1.5.5-beta2"
CONFIGFILE="/jffs/configs/wan-failover.conf"
SYSTEMLOG="/tmp/syslog.log"
DNSRESOLVFILE="/tmp/resolv.conf"
LOCKFILE="/var/lock/wan-failover.lock"
WANPREFIXES="wan0 wan1"
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
  echo -e "${BLUE}$0 install${WHITE} - This will install the script and configuration files necessary for it to run.${NOCOLOR}"
  echo -e "${GREEN}$0 run${WHITE} - This mode is for the script to run in the background via cron job.${NOCOLOR}"
  echo -e "${GREEN}$0 manual${WHITE} - This will allow you to run the script in a command console.${NOCOLOR}"
  echo -e "${GREEN}$0 monitor${WHITE} - This will monitor the log file of the script.${NOCOLOR}"
  echo -e "${YELLOW}$0 update${WHITE} - This will download and update to the latest version.${NOCOLOR}"
  echo -e "${YELLOW}$0 config${WHITE} - This will allow reconfiguration of WAN Failover to update or change settings.${NOCOLOR}"
  echo -e "${YELLOW}$0 cron${WHITE} - This will create the Cron Jobs necessary for the script to run and also perform log cleaning.${NOCOLOR}"
  echo -e "${YELLOW}$0 switchwan${WHITE} - This will manually switch Primary WAN.${NOCOLOR}"
  echo -e "${YELLOW}$0 email${WHITE} - This will enable or disable email notifications using enable or disable parameter.${NOCOLOR}"
  echo -e "${RED}$0 uninstall${WHITE} - This will uninstall the configuration files necessary to stop the script from running.${NOCOLOR}"
  echo -e "${RED}$0 kill${WHITE} - This will kill any running instances of the script.${NOCOLOR}"
  break && exit
fi
mode="${1#}"
if [ "$#" == "2" ] >/dev/null;then
  arg2=$2
elif [ "$#" == "1" ] >/dev/null;then
  arg2=0
fi
scriptmode ()
{
if [[ "${mode}" == "install" ]] >/dev/null;then
  echo -e "${BLUE}${0##*/} - Install mode${NOCOLOR}"
  install
elif [[ "${mode}" == "config" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Configuration Mode${NOCOLOR}"
  install
elif [[ "${mode}" == "run" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Run Mode${NOCOLOR}"
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} already running...${NOCOLOR}" && exit ;}
  trap 'rm -f "$LOCKFILE"' EXIT
  setvariables
elif [[ "${mode}" == "manual" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Manual Mode${NOCOLOR}"
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} already running...${NOCOLOR}" && exit ;}
  trap 'rm -f "$LOCKFILE"' EXIT
  setvariables
elif [[ "${mode}" == "monitor" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Monitor Mode${NOCOLOR}"
  monitor
elif [[ "${mode}" == "kill" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Kill Mode${NOCOLOR}"
  kill
elif [[ "${mode}" == "uninstall" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Uninstall Mode${NOCOLOR}"
  uninstall
elif [[ "${mode}" == "cron" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Cron Job Mode${NOCOLOR}"
  cronjob
elif [[ "${mode}" == "logclean" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Log Clean Mode${NOCOLOR}"
  logclean
elif [[ "${mode}" == "switchwan" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Switch WAN Mode${NOCOLOR}"
  setvariables
elif [[ "${mode}" == "update" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Update Mode${NOCOLOR}"
  update
elif [[ "${mode}" == "email" ]] >/dev/null;then
  if [ "$arg2" == "0" ] >/dev/null;then
    echo -e "${RED}Select (enable) or (disable)${NOCOLOR}"
    exit
  elif [ "$arg2" == "enable" ] || [ "$arg2" == "disable" ] >/dev/null;then
    OPTION=$arg2
    sendemail
  fi
fi
if [[ ! -f "$CONFIGFILE" ]] >/dev/null;then
  echo -e "${RED}${0##*/} - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  exit
fi
}

# Install
install ()
{
if [[ "${mode}" == "install" ]] >/dev/null;then
  read -n 1 -s -r -p "Press any key to continue to install..."
fi
if [[ "${mode}" == "install" ]] || [[ "${mode}" == "config" ]] >/dev/null;then
  if [[ "${mode}" == "install" ]] >/dev/null;then
    # Check if JFFS Custom Scripts is enabled during installation
    if [[ "$(nvram get jffs2_scripts)" != "1" ]] >/dev/null;then
      echo -e "${RED}Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled.${NOCOLOR}"
      logger -t "${0##*/}" "Install - Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled"
    else
      echo -e "${GREEN}Administration > System > Enable JFFS custom scripts and configs is enabled...${NOCOLOR}"
      logger -t "${0##*/}" "Install - Administration > System > Enable JFFS custom scripts and configs is enabled"
    fi
  fi

  # Check for Config File
  if [[ "${mode}" == "install" ]] || [[ "${mode}" == "config" ]] >/dev/null;then
    echo -e "${BLUE}Creating $CONFIGFILE...${NOCOLOR}"
    logger -t "${0##*/}" "Install - Creating $CONFIGFILE"
    if [ ! -f $CONFIGFILE ] >/dev/null;then
      touch -a $CONFIGFILE
      chmod 666 $CONFIGFILE
      echo -e "${GREEN}$CONFIGFILE created.${NOCOLOR}"
      logger -t "${0##*/}" "Install - $CONFIGFILE created"
    else
      echo -e "${YELLOW}$CONFIGFILE already exists...${NOCOLOR}"
      logger -t "${0##*/}" "Install - $CONFIGFILE already exists"
    fi
  fi

  # Prompt to ask confirmation for reconfiguration
  if [[ "${mode}" == "install" ]] >/dev/null;then
    break
  elif [[ "${mode}" == "config" ]] && [ -f $CONFIGFILE ] >/dev/null;then
    while [[ "${mode}" == "config" ]] >/dev/null;do
      read -p "Do you want to reconfigure WAN Failover? ***Enter Y for Yes or N for No***" yn
      case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
    done
  elif [[ "${mode}" == "config" ]] && [ ! -f $CONFIGFILE ] >/dev/null;then
    echo -e "${RED}$CONFIGFILE doesn't exist, please run Install Mode...${NOCOLOR}"
    logger -t "${0##*/}" "Configuration - $CONFIGFILE doesn't exist, please run Install Mode"
  fi

  # User Input for Custom Variables
  echo "Setting Custom Variables..."
  echo -e "${YELLOW}***WAN Target IP Addresses will be routed via WAN Gateway dev WAN Interface***${NOCOLOR}"
  # Configure WAN0 Target IP Address
  while true >/dev/null;do  
    read -p "Configure WAN0 Target IP Address - Will be routed via $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gateway) dev $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname): " ip
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null;then
      for i in 1 2 3 4;do
        if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null;then
          echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
          break 1
        elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gateway)" == "$ip" ]] >/dev/null;then
          echo -e "${RED}***IP Address is the WAN0 Gateway IP Address***${NOCOLOR}"
          break 1
        else
          SETWAN0TARGET=$ip
          break 2
        fi
      done
    else  
      echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
      continue
    fi
  done
  # Configure WAN1 Target IP Address
  while true >/dev/null;do  
    read -p "Configure WAN1 Target IP Address - Will be routed via $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gateway) dev $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gw_ifname): " ip
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null;then
      for i in 1 2 3 4;do
        if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null;then
          echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
          break 1
        elif [[ "$ip" == "$SETWAN0TARGET" ]] >/dev/null;then
          echo -e "${RED}***IP Address already assigned to WAN0***${NOCOLOR}"
          break 1
        elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gateway)" == "$ip" ]] >/dev/null;then
          echo -e "${RED}***IP Address is the WAN1 Gateway IP Address***${NOCOLOR}"
          break 1
        else
          SETWAN1TARGET=$ip
          break 2
        fi
      done
    else  
      echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
      continue
    fi
  done
  # Configure Ping Count
  while true >/dev/null;do  
    read -p "Configure Ping Count - This is how many consecutive times a ping will fail before a WAN connection is considered disconnected: " value
      case $value in
        [0123456789]* ) SETPINGCOUNT=$value; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter a valid number***${NOCOLOR}"
      esac
  done
  # Configure Ping Timeout
  while true >/dev/null;do  
    read -p "Configure Ping Timeout - Value is in seconds: " value
      case $value in
        [0123456789]* ) SETPINGTIMEOUT=$value; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
      esac
  done
  # Configure Boot Delay Timer
  while true >/dev/null;do  
    read -p "Configure Boot Delay Timer - This is how long the script will delay execution after bootup ***Value is in seconds***: " value
      case $value in
        [0123456789]* ) SETBOOTDELAYTIMER=$value; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
      esac
  done
  # Configure WAN Disabled Timer
  while true >/dev/null;do  
    read -p "Configure WAN Disabled Timer - This is how long the script will sleep if Dual WAN/Failover Mode/WAN Links are disabled before checking status again, value is in seconds: " value
      case $value in
        [0123456789]* ) SETWANDISABLEDSLEEPTIMER=$value; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in seconds***${NOCOLOR}"
      esac
  done
  # Configure WAN0 QoS Download Bandwidth
  while true >/dev/null;do  
    read -p "Configure WAN0 QoS Download Bandwidth - Value is in Mbps: " value
      case $value in
        [0123456789]* ) SETWAN0_QOS_IBW=$(($value*1024)); break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
      esac
  done
  # Configure WAN1 QoS Download Bandwidth
  while true >/dev/null;do  
    read -p "Configure WAN1 QoS Download Bandwidth - Value is in Mbps: " value
      case $value in
        [0123456789]* ) SETWAN1_QOS_IBW=$(($value*1024)); break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
      esac
  done
  # Configure WAN0 QoS Upload Bandwidth
  while true >/dev/null;do  
    read -p "Configure WAN0 QoS Upload Bandwidth - Value is in Mbps: " value
      case $value in
        [0123456789]* ) SETWAN0_QOS_OBW=$(($value*1024)); break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
      esac
  done
  # Configure WAN1 QoS Upload Bandwidth
  while true >/dev/null;do  
    read -p "Configure WAN1 QoS Upload Bandwidth - Value is in Mbps: " value
      case $value in
        [0123456789]* ) SETWAN1_QOS_OBW=$(($value*1024)); break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Mbps***${NOCOLOR}"
      esac
  done
  echo -e "${WHITE}***QoS WAN Packet Overhead Reference Guide - ${BLUE}None: 0, Conservative Default: 48, VLAN: 42, DOCSIS: 18, PPPoE VDSL: 27, ADSL PPPoE VC: 32, ADSL PPPoE LLC: 40, VDSL Bridged: 19, VDSL2 PPPoE: 30, VDSL2 Bridged: 22***${NOCOLOR}"
  # Configure WAN0 QoS Packet Overhead
  while true >/dev/null;do  
    read -p "Configure WAN0 QoS Packet Overhead: " value
      case $value in
        [0123456789]* ) SETWAN0_QOS_OVERHEAD=$value; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
      esac
  done
  # Configure WAN1 QoS Packet Overhead
  while true >/dev/null;do  
    read -p "Configure WAN1 QoS Packet Overhead: " value
      case $value in
        [0123456789]* ) SETWAN1_QOS_OVERHEAD=$value; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Value is in Bytes***${NOCOLOR}"
      esac
  done
  echo -e "${WHITE}***QoS ATM Reference Guide - ${BLUE}Recommended is Disabled unless using ISDN***${NOCOLOR}"
  # Configure WAN0 QoS ATM
  while true >/dev/null;do  
    read -p "Enable WAN0 QoS ATM? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETWAN0_QOS_ATM=1; break;;
        [Nn]* ) SETWAN0_QOS_ATM=0; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done
  # Configure WAN1 QoS ATM
  while true >/dev/null;do  
    read -p "Enable WAN1 QoS ATM? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETWAN1_QOS_ATM=1; break;;
        [Nn]* ) SETWAN1_QOS_ATM=0; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done
  # Configure Packet Loss Logging
  while true >/dev/null;do  
    read -p "Enable Packet Loss Logging? ***Enter Y for Yes or N for No*** " yn
      case $yn in
        [Yy]* ) SETPACKETLOSSLOGGING=1; break;;
        [Nn]* ) SETPACKETLOSSLOGGING=0; break;;
        * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
      esac
  done

# Create Array for Custom Variables
NEWVARIABLES='
WAN0TARGET=|'$SETWAN0TARGET'
WAN1TARGET=|'$SETWAN1TARGET'
PINGCOUNT=|'$SETPINGCOUNT'
PINGTIMEOUT=|'$SETPINGTIMEOUT'
WANDISABLEDSLEEPTIMER=|'$SETWANDISABLEDSLEEPTIMER'
BOOTDELAYTIMER=|'$SETBOOTDELAYTIMER'
WAN0_QOS_IBW=|'$SETWAN0_QOS_IBW'
WAN1_QOS_IBW=|'$SETWAN1_QOS_IBW'
WAN0_QOS_OBW=|'$SETWAN0_QOS_OBW'
WAN1_QOS_OBW=|'$SETWAN1_QOS_OBW'
WAN0_QOS_OVERHEAD=|'$SETWAN0_QOS_OVERHEAD'
WAN1_QOS_OVERHEAD=|'$SETWAN1_QOS_OVERHEAD'
WAN0_QOS_ATM=|'$SETWAN0_QOS_ATM'
WAN1_QOS_ATM=|'$SETWAN1_QOS_ATM'
PACKETLOSSLOGGING=|'$SETPACKETLOSSLOGGING'
'
  # Adding Custom Variables to Config File
  echo -e "${BLUE}Adding Custom Settings to $CONFIGFILE...${NOCOLOR}"
  logger -t "${0##*/}" "Install - Adding Custom Settings to $CONFIGFILE"
  for NEWVARIABLE in ${NEWVARIABLES};do
    if [ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] >/dev/null;then
      echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    else
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    fi
  done
  echo -e "${GREEN}Custom Variables added to $CONFIGFILE.${NOCOLOR}"
  logger -t "${0##*/}" "Install - Custom Variables added to $CONFIGFILE"

  if [[ "${mode}" == "install" ]] >/dev/null;then
    # Create Wan-Event if it doesn't exist
    echo -e "${BLUE}Creating Wan-Event script...${NOCOLOR}"
    logger -t "${0##*/}" "Install - Creating Wan-Event script"
    if [ ! -f "/jffs/scripts/wan-event" ] >/dev/null;then
      touch -a /jffs/scripts/wan-event
      chmod 755 /jffs/scripts/wan-event
      echo "#!/bin/sh" >> /jffs/scripts/wan-event
      echo -e "${GREEN}Wan-Event script has been created.${NOCOLOR}"
    logger -t "${0##*/}" "Install - Wan-Event script has been created"
    else
      echo -e "${YELLOW}Wan-Event script already exists...${NOCOLOR}"
      logger -t "${0##*/}" "Install - Wan-Event script already exists"
    fi

    # Add Script to Wan-event
    if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "# Wan-Failover")" ] >/dev/null;then 
      echo -e "${YELLOW}${0##*/} already added to Wan-Event...${NOCOLOR}"
      logger -t "${0##*/}" "Install - ${0##*/} already added to Wan-Event"
    else
      cmdline="sh $0 cron"
      echo -e "${BLUE}Adding ${0##*/} to Wan-Event...${NOCOLOR}"
      logger -t "${0##*/}" "Install - Adding ${0##*/} to Wan-Event"
      echo -e "\r\n$cmdline # Wan-Failover" >> /jffs/scripts/wan-event
      echo -e "${GREEN}${0##*/} added to Wan-Event.${NOCOLOR}"
      logger -t "${0##*/}" "Install - ${0##*/} added to Wan-Event"
    fi

    # Create Initial Cron Jobs
    cronjob

    # Start Initial Script
    sh $0 run
  fi
  # Kill current instance of script to allow new configuration to take place.
  if [[ "${mode}" == "config" ]] >/dev/null;then
    kill
  fi
fi
exit
}

# Uninstall
uninstall ()
{
if [[ "${mode}" == "uninstall" ]] >/dev/null;then
read -n 1 -s -r -p "Press any key to continue to uninstall..."
  # Remove Cron Job
  if [ ! -z "$(crontab -l | grep -e "setup_wan_failover_run")" ] >/dev/null; then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job for Run Mode...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing Cron Job for Run Mode"
    cru d setup_wan_failover_run
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job for Run Mode.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed Cron Job for Run Mode"
  else
    echo -e "${GREEN}${0##*/} - Uninstall: Cron Job for Run Mode doesn't exist.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Cron Job for Run Mode doesn't exist"
  fi

  # Check for Config File
  echo -e "${BLUE}${0##*/} - Uninstall: Deleting $CONFIGFILE...${NOCOLOR}"
  logger -t "${0##*/}" "Uninstall - Deleting $CONFIGFILE"
  if [ -f $CONFIGFILE ] >/dev/null;then
    rm -f $CONFIGFILE
    echo -e "${GREEN}${0##*/} - Uninstall: $CONFIGFILE deleted.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - $CONFIGFILE deleted"
  else
    echo -e "${RED}${0##*/} - Uninstall: $CONFIGFILE doesn't exist.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - $CONFIGFILE doesn't exist"
  fi

  # Remove Script from Wan-event
  cmdline="sh $0 cron"
  if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ] >/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Wan-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing Cron Job from Wan-Event"
    sed -i '\~# Wan-Failover~d' /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Wan-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed Cron Job from Wan-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Wan-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Cron Job doesn't exist in Wan-Event"
  fi

  # Restart WAN Interfaces
  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] >/dev/null;then
    echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface $(echo $WANPREFIXES | awk '{print $1}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarting interface $(echo $WANPREFIXES | awk '{print $1}')"
    nvram set "$(echo $WANPREFIXES | awk '{print $1}')"_state_t=0
    service "restart_wan_if 0" &
    echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface $(echo $WANPREFIXES | awk '{print $1}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarted interface $(echo $WANPREFIXES | awk '{print $1}')"
  fi

  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
    echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface $(echo $WANPREFIXES | awk '{print $2}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarting interface $(echo $WANPREFIXES | awk '{print $2}')"
    nvram set "$(echo $WANPREFIXES | awk '{print $2}')"_state_t=0
    service "restart_wan_if 1" &
    echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface $(echo $WANPREFIXES | awk '{print $2}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarted interface $(echo $WANPREFIXES | awk '{print $2}')"
  fi

  # Remove Lock File
  if [ -f "$LOCKFILE" ] >/dev/null;then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing $LOCKFILE...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing $LOCKFILE"
    rm -f "$LOCKFILE"
    echo -e "${GREEN}${0##*/} - Uninstall: Removed $LOCKFILE...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed $LOCKFILE"
  else
    echo -e "${RED}${0##*/} - Uninstall: $LOCKFILE doesn't exist.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - $LOCKFILE doesn't exist"
  fi

  # Kill Running Processes
  echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
  logger -t "${0##*/}" "Uninstall - Killing ${0##*/}"
  sleep 3 && killall ${0##*/}
fi
exit
}

# Kill Script
kill ()
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
if [[ ! -z "$(echo "$VERSION" | grep -e "beta")" ]] >/dev/null; then
  echo -e "${YELLOW}Current Version: $VERSION - Script is a beta version and must be manually upgraded or replaced for a production version.${NOCOLOR}"
  while true >/dev/null;do  
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

# Cronjob
cronjob ()
{
if [ -z "$(crontab -l | grep -e "$0")" ] >/dev/null; then
  echo -e "${BLUE}Creating cron jobs...${NOCOLOR}"
  logger -t "${0##*/}" "Cron - Creating cron job"
  cru a setup_wan_failover_run "*/1 * * * *" $0 run
  echo -e "${GREEN}Completed creating cron job.${NOCOLOR}"
  logger -t "${0##*/}" "Cron - Completed creating cron job"
fi
exit
}

# Monitor Logging
monitor ()
{
tail -F $SYSTEMLOG | grep -e "${0##*/}" && exit
}

# Set Variables
setvariables ()
{
#Set Variables from Configuration
. $CONFIGFILE

if [[ "${mode}" == "switchwan" ]] >/dev/null;then
  switchwan
else
  wanstatus
fi
}

# WAN Status
wanstatus ()
{
# Boot Delay Timer
if [ ! -z "$BOOTDELAYTIMER" ] >/dev/null;then
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -lt "$BOOTDELAYTIMER" ]] >/dev/null;then
    logger -t "${0##*/}" "Boot Delay - Waiting for System Uptime to reach $BOOTDELAYTIMER seconds"
    while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -lt "$BOOTDELAYTIMER" ]] >/dev/null;do
      sleep 1
    done
    logger -t "${0##*/}" "Boot Delay - System Uptime is $(awk -F "." '{print $1}' "/proc/uptime") seconds"
  fi
fi
# Delay if NVRAM is not accessible
while [ -z "$(nvram get model)" ] >/dev/null;do
  sleep 5
done
# Check Current Status of Dual WAN Mode
if { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && [[ "$(nvram get wans_mode)" != "fo" ]] ;} >/dev/null;then
  logger -t "${0##*/}" "Dual WAN - Disabled"
  wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  logger -t "${0##*/}" "Dual WAN - ASUS Factory Watchdog: Enabled"
  wandisabled
# Check if both WAN Interfaces are Disabled
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  wandisabled
# Check if WAN Interfaces are Enabled and Connected
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] || [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
  for WANPREFIX in ${WANPREFIXES};do
    # Check if WAN Interfaces are Disabled
    if [[ "$(nvram get "${WANPREFIX}"_enable)" == "0" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Status - ${WANPREFIX} disabled"
      # Set WAN0 as Disabled
      if [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $1}')" ]] >/dev/null;then
        WAN0STATUS="DISABLED"
        continue
      # Set WAN1 as Disabled
      elif [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $2}')" ]] >/dev/null;then
        WAN1STATUS="DISABLED"
        continue
      fi
    # Check if WAN is Enabled
    elif [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Status - ${WANPREFIX} enabled"
      # Check WAN0 Connection
      if [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $1}')" ]] >/dev/null;then
        # Check if WAN0 is Connected
        if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - "${WANPREFIX}": Cable Unplugged"
          logger -t "${0##*/}" "WAN Status - Restarting "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          service "restart_wan_if 0" & 
          sleep 1
          while [[ "$(nvram get "${WANPREFIX}"_state_t)" == "6" ]] >/dev/null;do
            sleep 1
          done
          logger -t "${0##*/}" "WAN Status - Restarted "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
            WAN0STATUS="DISCONNECTED"
            continue
          elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
            break
          else
            wanstatus
          fi
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Restarting "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          service "restart_wan_if 0" & 
          sleep 1
          while [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] || [[ "$(nvram get "${WANPREFIX}"_state_t)" == "6" ]] >/dev/null;do
            sleep 1
          done
          logger -t "${0##*/}" "WAN Status - Restarted "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
            break
          else
            wanstatus
          fi
        fi
        # Check if WAN0 Gateway IP or IP Address are 0.0.0.0
        if { [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} is disconnected.  IP Address: "$(nvram get ${WANPREFIX}_ipaddr)" Gateway: "$(nvram get ${WANPREFIX}_gateway)""
          WAN0STATUS="DISCONNECTED"
          continue
        # Check WAN0 IP Address Target Route
        elif [ ! -z "$(ip route list default | grep -e "$WAN0TARGET")" ] && [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Default route already exists via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
        elif [ -z "$(ip route list default table 100 | grep -e "$(nvram get ${WANPREFIX}_gw_ifname)")" ] && [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Adding default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
          ip route add default via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname) table 100
          logger -t "${0##*/}" "WAN Status - Added default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
        fi
        # Check WAN0 IP Rule
        if [ -z "$(ip rule list from all to $WAN0TARGET iif lo lookup ${WANPREFIX})" ] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Adding IP Rule for "$WAN0TARGET""
          ip rule add from all iif lo ipproto icmp to $WAN0TARGET table 100
          logger -t "${0##*/}" "WAN Status - Added IP Rule for "$WAN0TARGET""
        fi
        # Check WAN0 Packet Loss
        WAN0PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
        if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN0PACKETLOSS packet loss"
          WAN0STATUS="CONNECTED"
          nvram set ${WANPREFIX}_state_t=2
          continue
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] && [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN0PACKETLOSS packet loss ***Verify $WAN0TARGET is a valid server for ICMP Echo Requests***"
          WAN0STATUS="DISCONNECTED"
          continue
        else
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN0PACKETLOSS packet loss"
          WAN0STATUS="DISCONNECTED"
          continue
        fi
      # Check WAN1 Connection
      elif [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $2}')" ]] >/dev/null;then
        # Check if WAN1 is Connected
        if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - "${WANPREFIX}": Cable Unplugged"
          logger -t "${0##*/}" "WAN Status - Restarting "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          service "restart_wan_if 1" & 
          sleep 1
          while [[ "$(nvram get "${WANPREFIX}"_state_t)" == "6" ]] >/dev/null;do
            sleep 1
          done
          logger -t "${0##*/}" "WAN Status - Restarted "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
            WAN1STATUS="DISCONNECTED"
            continue
          elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
            break
          else
            wanstatus
          fi
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Restarting "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          service "restart_wan_if 1" & 
          sleep 1
          while [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] || [[ "$(nvram get "${WANPREFIX}"_state_t)" == "6" ]] >/dev/null;do
            sleep 1
          done
          logger -t "${0##*/}" "WAN Status - Restarted "${WANPREFIX}": "$(nvram get ${WANPREFIX}_gw_ifname)""
          if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
            break
          else
            wanstatus
          fi
        fi
        # Check if WAN1 Gateway IP or IP Address are 0.0.0.0
        if { [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} is disconnected.  IP Address: "$(nvram get ${WANPREFIX}_ipaddr)" Gateway: "$(nvram get ${WANPREFIX}_gateway)""
          WAN1STATUS="DISCONNECTED"
          continue
        # Check WAN1 IP Address Target Route
        elif [ ! -z "$(ip route list default | grep -e "$WAN1TARGET")" ] && [[ "$(nvram get wans_mode)" == "fo" ]]  >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Default route already exists via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
        elif [ -z "$(ip route list default table 200 | grep -e "$(nvram get ${WANPREFIX}_gw_ifname)")" ] && [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Adding default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
          ip route add default via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname) table 200
          logger -t "${0##*/}" "WAN Status - Added default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
        fi
        # Check WAN1 IP Rule
        if [ -z "$(ip rule list from all to $WAN1TARGET iif lo lookup ${WANPREFIX})" ] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Adding IP Rule for "$WAN1TARGET""
          ip rule add from all iif lo ipproto icmp to $WAN1TARGET table 200
          logger -t "${0##*/}" "WAN Status - Added IP Rule for "$WAN1TARGET""
        fi
        # Check WAN1 Packet Loss
        WAN1PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
        if [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN1PACKETLOSS packet loss"
          WAN1STATUS="CONNECTED"
          nvram set ${WANPREFIX}_state_t=2
          continue
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN1PACKETLOSS packet loss ***Verify $WAN1TARGET is a valid server for ICMP Echo Requests***"
          WAN1STATUS="DISCONNECTED"
          continue
        else
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN1PACKETLOSS packet loss"
          WAN1STATUS="DISCONNECTED"
          continue
        fi
      fi
    fi
  done
fi
# Set WAN Status to DISABLED, DISCONNECTED, or CONNECTED and select function.
if [[ "$WAN0STATUS" == "DISABLED" ]] && [[ "$WAN1STATUS" == "DISABLED" ]] >/dev/null;then
  wandisabled
elif [[ "$(nvram get wans_mode)" == "fo" ]] && [[ "$WAN0STATUS" == "DISCONNECTED" ]] && [[ "$WAN1STATUS" == "DISCONNECTED" ]] >/dev/null;then
  wandisabled
elif [[ "$(nvram get wans_mode)" == "fo" ]] && [[ "$WAN0STATUS" == "CONNECTED" ]] && { [[ "$WAN1STATUS" == "CONNECTED" ]] || [[ "$WAN1STATUS" == "DISABLED" ]] || [[ "$WAN1STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
  wan0active
elif [[ "$(nvram get wans_mode)" == "fo" ]] && [[ "$WAN1STATUS" == "CONNECTED" ]] && { [[ "$WAN0STATUS" != "CONNECTED" ]] || [[ "$WAN0STATUS" == "DISABLED" ]] || [[ "$WAN0STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
  wan1active
elif [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
  lbmonitor
else
  wanstatus
fi
}

# WAN0 Active
wan0active ()
{
  logger -t "${0##*/}" "WAN0 Active - Verifying WAN0"
if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
  wan0failovermonitor
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  wandisabled
else
  wanstatus
fi
}

# WAN1 Active
wan1active ()
{
  logger -t "${0##*/}" "WAN1 Active - Verifying WAN1"
if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] >/dev/null;then
  wan0failbackmonitor
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] >/dev/null;then
  wandisabled
else
  wanstatus
fi
}

# Load Balance Monitor
lbmonitor ()
{
  logger -t "${0##*/}" "Load Balance Monitor - Monitoring WAN0 via $WAN0TARGET and WAN1 via $WAN1TARGET for Failures"
while { [[ "$(nvram get wans_mode)" == "lb" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} \
&& { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gateway)" == "$(ip route show $WAN0TARGET | awk '{print $3}')" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname)" == "$(ip route show $WAN0TARGET | awk '{print $5}')" ]] ;} \
&& { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gateway)" == "$(ip route show $WAN1TARGET | awk '{print $3}')" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gw_ifname)" == "$(ip route show $WAN1TARGET | awk '{print $5}')" ]] ;} >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  WAN1PACKETLOSS="$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  if [ -z "$(ip route list $WAN0TARGET via "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_gateway)" dev "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_gw_ifname)")" ] \
  || [ -z "$(ip route list $WAN1TARGET via "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_gateway)" dev "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_gw_ifname)")" ] >/dev/null;then
    break
    echo "Break"
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -t "${0##*/}" "Load Balance Monitor - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      ip route del default
      logger -t "${0##*/}" "Load Balance Monitor - Adding nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      logger -t "${0##*/}" "Load Balance Monitor - Adding nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route add default scope global \
      nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}') \
      nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -t "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      ip route del default
      ip route add default scope global \
      nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null;then
    if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -t "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route del default
      ip route add default scope global \
      nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -t "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route del default
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] || [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null;then
    if [ -z "$PACKETLOSSLOGGING" ] || [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null;then
      logger -t "${0##*/}" "Load Balance Monitor - Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      continue
    elif [ ! -z "$PACKETLOSSLOGGING" ] && [[ "$PACKETLOSSLOGGING" == "0"]] >/dev/null;then
      continue
    fi
  fi
done
  wanstatus
}

# WAN0 Failover Monitor
wan0failovermonitor ()
{
  logger -t "${0##*/}" "WAN0 Failover Monitor - Monitoring $(echo $WANPREFIXES | awk '{print $1}') via $WAN0TARGET for Failure"
while { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] \
&& [ ! -z "$(ip rule list from all to "$WAN0TARGET" iif lo lookup "$(echo $WANPREFIXES | awk '{print $1}')")" ] \
&& { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gateway)" == "$(ip route list default table 100 | awk '{print $3}')" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname)" == "$(ip route list default table 100 | awk '{print $5}')" ]] ;} >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
    continue
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN0 Failover Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    switchwan
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null;then
    if [ -z "$PACKETLOSSLOGGING" ] || [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN0 Failover Monitor - Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
      continue
    elif [ ! -z "$PACKETLOSSLOGGING" ] && [[ "$PACKETLOSSLOGGING" == "0"]] >/dev/null;then
      continue
    fi
  fi
done
  wanstatus
}

# WAN0 Failback Monitor
wan0failbackmonitor ()
{
  logger -t "${0##*/}" "WAN0 Failback Monitor - Monitoring $(echo $WANPREFIXES | awk '{print $1}') via $WAN0TARGET for Failback"
while { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] \
&& [ ! -z "$(ip rule list from all to "$WAN0TARGET" iif lo lookup "$(echo $WANPREFIXES | awk '{print $1}')")" ] \
&& { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gateway)" == "$(ip route list default table 100 | awk '{print $3}')" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname)" == "$(ip route list default table 100 | awk '{print $5}')" ]] ;} >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  if [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null;then
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN0 Failback Monitor - Connection Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    switchwan
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null;then
    if [ -z "$PACKETLOSSLOGGING" ] || [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN0 Failback Monitor - Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
      continue
    elif [ ! -z "$PACKETLOSSLOGGING" ] && [[ "$PACKETLOSSLOGGING" == "0"]] >/dev/null;then
      continue
    fi
  fi
done
  wanstatus
}

# WAN Disabled
wandisabled ()
{
if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - Dual WAN is disabled"
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - ASUS Factory WAN Failover is enabled"
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') are disabled"
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') is disabled"
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') is disabled"
fi
  logger -t "${0##*/}" "WAN Failover Disabled - WAN Failover is currently stopped, will resume when Dual WAN Failover Mode is enabled and WAN Links are enabled with an active connection"
while \
  # Return to WAN Status if both interfaces are Enabled and Connected
  if  { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_enable)" == "1" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_state_t)" == "2" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_state_t)" == "2" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') are enabled and connected"
    break
  # Return to WAN Status if both interfaces are Enabled and have Real IP Addresses
  elif  { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_enable)" == "1" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_realip_state)" == "2" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_realip_state)" == "2" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') are enabled and connected"
    break
  # Return to WAN Status if only WAN0 is Enabled and Connected but is not Primary WAN
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if only WAN1 is Enabled and Connected but is not Primary WAN
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 is Connected and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 is Connected and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 has a Real IP Address and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_realip_state)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_realip_state)" != "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 has a Real IP Address and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_realip_state)" != "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_realip_state)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are pinging both Target IP Addresses.
  elif  { [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') have 0% packet loss"
    break
  # Return to WAN Status if WAN0 is pinging the Target IP Address and WAN1 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] && [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') has 0% packet loss but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN1 is pinging the Target IP Address and WAN0 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] && [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') has 0% packet loss but is not Primary WAN"
    switchwan && break
  # WAN Failover Disabled if not in Dual WAN Mode Failover Mode or if ASUS Factory Failover is Enabled
  elif { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] || [[ "$(nvram get wandog_enable)" != "0" ]] ;} >/dev/null;then
    sleep $WANDISABLEDSLEEPTIMER
    continue
  else
    sleep $WANDISABLEDSLEEPTIMER
    continue
  fi
 >/dev/null;do
  sleep $WANDISABLEDSLEEPTIMER
done
# Return to WAN Status
logger -t "${0##*/}" "WAN Failover Disabled - Returning to check WAN Status"
wanstatus
}

# Switch WAN
switchwan ()
{
# Determine Current Primary WAN and change it to the Inactive WAN
if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] >/dev/null;then
  ACTIVEWAN=wan1
  INACTIVEWAN=wan0
  echo Switching to $ACTIVEWAN
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] >/dev/null;then
  ACTIVEWAN=wan0
  INACTIVEWAN=wan1
  echo Switching to $ACTIVEWAN
fi
# Verify new Active WAN Gateway IP or IP Address are not 0.0.0.0
if { [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get "$ACTIVEWAN"_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
  logger -t "${0##*/}" "WAN Status - ${WANPREFIX} is disconnected.  IP Address: "$(nvram get ${WANPREFIX}_ipaddr)" Gateway: "$(nvram get ${WANPREFIX}_gateway)""
  wanstatus
fi
# Perform WAN Switch until Secondary WAN becomes Primary WAN
until { [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] && [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] ;} \
&& { [[ "$(echo $(ip route show default | awk '{print $3}'))" == "$(nvram get "$ACTIVEWAN"_gateway)" ]] && [[ "$(echo $(ip route show default | awk '{print $5}'))" == "$(nvram get "$ACTIVEWAN"_gw_ifname)" ]] ;} \
&& { [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" == "$(nvram get wan_ipaddr)" ]] && [[ "$(nvram get "$ACTIVEWAN"_gateway)" == "$(nvram get wan_gateway)" ]] && [[ "$(nvram get "$ACTIVEWAN"_gw_ifname)" == "$(nvram get wan_gw_ifname)" ]] ;} >/dev/null;do
  # Change Primary WAN
  if [[ "$(nvram get "$ACTIVEWAN"_primary)" != "1" ]] && [[ "$(nvram get "$INACTIVEWAN"_primary)" != "0" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Switching $ACTIVEWAN to Primary WAN"
    nvram set "$ACTIVEWAN"_primary=1 && nvram set "$INACTIVEWAN"_primary=0
  fi
  # Change WAN IP Address
  if [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" != "$(nvram get wan_ipaddr)" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr)"
    nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr)
  fi

  # Change WAN Gateway
  if [[ "$(nvram get "$ACTIVEWAN"_gateway)" != "$(nvram get wan_gateway)" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - WAN Gateway: $(nvram get "$ACTIVEWAN"_gateway)"
    nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway)
  fi
  # Change WAN Interface
  if [[ "$(nvram get "$ACTIVEWAN"_gw_ifname)" != "$(nvram get wan_gw_ifname)" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - WAN Interface: $(nvram get "$ACTIVEWAN"_gw_ifname)"
    nvram set wan_gw_ifname=$(nvram get "$ACTIVEWAN"_gw_ifname)
  fi
  if [[ "$(nvram get "$ACTIVEWAN"_ifname)" != "$(nvram get wan_ifname)" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - WAN Interface: $(nvram get "$ACTIVEWAN"_ifname)"
    nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname)
  fi

# Switch DNS
  # Check if AdGuard is Running or AdGuard Local is Enabled
  if [ ! -z "$(pidof AdGuardHome)" ] || { [ -f "/opt/etc/AdGuardHome/.config" ] && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - DNS is being managed by AdGuard"
  # Change Manual DNS Settings
  elif [[ "$(nvram get "$ACTIVEWAN"_dnsenable_x)" == "0" ]] >/dev/null;then
    # Change Manual DNS1 Server
    if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns1_x))")" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - DNS1 Server: "$(nvram get "$ACTIVEWAN"_dns1_x)""
      nvram set wan_dns1_x=$(nvram get "$ACTIVEWAN"_dns1_x)
      sed -i '1i nameserver '$(nvram get "$ACTIVEWAN"_dns1_x)'' $DNSRESOLVFILE
      sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns1_x)'/d' $DNSRESOLVFILE
    elif [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns1_x))")" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server"
    elif [ -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - No DNS1 Server for $ACTIVEWAN"
    fi
    # Change Manual DNS2 Server
    if [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns2_x))")" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - DNS2 Server: "$(nvram get "$ACTIVEWAN"_dns2_x)""
      nvram set wan_dns2_x=$(nvram get "$ACTIVEWAN"_dns2_x)
      sed -i '2i nameserver '$(nvram get "$ACTIVEWAN"_dns2_x)'' $DNSRESOLVFILE
      sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns2_x)'/d' $DNSRESOLVFILE
    elif [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns2_x))")" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server"
    elif [ -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - No DNS2 Server for $ACTIVEWAN"
    fi

  # Change Automatic ISP DNS Settings
  elif [[ "$(nvram get "$ACTIVEWAN"_dnsenable_x)" == "1" ]] >/dev/null;then
    if [[ "$(nvram get "$ACTIVEWAN"_dns)" != "$(nvram get wan_dns)" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - Automatic DNS Settings from ISP: "$(nvram get "$ACTIVEWAN"_dns)""
      nvram set wan_dns="$(echo $(nvram get "$ACTIVEWAN"_dns))"
    fi
    # Change Automatic DNS1 Server
    if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')")" ] >/dev/null;then
      sed -i '1i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')'' $DNSRESOLVFILE
      sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $1}')'/d' $DNSRESOLVFILE
    elif [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')")" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server"
    elif [ -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - DNS1 Server not detected in Automatic ISP Settings for $ACTIVEWAN"
    fi
    # Change Automatic DNS2 Server
    if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')")" ] >/dev/null;then
      sed -i '2i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')'' $DNSRESOLVFILE
      sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $2}')'/d' $DNSRESOLVFILE
    elif [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')")" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server"
    elif [ -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - DNS2 Server not detected in Automatic ISP Settings for $ACTIVEWAN"
    fi
  else
    logger -t "${0##*/}" "WAN Switch - No DNS Settings Detected"
  fi

  # Delete Old Default Route
  if [ ! -z "$(ip route list default | grep -e "$(nvram get "$INACTIVEWAN"_gw_ifname)")" ]  >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Deleting default route via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname)""
    ip route del default
  fi
  # Add New Default Route
  if [ -z "$(ip route list default | grep -e "$(nvram get "$ACTIVEWAN"_gw_ifname)")" ]  >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Adding default route via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname)""
    ip route add default via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_gw_ifname)
  fi

  # Change QoS Settings
  if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - QoS is Enabled"
    if [[ ! -z "$(nvram get qos_obw)" ]] && [[ ! -z "$(nvram get qos_obw)" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - Applying Manual QoS Bandwidth Settings"
      if [[ "$ACTIVEWAN" == "wan0" ]] >/dev/null;then
        if [[ "$(nvram get qos_obw)" != "$WAN0_QOS_OBW" ]] >/dev/null;then
          nvram set qos_obw=$WAN0_QOS_OBW
        fi
        if [[ "$(nvram get qos_ibw)" != "$WAN0_QOS_IBW" ]] >/dev/null;then
          nvram set qos_ibw=$WAN0_QOS_IBW
        fi
        if [[ "$(nvram get qos_overhead)" != "$WAN0_QOS_OVERHEAD" ]] >/dev/null;then
          nvram set qos_overhead=$WAN0_QOS_OVERHEAD
        fi
        if [[ "$(nvram get qos_atm)" != "$WAN0_QOS_ATM" ]] >/dev/null;then
          nvram set qos_atm=$WAN0_QOS_ATM
        fi
      elif [[ "$ACTIVEWAN" == "wan1" ]] >/dev/null;then
        if [[ "$(nvram get qos_obw)" != "$WAN1_QOS_OBW" ]] >/dev/null;then
          nvram set qos_obw=$WAN1_QOS_OBW
        fi
        if [[ "$(nvram get qos_ibw)" != "$WAN1_QOS_IBW" ]] >/dev/null;then
          nvram set qos_ibw=$WAN1_QOS_IBW
        fi
        if [[ "$(nvram get qos_overhead)" != "$WAN1_QOS_OVERHEAD" ]] >/dev/null;then
          nvram set qos_overhead=$WAN1_QOS_OVERHEAD
        fi
        if [[ "$(nvram get qos_atm)" != "$WAN1_QOS_ATM" ]] >/dev/null;then
          nvram set qos_atm=$WAN1_QOS_ATM
        fi
      fi
      logger -t "${0##*/}" "WAN Switch - QoS Settings: Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps"
    fi
  elif [[ "$(nvram get qos_enable)" == "0" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - QoS is Disabled"
  fi
  sleep 1
done
  if [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] && [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Switched $ACTIVEWAN to Primary WAN"
  fi
restartservices
}

# Restart Services
restartservices ()
{
# Check for services that need to be restarted:
SERVICES=""
if [ ! -z "$(pidof dnsmasq)" ] >/dev/null;then
  SERVICE="dnsmasq"
  SERVICES="${SERVICES} ${SERVICE}"
fi
if [[ "$(nvram get fw_enable_x)" == "1" ]] >/dev/null;then
  SERVICE="firewall"
  SERVICES="${SERVICES} ${SERVICE}"
fi
if [[ "$(nvram get led_disable)" == "0" ]] >/dev/null;then
  SERVICE="leds"
  SERVICES="${SERVICES} ${SERVICE}"
fi
if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
  SERVICE="qos"
  SERVICES="${SERVICES} ${SERVICE}"
fi

# Restart Services
for SERVICE in ${SERVICES};do
  logger -t "${0##*/}" "Service Restart - Restarting $SERVICE service"
  service restart_$SERVICE
  logger -t "${0##*/}" "Service Restart - Restarted $SERVICE service"
done
if [[ "${mode}" == "switchwan" ]] >/dev/null;then
  exit
elif [[ "$SENDEMAIL" == "1" ]] || [ -z "$SENDEMAIL" ] >/dev/null;then
  sendemail
elif [[ "$SENDEMAIL" == "0" ]] >/dev/null;then
  wanevent
else
  wanevent
fi
}

# Send Email
sendemail ()
{
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
if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
  . "$AMTM_EMAILCONFIG"
fi

if [ ! -z "$BOOTDELAYTIMER" ] >/dev/null;then
  SKIPEMAILSYSTEMUPTIME="$(($BOOTDELAYTIMER+60))"
elif [ -z "$BOOTDELAYTIMER" ] >/dev/null;then
  SKIPEMAILSYSTEMUPTIME="60"
fi

# Enable or Disable Email
if [[ "${mode}" == "email" ]] && [ ! -z "$OPTION" ] >/dev/null;then
  if [[ "$OPTION" == "enable" ]] >/dev/null;then
    SETSENDEMAIL=1
    logger -t "${0##*/}" "Email Notification - Email Notifications Enabled"
  elif [[ "$OPTION" == "disable" ]] >/dev/null;then
    SETSENDEMAIL=0
    logger -t "${0##*/}" "Email Notification - Email Notifications Disabled"
  else
    echo -e "${RED}Invalid Selection!!! Select enable or disable${NOCOLOR}"
    exit
  fi
  if [ -z "$(cat $CONFIGFILE | grep -e "SENDEMAIL=")" ] >/dev/null;then
    echo -e "SENDEMAIL=" >> "$CONFIGFILE"
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    kill
  else
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    kill
  fi
  exit
fi

# Send email notification if Alert Preferences are configured if System Uptime is more than Boot Delay Timer + Variable SKIPEMAILSYSEMUPTIME seconds.
if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -lt "$SKIPEMAILSYSTEMUPTIME" ]] >/dev/null;then
 wanevent
elif [ -f "$AIPROTECTION_EMAILCONFIG" ] || [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failover Notification" >/tmp/divmail-body
  elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failback Notification" >/tmp/divmail-body
  fi
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
    echo "From: \"$TO_NAME\"<$FROM_ADDRESS>" >>/tmp/divmail-body
  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null;then
    echo "From: \"$MY_NAME\"<$MY_EMAIL>" >>/tmp/divmail-body
  fi
  echo "Date: $(date -R)" >>/tmp/divmail-body
  echo "" >>/tmp/divmail-body
  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failover Notification***" >>/tmp/divmail-body
  elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failback Notification***" >>/tmp/divmail-body
  fi
  echo "----------------------------------------------------------------------------------------" >>/tmp/divmail-body
  if [ ! -z "$(nvram get ddns_hostname_x)" ] >/dev/null;then
    echo "Hostname: $(nvram get ddns_hostname_x)" >>/tmp/divmail-body
  elif [ ! -z "$(nvram get lan_hostname)" ] >/dev/null;then
    echo "Hostname: $(nvram get lan_hostname)" >>/tmp/divmail-body
  fi
  echo "Event Time: $(date | awk '{print $2,$3,$4}')" >>/tmp/divmail-body
  echo "Active ISP: $(curl ipinfo.io | grep -e "org" | awk '{print $3" "$4}' | cut -f 1 -d "," | cut -f 1 -d '"')" >>/tmp/divmail-body
  echo "WAN IPv4 Address: $(nvram get wan_ipaddr)" >>/tmp/divmail-body
  if [ ! -z "$(nvram get ipv6_wan_addr)" ] >/dev/null;then
    echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>/tmp/divmail-body
  fi
  echo "WAN Gateway IP Address: $(nvram get wan_gateway)" >>/tmp/divmail-body
  echo "WAN Interface: $(nvram get wan_gw_ifname)" >>/tmp/divmail-body
  # Check if AdGuard is Running or if AdGuard Local is Enabled
  if [ ! -z "$(pidof AdGuardHome)" ] || { [ -f "/opt/etc/AdGuardHome/.config" ] && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] ;} >/dev/null;then
    echo "DNS: Managed by AdGuard" >>/tmp/divmail-body
  else
    if [ ! -z "$(nvram get wan_dns1_x)" ] >/dev/null;then
      echo "DNS Server 1: $(nvram get wan_dns1_x)" >>/tmp/divmail-body
      elif [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $1}')" ] >/dev/null;then
        echo "DNS Server 1: $(echo $(nvram get wan_dns) | awk '{print $1}')" >>/tmp/divmail-body
      else
        echo "DNS Server 1: N/A" >>/tmp/divmail-body
      fi
    if [ ! -z "$(nvram get wan_dns2_x)" ] >/dev/null;then
      echo "DNS Server 2: $(nvram get wan_dns2_x)" >>/tmp/divmail-body
    elif [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $2}')" ] >/dev/null;then
      echo "DNS Server 2: $(echo $(nvram get wan_dns) | awk '{print $2}')" >>/tmp/divmail-body
    else
      echo "DNS Server 2: N/A" >>/tmp/divmail-body
    fi
  fi
  if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
    echo "QoS Status: Enabled" >>/tmp/divmail-body
    if [[ ! -z "$(nvram get qos_obw)" ]] && [[ ! -z "$(nvram get qos_obw)" ]] >/dev/null;then
      echo "QoS Mode: Manual Settings" >>/tmp/divmail-body
      echo "QoS Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps" >>/tmp/divmail-body
      echo "QoS Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps" >>/tmp/divmail-body
      echo "QoS WAN Packet Overhead: $(nvram get qos_overhead)" >>/tmp/divmail-body
    else
      echo "QoS Mode: Automatic Settings" >>/tmp/divmail-body
    fi
  fi
  echo "----------------------------------------------------------------------------------------" >>/tmp/divmail-body
  echo "" >>/tmp/divmail-body

# Determine whether to AMTM or AIProtection Email Configuration
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
    logger -t "${0##*/}" "Email Notification - AMTM Email Configuration Detected"
    if [ -z "$FROM_ADDRESS" ] || [ -z "$TO_NAME" ] || [ -z "$TO_ADDRESS" ] || [ -z "$USERNAME" ] || [ ! -f "$AMTM_EMAIL_DIR/emailpw.enc" ] || [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] >/dev/null;then
      logger -t "${0##*/}" "Email Notification - AMTM Email Configuration Incomplete"
    else
	/usr/sbin/curl --url $PROTOCOL://$SMTP:$PORT \
		--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
		--upload-file /tmp/divmail-body \
		--ssl-reqd \
		--user "$USERNAME:$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$AMTM_EMAIL_DIR/emailpw.enc" -pass pass:ditbabot,isoi)" $SSL_FLAG

      rm /tmp/divmail-body
    fi

  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null;then
    logger -t "${0##*/}" "Email Notification - AIProtection Alerts Email Configuration Detected"

    if [ ! -z "$SMTP_SERVER" ] && [ ! -z "$SMTP_PORT" ] && [ ! -z "$MY_NAME" ] && [ ! -z "$MY_EMAIL" ] && [ ! -z "$SMTP_AUTH_USER" ] && [ ! -z "$SMTP_AUTH_PASS" ] >/dev/null;then
      cat /tmp/divmail-body | sendmail -w 30 -H "exec openssl s_client -quiet -CAfile $CAFILE -connect $SMTP_SERVER:$SMTP_PORT -tls1_3 -starttls smtp" -f"$MY_EMAIL" -au"$SMTP_AUTH_USER" -ap"$SMTP_AUTH_PASS" "$MY_EMAIL"
      rm /tmp/divmail-body
    else
      logger -t "${0##*/}" "Email Notification - AIProtection Alerts Email Configuration Incomplete"
    fi
  fi
    if [ ! -f "/tmp/divmail-body" ] >/dev/null;then
      logger -t "${0##*/}" "Email Notification - Email Notification Sent"
    elif [ -f "/tmp/divmail-body" ] >/dev/null;then
      logger -t "${0##*/}" "Email Notification - Email Notification Failed"
      rm /tmp/divmail-body
    fi
    wanevent
else
  logger -t "${0##*/}" "Email Notification - Email Notifications are not configured"
  wanevent
fi
}

# Trigger WAN Event
wanevent ()
{
if [ -f "/jffs/scripts/wan-event" ] >/dev/null;then
  sh /jffs/scripts/wan-event
  wanstatus
else
  wanstatus
fi
}

# Log Clean - Feature has been deprecated
logclean ()
{
if [[ "${mode}" == "logclean" ]] >/dev/null;then
LOGPATH="/tmp/wan_event.log"
  echo -e "${YELLOW}Log Cleanup - This mode has been deprecated${NOCOLOR}"
  logger -t "${0##*/}" "Log Cleanup - This mode has been deprecated"
  # Will delete legacy cron job
  if [ ! -z "$(crontab -l | grep -e "setup_wan_failover_logclean")" ] >/dev/null; then
    logger -t "${0##*/}" "Log Cleanup - Removing Cron Job for Log Clean Mode"
    cru d setup_wan_failover_logclean
    logger -t "${0##*/}" "Log Cleanup - Removed Cron Job for Log Clean Mode"
  fi
  # Will remove legacy log file
  if [ -f "$LOGPATH" ] >/dev/null;then
    logger -t "${0##*/}" "Log Cleanup - Removing $LOGPATH"
    rm -f $LOGPATH
    logger -t "${0##*/}" "Log Cleanup - Removed $LOGPATH"
  fi
fi
exit
}
scriptmode
