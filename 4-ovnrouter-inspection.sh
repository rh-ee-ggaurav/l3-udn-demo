#!/bin/bash
#
# L3 UDN - Training Demo
#
# Flow:
# 1. Show all pod UDN IPs, node IPs, routers
# 2. Full diagram showing how everything connects
# 3. Same-node ping + diagram showing what happened
# 4. Cross-node ping + diagram showing what happened
# 5. Summary
#

echo ""
echo "============================================================"
echo "  L3 UDN TRAINING DEMO"
echo "============================================================"
echo ""
echo "  We created a Layer3 UDN called 'my-l3-network'"
echo "  with CIDR 10.50.0.0/16 and hostSubnet /24"
echo ""
echo "  OVN automatically gave each node its own /24 subnet"
echo "  and created a router to connect them."
echo ""
read -p "  Press ENTER to start..."

echo ""
echo "  Gathering data... please wait..."
echo ""

# Gather all data
OVN_M01=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node --field-selector spec.nodeName=master01 -o jsonpath='{.items[0].metadata.name}')
OVN_M02=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node --field-selector spec.nodeName=master02 -o jsonpath='{.items[0].metadata.name}')
OVN_M03=$(oc get pods -n openshift-ovn-kubernetes -l app=ovnkube-node --field-selector spec.nodeName=master03 -o jsonpath='{.items[0].metadata.name}')

NODE1_IP=$(oc get node master01 -o jsonpath='{.status.addresses[0].address}')
NODE2_IP=$(oc get node master02 -o jsonpath='{.status.addresses[0].address}')
NODE3_IP=$(oc get node master03 -o jsonpath='{.status.addresses[0].address}')

POD1_IP=$(oc exec -n l3-demo pod-1 -- ip -4 addr show dev ovn-udn1 | grep inet | awk '{print $2}' | cut -d/ -f1)
POD2_IP=$(oc exec -n l3-demo pod-2 -- ip -4 addr show dev ovn-udn1 | grep inet | awk '{print $2}' | cut -d/ -f1)
POD3_IP=$(oc exec -n l3-demo pod-3 -- ip -4 addr show dev ovn-udn1 | grep inet | awk '{print $2}' | cut -d/ -f1)
POD4_IP=$(oc exec -n l3-demo pod-4 -- ip -4 addr show dev ovn-udn1 | grep inet | awk '{print $2}' | cut -d/ -f1)
POD5_IP=$(oc exec -n l3-demo pod-5 -- ip -4 addr show dev ovn-udn1 | grep inet | awk '{print $2}' | cut -d/ -f1)

POD1_GW=$(oc exec -n l3-demo pod-1 -- ip route show dev ovn-udn1 | grep default | awk '{print $3}')
POD3_GW=$(oc exec -n l3-demo pod-3 -- ip route show dev ovn-udn1 | grep default | awk '{print $3}')
POD5_GW=$(oc exec -n l3-demo pod-5 -- ip route show dev ovn-udn1 | grep default | awk '{print $3}')

SUB1=$(echo $POD1_GW | sed 's/\.[0-9]*$/.0\/24/')
SUB2=$(echo $POD3_GW | sed 's/\.[0-9]*$/.0\/24/')
SUB3=$(echo $POD5_GW | sed 's/\.[0-9]*$/.0\/24/')

UDN_ROUTER="l3.demo_my.l3.network_ovn_cluster_router"

echo "  Done!"

# ============================================================
# STEP 1: Show everything
# ============================================================
echo ""
echo "============================================================"
echo "  STEP 1: ALL THE IPs"
echo "============================================================"
echo ""
echo "  NODE IPs (the actual machines):"
echo ""
echo "    master01:  $NODE1_IP"
echo "    master02:  $NODE2_IP"
echo "    master03:  $NODE3_IP"
echo ""
echo "  POD UDN IPs (on the ovn-udn1 interface):"
echo ""
echo "    pod-1 (master01):  $POD1_IP"
echo "    pod-2 (master01):  $POD2_IP"
echo "    pod-3 (master02):  $POD3_IP"
echo "    pod-4 (master02):  $POD4_IP"
echo "    pod-5 (master03):  $POD5_IP"
echo ""
echo "  UDN SUBNETS (each node got its own /24):"
echo ""
echo "    master01:  $SUB1"
echo "    master02:  $SUB2"
echo "    master03:  $SUB3"
echo ""
echo "  ROUTER GATEWAYS (the door on each node):"
echo ""
echo "    master01:  $POD1_GW"
echo "    master02:  $POD3_GW"
echo "    master03:  $POD5_GW"
echo ""
echo "  OVN created all of this automatically from just:"
echo "    topology: Layer3"
echo "    cidr: 10.50.0.0/16"
echo "    hostSubnet: 24"
echo ""
read -p "  Press ENTER to see the routers..."

