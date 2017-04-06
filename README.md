mainTemplate.json, (uses nested template as well) deploys a virtual network with three subnets, (internal, external, and mgmt.) and either an individual BIG-IP or a pair of BIG-IPs in a sync cluster  Each BIG-IP is configured with:

•	3 NICs & 3 VLANS
o	Mgmt VLAN. – located on mgmt. subnet
    *	1 Self-IP connected to a public IP for management of BIG-IP
o	Internal_VLAN - located on internal subnet
    * 1 Self-IP internal facing only
o	External_VLAN – located on external subnet
    * Creates 1- 5 self-IPs on each BIG-IP which can be used as virtual server destinations – (load balanced pair – public IPs are associated with ALB object). For example, the template will create up to five:
    •	Self_vip1 - connected to a public IP
    •	Self_vip2 - connected to a public IP
    •	Self_vip3 - connected to a public IP
    •	Self_vip4 - connected to a public IP
    •	Self_vip5 - connected to a public IP
    
The design is basically equivalent to a traditional on-premises multi-arm deployment. Non-standard parameters include:  
  •	BYOL or HOURLY;
  •	1 or 2 BIGIPs deployed;
  •	Good, Better, or Best - (relevant for hourly only);
  •	Licensed Bandwidth - (relevant for hourly only); and  I
  •	Number of public-facing virtual instances to be created, (1-5).  Creates a self-IP on the BIG-IP for each instance selected, (Instance = virtual server).
                
https://docs.microsoft.com/en-us/azure/azure-subscription-service-limits#networking-limits

