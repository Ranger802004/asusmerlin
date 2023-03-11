#!/bin/sh

#  Variables
CONFIGFILE="/jffs/configs/wan-failover.conf"
LOGFILE="/tmp/wan-failover-tester-$(date +"%F-%T-%Z").log"

if [[ -f "$CONFIGFILE" ]] &>/dev/null && [[ ! -z "$(ps | grep -v "grep" | grep -w "/jffs/scripts/wan-failover.sh" | grep -w "run\|manual")" ]] &>/dev/null;then
  . $CONFIGFILE
else
  echo -e "WAN Failover is not running..." \
  && return
fi

pingwan0target ()
{
if [[ "$(nvram get wan0_state_t)" == "2" ]] &>/dev/null;then
  echo -e "Pinging WAN0 Target: $WAN0TARGET"
  WAN0GWIFNAME=$(nvram get wan0_gw_ifname)
  PINGWAN0TARGETOUTPUT="$(ping -I $WAN0GWIFNAME $WAN0TARGET -q -c $PINGCOUNT -W $(($PINGCOUNT*PINGTIMEOUT)) -w $(($PINGCOUNT*PINGTIMEOUT)) -s $WAN0PACKETSIZE 2>/dev/null)" \
  && WAN0PACKETLOSS="$(echo $PINGWAN0TARGETOUTPUT | awk '/packet loss/ {print $18}')"
  if [[ "$WAN0PACKETLOSS" != "100%" ]] &>/dev/null;then
    WAN0PINGTIME="$(echo $PINGWAN0TARGETOUTPUT | awk '/packet loss/ {print $24}' | awk -F "/" '{print $3}' | cut -f 1 -d ".")"
  else
    WAN0PINGTIME="N\/A"
  fi
  [[ ! -z "${WAN0PACKETLOSS+x}" ]] &>/dev/null && echo -e "WAN0 Packet Loss: $WAN0PACKETLOSS"
  [[ ! -z "${WAN0PINGTIME+x}" ]] &>/dev/null && echo -e "WAN0 Ping Time: "$WAN0PINGTIME"ms"
  echo -e "WAN0 Target IP Rules: \n$(ip rule list | grep -w "to $WAN0TARGET")"
  echo -e "WAN0 Routing Table: \n$(ip route list table $WAN0ROUTETABLE)"
  echo -e "WAN0 Gateway ARP Entry: \n$(arp -a $(nvram get wan0_gateway))"
else
  echo -e "WAN0 is not Connected"
fi
return
}

pingwan1target ()
{
if [[ "$(nvram get wan1_state_t)" == "2" ]] &>/dev/null;then
  echo -e "Pinging WAN1 Target: $WAN1TARGET"
  WAN1GWIFNAME=$(nvram get wan1_gw_ifname)
  PINGWAN1TARGETOUTPUT="$(ping -I $WAN1GWIFNAME $WAN1TARGET -q -c $PINGCOUNT -W $(($PINGCOUNT*PINGTIMEOUT)) -w $(($PINGCOUNT*PINGTIMEOUT)) -s $WAN1PACKETSIZE 2>/dev/null)" \
  && WAN1PACKETLOSS="$(echo $PINGWAN1TARGETOUTPUT | awk '/packet loss/ {print $18}')"
  if [[ "$WAN1PACKETLOSS" != "100%" ]] &>/dev/null;then
    WAN1PINGTIME="$(echo $PINGWAN1TARGETOUTPUT | awk '/packet loss/ {print $24}' | awk -F "/" '{print $3}' | cut -f 1 -d ".")"
  else
    WAN1PINGTIME="N\/A"
  fi
  [[ ! -z "${WAN1PACKETLOSS+x}" ]] &>/dev/null && echo -e "WAN1 Packet Loss: $WAN1PACKETLOSS"
  [[ ! -z "${WAN1PINGTIME+x}" ]] &>/dev/null && echo -e "WAN1 Ping Time: "$WAN1PINGTIME"ms"
  echo -e "WAN1 Target IP Rules: \n$(ip rule list | grep -w "to $WAN1TARGET")"
  echo -e "WAN1 Routing Table: \n$(ip route list table $WAN1ROUTETABLE)"
  echo -e "WAN1 Gateway ARP Entry: \n$(arp -a $(nvram get wan1_gateway))"
else
  echo -e "WAN1 is not Connected"
fi
return
}

pingwan0target
if [[ ! -z "${WAN0PACKETLOSS+x}" ]] &>/dev/null;then
  if [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Attempting to ping WAN0 again..."
    pingwan0target
  fi
  zWAN0PACKETSIZE="$WAN0PACKETSIZE"
  if [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
    WAN0PACKETSIZE="56"
    echo -e "Set WAN0 Packet Size to 56 Bytes"
    pingwan0target
  fi
  if [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
    WAN0PACKETSIZE="4"
    echo -e "Set WAN0 Packet Size to 10 Bytes"
    pingwan0target
  fi
  WAN0PACKETSIZE="$zWAN0PACKETSIZE"
  if [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
    PINGTIMEOUT="$(($PINGTIMEOUT*3))"
    echo -e "Increasing Ping Time Out to $((PINGTIMEOUT*PINGCOUNT))"
    pingwan0target
  fi
  if [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Adding IP Rule specifying Inbound and Outbound Interfaces"
    ip rule add iif lo from all to $WAN0TARGET oif $WAN0GWIFNAME table $WAN0ROUTETABLE priority $WAN0PRIORITY &>/dev/null
    pingwan0target
  fi
  if [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Adding IP Rule specifying Inbound Interface"
    ip rule add iif lo from all to $WAN0TARGET table $WAN0ROUTETABLE priority $WAN0PRIORITY &>/dev/null
    pingwan0target
  fi
  if [[ "$WAN0PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Adding route to Main Routing Table"
    ip route add $WAN0TARGET via $WAN0GATEWAY dev $WAN0GWIFNAME
    pingwan0target
  fi
fi

pingwan1target
if [[ ! -z "${WAN1PACKETLOSS+x}" ]] &>/dev/null;then
  if [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Attempting to ping WAN1 again..."
    pingwan1target
  fi
  zWAN1PACKETSIZE="$WAN1PACKETSIZE"
  if [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    WAN1PACKETSIZE="56"
    echo -e "Set WAN1 Packet Size to 56 Bytes"
    pingwan1target
  fi
  if [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    WAN1PACKETSIZE="4"
    echo -e "Set WAN1 Packet Size to 10 Bytes"
    pingwan1target
  fi
  WAN1PACKETSIZE="$zWAN1PACKETSIZE"
  if [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    PINGTIMEOUT="$(($PINGTIMEOUT*3))"
    echo -e "Increasing Ping Time Out to $((PINGTIMEOUT*PINGCOUNT))"
    pingwan1target
  fi
  if [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Adding IP Rule specifying Inbound and Outbound Interfaces"
    ip rule add iif lo from all to $WAN1TARGET oif $WAN1GWIFNAME table $WAN1ROUTETABLE priority $WAN1PRIORITY &>/dev/null
    pingwan1target
  fi
  if [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Adding IP Rule specifying Inbound Interface"
    ip rule add iif lo from all to $WAN1TARGET table $WAN1ROUTETABLE priority $WAN1PRIORITY &>/dev/null
    pingwan1target
  fi
  if [[ "$WAN1PACKETLOSS" == "100%" ]] &>/dev/null;then
    echo -e "Adding route to Main Routing Table"
    ip route add $WAN1TARGET via $WAN1GATEWAY dev $WAN1GWIFNAME
    pingwan1target
  fi
fi