# ============================================================
# STEP 2: Show routers
# ============================================================
echo ""
echo "============================================================"
echo "  STEP 2: THE ROUTERS"
echo ""
echo "  OVN created a distributed router."
echo "  It has a PORT on each node - this is the gateway."
echo "============================================================"
echo ""
echo "  Command: ovn-nbctl show (filtered for router ports)"
echo ""
echo "  --- master01 ---"
oc exec -n openshift-ovn-kubernetes $OVN_M01 -c nbdb -- ovn-nbctl show $UDN_ROUTER | grep -A 4 "rtos.*master01"
echo ""
echo "  --- master02 ---"
oc exec -n openshift-ovn-kubernetes $OVN_M02 -c nbdb -- ovn-nbctl show $UDN_ROUTER | grep -A 4 "rtos.*master02"
echo ""
echo "  --- master03 ---"
oc exec -n openshift-ovn-kubernetes $OVN_M03 -c nbdb -- ovn-nbctl show $UDN_ROUTER | grep -A 4 "rtos.*master03"
echo ""
echo "  Each port has a MAC address and a network (gateway IP)."
echo "  This is what pods see when they run 'ip route'."
echo ""
read -p "  Press ENTER to see the full diagram..."

# ============================================================
# STEP 3: Full diagram
# ============================================================
echo ""
echo "============================================================"
echo "  STEP 3: THE FULL PICTURE"
echo ""
echo "  How everything connects:"
echo "============================================================"
echo ""
echo "  +--------------------+   +--------------------+   +--------------------+"
echo "  | master01           |   | master02           |   | master03           |"
echo "  | Node: $NODE1_IP  |   | Node: $NODE2_IP  |   | Node: $NODE3_IP  |"
echo "  | Subnet: $SUB1|   | Subnet: $SUB2|   | Subnet: $SUB3|"
echo "  |                    |   |                    |   |                    |"
echo "  | pod-1: $POD1_IP |   | pod-3: $POD3_IP |   | pod-5: $POD5_IP |"
echo "  | pod-2: $POD2_IP |   | pod-4: $POD4_IP |   |                    |"
echo "  |        |           |   |        |           |   |        |           |"
echo "  |        v           |   |        v           |   |        v           |"
echo "  |   GW: $POD1_GW   |   |   GW: $POD3_GW   |   |   GW: $POD5_GW   |"
echo "  |   (router door)    |   |   (router door)    |   |   (router door)    |"
echo "  +--------+-----------+   +--------+-----------+   +--------+-----------+"
echo "           |                        |                        |"
echo "           +------------------------+------------------------+"
echo "           |                                                 |"
echo "           |           OVN DISTRIBUTED ROUTER                |"
echo "           |     (automatically created by L3 UDN)           |"
echo "           |                                                 |"
echo "           +-------------------------------------------------+"
echo ""
echo "  - Pods on the SAME node share a subnet (e.g. pod-1, pod-2)"
echo "  - Pods on DIFFERENT nodes have different subnets"
echo "  - The router connects all subnets together"
echo ""
read -p "  Press ENTER to test same-node ping..."

# ============================================================
# STEP 4: Same node ping
# ============================================================
echo ""
echo "============================================================"
echo "  STEP 4: SAME NODE PING"
echo ""
echo "  pod-1 ($POD1_IP) --> pod-2 ($POD2_IP)"
echo "  Both on master01, both in subnet $SUB1"
echo "============================================================"
echo ""
echo "  Command: oc exec -n l3-demo pod-1 -- ping -c 3 $POD2_IP"
echo ""
oc exec -n l3-demo pod-1 -- ping -c 3 $POD2_IP
echo ""
echo "  TTL = 64 --> Same node, direct, no router!"
echo ""
echo "  ARP table (pod-1 knows pod-2's MAC directly):"
oc exec -n l3-demo pod-1 -- ip neigh show dev ovn-udn1
echo ""
read -p "  Press ENTER to see the diagram..."

echo ""
echo "============================================================"
echo "  WHAT HAPPENED (same node):"
echo "============================================================"
echo ""
echo "  +--------------------------------------------+"
echo "  | master01          Subnet: $SUB1    |"
echo "  |                                            |"
echo "  |  pod-1              pod-2                  |"
echo "  |  $POD1_IP  ------->  $POD2_IP           |"
echo "  |            direct                          |"
echo "  |            (same subnet)                   |"
echo "  |                                            |"
echo "  |  GW: $POD1_GW  (NOT used)                |"
echo "  |  (router door)                             |"
echo "  +--------------------------------------------+"
echo ""
echo "  pod-1 checked: 'Is $POD2_IP in my subnet $SUB1?'"
echo "  Answer: YES!"
echo "  So pod-1 talked to pod-2 directly."
echo "  The router was NOT involved."
echo "  TTL stayed at 64 (no hops)."
echo ""
read -p "  Press ENTER to test cross-node ping..."

