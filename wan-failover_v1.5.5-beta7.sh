#!/bin/sh

# WAN Failover for ASUS Routers using ASUS Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 07/06/2022
# Version: v1.5.5-beta7

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh"
VERSION="v1.5.5-beta7"
CONFIGFILE="/jffs/configs/wan-failover.conf"
SYSTEMLOG="/tmp/syslog.log"
DNSRESOLVFILE="/tmp/resolv.conf"
LOCKFILE="/var/lock/wan-failover.lock"
WANPREFIXES="wan0 wan1"
WAN0="wan0"
WAN1="wan1"
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
  systemcheck
elif [[ "${mode}" == "manual" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Manual Mode${NOCOLOR}"
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} already running...${NOCOLOR}" && exit ;}
  trap 'rm -f "$LOCKFILE"' EXIT
  systemcheck
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

systemcheck ()
{
# Check System Binaries Path
if [[ "$(echo $PATH | awk -F ":" '{print $1":"$2":"$3":"$4":"}')" != "/sbin:/bin:/usr/sbin:/usr/bin:" ]] >/dev/null;then
  export PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH
fi

# Script Version Logging
logger -t "${0##*/}" "Version - "$VERSION""

# Supported Firmware Versions
FWVERSIONS='
386.5
386.7
'

# Firmware Version Check
for FWVERSION in ${FWVERSIONS};do
  if [[ "$(nvram get 3rd-party)" == "merlin" ]] && [[ "$(nvram get buildno)" == "$FWVERSION" ]] >/dev/null;then
    break
  elif [[ "$(nvram get 3rd-party)" == "merlin" ]] && [ ! -z "$(echo "${FWVERSIONS}" | grep -w "$(nvram get buildno)")" ] >/dev/null;then
    continue
  else
    logger -t "${0##*/}" "Firmware: ***"$(nvram get buildno)" is not supported, issues may occur from running this version***"
  fi
done
setvariables
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
    read -p "Configure WAN0 Target IP Address - Will be routed via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname): " ip
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null;then
      for i in 1 2 3 4;do
        if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null;then
          echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
          break 1
        elif [[ "$(nvram get wan0_gateway)" == "$ip" ]] >/dev/null;then
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
    read -p "Configure WAN1 Target IP Address - Will be routed via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname): " ip
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null;then
      for i in 1 2 3 4;do
        if [ $(echo "$ip" | cut -d. -f$i) -gt "255" ] >/dev/null;then
          echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
          break 1
        elif [[ "$ip" == "$SETWAN0TARGET" ]] >/dev/null;then
          echo -e "${RED}***IP Address already assigned to WAN0***${NOCOLOR}"
          break 1
        elif [[ "$(nvram get wan1_gateway)" == "$ip" ]] >/dev/null;then
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
  if [[ "$(nvram get wan0_enable)" == "1" ]] >/dev/null;then
    echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface "$WAN0"${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarting interface "$WAN0""
    nvram set wan0_state_t=0
    service "restart_wan_if 0" &
    echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface "$WAN0"${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarted interface "$WAN0""
  fi

  if [[ "$(nvram get wan1_enable)" == "1" ]] >/dev/null;then
    echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface "$WAN1"${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarting interface "$WAN1""
    nvram set wan1_state_t=0
    service "restart_wan_if 1" &
    echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface "$WAN1"${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarted interface "$WAN1""
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
if [[ "$VERSION" != "$REMOTEVERSION" ]] >/dev/null;then
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
if [ -z "$(cru l | grep -e "$0")" ] >/dev/null;then
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

# Check Configuration File for Missing Settings and Set Default if Missing
if [ -z "$(awk -F "=" '/WAN0TARGET/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0TARGET=8.8.8.8" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1TARGET/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0TARGET=8.8.4.4" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/PINGCOUNT/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "PINGCOUNT=3" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/PINGTIMEOUT/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "PINGTIMEOUT=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WANDISABLEDSLEEPTIMER/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WANDISABLEDSLEEPTIMER=10" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_IBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0_QOS_IBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_IBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1_QOS_IBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_OBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0_QOS_OBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_OBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1_QOS_OBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_OVERHEAD/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_OVERHEAD/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_ATM/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_ATM/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/PACKETLOSSLOGGING/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "PACKETLOSSLOGGING=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/SENDEMAIL/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "SENDEMAIL=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/SKIPEMAILSYSTEMUPTIME/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "SKIPEMAILSYSTEMUPTIME=180" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/BOOTDELAYTIMER/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "BOOTDELAYTIMER=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/OVPNSPLITTUNNEL/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "OVPNSPLITTUNNEL=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0ROUTETABLE/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0ROUTETABLE=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1ROUTETABLE/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1ROUTETABLE=200" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0TARGETRULEPRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1TARGETRULEPRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0SUFFIX/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0SUFFIX=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1SUFFIX/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1SUFFIX=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0MARK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0MARK=0x80000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1MARK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1MARK=0x90000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0MASK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN0MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1MASK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "WAN1MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/LBRULEPRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "LBRULEPRIORITY=150" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/FROMWAN0PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "FROMWAN0PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/TOWAN0PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "TOWAN0PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/FROMWAN1PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "FROMWAN1PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/TOWAN1PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "TOWAN1PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/OVPNWAN0PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "OVPNWAN0PRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/OVPNWAN1PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  echo -e "OVPNWAN1PRIORITY=200" >> $CONFIGFILE
fi

. $CONFIGFILE

if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null;then
OVPNCONFIGFILES='
/etc/openvpn/client1/config.ovpn
/etc/openvpn/client2/config.ovpn
/etc/openvpn/client3/config.ovpn
/etc/openvpn/client4/config.ovpn
/etc/openvpn/client5/config.ovpn
'

  # Create Array for OVPN Remote Addresses
  REMOTEADDRESSES=""  
  for OVPNCONFIGFILE in ${OVPNCONFIGFILES};do
    if [ -f "${OVPNCONFIGFILE}" ] >/dev/null;then
      REMOTEADDRESS="$(awk -F " " '/remote/ {print $2}' "$OVPNCONFIGFILE")"
      REMOTEADDRESSES="${REMOTEADDRESSES} ${REMOTEADDRESS}"
    fi
  done
fi

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
if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null;then
  logger -t "${0##*/}" "Dual WAN - Disabled"
  wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  logger -t "${0##*/}" "Dual WAN - ASUS Factory Watchdog: Enabled"
  wandisabled
# Check if both WAN Interfaces are Disabled
elif [[ "$(nvram get wan0_enable)" == "0" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null;then
  wandisabled
# Check if WAN Interfaces are Enabled and Connected
elif [[ "$(nvram get wan0_enable)" == "1" ]] || [[ "$(nvram get wan1_enable)" == "1" ]] >/dev/null;then
  for WANPREFIX in ${WANPREFIXES};do
      # Set WAN Interface Parameters
      if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null;then
        TARGET="$WAN0TARGET"
        TABLE="$WAN0ROUTETABLE"
        PRIORITY="$WAN0TARGETRULEPRIORITY"
        WANSUFFIX="$WAN0SUFFIX"
      elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null;then
        TARGET="$WAN1TARGET"
        TABLE="$WAN1ROUTETABLE"
        PRIORITY="$WAN1TARGETRULEPRIORITY"
        WANSUFFIX="$WAN1SUFFIX"
      fi
    # Check if WAN Interfaces are Disabled
    if [[ "$(nvram get "${WANPREFIX}"_enable)" == "0" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Status - ${WANPREFIX} disabled"
      STATUS=DISABLED
    # Check if WAN is Enabled
    elif [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Status - ${WANPREFIX} enabled"
      # Check WAN Connection
      if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] || [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
        if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - "${WANPREFIX}": Cable Unplugged"
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - "${WANPREFIX}": Disconnected"
        fi
        logger -t "${0##*/}" "WAN Status - Restarting "${WANPREFIX}""
        service "restart_wan_if "$WANSUFFIX"" & 
        sleep 1
        # Set Timeout for WAN interface to restart to a max of 30 seconds and while WAN Interface is State 6
        RESTARTTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
        while [[ "$(nvram get "${WANPREFIX}"_state_t)" == "6" ]] && [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -lt "$RESTARTTIMEOUT" ]] >/dev/null;do
          sleep 1
        done
        if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] || [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
          if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
            logger -t "${0##*/}" "WAN Status - "${WANPREFIX}": Cable Unplugged"
          elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
            logger -t "${0##*/}" "WAN Status - "${WANPREFIX}": Disconnected"
          fi
          STATUS=DISCONNECTED
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Restarted "${WANPREFIX}""
          break
        else
          wanstatus
        fi
      fi
      # Check if WAN Gateway IP or IP Address are 0.0.0.0
      if { [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
        logger -t "${0##*/}" "WAN Status - ${WANPREFIX} is disconnected.  IP Address: "$(nvram get ${WANPREFIX}_ipaddr)" Gateway: "$(nvram get ${WANPREFIX}_gateway)""
        STATUS=DISCONNECTED
      fi
      # Check WAN IP Address Target Route
      if [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] && [ ! -z "$(ip route list default table main | grep -e "$TARGET")" ] && [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Default route already exists via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
      fi
      # Check WAN Routing Table for Default Routes
      if [ -z "$(ip route list default table "$TABLE" | grep -e "$(nvram get ${WANPREFIX}_gw_ifname)")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
        ip route add default via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname) table "$TABLE"
        logger -t "${0##*/}" "WAN Status - Added default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
      fi
      # Check WAN IP Rule
      if [ -z "$(ip rule list from all iif lo to $TARGET lookup ${TABLE} priority "$PRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule for "$TARGET""
        ip rule add from all iif lo to $TARGET table ${TABLE} priority "$PRIORITY"
        logger -t "${0##*/}" "WAN Status - Added IP Rule for "$TARGET""
      fi
      # Check WAN Packet Loss
      PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_gw_ifname) $TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
      if [[ "$PACKETLOSS" == "0%" ]] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss"
        STATUS="CONNECTED"
        if [[ "$(nvram get ${WANPREFIX}_state_t)" != "2" ]] >/dev/null;then
          nvram set ${WANPREFIX}_state_t=2
        fi
      elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] && [[ "$PACKETLOSS" == "100%" ]] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss ***Verify $TARGET is a valid server for ICMP Echo Requests***"
        STATUS="DISCONNECTED"
      else
        logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss"
        STATUS="DISCONNECTED"
      fi
    fi
    # Set WAN Status
    if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null;then
      WAN0STATUS="$STATUS"
    elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null;then
      WAN1STATUS="$STATUS"
    fi

    # Create WAN NAT Rules
    # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
    if [[ "$(nvram get misc_http_x)" == "1" ]] >/dev/null;then
      # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
      if [ -z "$(iptables -t nat -L PREROUTING -v -n | awk '{ if( /VSERVER/ && /'$(nvram get ${WANPREFIX}_ipaddr)'/ ) print}' )" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - ${WANPREFIX} creating VSERVER Rule for $(nvram get ${WANPREFIX}_ipaddr)"
        iptables -t nat -A PREROUTING -d $(nvram get ${WANPREFIX}_ipaddr) -j VSERVER
      fi
    fi
    # Create UPNP Rules if Enabled
    if [[ "$(nvram get ${WANPREFIX}_upnp_enable)" == "1" ]] >/dev/null;then
      if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /PUPNP/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ ) print}' )" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - ${WANPREFIX} creating UPNP Rule for $(nvram get ${WANPREFIX}_gw_ifname)"
        iptables -t nat -A POSTROUTING -o $(nvram get ${WANPREFIX}_gw_ifname) -j PUPNP
      fi
    fi
    # Create MASQUERADE Rules if NAT is Enabled
    if [[ "$(nvram get ${WANPREFIX}_nat_x)" == "1" ]] >/dev/null;then
      if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /MASQUERADE/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /'$(nvram get ${WANPREFIX}_ipaddr)'/ ) print}')" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding iptables MASQUERADE rule for excluding $(nvram get ${WANPREFIX}_ipaddr) via $(nvram get ${WANPREFIX}_gw_ifname)"
        iptables -t nat -A POSTROUTING -o $(nvram get ${WANPREFIX}_gw_ifname) ! -s $(nvram get ${WANPREFIX}_ipaddr) -j MASQUERADE
      fi
    fi
  done
fi

# Check Rules for Load Balance Mode
if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
  # Check IPTables Mangle Balance Rule for PREROUTING Table
  if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$(nvram get lan_ifname)'/ && /state/ && /NEW/ ) print}')" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - Adding IPTables MANGLE Balance Rule"
    iptables -t mangle -A PREROUTING -i $(nvram get lan_ifname) -m state --state NEW -j balance
  fi

for WANPREFIX in ${WANPREFIXES};do
  # Set WAN Interface Parameters
  if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null;then
    TABLE="$WAN0ROUTETABLE"
    MARK="$WAN0MARK"
    DELETEMARK="$WAN1MARK"
    MASK="$WAN0MASK"
    FROMWANPRIORITY="$FROMWAN0PRIORITY"
    TOWANPRIORITY="$TOWAN0PRIORITY"
  elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null;then
    TABLE="$WAN1ROUTETABLE"
    MARK="$WAN1MARK"
    DELETEMARK="$WAN0MARK"
    MASK="$WAN1MASK"
    FROMWANPRIORITY="$FROMWAN1PRIORITY"
    TOWANPRIORITY="$TOWAN1PRIORITY"
  fi

  # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
  if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get lan_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - Adding IPTables MANGLE match rule for $(nvram get lan_ifname) marked with "$MARK""
    iptables -t mangle -A PREROUTING -i $(nvram get lan_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK"
  fi
  # Check IPTables Mangle Match Rule for WAN for OUTPUT Table
  if [ -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - Adding IPTables MANGLE match rule for $(nvram get ${WANPREFIX}_gw_ifname) marked with "$MARK""
    iptables -t mangle -A OUTPUT -o $(nvram get ${WANPREFIX}_gw_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK"
  fi
  if [ ! -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /connmark match/ && /'$DELETEMARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - Deleting IPTables MANGLE match rule for $(nvram get ${WANPREFIX}_gw_ifname) marked with "$DELETEMARK""
    iptables -t mangle -D OUTPUT -o $(nvram get ${WANPREFIX}_gw_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK"
  fi
  # Check IPTables Mangle Set XMark Rule for WAN for PREROUTING Table
  if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /state/ && /NEW/ && /CONNMARK/ && /xset/ && /'$MARK'/ ) print}')" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - Adding IPTables MANGLE set xmark rule for $(nvram get ${WANPREFIX}_gw_ifname)"
    iptables -t mangle -A PREROUTING -i $(nvram get ${WANPREFIX}_gw_ifname) -m state --state NEW -j CONNMARK --set-xmark "$MARK"/"$MASK"
  fi
  # Create WAN IP Address Rule
  if [[ "$(nvram get ${WANPREFIX}_ipaddr)" != "0.0.0.0" ]] && [ -z "$(ip rule list from $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - Adding IP Rule for $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE}"
    ip rule add from $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE} priority "$FROMWANPRIORITY"
  fi
  # Create WAN Gateway IP Rule
  if [[ "$(nvram get ${WANPREFIX}_gateway)" != "0.0.0.0" ]] && [ -z "$(ip rule list from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - Adding IP Rule from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE}"
    ip rule add from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE} priority "$TOWANPRIORITY"
  fi
  # Create WAN DNS IP Rules
  if [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "0" ]] >/dev/null;then
    if [ ! -z "$(nvram get ${WANPREFIX}_dns1_x)" ] >/dev/null;then
      if [ -z "$(ip rule list from $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule for $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE}"
        ip rule add from $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$FROMWANPRIORITY"
      fi
      if [ -z "$(ip rule list from all to $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule from all to $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE}"
        ip rule add from all to $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$TOWANPRIORITY"
      fi
    fi
    if [ ! -z "$(nvram get ${WANPREFIX}_dns2_x)" ] >/dev/null;then
      if [ -z "$(ip rule list from $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule for $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE}"
        ip rule add from $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$FROMWANPRIORITY"
      fi
      if [ -z "$(ip rule list from all to $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule from all to $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE}"
        ip rule add from all to $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$TOWANPRIORITY"
      fi
    fi
  elif [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "1" ]] >/dev/null;then
    if [ ! -z "$(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}')" ] >/dev/null;then
      if [ -z "$(ip rule list from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}') lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule for $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}') lookup ${TABLE}"
        ip rule add from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}') lookup ${TABLE} priority "$FROMWANPRIORITY"
      fi
    fi
    if [ ! -z "$(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}')" ] >/dev/null;then
      if [ -z "$(ip rule list from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}') lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule for $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}') lookup ${TABLE}"
        ip rule add from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}') lookup ${TABLE} priority "$FROMWANPRIORITY"
      fi
    fi
  fi
done

  # If OVPN Split Tunneling is Disabled in Configuration, create rules to bind OpenVPN Clients to a single interface
  if [[ "$OVPNSPLITTUNNEL" == "1" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - OpenVPN Split Tunneling is Enabled"
  elif [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Status - OpenVPN Split Tunneling is Disabled"
    # Create IP Rules for OVPN Remote Addresses
    for REMOTEADDRESS in ${REMOTEADDRESSES};do
      REMOTEIP=$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')
      if [ -z "$(ip rule list from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY""
        ip rule add from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY"
      fi
      if [ -z "$(ip rule list from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "WAN Status - Adding IP Rule from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY""
        ip rule add from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY"
      fi
    done
  fi
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
if [[ "$(nvram get wan0_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get wan0_primary)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] >/dev/null;then
  wan0failovermonitor
elif [[ "$(nvram get wan0_primary)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null;then
  wandisabled
else
  wanstatus
fi
}

# WAN1 Active
wan1active ()
{
  logger -t "${0##*/}" "WAN1 Active - Verifying WAN1"
if [[ "$(nvram get wan1_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(nvram get wan0_enable)" == "1" ]] >/dev/null;then
  wan0failbackmonitor
elif [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(nvram get wan0_enable)" == "0" ]] >/dev/null;then
  wandisabled
else
  wanstatus
fi
}

# Load Balance Monitor
lbmonitor ()
{
if [[ "$WAN0STATUS" == "CONNECTED" ]] >/dev/null;then
  logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
elif [[ "$WAN0STATUS" != "CONNECTED" ]] >/dev/null;then
  logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
fi
if [[ "$WAN1STATUS" == "CONNECTED" ]] >/dev/null;then
  logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
elif [[ "$WAN1STATUS" != "CONNECTED" ]] >/dev/null;then
  logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
fi
while { [[ "$(nvram get wans_mode)" == "lb" ]] && [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
&& { [[ "$(nvram get wan0_gateway)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] ;} \
&& { [[ "$(nvram get wan1_gateway)" == "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan1_gw_ifname)" == "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] ;} \
|| { [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] ;} >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  WAN1PACKETLOSS="$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  if [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] && [[ "$(nvram get wan0_state_t)" == "2" ]] \
  || [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] && [[ "$(nvram get wan1_state_t)" == "2" ]] >/dev/null;then
    break
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

      # Create fwmark IP Rules
      if [ -z "$(ip rule list from all fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE" priority "$LBRULEPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule for fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE""
        ip rule add from all fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE" priority "$LBRULEPRIORITY"
      fi
      if [ ! -z "$(ip rule list from all fwmark "$WAN0MARK"/"$WAN0MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Removing Blackhole IP Rule for fwmark "$WAN0MARK"/"$WAN0MASK""
        ip rule del blackhole from all fwmark "$WAN0MARK"/"$WAN0MASK" priority "$LBRULEPRIORITY"
      fi
      if [ -z "$(ip rule list from all fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE" priority "$LBRULEPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule for fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE""
        ip rule add from all fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE" priority "$LBRULEPRIORITY"
      fi
      if [ ! -z "$(ip rule list from all fwmark "$WAN1MARK"/"$WAN1MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Removing Blackhole IP Rule for fwmark "$WAN1MARK"/"$WAN1MASK""
        ip rule del blackhole from all fwmark "$WAN1MARK"/"$WAN1MASK" priority "$LBRULEPRIORITY"
      fi

      # If OVPN Split Tunneling is Disabled in Configuration, create rules to bind OpenVPN Clients to a single interface
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null;then
        # Create IP Rules for OVPN Remote Addresses
        for REMOTEADDRESS in ${REMOTEADDRESSES};do
          REMOTEIP=$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')
          if [ -z "$(ip rule list from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY""
            ip rule add from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY"
          fi
          if [ -z "$(ip rule list from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY""
            ip rule add from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY"
          fi
        done
      fi
      logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
      logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
      WAN0STATUS=CONNECTED
      WAN1STATUS=CONNECTED
      sendemail || return
      continue
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -t "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      ip route del default
      ip route add default scope global \
      nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')

      # Create fwmark IP Rules
      if [ ! -z "$(ip rule list from all fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE" priority "$LBRULEPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Removing IP Rule for fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE""
        ip rule del from all fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE" priority "$LBRULEPRIORITY"
      fi
      if [ -z "$(ip rule list from all fwmark "$WAN0MARK"/"$WAN0MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding Blackhole IP Rule for fwmark "$WAN0MARK"/"$WAN0MASK""
        ip rule add blackhole from all fwmark "$WAN0MARK"/"$WAN0MASK" priority "$LBRULEPRIORITY"
      fi

      # Create WAN1 IP Address Rule
      if [ -z "$(ip rule list from $(nvram get wan1_ipaddr) lookup "$WAN1ROUTETABLE" priority "$FROMWAN1PRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule for $(nvram get wan1_ipaddr) lookup "$WAN1ROUTETABLE""
        ip rule add from $(nvram get wan1_ipaddr) lookup "$WAN1ROUTETABLE" priority "$FROMWAN1PRIORITY"
      fi

      # Create WAN1 Gateway IP Rule
      if [ -z "$(ip rule list from all to $(nvram get wan1_gateway) lookup "$WAN1ROUTETABLE" priority "$TOWANPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule from all to $(nvram get wan1_gateway) lookup "$WAN1ROUTETABLE""
        ip rule add from all to $(nvram get wan1_gateway) lookup "$WAN1ROUTETABLE" priority "$TOWANPRIORITY"
      fi

      # If OVPN Split Tunneling is Disabled in Configuration, create rules to bind OpenVPN Clients to a single interface
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null;then
        # Create IP Rules for OVPN Remote Addresses
        for REMOTEADDRESS in ${REMOTEADDRESSES};do
          REMOTEIP=$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')
          if [ -z "$(ip rule list from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY""
            ip rule add from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY"
          fi
          if [ ! -z "$(ip rule list from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Load Balance Monitor - Removing IP Rule from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY""
            ip rule del from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY"
          fi
        done
      fi
      logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
      WAN0STATUS=DISCONNECTED
      WAN1STATUS=CONNECTED
      sendemail || return
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] ;} >/dev/null;then
    if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -t "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route del default
      ip route add default scope global \
      nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')

      # Create fwmark IP Rules
      if [ ! -z "$(ip rule list from all fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE" priority "$LBRULEPRIORITY")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Removing IP Rule for fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE""
        ip rule del from all fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE" priority "$LBRULEPRIORITY"
      fi
      if [ -z "$(ip rule list from all fwmark "$WAN1MARK"/"$WAN1MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding Blackhole IP Rule for fwmark "$WAN1MARK"/"$WAN1MASK""
        ip rule add blackhole from all fwmark "$WAN1MARK"/"$WAN1MASK" priority "$LBRULEPRIORITY"
      fi

      # If OVPN Split Tunneling is Disabled in Configuration, create rules to bind OpenVPN Clients to a single interface
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null;then
        # Create IP Rules for OVPN Remote Addresses
        for REMOTEADDRESS in ${REMOTEADDRESSES};do
          REMOTEIP=$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')
          if [ -z "$(ip rule list from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Load Balance Monitor - Adding IP Rule from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY""
            ip rule add from all to $REMOTEIP lookup "$WAN0ROUTETABLE" priority "$OVPNWAN0PRIORITY"
          fi
          if [ ! -z "$(ip rule list from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY")" ] >/dev/null;then
            logger -t "${0##*/}" "Load Balance Monitor - Removing IP Rule from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY""
            ip rule del from all to $REMOTEIP lookup "$WAN1ROUTETABLE" priority "$OVPNWAN1PRIORITY"
          fi
        done
      fi
      logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
      WAN0STATUS=CONNECTED
      WAN1STATUS=DISCONNECTED
      sendemail || return
      continue
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] ;} >/dev/null;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -t "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      logger -t "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route del default
      if [ ! -z "$(ip rule list from all fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Removing IP Rule for fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE""
        ip rule del from all fwmark "$WAN0MARK"/"$WAN0MASK" lookup "$WAN0ROUTETABLE" priority "$LBRULEPRIORITY"
      fi
      if [ -z "$(ip rule list from all fwmark "$WAN0MARK"/"$WAN0MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding Blackhole IP Rule for fwmark "$WAN0MARK"/"$WAN0MASK""
        ip rule add blackhole from all fwmark "$WAN0MARK"/"$WAN0MASK" priority "$LBRULEPRIORITY"
      fi
      if [ ! -z "$(ip rule list from all fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Removing IP Rule for fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE""
        ip rule del from all fwmark "$WAN1MARK"/"$WAN1MASK" lookup "$WAN1ROUTETABLE" priority "$LBRULEPRIORITY"
      fi
      if [ -z "$(ip rule list from all fwmark "$WAN1MARK"/"$WAN1MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -t "${0##*/}" "Load Balance Monitor - Adding Blackhole IP Rule for fwmark "$WAN1MARK"/"$WAN1MASK""
        ip rule add blackhole from all fwmark "$WAN1MARK"/"$WAN1MASK" priority "$LBRULEPRIORITY"
      fi
      logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
      logger -t "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] || [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null;then
    if [ -z "$PACKETLOSSLOGGING" ] || [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null;then
      logger -t "${0##*/}" "Load Balance Monitor - Packet Loss Detected - WAN0 Packet Loss: "$WAN0PACKETLOSS""
      logger -t "${0##*/}" "Load Balance Monitor - Packet Loss Detected - WAN1 Packet Loss: "$WAN1PACKETLOSS""
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
  logger -t "${0##*/}" "WAN0 Failover Monitor - Monitoring "$WAN0" via $WAN0TARGET for Failure"
while { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} && [[ "$(nvram get wan0_primary)" == "1" ]] \
&& [ ! -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] \
&& { [[ "$(nvram get wan0_gateway)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] ;} >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
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
  logger -t "${0##*/}" "WAN0 Failback Monitor - Monitoring "$WAN0" via $WAN0TARGET for Failback"
while { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} && [[ "$(nvram get wan1_primary)" == "1" ]] \
&& [ ! -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] \
&& { [[ "$(nvram get wan0_gateway)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] ;} >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
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
elif [[ "$(nvram get wan0_enable)" == "0" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" are disabled"
elif [[ "$(nvram get wan0_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" is disabled"
elif [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - "$WAN1" is disabled"
fi
  logger -t "${0##*/}" "WAN Failover Disabled - WAN Failover is currently disabled.  ***Review Logs***"
while \
  # Return to WAN Status if both interfaces are Enabled and Connected
  if  { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan1_state_t)" == "2" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" are enabled and connected"
    break
  # Return to WAN Status if both interfaces are Enabled and have Real IP Addresses
  elif  { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get wan0_realip_state)" == "2" ]] && [[ "$(nvram get wan1_realip_state)" == "2" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" are enabled and connected"
    break
  # Return to WAN Status if only WAN0 is Enabled and Connected but is not Primary WAN
  elif  { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] \
        && [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if only WAN1 is Enabled and Connected but is not Primary WAN
  elif  { [[ "$(nvram get wan0_enable)" == "0" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] \
        && [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan0_primary)" == "1" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN1" is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 is Connected and is not Primary WAN.
  elif  { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] \
        && [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan0_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 is Connected and is not Primary WAN.
  elif  { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] \
        && [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan1_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN1" is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 has a Real IP Address and is not Primary WAN.
  elif  { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get wan0_realip_state)" == "2" ]] && [[ "$(nvram get wan1_realip_state)" != "2" ]] && [[ "$(nvram get wan0_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN1" has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 has a Real IP Address and is not Primary WAN.
  elif  { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get wan0_realip_state)" != "2" ]] && [[ "$(nvram get wan1_realip_state)" == "2" ]] && [[ "$(nvram get wan1_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN1" has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are pinging both Target IP Addresses.
  elif  { [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" have 0% packet loss"
    break
  # Return to WAN Status if WAN0 is pinging the Target IP Address and WAN1 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && { [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN1 is pinging the Target IP Address and WAN0 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && { [[ "$(nvram get wan0_primary)" == "1" ]] && [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
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
if [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null;then
  ACTIVEWAN=wan1
  INACTIVEWAN=wan0
  echo Switching to $ACTIVEWAN
elif [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;then
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
    if [[ "$(nvram get "$ACTIVEWAN"_ifname)" != "$(nvram get "$ACTIVEWAN"_gw_ifname)" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - WAN Interface: $(nvram get "$ACTIVEWAN"_ifname)"
    fi
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
      if [[ "$ACTIVEWAN" == "$WAN0" ]] >/dev/null;then
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
      elif [[ "$ACTIVEWAN" == "$WAN1" ]] >/dev/null;then
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
TMPEMAILFILE=/tmp/wan-failover-mail
if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
  . "$AMTM_EMAILCONFIG"
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
  if [ -z "$(awk -F "=" '/SENDEMAIL/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
    echo -e "SENDEMAIL=" >> $CONFIGFILE
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    kill
  else
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    kill
  fi
  exit
fi

# Send email notification if Alert Preferences are configured if System Uptime is more than Boot Delay Timer + Variable SKIPEMAILSYSEMUPTIME seconds.
if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -lt "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))" ]] >/dev/null;then
 wanevent
elif [ -f "$AIPROTECTION_EMAILCONFIG" ] || [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
  # Check for old mail temp file and delete it or create file and set permissions
  if [ -f "$TMPEMAILFILE" ] >/dev/null;then
    rm "$TMPEMAILFILE"
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  elif [ ! -f "$TMPEMAILFILE" ] >/dev/null;then
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  fi

  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
    echo "Subject: WAN Load Balancing Notification" >"$TMPEMAILFILE"
  elif [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failover Notification" >"$TMPEMAILFILE"
  elif [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failback Notification" >"$TMPEMAILFILE"
  fi
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
    echo "From: \"$TO_NAME\"<$FROM_ADDRESS>" >>"$TMPEMAILFILE"
  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null;then
    echo "From: \"$MY_NAME\"<$MY_EMAIL>" >>"$TMPEMAILFILE"
  fi
  echo "Date: $(date -R)" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
    echo "***WAN Load Balancing Notification***" >>"$TMPEMAILFILE"
  elif [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failover Notification***" >>"$TMPEMAILFILE"
  elif [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failback Notification***" >>"$TMPEMAILFILE"
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"
  if [ ! -z "$(nvram get ddns_hostname_x)" ] >/dev/null;then
    echo "Hostname: $(nvram get ddns_hostname_x)" >>"$TMPEMAILFILE"
  elif [ ! -z "$(nvram get lan_hostname)" ] >/dev/null;then
    echo "Hostname: $(nvram get lan_hostname)" >>"$TMPEMAILFILE"
  fi
  echo "Event Time: $(date | awk '{print $2,$3,$4}')" >>"$TMPEMAILFILE"
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
    echo "WAN0 IPv4 Address: $(nvram get wan0_ipaddr)" >>"$TMPEMAILFILE"
    echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    echo "WAN1 IPv4 Address: $(nvram get wan1_ipaddr)" >>"$TMPEMAILFILE"
    echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"
    if [ ! -z "$(nvram get ipv6_wan_addr)" ] >/dev/null;then
      echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>"$TMPEMAILFILE"
    fi

  elif [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
    echo "Active ISP: $(curl ipinfo.io | grep -e "org" | awk '{print $3" "$4}' | cut -f 1 -d "," | cut -f 1 -d '"')" >>"$TMPEMAILFILE"
    echo "WAN IPv4 Address: $(nvram get wan_ipaddr)" >>"$TMPEMAILFILE"
    if [ ! -z "$(nvram get ipv6_wan_addr)" ] >/dev/null;then
      echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>"$TMPEMAILFILE"
    fi
    echo "WAN Gateway IP Address: $(nvram get wan_gateway)" >>"$TMPEMAILFILE"
    echo "WAN Interface: $(nvram get wan_gw_ifname)" >>"$TMPEMAILFILE"
    # Check if AdGuard is Running or if AdGuard Local is Enabled
    if [ ! -z "$(pidof AdGuardHome)" ] || { [ -f "/opt/etc/AdGuardHome/.config" ] && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] ;} >/dev/null;then
      echo "DNS: Managed by AdGuard" >>"$TMPEMAILFILE"
    else
      if [ ! -z "$(nvram get wan_dns1_x)" ] >/dev/null;then
        echo "DNS Server 1: $(nvram get wan_dns1_x)" >>"$TMPEMAILFILE"
      elif [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $1}')" ] >/dev/null;then
        echo "DNS Server 1: $(echo $(nvram get wan_dns) | awk '{print $1}')" >>"$TMPEMAILFILE"
      else
        echo "DNS Server 1: N/A" >>"$TMPEMAILFILE"
      fi
      if [ ! -z "$(nvram get wan_dns2_x)" ] >/dev/null;then
        echo "DNS Server 2: $(nvram get wan_dns2_x)" >>"$TMPEMAILFILE"
      elif [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $2}')" ] >/dev/null;then
        echo "DNS Server 2: $(echo $(nvram get wan_dns) | awk '{print $2}')" >>"$TMPEMAILFILE"
      else
        echo "DNS Server 2: N/A" >>"$TMPEMAILFILE"
      fi
    fi
    if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
      echo "QoS Status: Enabled" >>"$TMPEMAILFILE"
      if [[ ! -z "$(nvram get qos_obw)" ]] && [[ ! -z "$(nvram get qos_obw)" ]] >/dev/null;then
        echo "QoS Mode: Manual Settings" >>"$TMPEMAILFILE"
        echo "QoS Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps" >>"$TMPEMAILFILE"
        echo "QoS Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps" >>"$TMPEMAILFILE"
        echo "QoS WAN Packet Overhead: $(nvram get qos_overhead)" >>"$TMPEMAILFILE"
      else
        echo "QoS Mode: Automatic Settings" >>"$TMPEMAILFILE"
      fi
    fi
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

# Determine whether to AMTM or AIProtection Email Configuration
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
    logger -t "${0##*/}" "Email Notification - AMTM Email Configuration Detected"
    if [ -z "$FROM_ADDRESS" ] || [ -z "$TO_NAME" ] || [ -z "$TO_ADDRESS" ] || [ -z "$USERNAME" ] || [ ! -f "$AMTM_EMAIL_DIR/emailpw.enc" ] || [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] >/dev/null;then
      logger -t "${0##*/}" "Email Notification - AMTM Email Configuration Incomplete"
    else
	/usr/sbin/curl --url $PROTOCOL://$SMTP:$PORT \
		--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
		--upload-file "$TMPEMAILFILE" \
		--ssl-reqd \
		--user "$USERNAME:$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$AMTM_EMAIL_DIR/emailpw.enc" -pass pass:ditbabot,isoi)" $SSL_FLAG

      rm "$TMPEMAILFILE"
    fi

  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null;then
    logger -t "${0##*/}" "Email Notification - AIProtection Alerts Email Configuration Detected"

    if [ ! -z "$SMTP_SERVER" ] && [ ! -z "$SMTP_PORT" ] && [ ! -z "$MY_NAME" ] && [ ! -z "$MY_EMAIL" ] && [ ! -z "$SMTP_AUTH_USER" ] && [ ! -z "$SMTP_AUTH_PASS" ] >/dev/null;then
      cat "$TMPEMAILFILE" | sendmail -w 30 -H "exec openssl s_client -quiet -CAfile $CAFILE -connect $SMTP_SERVER:$SMTP_PORT -tls1_3 -starttls smtp" -f"$MY_EMAIL" -au"$SMTP_AUTH_USER" -ap"$SMTP_AUTH_PASS" "$MY_EMAIL"
      rm "$TMPEMAILFILE"
    else
      logger -t "${0##*/}" "Email Notification - AIProtection Alerts Email Configuration Incomplete"
    fi
  fi
    if [ ! -f "$TMPEMAILFILE" ] >/dev/null;then
      logger -t "${0##*/}" "Email Notification - Email Notification Sent"
    elif [ -f "$TMPEMAILFILE" ] >/dev/null;then
      logger -t "${0##*/}" "Email Notification - Email Notification Failed"
      rm "$TMPEMAILFILE"
    fi
    if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
      lbmonitor
    elif  [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
      wanevent
    fi
elif [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
  logger -t "${0##*/}" "Email Notification - Email Notifications are not configured"
  lbmonitor
elif  [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
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
