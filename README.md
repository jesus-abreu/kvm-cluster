# kvm-cluster
How to create a cluster of VMs using KVM hypervisor type 1

**Background info:**
As most of us that want to put the hands dirty into computer hardware, OS, etc. but don’t have the budget, need to be creative for proving concepts and learning how to.  
I will take advantage of my previous experience building servers and will put together  a single x86 server machine and will try to meet this article objectives.  In in a nutshell, here is a summary of my tasks, resources, and what is needed to meet the objectives:

**Tasks:**
1.	I built a server with 64 GB RAM, 2 CPUs, and 4 TB storage in my home and installed Ubuntu 24.04, with virtualization enabled using the BIOS setup; and attached it to my home Wi-Fi network.
2.	I named this server ‘data-science’ as hostname, that gets its ip 192.168.1.246 from the Wi-Fi router.  
3.	It is running KVM as hypervisor to manage 3 VMs with 16 GB RAM, 300 GB storage, and 4 vCPUs.  There are 16 extra MB of memory, but with 3 VMs for now, it suffices to meet our objectives.
4.	The VMs are linked together using a virtual bridge, to allow access to the VMs from the host machine network and ensuring that the VMs have a serial console enabled to login to them from command line.
5.	I will setup the VMs in a NAT network (I will provide a brief description on the difference from bridge network) 
6.	Install RHCOS 9.5 on each VM
7.	Configure dnsmasq for domain resolution, using as base domain ‘home.com’. The host machine will be running dnsmasq for DNS resolution (we can also use iptables)
8.	Install and Configure SSH on RHCOS, enabling SSH Key-Based Authentication on the VMs. 
9.	Name the VM cluster ‘kvm-cluster’.
10.	Setup NGINX a s external load balancer, running in the host.
11.	And will create a set of testing scripts to verify functionality.

To download the articles source code do:
$ git clone https://github.com/jesus-abreu/kvm-cluster.git <your target foler>