# ============================================================
# STEP 5: Cross node ping
# ============================================================
echo ""
echo "============================================================"
echo "  STEP 5: CROSS NODE PING"
echo ""
echo "  pod-1 ($POD1_IP) on master01  subnet: $SUB1"
echo "  pod-3 ($POD3_IP) on master02  subnet: $SUB2"
echo ""
echo "  DIFFERENT subnets! Router will be used."
echo "============================================================"
echo ""
echo "  Command: oc exec -n l3-demo pod-1 -- ping -c 3 $POD3_IP"
echo ""
oc exec -n l3-demo pod-1 -- ping -c 3 $POD3_IP
echo ""
echo "  TTL = 62 --> Different node, router was used!"
echo ""
echo "  ARP table (pod-1 does NOT know pod-3's MAC):"
oc exec -n l3-demo pod-1 -- ip neigh show dev ovn-udn1
echo ""
echo "  See? No $POD3_IP in the list!"
echo "  pod-1 only knows the gateway ($POD1_GW)."
echo "  It sent the packet to the router."
echo ""
read -p "  Press ENTER to see the diagram..."

echo ""
echo "============================================================"
echo "  WHAT HAPPENED (cross node):"
echo "============================================================"
echo ""
echo "  +--------------------+                     +--------------------+"
echo "  | master01           |                     | master02           |"
echo "  | Subnet: $SUB1|                     | Subnet: $SUB2|"
echo "  |                    |                     |                    |"
echo "  |  pod-1             |                     |             pod-3  |"
echo "  |  $POD1_IP        |                     |        $POD3_IP  |"
echo "  |     |              |                     |              ^     |"
echo "  |     | 1.send to    |                     |   4.deliver  |     |"
echo "  |     |   gateway    |                     |     to pod   |     |"
echo "  |     v              |                     |              |     |"
echo "  |  GW: $POD1_GW    |                     |    GW: $POD3_GW  |"
echo "  |  (router door)     |                     |    (router door)   |"
echo "  +--------+-----------+                     +-----------+--------+"
echo "           |                                             |"
echo "           |  2.router checks:                           |"
echo "           |    '$SUB2 is on master02'       |"
echo "           |    'send via transit highway'               |"
echo "           |                                             |"
echo "           +------ 3.transit highway -------->"
echo "                  (OVN internal network)"
echo ""
echo ""
echo "  Step by step:"
echo ""
echo "  1. pod-1 says: '$POD3_IP is NOT in my subnet $SUB1'"
echo "     Sends packet to gateway $POD1_GW (the router door)"
echo ""
echo "  2. Router on master01 knows: '$SUB2 is on master02'"
echo "     Forwards packet via transit highway"
echo ""
echo "  3. Packet travels through OVN internal network"
echo ""
echo "  4. Router on master02 says: '$SUB2 is MY subnet'"
echo "     Delivers packet to pod-3"
echo ""
echo "  5. pod-3 receives with TTL=62 (passed through 2 routers)"
echo ""
read -p "  Press ENTER to see the summary..."

# ============================================================
# STEP 6: Summary
# ============================================================
echo ""
echo "============================================================"
echo "  STEP 6: SUMMARY"
echo "============================================================"
echo ""
echo "  THE SIMPLE TEST:"
echo ""
echo "  +--------------------------------------------------+"
echo "  | Test               | TTL | What it means         |"
echo "  |--------------------|-----|-----------------------|"
echo "  | pod-1 -> pod-2     | 64  | Same node! Direct.    |"
echo "  | pod-1 -> pod-3     | 62  | Different node!       |"
echo "  |                    |     | Router handled it.    |"
echo "  +--------------------------------------------------+"
echo ""
echo "  TTL=64? Same node. Direct."
echo "  TTL=62? Different node. Router."
echo ""
echo "  WHY THIS MATTERS AT SCALE:"
echo ""
echo "    With L2 (no router):"
echo "      pod-1 shouts 'WHO HAS $POD3_IP?'"
echo "      ALL pods on ALL nodes hear this."
echo "      1000 pods = constant shouting = slow."
echo ""
echo "    With L3 (router):"
echo "      pod-1 sends to gateway $POD1_GW"
echo "      Router already knows the answer."
echo "      Sends directly to the right node."
echo "      No other pod is disturbed."
echo ""
echo "      Like asking the receptionist instead of"
echo "      shouting in a room of 1000 people."
echo ""
echo "============================================================"
echo "  DEMO COMPLETE"
echo "============================================================"
