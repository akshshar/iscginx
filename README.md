# iscginx
ISC DHCP server and NGINX in a docker container to run PXE servers on IOS-XR boxes

# Build Docker image

Adjust the required isc-dhcp configs and nginx configs under the `overlay/defaults/` directory.

Now build Docker image locally:

```
docker build -t akshshar/iscginx .

```

# Set up the configuration on Router

If you're trying to use the router itself as a PXE server for other devices on the LAN, then you may require multiple physical ports associated with a bridge domain in the configuration. 

Note: For all releases of IOS-XR < 7.4.1, only untagged interfaces associated with a bridge domain are supported for Linux applications.

A sample configuration is shown below. Play around with it and adjust based on your requirement:

```
RP/0/RP0/CPU0:ios#show running-config  l2vpn 
Thu Oct 29 08:51:24.677 UTC
l2vpn
 bridge group Test
  bridge-domain 100
   interface FourHundredGigE0/0/0/0
   !
   routed interface BVI100
   !
  !
 !
!

RP/0/RP0/CPU0:ios#show running-config  interface FourHundredGigE 0/0/0/0
Thu Oct 29 08:51:35.785 UTC
interface FourHundredGigE0/0/0/0
 l2transport
 !
!

RP/0/RP0/CPU0:ios#


```

With the above configuration, BVI100 interface should be up in XR and will appear as BV100 in the Linux kernel of the router:

```

RP/0/RP0/CPU0:ios#show l2vpn bridge-domain bd-name 100
Thu Oct 29 08:53:22.698 UTC
Legend: pp = Partially Programmed.
Bridge group: Test, bridge-domain: 100, id: 0, state: up, ShgId: 0, MSTi: 0
  Aging: 300 s, MAC limit: 131072, Action: none, Notification: syslog
  Filter MAC addresses: 0
  ACs: 2 (2 up), VFIs: 0, PWs: 0 (0 up), PBBs: 0 (0 up), VNIs: 0 (0 up)
  List of ACs:
    BV100, state: up, BVI MAC addresses: 1
    FH0/0/0/0, state: up, Static MAC addresses: 0
  List of Access PWs:
  List of VFIs:
  List of Access VFIs:
RP/0/RP0/CPU0:ios#

```
Check the interface in XR kernel by dropping into the bash shell:

```
RP/0/RP0/CPU0:ios#bash
Thu Oct 29 08:54:15.183 UTC
[ios:~]$
[ios:~]$ifconfig BV100
BV100     Link encap:Ethernet  HWaddr 78:6e:f5:7a:29:05  
          inet addr:10.1.1.20  Bcast:0.0.0.0  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:133258 errors:0 dropped:0 overruns:0 frame:0
          TX packets:91606 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:199096568 (189.8 MiB)  TX bytes:6213708 (5.9 MiB)

[ios:~]$

```

Perfect! Now you can spin up the Docker container and start the DHCP and NGINX servers on the BV100 interface to serve devices connecting to the router over the bridge-domain L2 interfaces (like FourHundredGigE0/0/0/0 in the above example).



# Save Docker image into a tarball

```
docker save akshshar/iscginx > iscginx.tar

```

# Copy Docker image to Router running IOS-XR

```

RP/0/RP0/CPU0:ios#scp admin@192.168.122.119:/admin/iscginx/iscginx.tar /misc/dis$
Thu Oct 29 08:43:57.685 UTC
Connecting to 192.168.122.119...
Password: 
  Transferred 66061312 Bytes
  66061312 bytes copied in 10 sec (6401910)bytes/sec

RP/0/RP0/CPU0:ios#
```

# Load the docker image on the Router running IOS-XR

First drop to the bash shell using XR CLI "bash"

```
RP/0/RP0/CPU0:ios#bash
Thu Oct 29 08:45:37.555 UTC
[ios:~]$
[ios:~]$$docker load --input /misc/disk1/iscginx.tar
c50bf1b98176: Loading layer  60.18MB/60.18MB
d5ad657ea3a5: Loading layer  2.048kB/2.048kB
a45228119a09: Loading layer  6.656kB/6.656kB
125eb74543f1: Loading layer  2.048kB/2.048kB
a9405e44381c: Loading layer   2.56kB/2.56kB
Loaded image: akshshar/iscginx:latest
[ios:~]$
```

# Spin up the Docker container to start your own PXE server

Use --net=host to run the docker container in the "default/global" VRF where the BV100 interface was created earlier.
Also change into the `/misc/disk1` directory before using the docker run commandbelow to ensure your mount points have enough disk space.

```
RP/0/RP0/CPU0:ios#bash
Thu Oct 29 08:45:37.555 UTC
[ios:~]$ cd /misc/disk1
[ios:~]$ docker run -itd --name iscginx \
                --net=host \
                -v "$(pwd)/config:/config" \
                -v "$(pwd)/data:/data" \
                -e PUID=`id -u` \
                -e PGID=`id -g` \
                akshshar/iscginx

```

