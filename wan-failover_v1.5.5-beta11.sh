#!/bin/sh

# WAN Failover for ASUS Routers using ASUS Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 07/12/2022
# Version: v1.5.5

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh"
VERSION="v1.5.5"
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
  echo -e "${YELLOW}$0 cron${WHITE} - This will creates or deletes the Cron Job necessary for the script to run.${NOCOLOR}"
  echo -e "${YELLOW}$0 switchwan${WHITE} - This will manually switch Primary WAN.  ***Failover Mode Only***${NOCOLOR}"
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
  echo -e "${BLUE}${0##*/} - Install Mode${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  install
elif [[ "${mode}" == "config" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Configuration Mode${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  install
elif [[ "${mode}" == "run" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Run Mode${NOCOLOR}"d
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} already running...${NOCOLOR}" && exit ;}
  logger -p 6 -t "${0##*/}" "Debug - Locked File: "$LOCKFILE""
  trap 'rm -f "$LOCKFILE" && kill -9 "$$"' EXIT HUP INT QUIT TERM
  logger -p 6 -t "${0##*/}" "Debug - Trap set to remove "$LOCKFILE" on exit"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  systemcheck
elif [[ "${mode}" == "manual" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Manual Mode${NOCOLOR}"
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || { echo -e "${RED}${0##*/} already running...${NOCOLOR}" && exit ;}
  logger -p 6 -t "${0##*/}" "Debug - Locked File: "$LOCKFILE""
  trap 'rm -f "$LOCKFILE" && kill -9 "$$"' EXIT HUP INT QUIT TERM
  logger -p 6 -t "${0##*/}" "Debug - Trap set to remove "$LOCKFILE" on exit"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  systemcheck
elif [[ "${mode}" == "restart" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  killscript
elif [[ "${mode}" == "monitor" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Monitor Mode${NOCOLOR}"
  trap 'exit' EXIT HUP INT QUIT TERM
  logger -p 6 -t "${0##*/}" "Debug - Trap set to kill background process on exit"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  monitor
elif [[ "${mode}" == "kill" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Kill Mode${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  killscript
elif [[ "${mode}" == "uninstall" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Uninstall Mode${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  uninstall
elif [[ "${mode}" == "cron" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Cron Job Mode${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  cronjob
elif [[ "${mode}" == "switchwan" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Switch WAN Mode${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  if [[ "$(nvram get wans_mode)" != "fo" ]] >/dev/null;then
    echo -e "${RED}***Switch WAN Mode is only available in Failover Mode***${NOCOLOR}"
    exit
  elif [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
    setvariables
  fi
elif [[ "${mode}" == "update" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Update Mode${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  update
elif [[ "${mode}" == "email" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Script Mode: "${mode}""
  if [ "$arg2" == "0" ] >/dev/null;then
    echo -e "${RED}Select (enable) or (disable)${NOCOLOR}"
    exit
  elif [ "$arg2" == "enable" ] || [ "$arg2" == "disable" ] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - Email Configuration Changing to $arg2"
    OPTION=$arg2
    sendemail
  fi
fi
if [[ ! -f "$CONFIGFILE" ]] >/dev/null;then
  echo -e "${RED}${0##*/} - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  logger -p 2 -t "${0##*/}" "***No Configuration File Detected - Run Install Mode***"
  logger -p 6 -t "${0##*/}" "Debug - Configuration File: "$CONFIGFILE""
  exit
fi
}

systemcheck ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: systemcheck"

#Get Log Level
logger -p 6 -t "${0##*/}" "Debug - Log Level: "$(nvram get log_level)""

#Get PID
logger -p 5 -t "${0##*/}" "Process ID - "$$""

nvramcheck || return

# Check System Binaries Path
if [[ "$(echo $PATH | awk -F ":" '{print $1":"$2":"$3":"$4":"}')" != "/sbin:/bin:/usr/sbin:/usr/bin:" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting System Binaries Path"
  export PATH=/sbin:/bin:/usr/sbin:/usr/bin:$PATH
  logger -p 6 -t "${0##*/}" "Debug - PATH: "$PATH""
fi

# Script Version Logging
logger -p 5 -t "${0##*/}" "Version - "$VERSION""

# Supported Firmware Versions
FWVERSIONS='
386.5
386.7
'

# Firmware Version Check
logger -p 6 -t "${0##*/}" "Debug - Firmware: "$(nvram get buildno)""
for FWVERSION in ${FWVERSIONS};do
  if [[ "$(nvram get 3rd-party)" == "merlin" ]] && [[ "$(nvram get buildno)" == "$FWVERSION" ]] >/dev/null;then
    break
  elif [[ "$(nvram get 3rd-party)" == "merlin" ]] && [ ! -z "$(echo "${FWVERSIONS}" | grep -w "$(nvram get buildno)")" ] >/dev/null;then
    continue
  else
    logger -p 3 -st "${0##*/}" "Firmware: ***"$(nvram get buildno)" is not supported, issues may occur from running this version***"
  fi
done

setvariables
}

# Install
install ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: Install"
if [[ "${mode}" == "install" ]] >/dev/null;then
  read -n 1 -s -r -p "Press any key to continue to install..."
fi
if [[ "${mode}" == "install" ]] || [[ "${mode}" == "config" ]] >/dev/null;then
  if [[ "${mode}" == "install" ]] >/dev/null;then
    # Check if JFFS Custom Scripts is enabled during installation
    if [[ "$(nvram get jffs2_scripts)" != "1" ]] >/dev/null;then
      echo -e "${RED}Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled.${NOCOLOR}"
      logger -p 3 -t "${0##*/}" "Install - Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled"
    else
      echo -e "${GREEN}Administration > System > Enable JFFS custom scripts and configs is enabled...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Administration > System > Enable JFFS custom scripts and configs is enabled"
    fi
  fi

  # Check for Config File
  if [[ "${mode}" == "install" ]] || [[ "${mode}" == "config" ]] >/dev/null;then
    echo -e "${BLUE}Creating $CONFIGFILE...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - Creating $CONFIGFILE"
    if [ ! -f $CONFIGFILE ] >/dev/null;then
      touch -a $CONFIGFILE
      chmod 666 $CONFIGFILE
      echo -e "${GREEN}$CONFIGFILE created.${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - $CONFIGFILE created"
    else
      echo -e "${YELLOW}$CONFIGFILE already exists...${NOCOLOR}"
      logger -p 4 -t "${0##*/}" "Install - $CONFIGFILE already exists"
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
    logger -p 3 -t "${0##*/}" "Configuration - $CONFIGFILE doesn't exist, please run Install Mode"
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
          logger -p 6 -t "${0##*/}" "Debug - WAN0TARGET: Invalid IP Address"
          break 1
        elif [[ "$(nvram get wan0_gateway)" == "$ip" ]] >/dev/null;then
          echo -e "${RED}***"$ip" is the WAN0 Gateway IP Address***${NOCOLOR}"
          logger -p 6 -t "${0##*/}" ""WAN0TARGET: $ip" is "$WAN0" Gateway IP Address"
          break 1
        else
          SETWAN0TARGET=$ip
          logger -p 6 -t "${0##*/}" "Debug - WAN0TARGET: $ip"
          break 2
        fi
      done
    else  
      echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${0##*/}" "Debug - WAN0TARGET: Invalid IP Address"
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
          logger -p 6 -t "${0##*/}" "Debug - WAN1TARGET: Invalid IP Address"
          break 1
        elif [[ "$ip" == "$SETWAN0TARGET" ]] >/dev/null;then
          echo -e "${RED}***$ip already assigned to "$WAN0"***${NOCOLOR}"
          logger -p 6 -t "${0##*/}" "Debug - WAN1TARGET: $ip already assigned to "$WAN0""
          break 1
        elif [[ "$(nvram get wan1_gateway)" == "$ip" ]] >/dev/null;then
          echo -e "${RED}***IP Address is the WAN1 Gateway IP Address***${NOCOLOR}"
          logger -p 6 -t "${0##*/}" ""WAN1TARGET: $ip" is "$WAN1" Gateway IP Address"
          break 1
        else
          SETWAN1TARGET=$ip
          logger -p 6 -t "${0##*/}" "Debug - WAN1 Target: $ip"
          break 2
        fi
      done
    else  
      echo -e "${RED}***Invalid IP Address***${NOCOLOR}"
      logger -p 6 -t "${0##*/}" "Debug - WAN1TARGET: Invalid IP Address"
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
  logger -p 5 -t "${0##*/}" "Install - Adding Custom Settings to $CONFIGFILE"
  for NEWVARIABLE in ${NEWVARIABLES};do
    if [ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] >/dev/null;then
      echo -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    else
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    fi
  done
  echo -e "${GREEN}Custom Variables added to $CONFIGFILE.${NOCOLOR}"
  logger -p 5 -t "${0##*/}" "Install - Custom Variables added to $CONFIGFILE"

  if [[ "${mode}" == "install" ]] >/dev/null;then
    # Create Wan-Event if it doesn't exist
    echo -e "${BLUE}Creating Wan-Event script...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - Creating Wan-Event script"
    if [ ! -f "/jffs/scripts/wan-event" ] >/dev/null;then
      touch -a /jffs/scripts/wan-event
      chmod 755 /jffs/scripts/wan-event
      echo "#!/bin/sh" >> /jffs/scripts/wan-event
      echo -e "${GREEN}Wan-Event script has been created.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Install - Wan-Event script has been created"
    else
      echo -e "${YELLOW}Wan-Event script already exists...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Wan-Event script already exists"
    fi

    # Add Script to Wan-event
    if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "# Wan-Failover")" ] >/dev/null;then 
      echo -e "${YELLOW}${0##*/} already added to Wan-Event...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - ${0##*/} already added to Wan-Event"
    else
      cmdline="sh $0 cron"
      echo -e "${BLUE}Adding ${0##*/} to Wan-Event...${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - Adding ${0##*/} to Wan-Event"
      echo -e "\r\n$cmdline # Wan-Failover" >> /jffs/scripts/wan-event
      echo -e "${GREEN}${0##*/} added to Wan-Event.${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Install - ${0##*/} added to Wan-Event"
    fi

    # Create Initial Cron Jobs
    cronjob &
  fi
  # Kill current instance of script to allow new configuration to take place.
  if [[ "${mode}" == "config" ]] >/dev/null;then
    killscript
  fi
fi
exit
}

# Uninstall
uninstall ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: Uninstall"
if [[ "${mode}" == "uninstall" ]] >/dev/null;then
read -n 1 -s -r -p "Press any key to continue to uninstall..."
  # Remove Cron Job
  cronjob &

  # Check for Config File
  echo -e "${BLUE}${0##*/} - Uninstall: Deleting $CONFIGFILE...${NOCOLOR}"
  logger -p 5 -t "${0##*/}" "Uninstall - Deleting $CONFIGFILE"
  if [ -f $CONFIGFILE ] >/dev/null;then
    rm -f $CONFIGFILE
    echo -e "${GREEN}${0##*/} - Uninstall: $CONFIGFILE deleted.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - $CONFIGFILE deleted"
  else
    echo -e "${RED}${0##*/} - Uninstall: $CONFIGFILE doesn't exist.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - $CONFIGFILE doesn't exist"
  fi

  # Remove Script from Wan-event
  cmdline="sh $0 cron"
  if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ] >/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Wan-Event...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removing Cron Job from Wan-Event"
    sed -i '\~# Wan-Failover~d' /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Wan-Event.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removed Cron Job from Wan-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Wan-Event.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Cron Job doesn't exist in Wan-Event"
  fi

  # Restart Enabled WAN Interfaces
  for WANPREFIX in ${WANPREFIXES};do
    if [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null;then
      echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface "${WANPREFIX}"${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Uninstall - Restarting interface "${WANPREFIX}""
      SUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
      service "restart_wan_if "$SUFFIX"" &
      echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface "${WANPREFIX}"${NOCOLOR}"
      logger -p 5 -t "${0##*/}" "Uninstall - Restarted interface "${WANPREFIX}""
    fi
  done

  # Remove Lock File
  if [ -f "$LOCKFILE" ] >/dev/null;then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing $LOCKFILE...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removing $LOCKFILE"
    rm -f "$LOCKFILE"
    echo -e "${GREEN}${0##*/} - Uninstall: Removed $LOCKFILE...${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - Removed $LOCKFILE"
  else
    echo -e "${RED}${0##*/} - Uninstall: $LOCKFILE doesn't exist.${NOCOLOR}"
    logger -p 5 -t "${0##*/}" "Uninstall - $LOCKFILE doesn't exist"
  fi

  # Kill Running Processes
  echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
  logger -p 0 -t "${0##*/}" "Uninstall - Killing ${0##*/}"
  sleep 3 && killall ${0##*/}
fi
exit
}

# Kill Script
killscript ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: killscript"
if [[ "${mode}" == "restart" ]] || [[ "${mode}" == "update" ]] || [[ "${mode}" == "config" ]] || [[ "$[mode}" == "email" ]] >/dev/null;then
  # Determine PIDs to kill
  logger -p 6 -t "${0##*/}" "Debug - Selecting PIDs to kill"
  PIDS=""
  PIDSRUN="$(ps | grep -v "grep" | grep -w "$0 run" | awk '{print $1}')"
  PIDSMANUAL="$(ps | grep -v "grep" | grep -w "$0 manual" | awk '{print $1}')"
  for PID in ${PIDSRUN};do
    PIDS="${PIDS} ${PID}"
  done
  for PID in ${PIDSMANUAL};do
    PIDS="${PIDS} ${PID}"
  done

  # Schedule CronJob  
  logger -p 6 -t "${0##*/}" "Debug - Calling CronJob to be rescheduled"
  $(cronjob >/dev/null &) || return

  logger -p 6 -t "${0##*/}" "Debug - ***Checking if PIDs array is null*** Process ID: "$PIDS""
  if [ ! -z "$PIDS" ] >/dev/null;then
    # Schedule kill for Old PIDs
    logger -p 1 -st "${0##*/}" "Restart - Restarting ${0##*/} ***This can take up to approximately 1 minute***"
    logger -p 6 -t "${0##*/}" "Debug - Waiting to kill script until seconds into the minute are above 40 seconds or below 45 seconds"
    CURRENTSYSTEMUPTIME="$(awk -F "." '{print $1}' "/proc/uptime")"
    while [[ "$(date "+%S")" -lt "40" ]] || [[ "$(date "+%S")" -gt "45" ]] >/dev/null;do
      if tty >/dev/null 2>&1;then
        WAITTIMER=$(($(awk -F "." '{print $1}' "/proc/uptime")-$CURRENTSYSTEMUPTIME))
        printf '%s\r' "***Waiting to kill ${0##*/}*** Current Wait Time: "$WAITTIMER" Seconds"
        if [[ "$WAITTIMER" -lt "30" ]] >/dev/null;then
          printf '%b\r' "***Waiting to kill ${0##*/}*** Current Wait Time: "${GREEN}""$WAITTIMER" Seconds"${NOCOLOR}""
        elif [[ "$WAITTIMER" -lt "60" ]] >/dev/null;then
          printf '%b\r' "***Waiting to kill ${0##*/}*** Current Wait Time: "${YELLOW}""$WAITTIMER" Seconds"${NOCOLOR}""
        elif [[ "$WAITTIMER" -ge "60" ]] >/dev/null;then
          printf '%b\r' "***Waiting to kill ${0##*/}*** Current Wait Time: "${RED}""$WAITTIMER" Seconds"${NOCOLOR}""
        fi
      fi
      sleep 1
    done
    # Kill PIDs
    for PID in ${PIDS};do
      logger -p 1 -st "${0##*/}" "Restart - Killing ${0##*/} Process ID: "${PID}""
      kill -9 ${PID}
      logger -p 1 -st "${0##*/}" "Restart - Killed ${0##*/} Process ID: "${PID}""
    done
  elif [ -z "$PIDS" ] >/dev/null;then
    # Log no PIDs found and exit
    logger -p 1 -st "${0##*/}" "Restart - ***${0##*/} is not running*** No Process ID Detected"
    if tty >/dev/null 2>&1;then
      printf '%b\r' ""${RED}"***${0##*/} is not running*** No Process ID Detected"${NOCOLOR}""
    fi
  fi

  # Check for restart from CronJob
  RESTARTTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+120))"
  logger -p 1 -t "${0##*/}" "Restart - Waiting for ${0##*/} to restart from CronJob"
  logger -p 6 -t "${0##*/}" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"
  logger -p 6 -t "${0##*/}" "Debug - Restart Timeout is in "$(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))" Seconds"
  while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$RESTARTTIMEOUT" ]] >/dev/null;do
    PIDS=""
    PIDSRUN="$(ps | grep -v "grep" | grep -w "$0 run" | awk '{print $1}')"
    PIDSMANUAL="$(ps | grep -v "grep" | grep -w "$0 manual" | awk '{print $1}')"
    for PID in ${PIDSRUN};do
      PIDS="${PIDS} ${PID}"
    done
    for PID in ${PIDSMANUAL};do
      PIDS="${PIDS} ${PID}"
    done
    if [ ! -z "$PIDS" ] >/dev/null;then
      break
    elif [ -z "$PIDS" ] >/dev/null;then
      if tty >/dev/null 2>&1;then
        TIMEOUTTIMER=$(($RESTARTTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))
        if [[ "$TIMEOUTTIMER" -ge "60" ]] >/dev/null;then
          printf '%b\r' "***Waiting for ${0##*/} to restart from cronjob*** Timeout: "${GREEN}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        elif [[ "$TIMEOUTTIMER" -ge "30" ]] >/dev/null;then
          printf '%b\r' "***Waiting for ${0##*/} to restart from cronjob*** Timeout: "${YELLOW}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        elif [[ "$TIMEOUTTIMER" -ge "0" ]] >/dev/null;then
          printf '%b\r' "***Waiting for ${0##*/} to restart from cronjob*** Timeout: "${RED}""$TIMEOUTTIMER" Seconds"${NOCOLOR}""
        fi
      fi
      sleep 1
    fi
  done
  logger -p 6 -t "${0##*/}" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"

  # Check if script restarted
  logger -p 6 -t "${0##*/}" "Debug - Checking if "${0##*/}" restarted"
  PIDS=""
  PIDSRUN="$(ps | grep -v "grep" | grep -w "$0 run" | awk '{print $1}')"
  PIDSMANUAL="$(ps | grep -v "grep" | grep -w "$0 manual" | awk '{print $1}')"
  for PID in ${PIDSRUN};do
    PIDS="${PIDS} ${PID}"
  done
  for PID in ${PIDSMANUAL};do
    PIDS="${PIDS} ${PID}"
  done
  logger -p 6 -t "${0##*/}" "Debug - ***Checking if PIDs array is null*** Process ID: "$PIDS""
  if [ ! -z "$PIDS" ] >/dev/null;then
    logger -p 1 -st "${0##*/}" "Restart - Successfully Restarted ${0##*/} Process ID: "$PIDS""
    if tty >/dev/null 2>&1;then
      printf '%b\r' ""${GREEN}"Successfully Restarted ${0##*/} Process ID: "$PIDS""${NOCOLOR}""
    fi
  elif [ -z "$PIDS" ] >/dev/null;then
    logger -p 1 -st "${0##*/}" "Restart - Failed to restart ${0##*/} ***Check Logs***"
    if tty >/dev/null 2>&1;then
      printf '%b\r' ""${RED}"Failed to restart ${0##*/} ***Check Logs***"${NOCOLOR}""
    fi
  fi
  exit
elif [[ "${mode}" == "kill" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Calling CronJob to delete jobs"
  $(cronjob >/dev/null &)
  logger -p 0 -st "${0##*/}" "Kill - Killing ${0##*/}"
  killall ${0##*/}
  exit
fi
exit
}

# Update Script
update ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: update"
REMOTEVERSION="$(echo $(curl "$DOWNLOADPATH" | grep -v "grep" | grep -e "# Version:" | awk '{print $3}'))"
if [[ ! -z "$(echo "$VERSION" | grep -e "beta")" ]] >/dev/null; then
  echo -e "${YELLOW}Current Version: "$VERSION" - Script is a beta version and must be manually upgraded or replaced for a production version.${NOCOLOR}"
  logger -p 6 -t "${0##*/}" "Debug - Current Version: "$VERSION" - Script is a beta version and must be manually upgraded or replaced for a production version"
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
  logger -p 3 -st "${0##*/}" "Script is out of date - Current Version: "$VERSION" Available Version: "$REMOTEVERSION""$VERSION""
  read -n 1 -s -r -p "Press any key to continue to update..."
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" && chmod 755 $0 && sh $0 restart
  logger -p 4 -st "${0##*/}" "Update - Script has been updated ${0##*/}"
elif [[ "$VERSION" == "$REMOTEVERSION" ]] >/dev/null;then
  logger -p 5 -st "${0##*/}" "Script is up to date - Version: "$VERSION""
fi
}

# Cronjob
cronjob ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: cronjob"
# Create Cron Job
if [[ "${mode}" == "cron" ]] || [[ "${mode}" == "install" ]] || [[ "${mode}" == "restart" ]] || [[ "${mode}" == "update" ]] || [[ "${mode}" == "config" ]] >/dev/null;then
  if [ -z "$(cru l | grep -w "$0")" ] >/dev/null;then
    logger -p 5 -st "${0##*/}" "Cron - Creating Cron Job"
    cru a setup_wan_failover_run "*/1 * * * *" $0 run
    logger -p 5 -st "${0##*/}" "Cron - Created Cron Job"
  fi
# Remove Cron Job
elif [[ "${mode}" == "kill" ]] || [[ "${mode}" == "uninstall" ]] >/dev/null;then
  if [ ! -z "$(cru l | grep -w "$0")" ] >/dev/null;then
    logger -p 3 -st "${0##*/}" "Cron - Removing Cron Job"
    cru d setup_wan_failover_run
    logger -p 3 -st "${0##*/}" "Cron - Removed Cron Job"
  fi
  return
fi
exit
}

# Monitor Logging
monitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: monitor"
tail -F $SYSTEMLOG | grep -e "${0##*/}" 2>/dev/null && exit
}

# Set Variables
setvariables ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: setvariables"
#Set Variables from Configuration
logger -p 6 -t "${0##*/}" "Debug - Reading "$CONFIGFILE""
. $CONFIGFILE

# Check Configuration File for Missing Settings and Set Default if Missing
logger -p 6 -t "${0##*/}" "Debug - Checking for missing configuration options"
if [ -z "$(awk -F "=" '/WAN0TARGET/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0TARGET Default: 8.8.8.8"
  echo -e "WAN0TARGET=8.8.8.8" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1TARGET/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1TARGET Default: 8.8.4.4"
  echo -e "WAN0TARGET=8.8.4.4" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/PINGCOUNT/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting PINGCOUNT Default: 3 Seconds"
  echo -e "PINGCOUNT=3" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/PINGTIMEOUT/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting PINGTIMEOUT Default: 1 Second"
  echo -e "PINGTIMEOUT=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WANDISABLEDSLEEPTIMER/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WANDISABLEDSLEEPTIMER Default: 10 Seconds"
  echo -e "WANDISABLEDSLEEPTIMER=10" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_IBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_IBW Default: 0 Mbps"
  echo -e "WAN0_QOS_IBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_IBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_IBW Default: 0 Mbps"
  echo -e "WAN1_QOS_IBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_OBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_OBW Default: 0 Mbps"
  echo -e "WAN0_QOS_OBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_OBW/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_OBW Default: 0 Mbps"
  echo -e "WAN1_QOS_OBW=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_OVERHEAD/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_OVERHEAD Default: 0 Bytes"
  echo -e "WAN0_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_OVERHEAD/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_OVERHEAD Default: 0 Bytes"
  echo -e "WAN1_QOS_OVERHEAD=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0_QOS_ATM/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0_QOS_ATM Default: Disabled"
  echo -e "WAN0_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1_QOS_ATM/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1_QOS_ATM Default: Disabled"
  echo -e "WAN1_QOS_ATM=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/PACKETLOSSLOGGING/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting PACKETLOSSLOGGING Default: Enabled"
  echo -e "PACKETLOSSLOGGING=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/SENDEMAIL/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting SENDEMAIL Default: Enabled"
  echo -e "SENDEMAIL=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/SKIPEMAILSYSTEMUPTIME/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting SKIPEMAILSYSTEMUPTIME Default: 180 Seconds"
  echo -e "SKIPEMAILSYSTEMUPTIME=180" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/EMAILTIMEOUT/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
  echo -e "EMAILTIMEOUT=30" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/BOOTDELAYTIMER/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting BOOTDELAYTIMER Default: 0 Seconds"
  echo -e "BOOTDELAYTIMER=0" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/OVPNSPLITTUNNEL/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNSPLITTUNNEL Default: Enabled"
  echo -e "OVPNSPLITTUNNEL=1" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0ROUTETABLE/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0ROUTETABLE Default: Table 100"
  echo -e "WAN0ROUTETABLE=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1ROUTETABLE/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1ROUTETABLE Default: Table 200"
  echo -e "WAN1ROUTETABLE=200" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0TARGETRULEPRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0TARGETRULEPRIORITY Default: Priority 100"
  echo -e "WAN0TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1TARGETRULEPRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1TARGETRULEPRIORITY Default: Priority 100"
  echo -e "WAN1TARGETRULEPRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0MARK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0MARK Default: 0x80000000"
  echo -e "WAN0MARK=0x80000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1MARK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1MARK Default: 0x90000000"
  echo -e "WAN1MARK=0x90000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN0MASK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN0MASK Default: 0xf0000000"
  echo -e "WAN0MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/WAN1MASK/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting WAN1MASK Default: 0xf0000000"
  echo -e "WAN1MASK=0xf0000000" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/LBRULEPRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting LBRULEPRIORITY Default: Priority 150"
  echo -e "LBRULEPRIORITY=150" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/FROMWAN0PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting FROMWAN0PRIORITY Default: Priority 200"
  echo -e "FROMWAN0PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/TOWAN0PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting TOWAN0PRIORITY Default: Priority 400"
  echo -e "TOWAN0PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/FROMWAN1PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting FROMWAN1PRIORITY Default: Priority 200"
  echo -e "FROMWAN1PRIORITY=200" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/TOWAN1PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting TOWAN1PRIORITY Default: Priority 400"
  echo -e "TOWAN1PRIORITY=400" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/OVPNWAN0PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNWAN0PRIORITY Default: Priority 100"
  echo -e "OVPNWAN0PRIORITY=100" >> $CONFIGFILE
fi
if [ -z "$(awk -F "=" '/OVPNWAN1PRIORITY/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Setting OVPNWAN1PRIORITY Default: Priority 200"
  echo -e "OVPNWAN1PRIORITY=200" >> $CONFIGFILE
fi

logger -p 6 -t "${0##*/}" "Debug - Reading "$CONFIGFILE""
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
      logger -p 6 -t "${0##*/}" "Debug - Added $REMOTEADDRESS to OVPN Remote Addresses"
      REMOTEADDRESSES="${REMOTEADDRESSES} ${REMOTEADDRESS}"
    fi
  done
fi

# Debug Logging
debuglog || return

if [[ "${mode}" == "switchwan" ]] >/dev/null;then
  switchwan
else
  wanstatus
fi
}

# WAN Status
wanstatus ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wanstatus"

# Delay if NVRAM is not accessible
nvramcheck || return

# Boot Delay Timer
logger -p 6 -t "${0##*/}" "Debug - System Uptime: "$(awk -F "." '{print $1}' "/proc/uptime")" Seconds"
logger -p 6 -t "${0##*/}" "Debug - Boot Delay Timer: "$BOOTDELAYTIMER" Seconds"
if [ ! -z "$BOOTDELAYTIMER" ] >/dev/null;then
  if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] >/dev/null;then
    logger -p 4 -st "${0##*/}" "Boot Delay - Waiting for System Uptime to reach $BOOTDELAYTIMER seconds"
    while [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$BOOTDELAYTIMER" ]] >/dev/null;do
      sleep 1
    done
    logger -p 5 -st "${0##*/}" "Boot Delay - System Uptime is $(awk -F "." '{print $1}' "/proc/uptime") seconds"
  fi
fi

# Check Current Status of Dual WAN Mode
if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null;then
  logger -p 2 -st "${0##*/}" "Dual WAN - Disabled"
  wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  logger -p 2 -st "${0##*/}" "Dual WAN - ASUS Factory Watchdog: Enabled"
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
      elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null;then
        TARGET="$WAN1TARGET"
        TABLE="$WAN1ROUTETABLE"
        PRIORITY="$WAN1TARGETRULEPRIORITY"
      fi

    # Check if WAN Interfaces are Disabled
    if [[ "$(nvram get "${WANPREFIX}"_enable)" == "0" ]] >/dev/null;then
      logger -p 1 -st "${0##*/}" "WAN Status - ${WANPREFIX} disabled"
      STATUS=DISABLED
      logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
    # Check if WAN is Enabled
    elif [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null;then
      logger -p 5 -t "${0##*/}" "WAN Status - ${WANPREFIX} enabled"
      # Check WAN Connection
      if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] || [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
        if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
          logger -p 1 -st "${0##*/}" "WAN Status - "${WANPREFIX}": Cable Unplugged"
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
          logger -p 1 -st "${0##*/}" "WAN Status - "${WANPREFIX}": Disconnected"
        fi
        logger -p 1 -st "${0##*/}" "WAN Status - Restarting "${WANPREFIX}""
        WANSUFFIX="$(echo "${WANPREFIX}" | awk -F "wan" '{print $2}')"
        service "restart_wan_if "$WANSUFFIX"" & 
        sleep 1
        # Set Timeout for WAN interface to restart to a max of 30 seconds and while WAN Interface is State 6
        RESTARTTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+30))"
        while [[ "$(nvram get "${WANPREFIX}"_state_t)" == "6" ]] && [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$RESTARTTIMEOUT" ]] >/dev/null;do
          sleep 1
        done
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" State - Post-Restart: "$(nvram get ${WANPREFIX}_state_t)""
        if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] || [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
          if [[ "$(nvram get "${WANPREFIX}"_state_t)" == "3" ]] >/dev/null;then
            logger -p 1 -st "${0##*/}" "WAN Status - "${WANPREFIX}": Cable Unplugged"
          elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "4" ]] >/dev/null;then
            logger -p 1 -st "${0##*/}" "WAN Status - "${WANPREFIX}": Disconnected"
          fi
          STATUS=DISCONNECTED
          logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
          logger -p 1 -st "${0##*/}" "WAN Status - Restarted "${WANPREFIX}""
          break
        else
          wanstatus
        fi
      fi
      # Check if WAN Gateway IP or IP Address are 0.0.0.0
      if { [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
        logger -p 1 -st "${0##*/}" "WAN Status - ${WANPREFIX} is disconnected.  IP Address: "$(nvram get ${WANPREFIX}_ipaddr)" Gateway: "$(nvram get ${WANPREFIX}_gateway)""
        STATUS=DISCONNECTED
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
        continue
      fi
      # Check WAN IP Address Target Route
      if [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] && [ ! -z "$(ip route list default table main | grep -e "$TARGET")" ] && [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
        logger -p 5 -t "${0##*/}" "WAN Status - Default route already exists via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
      fi
      # Check WAN Routing Table for Default Routes
      if [ -z "$(ip route list default table "$TABLE" | grep -e "$(nvram get ${WANPREFIX}_gw_ifname)")" ] >/dev/null;then
        logger -p 5 -t "${0##*/}" "WAN Status - Adding default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
        ip route add default via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_gw_ifname) table "$TABLE"
        logger -p 5 -t "${0##*/}" "WAN Status - Added default route for ${WANPREFIX} Routing Table via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_gw_ifname)""
      fi
      # Check WAN IP Rule
      if [ -z "$(ip rule list from all iif lo to $TARGET lookup ${TABLE} priority "$PRIORITY")" ] >/dev/null;then
        logger -p 5 -t "${0##*/}" "WAN Status - Adding IP Rule for "$TARGET""
        ip rule add from all iif lo to $TARGET table ${TABLE} priority "$PRIORITY"
        logger -p 5 -t "${0##*/}" "WAN Status - Added IP Rule for "$TARGET""
      fi
      # Check WAN Packet Loss
      PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_gw_ifname) $TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}' &)"
      logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Packet Loss: "$PACKETLOSS"%"
      if [[ "$PACKETLOSS" == "0%" ]] >/dev/null;then
        logger -p 5 -t "${0##*/}" "WAN Status - "${WANPREFIX}" has "$PACKETLOSS" packet loss"
        STATUS="CONNECTED"
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
        if [[ "$(nvram get ${WANPREFIX}_state_t)" != "2" ]] >/dev/null;then
          nvram set ${WANPREFIX}_state_t=2
        fi
      elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] && [[ "$PACKETLOSS" == "100%" ]] >/dev/null;then
        logger -p 2 -st "${0##*/}" "WAN Status - ${WANPREFIX} has $PACKETLOSS packet loss ***Verify $TARGET is a valid server for ICMP Echo Requests***"
        STATUS="DISCONNECTED"
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
      else
        logger -p 2 -st "${0##*/}" "WAN Status - "${WANPREFIX}" has "$PACKETLOSS" packet loss"
        STATUS="DISCONNECTED"
        logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" Status: "$STATUS""
      fi
    fi
    # Set WAN Status
    if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null;then
      WAN0STATUS="$STATUS"
    elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null;then
      WAN1STATUS="$STATUS"
    fi
  done
fi

# Check IP Rules and IPTables Rules
checkiprules || return

# Set WAN Status to DISABLED, DISCONNECTED, or CONNECTED and select function.
logger -p 6 -t "${0##*/}" "Debug - WAN0STATUS: "$WAN0STATUS""
logger -p 6 -t "${0##*/}" "Debug - WAN1STATUS: "$WAN1STATUS""
if [[ "$WAN0STATUS" == "DISABLED" ]] && [[ "$WAN1STATUS" == "DISABLED" ]] >/dev/null;then
  wandisabled
elif [[ "$WAN0STATUS" == "DISCONNECTED" ]] && [[ "$WAN1STATUS" == "DISCONNECTED" ]] >/dev/null;then
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

# Check IP Rules and IPTables Rules
checkiprules ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: checkiprules"

# Delay if NVRAM is not accessible
nvramcheck || return

for WANPREFIX in ${WANPREFIXES};do
  # Set WAN Interface Parameters
  if [[ "${WANPREFIX}" == "$WAN0" ]] >/dev/null;then
    TABLE="$WAN0ROUTETABLE"
    MARK="$WAN0MARK"
    DELETEMARK="$WAN1MARK"
    MASK="$WAN0MASK"
    FROMWANPRIORITY="$FROMWAN0PRIORITY"
    TOWANPRIORITY="$TOWAN0PRIORITY"
    STATUS="$WAN0STATUS"
    OVPNWANPRIORITY="$OVPNWAN0PRIORITY"
  elif [[ "${WANPREFIX}" == "$WAN1" ]] >/dev/null;then
    TABLE="$WAN1ROUTETABLE"
    MARK="$WAN1MARK"
    DELETEMARK="$WAN0MARK"
    MASK="$WAN1MASK"
    FROMWANPRIORITY="$FROMWAN1PRIORITY"
    TOWANPRIORITY="$TOWAN1PRIORITY"
    STATUS="$WAN1STATUS"
    OVPNWANPRIORITY="$OVPNWAN1PRIORITY"
  fi

  # Create WAN NAT Rules
  # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
  if [[ "$(nvram get misc_http_x)" == "1" ]] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - HTTP Web Access: "$(nvram get misc_http_x)""
    # Create VSERVER Rule if Web Access is Enabled for Adminstration GUI.
    if [ -z "$(iptables -t nat -L PREROUTING -v -n | awk '{ if( /VSERVER/ && /'$(nvram get ${WANPREFIX}_ipaddr)'/ ) print}' )" ] >/dev/null;then
      logger -p 5 -t "${0##*/}" "Check IP Rules - ${WANPREFIX} creating VSERVER Rule for $(nvram get ${WANPREFIX}_ipaddr)"
      iptables -t nat -A PREROUTING -d $(nvram get ${WANPREFIX}_ipaddr) -j VSERVER
    fi
  fi
  # Create UPNP Rules if Enabled
  if [[ "$(nvram get ${WANPREFIX}_upnp_enable)" == "1" ]] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" UPNP Enabled: "$(nvram get ${WANPREFIX}_upnp_enable)""
    if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /PUPNP/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ ) print}' )" ] >/dev/null;then
      logger -p 5 -t "${0##*/}" "Check IP Rules - ${WANPREFIX} creating UPNP Rule for $(nvram get ${WANPREFIX}_gw_ifname)"
      iptables -t nat -A POSTROUTING -o $(nvram get ${WANPREFIX}_gw_ifname) -j PUPNP
    fi
  fi
  # Create MASQUERADE Rules if NAT is Enabled
  if [[ "$(nvram get ${WANPREFIX}_nat_x)" == "1" ]] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - "${WANPREFIX}" NAT Enabled: "$(nvram get ${WANPREFIX}_nat_x)""
    if [ -z "$(iptables -t nat -L POSTROUTING -v -n | awk '{ if( /MASQUERADE/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /'$(nvram get ${WANPREFIX}_ipaddr)'/ ) print}')" ] >/dev/null;then
      logger -p 5 -t "${0##*/}" "Check IP Rules - Adding iptables MASQUERADE rule for excluding $(nvram get ${WANPREFIX}_ipaddr) via $(nvram get ${WANPREFIX}_gw_ifname)"
      iptables -t nat -A POSTROUTING -o $(nvram get ${WANPREFIX}_gw_ifname) ! -s $(nvram get ${WANPREFIX}_ipaddr) -j MASQUERADE
    fi
  fi

  # Check Rules for Load Balance Mode
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - Checking IPTables Mangle Rules"
    # Check IPTables Mangle Balance Rules for PREROUTING Table
    if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$(nvram get lan_ifname)'/ && /state/ && /NEW/ ) print}')" ] >/dev/null;then
      logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE Balance Rule"
      iptables -t mangle -A PREROUTING -i $(nvram get lan_ifname) -m state --state NEW -j balance
    fi
    # Check Rules if Status is Connected
    if [[ "$STATUS" == "CONNECTED" ]] >/dev/null;then
      # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
      if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get lan_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE match rule for $(nvram get lan_ifname) marked with "$MARK""
        iptables -t mangle -A PREROUTING -i $(nvram get lan_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK"
      fi
      # Check IPTables Mangle Match Rule for WAN for OUTPUT Table
      if [ -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE match rule for $(nvram get ${WANPREFIX}_gw_ifname) marked with "$MARK""
        iptables -t mangle -A OUTPUT -o $(nvram get ${WANPREFIX}_gw_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK"
      fi
      if [ ! -z "$(iptables -t mangle -L OUTPUT -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /connmark match/ && /'$DELETEMARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null;then
        logger -p 6 -t "${0##*/}" "Check IP Rules - Deleting IPTables MANGLE match rule for $(nvram get ${WANPREFIX}_gw_ifname) marked with "$DELETEMARK""
        iptables -t mangle -D OUTPUT -o $(nvram get ${WANPREFIX}_gw_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK"
      fi
      # Check IPTables Mangle Set XMark Rule for WAN for PREROUTING Table
      if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get ${WANPREFIX}_gw_ifname)'/ && /state/ && /NEW/ && /CONNMARK/ && /xset/ && /'$MARK'/ ) print}')" ] >/dev/null;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE set xmark rule for $(nvram get ${WANPREFIX}_gw_ifname)"
        iptables -t mangle -A PREROUTING -i $(nvram get ${WANPREFIX}_gw_ifname) -m state --state NEW -j CONNMARK --set-xmark "$MARK"/"$MASK"
      fi
      # Create WAN IP Address Rule
      if [[ "$(nvram get ${WANPREFIX}_ipaddr)" != "0.0.0.0" ]] && [ -z "$(ip rule list from $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE}"
        ip rule add from $(nvram get ${WANPREFIX}_ipaddr) lookup ${TABLE} priority "$FROMWANPRIORITY"
      fi
      # Create WAN Gateway IP Rule
      if [[ "$(nvram get ${WANPREFIX}_gateway)" != "0.0.0.0" ]] && [ -z "$(ip rule list from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null;then
        logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE}"
        ip rule add from all to $(nvram get ${WANPREFIX}_gateway) lookup ${TABLE} priority "$TOWANPRIORITY"
      fi
      # Create WAN DNS IP Rules
      if [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "0" ]] >/dev/null;then
        if [ ! -z "$(nvram get ${WANPREFIX}_dns1_x)" ] >/dev/null;then
          if [ -z "$(ip rule list from $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE}"
            ip rule add from $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$FROMWANPRIORITY"
          fi
          if [ -z "$(ip rule list from all to $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE}"
            ip rule add from all to $(nvram get ${WANPREFIX}_dns1_x) lookup ${TABLE} priority "$TOWANPRIORITY"
          fi
        fi
        if [ ! -z "$(nvram get ${WANPREFIX}_dns2_x)" ] >/dev/null;then
          if [ -z "$(ip rule list from $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE}"
            ip rule add from $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$FROMWANPRIORITY"
          fi
          if [ -z "$(ip rule list from all to $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$TOWANPRIORITY")" ] >/dev/null;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE}"
            ip rule add from all to $(nvram get ${WANPREFIX}_dns2_x) lookup ${TABLE} priority "$TOWANPRIORITY"
          fi
        fi
      elif [[ "$(nvram get ${WANPREFIX}_dnsenable_x)" == "1" ]] >/dev/null;then
        if [ ! -z "$(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}')" ] >/dev/null;then
          if [ -z "$(ip rule list from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}') lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}') lookup ${TABLE}"
            ip rule add from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $1}') lookup ${TABLE} priority "$FROMWANPRIORITY"
          fi
        fi
        if [ ! -z "$(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}')" ] >/dev/null;then
          if [ -z "$(ip rule list from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}') lookup ${TABLE} priority "$FROMWANPRIORITY")" ] >/dev/null;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule for $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}') lookup ${TABLE}"
            ip rule add from $(echo $(nvram get ${WANPREFIX}_dns) | awk '{print $2}') lookup ${TABLE} priority "$FROMWANPRIORITY"
          fi
        fi
      fi

      # Check Guest Network Rules for Load Balance Mode
      logger -p 6 -t "${0##*/}" "Debug - Checking Guest Networks IPTables Mangle Rules"
      i=0
      while [ "$i" -le "10" ] >/dev/null;do
        i=$(($i+1))
        if [ ! -z "$(nvram get lan${i}_ifname)" ] >/dev/null;then
          if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /balance/ && /'$(nvram get lan${i}_ifname)'/ && /state/ && /NEW/ ) print}')" ] >/dev/null;then
            logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE Balance Rule for "$(nvram get lan${i}_ifname)""
            iptables -t mangle -A PREROUTING -i $(nvram get lan${i}_ifname) -m state --state NEW -j balance
          fi
        fi
  
        # Check IPTables Mangle Match Rule for WAN for PREROUTING Table
        if [ -z "$(iptables -t mangle -L PREROUTING -v -n | awk '{ if( /CONNMARK/ && /'$(nvram get lan${i}_ifname)'/ && /connmark match/ && /'$MARK'/ && /CONNMARK/ && /restore/ && /mask/ && /'$MASK'/ ) print}')" ] >/dev/null;then
          logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IPTables MANGLE match rule for $(nvram get lan${i}_ifname) marked with "$MARK""
          iptables -t mangle -A PREROUTING -i $(nvram get lan${i}_ifname) -m connmark --mark "$MARK"/"$MARK" -j CONNMARK --restore-mark --mask "$MASK"
        fi
      done
      i=0

      # Create fwmark IP Rules
      logger -p 6 -t "${0##*/}" "Debug - Checking fwmark IP Rules"
      if [ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ] >/dev/null;then
        logger -p 4 -t "${0##*/}" "Check IP Rules - Adding IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule add from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY"
      fi
      if [ ! -z "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -p 4 -t "${0##*/}" "Check IP Rules - Removing Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule del blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY"
      fi

      # If OVPN Split Tunneling is Disabled in Configuration, create rules for WAN Interface.
      logger -p 6 -t "${0##*/}" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null;then
        # Create IP Rules for OVPN Remote Addresses
          for REMOTEADDRESS in ${REMOTEADDRESSES};do
            REMOTEIP=$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')
              logger -p 6 -t "${0##*/}" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
              logger -p 6 -t "${0##*/}" "Debug - Remote IP Address: "$REMOTEIP""
              if [ -z "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ] >/dev/null;then
                logger -p 5 -t "${0##*/}" "Check IP Rules - Adding IP Rule from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY""
                ip rule add from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY"
              fi
          done
      fi

    # Check Rules if Status is Disconnected
    elif [[ "$STATUS" == "DISCONNECTED" ]] >/dev/null;then
      # Create fwmark IP Rules
      logger -p 6 -t "${0##*/}" "Debug - Checking fwmark IP Rules"
      if [ ! -z "$(ip rule list from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY")" ] >/dev/null;then
        logger -p 4 -t "${0##*/}" "Check IP Rules - Removing IP Rule for fwmark "$MARK"/"$MASK" lookup "$TABLE""
        ip rule del from all fwmark "$MARK"/"$MASK" lookup "$TABLE" priority "$LBRULEPRIORITY"
      fi
      if [ -z "$(ip rule list from all fwmark "$MARK"/"$MASK" | grep -w "blackhole")" ] >/dev/null;then
        logger -p 4 -t "${0##*/}" "Check IP Rules - Adding Blackhole IP Rule for fwmark "$MARK"/"$MASK""
        ip rule add blackhole from all fwmark "$MARK"/"$MASK" priority "$LBRULEPRIORITY"
      fi
      
      # If OVPN Split Tunneling is Disabled in Configuration, delete rules for down WAN Interface.
      logger -p 6 -t "${0##*/}" "Debug - OVPNSPLITTUNNEL Enabled: "$OVPNSPLITTUNNEL""
      if [[ "$OVPNSPLITTUNNEL" == "0" ]] >/dev/null;then
        # Create IP Rules for OVPN Remote Addresses
        for REMOTEADDRESS in ${REMOTEADDRESSES};do
          logger -p 6 -t "${0##*/}" "Debug - OVPN Remote Address: "$REMOTEADDRESS""
          logger -p 6 -t "${0##*/}" "Debug - Remote IP Address: "$REMOTEIP""
          REMOTEIP=$(nslookup $REMOTEADDRESS | awk '(NR>2) && /^Address/ {print $3}' | awk '!/:/')
          if [ ! -z "$(ip rule list from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY")" ] >/dev/null;then
            logger -p 4 -t "${0##*/}" "Check IP Rules - Removing IP Rule from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY""
            ip rule del from all to $REMOTEIP lookup "$TABLE" priority "$OVPNWANPRIORITY"
          fi
        done
      fi
    fi
  fi
done
return
}

# WAN0 Active
wan0active ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wan0active"

# Delay if NVRAM is not accessible
nvramcheck || return

logger -p 5 -t "${0##*/}" "WAN0 Active - Verifying WAN0"
if [[ "$(nvram get wan0_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] >/dev/null;then
  wandisabled
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
logger -p 6 -t "${0##*/}" "Debug - Function: wan1active"

# Delay if NVRAM is not accessible
nvramcheck || return

logger -p 5 -t "${0##*/}" "WAN1 Active - Verifying WAN1"
if [[ "$(nvram get wan1_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get wan0_gateway)" == "0.0.0.0" ]] >/dev/null;then
  wandisabled
elif [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(nvram get wan0_enable)" == "1" ]] >/dev/null;then
  wan0failbackmonitor
elif [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(nvram get wan0_enable)" == "0" ]] >/dev/null;then
  wandisabled
else
  wanstatus
fi
}

# Ping Targets
pingtargets ()
{
WAN0PACKETLOSS="$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}' &)"
WAN1PACKETLOSS="$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}' &)"
if tty >/dev/null 2>&1;then
  if [ -z "$WAN0PACKETLOSS" ] || [ -z "$WAN1PACKETLOSS" ] >/dev/null;then
    sleep 1
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    printf '%b\r' "$(date "+%D @ %T") - WAN0 Target: "$WAN0TARGET" Packet Loss: "${GREEN}""$WAN0PACKETLOSS""${NOCOLOR}" WAN1 Target: "$WAN1TARGET" Packet Loss: "${GREEN}""$WAN1PACKETLOSS""${NOCOLOR}""
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    printf '%b\r' "$(date "+%D @ %T") - WAN0 Target: "$WAN0TARGET" Packet Loss: "${RED}""$WAN0PACKETLOSS""${NOCOLOR}" WAN1 Target: "$WAN1TARGET" Packet Loss: "${GREEN}""$WAN1PACKETLOSS""${NOCOLOR}""
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null;then
    printf '%b\r' "$(date "+%D @ %T") - WAN0 Target: "$WAN0TARGET" Packet Loss: "${GREEN}""$WAN0PACKETLOSS""${NOCOLOR}" WAN1 Target: "$WAN1TARGET" Packet Loss: "${RED}""$WAN1PACKETLOSS""${NOCOLOR}""
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] && [[ "$WAN1PACKETLOSS" == "100%" ]] >/dev/null;then
    printf '%b\r' "$(date "+%D @ %T") - WAN0 Target: "$WAN0TARGET" Packet Loss: "${RED}""$WAN0PACKETLOSS""${NOCOLOR}" WAN1 Target: "$WAN1TARGET" Packet Loss: "${RED}""$WAN1PACKETLOSS""${NOCOLOR}""
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] && [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null;then
    printf '%b\r' "$(date "+%D @ %T") - WAN0 Target: "$WAN0TARGET" Packet Loss: "${YELLOW}""$WAN0PACKETLOSS""${NOCOLOR}" WAN1 Target: "$WAN1TARGET" Packet Loss: "${YELLOW}""$WAN1PACKETLOSS""${NOCOLOR}""
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    printf '%b\r' "$(date "+%D @ %T") - WAN0 Target: "$WAN0TARGET" Packet Loss: "${YELLOW}""$WAN0PACKETLOSS""${NOCOLOR}" WAN1 Target: "$WAN1TARGET" Packet Loss: "${GREEN}""$WAN1PACKETLOSS""${NOCOLOR}""
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null;then
    printf '%b\r' "$(date "+%D @ %T") - WAN0 Target: "$WAN0TARGET" Packet Loss: "${GREEN}""$WAN0PACKETLOSS""${NOCOLOR}" WAN1 Target: "$WAN1TARGET" Packet Loss: "${YELLOW}""$WAN1PACKETLOSS""${NOCOLOR}""
  fi
fi
return
}


# Load Balance Monitor
lbmonitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: lbmonitor"
logger -p 6 -t "${0##*/}" "Debug - Load Balance Ratio: "$(nvram get wans_lb_ratio)""

# Delay if NVRAM is not accessible
nvramcheck || return

if [[ "$WAN0STATUS" == "CONNECTED" ]] >/dev/null;then
  logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
elif [[ "$WAN0STATUS" != "CONNECTED" ]] >/dev/null;then
  logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
fi
if [[ "$WAN1STATUS" == "CONNECTED" ]] >/dev/null;then
  logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
elif [[ "$WAN1STATUS" != "CONNECTED" ]] >/dev/null;then
  logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
fi
while { [[ "$(nvram get wans_mode)" == "lb" ]] && [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
&& { [[ "$(nvram get wan0_gateway)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] ;} \
&& { [[ "$(nvram get wan1_gateway)" == "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan1_gw_ifname)" == "$(ip route list default table "$WAN1ROUTETABLE" | awk '{print $5}')" ]] ;} \
|| { [[ "$(nvram get wan0_state_t)" != "2" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] ;} >/dev/null;do
  pingtargets || wanstatus
  if { [ -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] && [[ "$(nvram get wan0_state_t)" == "2" ]] ;} && { [[ "$(nvram get wan0_ipaddr)" != "0.0.0.0" ]] || [[ "$(nvram get wan0_gateway)" != "0.0.0.0" ]] ;} \
  || { [ -z "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")" ] && [[ "$(nvram get wan1_state_t)" == "2" ]] ;} && { [[ "$(nvram get wan1_ipaddr)" != "0.0.0.0" ]] || [[ "$(nvram get wan1_gateway)" != "0.0.0.0" ]] ;} >/dev/null;then
    break
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Adding nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Adding nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route add default scope global \
      nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}') \
      nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')

      # Set WAN Status, Check Rules, and Send Email
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Packet Loss"
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Packet Loss"
      WAN0STATUS=CONNECTED
      WAN1STATUS=CONNECTED
      logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: "$WAN1STATUS""
      checkiprules || return
      sendemail || return
      continue
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] ;} && [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ ! -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -p 1 -st "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default
      logger -p 6 -t "${0##*/}" "Debug - Adding nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route add default scope global \
      nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')

      # Set WAN Status, Check Rules, and Send Email
      logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
      WAN0STATUS=DISCONNECTED
      WAN1STATUS=CONNECTED
      logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: "$WAN1STATUS""
      checkiprules || return
      sendemail || return
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] ;} >/dev/null;then
    if [ ! -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -p 1 -st "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default
      logger -p 6 -t "${0##*/}" "Debug - Adding nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      ip route add default scope global \
      nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')

      # Set WAN Status, Check Rules, and Send Email
      logger -p 3 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
      WAN0STATUS=CONNECTED
      WAN1STATUS=DISCONNECTED
      logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: "$WAN0STATUS""
      logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: "$WAN1STATUS""
      checkiprules || return
      sendemail || return
      continue
    fi
  elif { [[ "$WAN0PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan0_state_t)" != "2" ]] ;} \
  && { [[ "$WAN1PACKETLOSS" == "100%" ]] || [[ "$(nvram get wan1_state_t)" != "2" ]] ;} >/dev/null;then
    if [ -z "$(ip route show default | grep -w "$(nvram get wan0_gateway)")" ] && [ -z "$(ip route show default | grep -w "$(nvram get wan1_gateway)")" ] >/dev/null;then
      continue
    else
      logger -p 1 -st "${0##*/}" "Load Balance Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS WAN1 Packet Loss: $WAN1PACKETLOSS"
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan0_gateway) dev $(nvram get wan0_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $1}')"
      logger -p 4 -st "${0##*/}" "Load Balance Monitor - Removing nexthop via $(nvram get wan1_gateway) dev $(nvram get wan1_gw_ifname) weight $(echo "$(nvram get wans_lb_ratio)" | awk -F ":" '{print $2}')"
      logger -p 6 -t "${0##*/}" "Debug - Deleting Default Route"
      ip route del default

      # Set WAN Status and Check Rules
      logger -p 1 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN0" via "$WAN0TARGET" for Restoration"
      logger -p 1 -st "${0##*/}" "Load Balance Monitor - Monitoring "$WAN1" via "$WAN1TARGET" for Restoration"
      checkiprules || return
      continue
    fi
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] || [[ "$WAN1PACKETLOSS" != "0%" ]] >/dev/null;then
    if [ -z "$PACKETLOSSLOGGING" ] || [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null;then
      logger -p 3 -st "${0##*/}" "Load Balance Monitor - Packet Loss Detected - WAN0 Packet Loss: "$WAN0PACKETLOSS""
      logger -p 3 -st "${0##*/}" "Load Balance Monitor - Packet Loss Detected - WAN1 Packet Loss: "$WAN1PACKETLOSS""
      continue
    elif [ ! -z "$PACKETLOSSLOGGING" ] && [[ "$PACKETLOSSLOGGING" == "0"]] >/dev/null;then
      continue
    fi
  fi
done

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***Load Balance Monitor Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# WAN0 Failover Monitor
wan0failovermonitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wan0failovermonitor"

# Delay if NVRAM is not accessible
nvramcheck || return

logger -p 4 -st "${0##*/}" "WAN0 Failover Monitor - Monitoring "$WAN0" via $WAN0TARGET for Failure"
while { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} && [[ "$(nvram get wan0_primary)" == "1" ]] \
&& [ ! -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] \
&& { [[ "$(nvram get wan0_gateway)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] ;} >/dev/null;do
  pingtargets || wanstatus
  if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
    continue
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null;then
    logger -p 1 -st "${0##*/}" "WAN0 Failover Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    switchwan
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null;then
    if [ -z "$PACKETLOSSLOGGING" ] || [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null;then
      logger -p 3 -st "${0##*/}" "WAN0 Failover Monitor - Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
      continue
    elif [ ! -z "$PACKETLOSSLOGGING" ] && [[ "$PACKETLOSSLOGGING" == "0"]] >/dev/null;then
      continue
    fi
  fi
done

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***WAN0 Failover Monitor Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# WAN0 Failback Monitor
wan0failbackmonitor ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wan0failbackmonitor"

# Delay if NVRAM is not accessible
nvramcheck || return

logger -p 3 -st "${0##*/}" "WAN0 Failback Monitor - Monitoring "$WAN0" via $WAN0TARGET for Failback"
while { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} && [[ "$(nvram get wan1_primary)" == "1" ]] \
&& [ ! -z "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")" ] \
&& { [[ "$(nvram get wan0_gateway)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $3}')" ]] && [[ "$(nvram get wan0_gw_ifname)" == "$(ip route list default table "$WAN0ROUTETABLE" | awk '{print $5}')" ]] ;} >/dev/null;do
  pingtargets || wanstatus
  if [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null;then
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
    logger -p 1 -st "${0##*/}" "WAN0 Failback Monitor - Connection Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    switchwan
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null;then
    if [ -z "$PACKETLOSSLOGGING" ] || [[ "$PACKETLOSSLOGGING" == "1" ]] >/dev/null;then
      logger -p 3 -st "${0##*/}" "WAN0 Failback Monitor - Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
      continue
    elif [ ! -z "$PACKETLOSSLOGGING" ] && [[ "$PACKETLOSSLOGGING" == "0"]] >/dev/null;then
      continue
    fi
  fi
done

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***WAN0 Failback Monitor Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# WAN Disabled
wandisabled ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wandisabled"

# Delay if NVRAM is not accessible
nvramcheck || return

if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] >/dev/null;then
  logger -p 2 -st "${0##*/}" "WAN Failover Disabled - Dual WAN is disabled"
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  logger -p 2 -st "${0##*/}" "WAN Failover Disabled - ASUS Factory WAN Failover is enabled"
elif [[ "$(nvram get wan0_enable)" == "0" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null;then
  logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" are disabled"
elif [[ "$(nvram get wan0_enable)" == "0" ]] >/dev/null;then
  logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" is disabled"
elif [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null;then
  logger -p 2 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" is disabled"
fi
  logger -p 2 -st "${0##*/}" "WAN Failover Disabled - WAN Failover is currently disabled.  ***Review Logs***"
while \
  # WAN Disabled if both interfaces do not have an IP Address
  if { [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] ;} \
  && { [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if WAN0 does not have have an IP and WAN1 is Primary - Failover Mode
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] ;} \
  && { [[ "$(nvram get wan0_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get wan0_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # WAN Disabled if WAN1 does not have have an IP and WAN0 is Primary - Failover Mode
  elif { [[ "$(nvram get wans_mode)" == "fo" ]] && [[ "$(nvram get wan0_primary)" == "1" ]] ;} \
  && { [[ "$(nvram get wan1_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get wan1_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
    sleep $WANDISABLEDSLEEPTIMER
    continue
  # Return to WAN Status if both interfaces are Enabled and Connected
  elif { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
  && { [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan1_state_t)" == "2" ]] ;} >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" are enabled and connected"
    break
  # Return to WAN Status if both interfaces are Enabled and have Real IP Addresses
  elif { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
  && { [[ "$(nvram get wan0_realip_state)" == "2" ]] && [[ "$(nvram get wan1_realip_state)" == "2" ]] ;} >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" are enabled and connected"
    break
  # Return to WAN Status if only WAN0 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif [[ "$(nvram get wans_mode)" == "fo" ]] \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] \
  && [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if only WAN1 is Enabled and Connected but is not Primary WAN - Failover Mode
  elif [[ "$(nvram get wans_mode)" == "fo" ]] \
  && { [[ "$(nvram get wan0_enable)" == "0" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] \
  && [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan0_primary)" == "1" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 is Connected and is not Primary WAN. - Failover Mode
  elif [[ "$(nvram get wans_mode)" == "fo" ]] \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] \
  && [[ "$(nvram get wan0_state_t)" == "2" ]] && [[ "$(nvram get wan0_primary)" == "0" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 is Connected and is not Primary WAN. - Failover Mode
  elif [[ "$(nvram get wans_mode)" == "fo" ]] \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] \
  && [[ "$(nvram get wan1_state_t)" == "2" ]] && [[ "$(nvram get wan1_primary)" == "0" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 has a Real IP Address and is not Primary WAN. - Failover Mode
  elif [[ "$(nvram get wans_mode)" == "fo" ]] \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
  && { [[ "$(nvram get wan0_realip_state)" == "2" ]] && [[ "$(nvram get wan1_realip_state)" != "2" ]] && [[ "$(nvram get wan0_primary)" == "0" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 has a Real IP Address and is not Primary WAN. - Failover Mode
  elif [[ "$(nvram get wans_mode)" == "fo" ]] \
  && { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} \
  && { [[ "$(nvram get wan0_realip_state)" != "2" ]] && [[ "$(nvram get wan1_realip_state)" == "2" ]] && [[ "$(nvram get wan1_primary)" == "0" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN1" has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are pinging both Target IP Addresses.
  elif { [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
  && [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" and "$WAN1" have 0% packet loss"
    break
  # Return to WAN Status if WAN0 is pinging the Target IP Address and WAN1 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
  && { [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN1 is pinging the Target IP Address and WAN0 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get wan1_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
  && { [[ "$(nvram get wan0_primary)" == "1" ]] && [[ "$(ping -I $(nvram get wan0_gw_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -p 3 -st "${0##*/}" "WAN Failover Disabled - "$WAN0" has 0% packet loss but is not Primary WAN"
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
logger -p 3 -st "${0##*/}" "WAN Failover Disabled - Returning to check WAN Status"

# Debug Logging
logger -p 6 -t "${0##*/}" "Debug - ***WAN Disabled Loop Ended***"
debuglog || return

# Return to WAN Status
wanstatus
}

# Switch WAN
switchwan ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: switchwan"

# Delay if NVRAM is not accessible
nvramcheck || return

# Determine Current Primary WAN and change it to the Inactive WAN
for WANPREFIX in ${WANPREFIXES};do
  if [[ "$(nvram get ${WANPREFIX}_primary)" == "1" ]] >/dev/null;then
    INACTIVEWAN="${WANPREFIX}"
    logger -p 6 -t "${0##*/}" "Debug - Inactive WAN: "${WANPREFIX}""
    continue
  elif [[ "$(nvram get ${WANPREFIX}_primary)" == "0" ]] >/dev/null;then
    ACTIVEWAN="${WANPREFIX}"
    logger -p 6 -t "${0##*/}" "Debug - Active WAN: "${WANPREFIX}""
    continue
  fi
done
# Verify new Active WAN Gateway IP or IP Address are not 0.0.0.0
if { [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get "$ACTIVEWAN"_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
  logger -p 1 -st "${0##*/}" "WAN Switch - "$ACTIVEWAN" is disconnected.  IP Address: "$(nvram get "$ACTIVEWAN"_ipaddr)" Gateway: "$(nvram get "$ACTIVEWAN"_gateway)""
  wanstatus
fi
# Perform WAN Switch until Secondary WAN becomes Primary WAN
until { [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] && [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] ;} \
&& { [[ "$(echo $(ip route show default | awk '{print $3}'))" == "$(nvram get "$ACTIVEWAN"_gateway)" ]] && [[ "$(echo $(ip route show default | awk '{print $5}'))" == "$(nvram get "$ACTIVEWAN"_gw_ifname)" ]] ;} \
&& { [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" == "$(nvram get wan_ipaddr)" ]] && [[ "$(nvram get "$ACTIVEWAN"_gateway)" == "$(nvram get wan_gateway)" ]] && [[ "$(nvram get "$ACTIVEWAN"_gw_ifname)" == "$(nvram get wan_gw_ifname)" ]] ;} >/dev/null;do
  # Change Primary WAN
  if [[ "$(nvram get "$ACTIVEWAN"_primary)" != "1" ]] && [[ "$(nvram get "$INACTIVEWAN"_primary)" != "0" ]] >/dev/null;then
    logger -p 1 -st "${0##*/}" "WAN Switch - Switching $ACTIVEWAN to Primary WAN"
    nvram set "$ACTIVEWAN"_primary=1 ; nvram set "$INACTIVEWAN"_primary=0
  fi
  # Change WAN IP Address
  if [[ "$(nvram get "$ACTIVEWAN"_ipaddr)" != "$(nvram get wan_ipaddr)" ]] >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Switch - WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr)"
    nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr)
  fi

  # Change WAN Gateway
  if [[ "$(nvram get "$ACTIVEWAN"_gateway)" != "$(nvram get wan_gateway)" ]] >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Switch - WAN Gateway IP: $(nvram get "$ACTIVEWAN"_gateway)"
    nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway)
  fi
  # Change WAN Interface
  if [[ "$(nvram get "$ACTIVEWAN"_gw_ifname)" != "$(nvram get wan_gw_ifname)" ]] >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Switch - WAN Interface: $(nvram get "$ACTIVEWAN"_gw_ifname)"
    nvram set wan_gw_ifname=$(nvram get "$ACTIVEWAN"_gw_ifname)
  fi
  if [[ "$(nvram get "$ACTIVEWAN"_ifname)" != "$(nvram get wan_ifname)" ]] >/dev/null;then
    if [[ "$(nvram get "$ACTIVEWAN"_ifname)" != "$(nvram get "$ACTIVEWAN"_gw_ifname)" ]] >/dev/null;then
      logger -p 4 -st "${0##*/}" "WAN Switch - WAN Interface: $(nvram get "$ACTIVEWAN"_ifname)"
    fi
    nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname)
  fi

# Switch DNS
  # Check if AdGuard is Running or AdGuard Local is Enabled
  if [ ! -z "$(pidof AdGuardHome)" ] || { [ -f "/opt/etc/AdGuardHome/.config" ] && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] ;} >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Switch - DNS is being managed by AdGuard"
  # Change Manual DNS Settings
  elif [[ "$(nvram get "$ACTIVEWAN"_dnsenable_x)" == "0" ]] >/dev/null;then
    # Change Manual DNS1 Server
    if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns1_x))")" ] >/dev/null;then
      logger -p 4 -st "${0##*/}" "WAN Switch - DNS1 Server: "$(nvram get "$ACTIVEWAN"_dns1_x)""
      nvram set wan_dns1_x=$(nvram get "$ACTIVEWAN"_dns1_x)
      sed -i '1i nameserver '$(nvram get "$ACTIVEWAN"_dns1_x)'' $DNSRESOLVFILE
      sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns1_x)'/d' $DNSRESOLVFILE
    elif [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns1_x))")" ] >/dev/null;then
      logger -p 5 -st "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server"
    elif [ -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] >/dev/null;then
      logger -p 3 -st "${0##*/}" "WAN Switch - No DNS1 Server for $ACTIVEWAN"
    fi
    # Change Manual DNS2 Server
    if [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns2_x))")" ] >/dev/null;then
      logger -p 4 -st "${0##*/}" "WAN Switch - DNS2 Server: "$(nvram get "$ACTIVEWAN"_dns2_x)""
      nvram set wan_dns2_x=$(nvram get "$ACTIVEWAN"_dns2_x)
      sed -i '2i nameserver '$(nvram get "$ACTIVEWAN"_dns2_x)'' $DNSRESOLVFILE
      sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns2_x)'/d' $DNSRESOLVFILE
    elif [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns2_x))")" ] >/dev/null;then
      logger -p 5 -st "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server"
    elif [ -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
      logger -p 3 -st "${0##*/}" "WAN Switch - No DNS2 Server for $ACTIVEWAN"
    fi

  # Change Automatic ISP DNS Settings
  elif [[ "$(nvram get "$ACTIVEWAN"_dnsenable_x)" == "1" ]] >/dev/null;then
    if [[ "$(nvram get "$ACTIVEWAN"_dns)" != "$(nvram get wan_dns)" ]] >/dev/null;then
      logger -p 4 -st "${0##*/}" "WAN Switch - Automatic DNS Settings from ISP: "$(nvram get "$ACTIVEWAN"_dns)""
      nvram set wan_dns="$(echo $(nvram get "$ACTIVEWAN"_dns))"
    fi
    # Change Automatic DNS1 Server
    if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')")" ] >/dev/null;then
      sed -i '1i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')'' $DNSRESOLVFILE
      sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $1}')'/d' $DNSRESOLVFILE
    elif [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')")" ] >/dev/null;then
      logger -p 5 -st "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server"
    elif [ -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] >/dev/null;then
      logger -p 3 -st "${0##*/}" "WAN Switch - DNS1 Server not detected in Automatic ISP Settings for $ACTIVEWAN"
    fi
    # Change Automatic DNS2 Server
    if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] && [ -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')")" ] >/dev/null;then
      sed -i '2i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')'' $DNSRESOLVFILE
      sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $2}')'/d' $DNSRESOLVFILE
    elif [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] && [ ! -z "$(awk -F " " '{print $2}' "$DNSRESOLVFILE" | grep -w "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')")" ] >/dev/null;then
      logger -p 5 -st "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server"
    elif [ -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] >/dev/null;then
      logger -p 3 -st "${0##*/}" "WAN Switch - DNS2 Server not detected in Automatic ISP Settings for $ACTIVEWAN"
    fi
  else
    logger -p 2 -st "${0##*/}" "WAN Switch - No DNS Settings Detected"
  fi

  # Delete Old Default Route
  if [ ! -z "$(ip route list default | grep -e "$(nvram get "$INACTIVEWAN"_gw_ifname)")" ]  >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Switch - Deleting default route via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_gw_ifname)""
    ip route del default
  fi
  # Add New Default Route
  if [ -z "$(ip route list default | grep -e "$(nvram get "$ACTIVEWAN"_gw_ifname)")" ]  >/dev/null;then
    logger -p 4 -st "${0##*/}" "WAN Switch - Adding default route via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_gw_ifname)""
    ip route add default via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_gw_ifname)
  fi

  # Change QoS Settings
  if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
    logger -p 5 -st "${0##*/}" "WAN Switch - QoS is Enabled"
    if [[ ! -z "$(nvram get qos_obw)" ]] && [[ ! -z "$(nvram get qos_obw)" ]] >/dev/null;then
      logger -p 4 -st "${0##*/}" "WAN Switch - Applying Manual QoS Bandwidth Settings"
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
      logger -p 5 -st "${0##*/}" "WAN Switch - QoS Settings: Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps"
    fi
  elif [[ "$(nvram get qos_enable)" == "0" ]] >/dev/null;then
    logger -p 5 -st "${0##*/}" "WAN Switch - QoS is Disabled"
  fi
  sleep 1
done
  if [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] && [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] >/dev/null;then
    logger -p 1 -st "${0##*/}" "WAN Switch - Switched $ACTIVEWAN to Primary WAN"
  else
    debuglog || continue
  fi
restartservices
}

# Restart Services
restartservices ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: restartservices"

# Delay if NVRAM is not accessible
nvramcheck || return

# Check for services that need to be restarted:
logger -p 6 -t "${0##*/}" "Debug - Checking which services need to be restarted"
SERVICES=""
if [ ! -z "$(pidof dnsmasq)" ] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Dnsmasq is running"
  SERVICE="dnsmasq"
  SERVICES="${SERVICES} ${SERVICE}"
fi
if [[ "$(nvram get fw_enable_x)" == "1" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Firewall is enabled"
  SERVICE="firewall"
  SERVICES="${SERVICES} ${SERVICE}"
fi
if [[ "$(nvram get led_disable)" == "0" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - LEDs are enabled"
  SERVICE="leds"
  SERVICES="${SERVICES} ${SERVICE}"
fi
if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - QoS is enabled"
  SERVICE="qos"
  SERVICES="${SERVICES} ${SERVICE}"
fi

# Restart Services
for SERVICE in ${SERVICES};do
  logger -p 4 -st "${0##*/}" "Service Restart - Restarting $SERVICE service"
  service restart_$SERVICE
  logger -p 4 -st "${0##*/}" "Service Restart - Restarted $SERVICE service"
done

# Trigger YazFi if installed
logger -p 6 -t "${0##*/}" "Debug - Checking if YazFi is installed"
if [ ! -z "$(cru l | grep -w "YazFi")" ] && [ -f "/jffs/scripts/YazFi" ] >/dev/null;then
  logger -p 4 -st "${0##*/}" "Service Restart - Triggering YazFi to update"
  sh /jffs/scripts/YazFi check &
fi

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
logger -p 6 -t "${0##*/}" "Debug - Function: sendemail"

# Delay if NVRAM is not accessible
nvramcheck || return

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
    logger -p 5 -st "${0##*/}" "Email Notification - Email Notifications Enabled"
  elif [[ "$OPTION" == "disable" ]] >/dev/null;then
    SETSENDEMAIL=0
    logger -p 5 -st "${0##*/}" "Email Notification - Email Notifications Disabled"
  else
    echo -e "${RED}Invalid Selection!!! Select enable or disable${NOCOLOR}"
    exit
  fi
  if [ -z "$(awk -F "=" '/SENDEMAIL/ {print $1}' "$CONFIGFILE")" ] >/dev/null;then
    echo -e "SENDEMAIL=" >> $CONFIGFILE
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    killscript
  else
    sed -i -e "s/\(^SENDEMAIL=\).*/\1"$SETSENDEMAIL"/" $CONFIGFILE
    killscript
  fi
  exit
fi

# Send email notification if Alert Preferences are configured if System Uptime is more than Boot Delay Timer + Variable SKIPEMAILSYSEMUPTIME seconds.
if [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -ge "$(($SKIPEMAILSYSTEMUPTIME+$BOOTDELAYTIMER))" ]] && { [ -f "$AIPROTECTION_EMAILCONFIG" ] || [ -f "$AMTM_EMAILCONFIG" ] ;} >/dev/null;then

  # Check for old mail temp file and delete it or create file and set permissions
  logger -p 6 -t "${0##*/}" "Debug - Checking if "$TMPEMAILFILE" exists"
  if [ -f "$TMPEMAILFILE" ] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - Deleting "$TMPEMAILFILE""
    rm "$TMPEMAILFILE"
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  elif [ ! -f "$TMPEMAILFILE" ] >/dev/null;then
    touch -a "$TMPEMAILFILE"
    chmod 666 "$TMPEMAILFILE"
  fi
  
  # Determine Subject Name
  logger -p 6 -t "${0##*/}" "Debug - Selecting Subject Name"
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
    echo "Subject: WAN Load Balancing Notification" >"$TMPEMAILFILE"
  elif [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failover Notification" >"$TMPEMAILFILE"
  elif [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failback Notification" >"$TMPEMAILFILE"
  fi

  # Determine From Name
  logger -p 6 -t "${0##*/}" "Debug - Selecting From Name"
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
    echo "From: \"$TO_NAME\"<$FROM_ADDRESS>" >>"$TMPEMAILFILE"
  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null;then
    echo "From: \"$MY_NAME\"<$MY_EMAIL>" >>"$TMPEMAILFILE"
  fi
  echo "Date: $(date -R)" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine Email Header
  logger -p 6 -t "${0##*/}" "Debug - Selecting Email Header"
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
    echo "***WAN Load Balancing Notification***" >>"$TMPEMAILFILE"
  elif [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failover Notification***" >>"$TMPEMAILFILE"
  elif [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failback Notification***" >>"$TMPEMAILFILE"
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"

  # Determine Hostname
  logger -p 6 -t "${0##*/}" "Debug - Selecting Hostname"
  if [ ! -z "$(nvram get ddns_hostname_x)" ] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - DDNS Hostname: $(nvram get ddns_hostname_x)"
    echo "Hostname: $(nvram get ddns_hostname_x)" >>"$TMPEMAILFILE"
  elif [ ! -z "$(nvram get lan_hostname)" ] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - LAN Hostname: $(nvram get lan_hostname)"
    echo "Hostname: $(nvram get lan_hostname)" >>"$TMPEMAILFILE"
  fi
  echo "Event Time: $(date | awk '{print $2,$3,$4}')" >>"$TMPEMAILFILE"

  # Determine Parameters to send based on Dual WAN Mode
  logger -p 6 -t "${0##*/}" "Debug - Selecting Parameters based on Dual WAN Mode: "$(nvram get wans_mode)""
  if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - WAN0 IP Address: $(nvram get wan0_ipaddr)"
    echo "WAN0 IPv4 Address: $(nvram get wan0_ipaddr)" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - WAN0 Status: $WAN0STATUS"
    echo "WAN0 Status: "$WAN0STATUS"" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - WAN1 IP Address: $(nvram get wan1_ipaddr)"
    echo "WAN1 IPv4 Address: $(nvram get wan1_ipaddr)" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - WAN1 Status: $WAN1STATUS"
    echo "WAN1 Status: "$WAN1STATUS"" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - IPv6 IP Address: $(nvram get ipv6_wan_addr)"
    if [ ! -z "$(nvram get ipv6_wan_addr)" ] >/dev/null;then
      echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>"$TMPEMAILFILE"
    fi
  elif [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - Connecting to ipinfo.io for Active ISP"
    echo "Active ISP: $(curl ipinfo.io | grep -e "org" | awk '{print $3" "$4}' | cut -f 1 -d "," | cut -f 1 -d '"' || continue)" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - WAN IP Address: $(nvram get wan_ipaddr)"
    echo "WAN IPv4 Address: $(nvram get wan_ipaddr)" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - IPv6 IP Address: $(nvram get ipv6_wan_addr)"
    if [ ! -z "$(nvram get ipv6_wan_addr)" ] >/dev/null;then
      echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>"$TMPEMAILFILE"
    fi
    logger -p 6 -t "${0##*/}" "Debug - WAN Gateway IP Address: $(nvram get wan_gateway)"
    echo "WAN Gateway IP Address: $(nvram get wan_gateway)" >>"$TMPEMAILFILE"
    logger -p 6 -t "${0##*/}" "Debug - WAN Interface: $(nvram get wan_gw_ifname)"
    echo "WAN Interface: $(nvram get wan_gw_ifname)" >>"$TMPEMAILFILE"
    # Check if AdGuard is Running or if AdGuard Local is Enabled
    logger -p 6 -t "${0##*/}" "Debug - Checking if AdGuardHome is running"
    if [ ! -z "$(pidof AdGuardHome)" ] || { [ -f "/opt/etc/AdGuardHome/.config" ] && [ ! -z "$(awk -F "=" '/ADGUARD_LOCAL/ {print $2}' "/opt/etc/AdGuardHome/.config" | sed -e 's/^"//' -e 's/"$//' | grep -w ^"YES")" ] ;} >/dev/null;then
      echo "DNS: Managed by AdGuardHome" >>"$TMPEMAILFILE"
    else
      logger -p 6 -t "${0##*/}" "Debug - Checking for Automatic or Manual DNS Settings. WAN DNS Enable: $(nvram get wan_dnsenable_x)"
      if [[ "$(nvram get wan_dnsenable_x)" == "0" ]] >/dev/null;then
        logger -p 6 -t "${0##*/}" "Debug - Manual DNS Server 1: $(nvram get wan_dns1_x)"
        if [ ! -z "$(nvram get wan_dns1_x)" ] >/dev/null;then
          echo "DNS Server 1: $(nvram get wan_dns1_x)" >>"$TMPEMAILFILE"
        else
          echo "DNS Server 1: N/A" >>"$TMPEMAILFILE"
        fi
        logger -p 6 -t "${0##*/}" "Debug - Manual DNS Server 2: $(nvram get wan_dns2_x)"
        if [ ! -z "$(nvram get wan_dns2_x)" ] >/dev/null;then
          echo "DNS Server 2: $(nvram get wan_dns2_x)" >>"$TMPEMAILFILE"
        else
          echo "DNS Server 2: N/A" >>"$TMPEMAILFILE"
        fi
      elif [[ "$(nvram get wan_dnsenable_x)" == "1" ]] >/dev/null;then
        logger -p 6 -t "${0##*/}" "Debug - Automatic DNS Servers: $(nvram get wan_dns)"
        if [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $1}')" ] >/dev/null;then
          echo "DNS Server 1: $(echo $(nvram get wan_dns) | awk '{print $1}')" >>"$TMPEMAILFILE"
        else
          echo "DNS Server 1: N/A" >>"$TMPEMAILFILE"
        fi
        if [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $2}')" ] >/dev/null;then
          echo "DNS Server 2: $(echo $(nvram get wan_dns) | awk '{print $2}')" >>"$TMPEMAILFILE"
        else
          echo "DNS Server 2: N/A" >>"$TMPEMAILFILE"
        fi
      fi
    fi
    logger -p 6 -t "${0##*/}" "Debug - QoS Enabled: $(nvram get qos_enable)"
    if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
      echo "QoS Status: Enabled" >>"$TMPEMAILFILE"
      logger -p 6 -t "${0##*/}" "Debug - QoS Outbound Bandwidth: $(nvram get qos_obw)"
      logger -p 6 -t "${0##*/}" "Debug - QoS Inbound Bandwidth: $(nvram get qos_ibw)"
      if [[ ! -z "$(nvram get qos_obw)" ]] && [[ ! -z "$(nvram get qos_ibw)" ]] >/dev/null;then
        echo "QoS Mode: Manual Settings" >>"$TMPEMAILFILE"
        echo "QoS Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps" >>"$TMPEMAILFILE"
        echo "QoS Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps" >>"$TMPEMAILFILE"
        logger -p 6 -t "${0##*/}" "Debug - QoS WAN Packet Overhead: $(nvram get qos_overhead)"
        echo "QoS WAN Packet Overhead: $(nvram get qos_overhead)" >>"$TMPEMAILFILE"
      else
        echo "QoS Mode: Automatic Settings" >>"$TMPEMAILFILE"
      fi
    fi
  fi
  echo "----------------------------------------------------------------------------------------" >>"$TMPEMAILFILE"
  echo "" >>"$TMPEMAILFILE"

  # Determine whether to use AMTM or AIProtection Email Configuration
  logger -p 6 -t "${0##*/}" "Debug - Selecting AMTM or AIProtection for Email Notification"
  if [ -f "$AMTM_EMAILCONFIG" ] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - AMTM Email Configuration Detected"
    if [ -z "$FROM_ADDRESS" ] || [ -z "$TO_NAME" ] || [ -z "$TO_ADDRESS" ] || [ -z "$USERNAME" ] || [ ! -f "$AMTM_EMAIL_DIR/emailpw.enc" ] || [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] >/dev/null;then
      logger -p 2 -st "${0##*/}" "Email Notification - AMTM Email Configuration Incomplete"
    else
	$(/usr/sbin/curl --connect-timeout $EMAILTIMEOUT --max-time $EMAILTIMEOUT --url $PROTOCOL://$SMTP:$PORT \
		--mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
		--upload-file "$TMPEMAILFILE" \
		--ssl-reqd \
		--user "$USERNAME:$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$AMTM_EMAIL_DIR/emailpw.enc" -pass pass:ditbabot,isoi)" $SSL_FLAG) \
		&& $(rm "$TMPEMAILFILE" &) || continue
    fi
  elif [ -f "$AIPROTECTION_EMAILCONFIG" ] >/dev/null;then
    logger -p 6 -t "${0##*/}" "Debug - AIProtection Alerts Email Configuration Detected"
    if [ ! -z "$SMTP_SERVER" ] && [ ! -z "$SMTP_PORT" ] && [ ! -z "$MY_NAME" ] && [ ! -z "$MY_EMAIL" ] && [ ! -z "$SMTP_AUTH_USER" ] && [ ! -z "$SMTP_AUTH_PASS" ] >/dev/null;then
      $(cat "$TMPEMAILFILE" | sendmail -w $EMAILTIMEOUT -H "exec openssl s_client -quiet -CAfile $CAFILE -connect $SMTP_SERVER:$SMTP_PORT -tls1_3 -starttls smtp" -f"$MY_EMAIL" -au"$SMTP_AUTH_USER" -ap"$SMTP_AUTH_PASS" "$MY_EMAIL") \
      && $(rm "$TMPEMAILFILE" &) || continue
    else
      logger -p 2 -st "${0##*/}" "Email Notification - AIProtection Alerts Email Configuration Incomplete"
    fi
  fi
  
  # Check if temporary file was deleted and log if email was sent
  logger -p 6 -t "${0##*/}" "Debug - Checking if "$TMPEMAILFILE" was deleted and log if email was sent"
  if [ ! -f "$TMPEMAILFILE" ] >/dev/null;then
    logger -p 4 -st "${0##*/}" "Email Notification - Email Notification Sent"
  elif [ -f "$TMPEMAILFILE" ] >/dev/null;then
    logger -p 2 -st "${0##*/}" "Email Notification - Email Notification Failed"
    rm "$TMPEMAILFILE"
  fi
else
  logger -p 6 -t "${0##*/}" "Debug - Email Notifications are not configured"
fi

# Determine Dual WAN Mode and return
logger -p 6 -t "${0##*/}" "Debug - Returning based on based on Dual WAN Mode: "$(nvram get wans_mode)""
if [[ "$(nvram get wans_mode)" == "lb" ]] >/dev/null;then
  lbmonitor || wanstatus
elif  [[ "$(nvram get wans_mode)" == "fo" ]] >/dev/null;then
  wanevent || wanstatus
fi
}

# Trigger WAN Event
wanevent ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: wanevent"
if [[ "${mode}" != "manual" ]] >/dev/null;then
  if [ -f "/jffs/scripts/wan-event" ] >/dev/null;then
    sh -c /jffs/scripts/wan-event &
  fi
fi
wanstatus
}

# Delay if NVRAM is not accessible
nvramcheck ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: nvramcheck"
if [ -z "$(nvram get model)" ] >/dev/null;then
  logger -p 1 -st "${0##*/}" "***NVRAM Inaccessible***"
  NVRAMTIMEOUT="$(($(awk -F "." '{print $1}' "/proc/uptime")+5))"
  while [ -z "$(nvram get model)" ] && [[ "$(awk -F "." '{print $1}' "/proc/uptime")" -le "$NVRAMTIMEOUT" ]] >/dev/null;do
    if tty >/dev/null 2>&1;then
      TIMEOUTTIMER=$(($NVRAMTIMEOUT-$(awk -F "." '{print $1}' "/proc/uptime")))
      printf '%s\r' "***Waiting for NVRAM Access*** Timeout: "$TIMEOUTTIMER" Seconds"
    fi
    sleep 1
  done
  return
fi
logger -p 6 -t "${0##*/}" "Debug - ***NVRAM Check Passed***"
return
}

# Debug Logging
debuglog ()
{
logger -p 6 -t "${0##*/}" "Debug - Function: debuglog"

# Delay if NVRAM is not accessible
nvramcheck || return

if [[ "$(nvram get log_level)" -ge "7" ]] >/dev/null;then
  logger -p 6 -t "${0##*/}" "Debug - Dual WAN Mode: "$(nvram get wans_mode)""
  logger -p 6 -t "${0##*/}" "Debug - Dual WAN Interfaces: "$(nvram get wans_dualwan)""
  logger -p 6 -t "${0##*/}" "Debug - ASUS Factory Watchdog: "$(nvram get wandog_enable)""
  logger -p 6 -t "${0##*/}" "Debug - Firewall Enabled: "$(nvram get fw_enable_x)""
  logger -p 6 -t "${0##*/}" "Debug - LEDs Disabled: "$(nvram get led_disable)""
  logger -p 6 -t "${0##*/}" "Debug - QoS Enabled: "$(nvram get qos_enable)""
  logger -p 6 -t "${0##*/}" "Debug - DDNS Hostname: "$(nvram get ddns_hostname_x)""
  logger -p 6 -t "${0##*/}" "Debug - LAN Hostname: "$(nvram get lan_hostname)""
  logger -p 6 -t "${0##*/}" "Debug - WAN IPv6 Address: "$(nvram get ipv6_wan_addr)""
  logger -p 6 -t "${0##*/}" "Debug - Default Route: "$(ip route list default table main)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Enabled: "$(nvram get wan0_enable)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Routing Table Default Route: "$(ip route list default table "$WAN0ROUTETABLE")""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Rule: "$(ip rule list from all iif lo to "$WAN0TARGET" lookup "$WAN0ROUTETABLE")""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 IP Address: "$(nvram get wan0_ipaddr)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Real IP Address: "$(nvram get wan0_realip_ip)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Real IP Address State: "$(nvram get wan0_realip_state)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Gateway IP: "$(nvram get wan0_gateway)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Gateway Interface: "$(nvram get wan0_gw_ifname)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Interface: "$(nvram get wan0_ifname)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 State: "$(nvram get wan0_state_t)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Primary Status: "$(nvram get wan0_primary)""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Target IP Address: "$WAN0TARGET""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Routing Table: "$WAN0ROUTETABLE""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 IP Rule Priority: "$WAN0TARGETRULEPRIORITY""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Mark: "$WAN0MARK""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 Mask: "$WAN0MASK""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 From WAN Priority: "$FROMWAN0PRIORITY""
  logger -p 6 -t "${0##*/}" "Debug - WAN0 To WAN Priority: "$TOWAN0PRIORITY""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Enabled: "$(nvram get wan1_enable)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Routing Table Default Route: "$(ip route list default table "$WAN1ROUTETABLE")""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Rule: "$(ip rule list from all iif lo to "$WAN1TARGET" lookup "$WAN1ROUTETABLE")""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 IP Address: "$(nvram get wan1_ipaddr)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Real IP Address: "$(nvram get wan1_realip_ip)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Real IP Address State: "$(nvram get wan1_realip_state)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Gateway IP: "$(nvram get wan1_gateway)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Gateway Interface: "$(nvram get wan1_gw_ifname)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Interface: "$(nvram get wan1_ifname)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 State: "$(nvram get wan1_state_t)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Primary Status: "$(nvram get wan1_primary)""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Target IP Address: "$WAN1TARGET""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Routing Table: "$WAN1ROUTETABLE""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 IP Rule Priority: "$WAN1TARGETRULEPRIORITY""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Mark: "$WAN1MARK""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 Mask: "$WAN1MASK""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 From WAN Priority: "$FROMWAN1PRIORITY""
  logger -p 6 -t "${0##*/}" "Debug - WAN1 To WAN Priority: "$TOWAN1PRIORITY""
fi
return
}
scriptmode