Make sure the Docker container is running:

```

[ios:~]$docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
7b533a29ceda        akshshar/iscginx    "/entrypoint.sh /usr…"   2 seconds ago       Up 1 second                             iscginx
[ios:~]$
[ios:~]$
```

# Check the DHCP and NGINX ports in use

```
[ios:~]$netstat -nlp | grep -E "8080|67"
tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      23982/nginx.conf -g
udp        0      0 0.0.0.0:67              0.0.0.0:*                           23981/dhcpd     
unix  2      [ ACC ]     STREAM     LISTENING     9767872  23925/docker-contai @/containerd-shim/moby/7b533a29cedaafa0b6714895303b0f54d4752540d305ca3f24c366f075db7015/shim.sock
[ios:~]$


```

# View the Docker logs to see incoming requests

```

[ios:~]$docker logs -f iscginx 
2020-10-29 08:58:14,148 CRIT Supervisor is running as root.  Privileges were not dropped because no user is specified in the config file.  If you intend to run as root, you can set user=root in the config file to avoid this message.
2020-10-29 08:58:14,151 INFO supervisord started with pid 1
2020-10-29 08:58:15,155 INFO spawned: 'dhcpd4' with pid 11
2020-10-29 08:58:15,157 INFO spawned: 'nginx' with pid 12
Internet Systems Consortium DHCP Server 4.4.2
Copyright 2004-2020 Internet Systems Consortium.
All rights reserved.
For info, please visit https://www.isc.org/software/dhcp/
2020-10-29 08:58:15,162 INFO success: dhcpd4 entered RUNNING state, process has stayed up for > than 0 seconds (startsecs)
Config file: /config/dhcpd.conf
Database file: /config/dhcpd.leases
PID file: /run/dhcp/dhcpd.pid
Wrote 0 leases to leases file.
Listening on LPF/BV100/78:6e:f5:7a:29:05/10-1-1-0
Sending on   LPF/BV100/78:6e:f5:7a:29:05/10-1-1-0

No subnet declaration for FH0_0_0_0 (no IPv4 addresses).
** Ignoring requests on FH0_0_0_0.  If this is not what
   you want, please write a subnet declaration
   in your dhcpd.conf file for the network segment
   to which interface FH0_0_0_0 is attached. **


No subnet declaration for Mg0_RP0_CPU0_0 (192.168.122.125).
** Ignoring requests on Mg0_RP0_CPU0_0.  If this is not what
   you want, please write a subnet declaration
   in your dhcpd.conf file for the network segment
   to which interface Mg0_RP0_CPU0_0 is attached. **


No subnet declaration for docker0 (172.17.0.1).
** Ignoring requests on docker0.  If this is not what
   you want, please write a subnet declaration
   in your dhcpd.conf file for the network segment
   to which interface docker0 is attached. **

Sending on   Socket/fallback/fallback-net
Server starting service.
2020-10-29 08:58:16,190 INFO success: nginx entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)


```


# Test your PXE server!

In the demo setup, we have a Linux box with interface eth1 connected to FourHundregGig0/0/0/0 port of the Cisco8201 device as seen in the lldp outputs below:

```
[root@localhost iscginx]# lldpcli show neighbors
-------------------------------------------------------------------------------
LLDP neighbors:
-------------------------------------------------------------------------------
Interface:    eth1, via: LLDP, RID: 1, Time: 0 day, 00:00:22
  Chassis:     
    ChassisID:    mac 78:6e:f5:7a:29:06
    SysName:      ios
    SysDescr:     7.2.12, 8000
    MgmtIP:       192.168.122.125
    Capability:   Router, on
  Port:        
    PortID:       ifname FourHundredGigE0/0/0/0
    TTL:          120
-------------------------------------------------------------------------------
[root@localhost iscginx]# 

```

```
RP/0/RP0/CPU0:ios#show lldp  neighbors 
Thu Oct 29 09:07:06.700 UTC
Capability codes:
        (R) Router, (B) Bridge, (T) Telephone, (C) DOCSIS Cable Device
        (W) WLAN Access Point, (P) Repeater, (S) Station, (O) Other

Device ID       Local Intf               Hold-time  Capability     Port ID
localhost       FourHundredGigE0/0/0/0   120        B,R             0200.0c14.0000

Total entries displayed: 1
```


## Testing the DHCP server on the router

With the iscginx docker container running on the router, let's issue a dhclient request on the eth1 interface of the connected linux box to see if things work:

```
[root@localhost iscginx]# dhclient eth1
[root@localhost iscginx]# 


```

With the real-time docker logs on the router, we should see the request come in:

```
[ios:~]$
[ios:~]$docker logs -f iscginx 
2020-10-29 08:58:14,148 CRIT Supervisor is running as root.  Privileges were not dropped because no user is specified in the config file.  If you intend to run as root, you can set user=root in the config file to avoid this message.
2020-10-29 08:58:14,151 INFO supervisord started with pid 1
2020-10-29 08:58:15,155 INFO spawned: 'dhcpd4' with pid 11
2020-10-29 08:58:15,157 INFO spawned: 'nginx' with pid 12
Internet Systems Consortium DHCP Server 4.4.2
Copyright 2004-2020 Internet Systems Consortium.
All rights reserved.
For info, please visit https://www.isc.org/software/dhcp/
2020-10-29 08:58:15,162 INFO success: dhcpd4 entered RUNNING state, process has stayed up for > than 0 seconds (startsecs)
Config file: /config/dhcpd.conf
Database file: /config/dhcpd.leases
PID file: /run/dhcp/dhcpd.pid
Wrote 0 leases to leases file.
Listening on LPF/BV100/78:6e:f5:7a:29:05/10-1-1-0
Sending on   LPF/BV100/78:6e:f5:7a:29:05/10-1-1-0

No subnet declaration for FH0_0_0_0 (no IPv4 addresses).
** Ignoring requests on FH0_0_0_0.  If this is not what
   you want, please write a subnet declaration
   in your dhcpd.conf file for the network segment
   to which interface FH0_0_0_0 is attached. **


No subnet declaration for Mg0_RP0_CPU0_0 (192.168.122.125).
** Ignoring requests on Mg0_RP0_CPU0_0.  If this is not what
   you want, please write a subnet declaration
   in your dhcpd.conf file for the network segment
   to which interface Mg0_RP0_CPU0_0 is attached. **


No subnet declaration for docker0 (172.17.0.1).
** Ignoring requests on docker0.  If this is not what
   you want, please write a subnet declaration
   in your dhcpd.conf file for the network segment
   to which interface docker0 is attached. **

Sending on   Socket/fallback/fallback-net
Server starting service.
2020-10-29 08:58:16,190 INFO success: nginx entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
DHCPREQUEST for 10.1.1.30 from 02:00:0c:14:00:00 via BV100
DHCPACK on 10.1.1.30 to 02:00:0c:14:00:00 via BV100
reuse_lease: lease age 0 (secs) under 25% threshold, reply with unaltered, existing lease for 10.1.1.30
DHCPDISCOVER from 02:00:0c:14:00:00 via BV100
DHCPOFFER on 10.1.1.30 to 02:00:0c:14:00:00 via BV100
reuse_lease: lease age 0 (secs) under 25% threshold, reply with unaltered, existing lease for 10.1.1.30
DHCPREQUEST for 10.1.1.30 (10.1.1.20) from 02:00:0c:14:00:00 via BV100
DHCPACK on 10.1.1.30 to 02:00:0c:14:00:00 via BV100



```

Checking on the requesting interface eth1, we see the required IP address assigned by the DHCP server running inside the docker container on the router:

```
[root@localhost iscginx]# ifconfig eth1
eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.1.1.30  netmask 255.255.255.0  broadcast 10.1.1.0
        inet6 fe80::cff:fe14:0  prefixlen 64  scopeid 0x20<link>
        ether 02:00:0c:14:00:00  txqueuelen 1000  (Ethernet)
        RX packets 92357  bytes 6628823 (6.3 MiB)
        RX errors 0  dropped 281  overruns 0  frame 0
        TX packets 134810  bytes 200127615 (190.8 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0


```

## Testing the NGINX server

Create files in the Router shell with a directory structure as described in your nginx.conf file found at the root of this repository. 
The default nginx.conf supports a directory structure with root `/data/`
and subdirectories: `/data/images` and `/data/configs/`

With the default nginx.conf in play, we create a couple of files on the router in the following file/directory structure based on the mount point (see `docker run` command above where we mount $(pwd) or `/misc/disk1/data` to `~/data` inside the container:


```
RP/0/RP0/CPU0:ios#bash
Thu Oct 29 09:27:48.621 UTC
[ios:~]$
[ios:~]$cd /misc/disk1/
[ios:/misc/disk1]$
[ios:/misc/disk1]$tree data
data
|-- configs
|   `-- rtr.conf
`-- images
    `-- image.iso

2 directories, 2 files
[ios:/misc/disk1]$

```

Now with the IP address already received via the DHCP interactions earlier, issue an HTTP request to download your required files from the NGINX server on the router:

```

[root@localhost iscginx]# wget http://10.1.1.20:8080/images/image.iso
--2020-10-29 02:30:27--  http://10.1.1.20:8080/images/image.iso
Connecting to 10.1.1.20:8080... connected.
HTTP request sent, awaiting response... 200 OK
Length: 6 [application/octet-stream]
Saving to: ‘image.iso’

100%[======================================>] 6           --.-K/s   in 0s      

2020-10-29 02:30:27 (638 KB/s) - ‘image.iso’ saved [6/6]

[root@localhost iscginx]# 


```
