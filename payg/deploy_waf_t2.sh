#!/bin/bash
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"

function passwd() {
  echo | awk '{print $1}' /config/mypass
}

while getopts m:d:n:j:k:h:s:t:l:a:c:r:o:u:p: option
do	case "$option"  in
        m) mode=$OPTARG;;
        d) deployment=$OPTARG;;
	   n) pool_member=$OPTARG;;       
        j) vs_http_port=$OPTARG;;
        k) vs_https_port=$OPTARG;;
        h) pool_http_port=$OPTARG;;
        s) pool_https_port=$OPTARG;;
        t) type=$OPTARG;;
        l) level=$OPTARG;;
        a) policy=$OPTARG;;
        c) ssl_cert=$OPTARG;;
        r) ssl_passwd=$OPTARG;;
        o) rewrite=$OPTARG;;
        u) user=$OPTARG;;
    esac 
done

IP_REGEX='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
FQDN_REGEX="(?=^.{1,254}$)(^(?:(?!\d+\.|-)[a-zA-Z0-9_\-]{1,63}(?<!-)\.?)+(?:[a-zA-Z]{2,})$)"

sleep 10

# check for existence of device-group
response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X GET -H "Content-Type: application/json" https://localhost/mgmt/tm/cm/device-group/~Common~Sync  -o /dev/null)

if [[ $response_code != 200 ]]; then
     echo "We are one, set device group to none"
     device_group="none"
else
     echo "We are two, set device group to Sync"
     device_group="/Common/Sync"
fi

# install iApp templates
template_location="/var/lib/waagent/custom-script/download/0"

for template in f5.http.v1.2.0rc7.tmpl f5.policy_creator_t2.tmpl f5.asm_log_creator_t2.tmpl
do
     cp $template_location/$template /config/$template
     response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/config -d '{"command": "load","name": "merge","options": [ { "file": "/config/'"$template"'" } ] }' -o /dev/null)
     if [[ $response_code != 200  ]]; then
          echo "Failed to install iApp template; exiting with response code '"$response_code"'"
          exit 1
     fi
     sleep 10
done

# deploy logging profiles
# profile names
deployment_name="azure-log"
asm_log_name="/Common/${deployment_name}.app/${deployment_name}_lp_asm_remote"
dos_log_name="/Common/${deployment_name}.app/${deployment_name}_lp_l7dos_remote"
local_asm_log_name="/Common/${deployment_name}.app/${deployment_name}_lp_asm_local"

#check for existence of previously deployed logging app
response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X GET -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/~Common~$deployment_name.app~$deployment_name -o /dev/null)

if [[ $response_code != 200  ]]; then
     response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment_name"'","partition":"Common","deviceGroup":"'"$device_group"'","strictUpdates":"disabled","template":"/Common/f5.asm_log_creator_t2","trafficGroup":"none"}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to install logging profiles; exiting with response code '"$response_code"'"
          exit 1
     fi
else 
     echo "Logging deployment already exists, continuing deployment"
fi

# download canned or custom security policy and create accompanying ltm policy
custom_policy="none"
ltm_policy_name="/Common/$deployment-ltm_policy" 
     
if [[ $level == "custom" ]]; then
     if [[ -n $policy && $policy != "NOT_SPECIFIED" ]]; then
          custom_policy=$policy
     else 
          level="high"
     fi
fi

# deploy policies
# profile name
l7dos_name="/Common/$deployment-l7dos"
deployment_name="$deployment-policy"

if [[ -n $rewrite && $rewrite != "NOT_SPECIFIED" ]]; then
     rewrite_fqdn=$rewrite
     server_host=$pool_member
     scheme=$mode
     rewrite_profile_name="/Common/$deployment-uri_rewrite"
else 
     rewrite_fqdn="false"
     server_host="none"
     scheme="none"
     rewrite_profile_name=""
fi

response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment_name"'","partition":"Common","deviceGroup":"'"$device_group"'","strictUpdates":"disabled","template":"/Common/f5.policy_creator_t2","trafficGroup":"none","lists":[],"variables":[{"name":"variables__deployment","value":"'"$deployment"'"},{"name":"variables__type","value":"'"$type"'"},{"name":"variables__level","value":"'"$level"'"},{"name":"variables__do_asm","value":"true"},{"name":"variables__do_l7dos","value":"true"},{"name":"variables__custom_asm_policy","value":"'"$custom_policy"'"},{"name":"variables__do_uri_rewrite","value":"'"$rewrite_fqdn"'"},{"name":"variables__server_host","value":"'"$server_host"'"},{"name":"variables__rewrite_scheme","value":"'"$scheme"'"}]}' -o /dev/null)

if [[ $response_code != 200  ]]; then
     echo "Failed to install LTM policy; exiting with response code '"$response_code"'"
     exit 1
fi

# pre-create node
if [[ $pool_member =~ $IP_REGEX ]]; then
     response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/node -d '{"name": "'"$pool_member"'","partition": "Common","address": "'"$pool_member"'"}' -o /dev/null)
else
     response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/node -d '{"name": "'"$pool_member"'","partition": "Common","fqdn": {"autopopulate": "enabled","tmName": "'"$pool_member"'"}}' -o /dev/null)
fi

if [[ $response_code != 200  ]]; then
     echo "Failed to create node; with response code '"$response_code"'"
fi

sleep 10

# deploy unencrypted application
if [[ $mode == "http" || $mode == "http-https" ]]; then        
     response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'-'"$vs_http_port"'","partition":"Common","deviceGroup":"'"$device_group"'","strictUpdates":"disabled","template":"/Common/f5.http.v1.2.0rc7","trafficGroup":"none","tables":[{"name":"pool__hosts","columnNames":["name"],"rows":[{"row":["'"$deployment"'"]}]},{"name":"pool__members","columnNames":["addr","port","connection_limit"],"rows":[{"row":["'"$pool_member"'","'"$pool_http_port"'","0"]}]},{"name":"server_pools__servers"}],"lists":[{"name":"asm__security_logging","value":["'"$asm_log_name"'","'"$local_asm_log_name"'", "'"$dos_log_name"'"]}],"variables":[{"name":"asm__use_asm","value":"'"$ltm_policy_name"'"},{"name":"monitor__monitor","value":"/Common/http"},{"name":"pool__addr","value":"0.0.0.0"},{"name":"pool__mask","value":"0.0.0.0"},{"name":"pool__persist","value":"/#cookie#"},{"name":"pool__port","value":"'"$vs_http_port"'"},{"name":"pool__profiles","value":"'"$l7dos_name $rewrite_profile_name"'"},{"name":"ssl__mode","value":"no_ssl"}]}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to deploy unencrypted application; exiting with response code '"$response_code"'"
          exit 1
     else
          echo "Deployment of unencrypted application succeeded."
     fi
fi

if [[ $mode == "https" || $mode == "http-https" || $mode == "https-offload" ]]; then
     chain="/Common/ca-bundle.crt"
     
     # download and install Certificate
     echo "Starting Certificate download"
     
     certificate_location=$ssl_cert
     
     curl -k -s -f --retry 5 --retry-delay 10 --retry-max-time 10 -o /config/tmp.pfx $certificate_location
      
     response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/crypto/pkcs12 -d '{"command": "install","name": "wafCert","options": [ { "from-local-file": "/config/tmp.pfx" }, { "passphrase": "'"$ssl_passwd"'" } ] }' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to install SSL cert; exiting with response code '"$response_code"'"
          exit 1
     else 
          echo "Certificate download complete."
     fi
fi

if [[ $mode == "https" || $mode == "https-offload" ]]; then
     do_redirect="yes"
else
     do_redirect="no"
fi

# deploy encrypted application
if [[ $mode == "https" || $mode == "http-https" ]]; then      
     response_code=$(curl -sk -u $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'-'"$vs_https_port"'","partition":"Common","deviceGroup":"'"$device_group"'","strictUpdates":"disabled","template":"/Common/f5.http.v1.2.0rc7","trafficGroup":"none","tables":[{"name":"pool__hosts","columnNames":["name"],"rows":[{"row":["'"$deployment"'"]}]},{"name":"pool__members","columnNames":["addr","port_secure","connection_limit"],"rows":[{"row":["'"$pool_member"'","'"$pool_https_port"'","0"]}]},{"name":"server_pools__servers"}],"lists":[{"name":"asm__security_logging","value":["'"$asm_log_name"'","'"$local_asm_log_name"'", "'"$dos_log_name"'"]}],"variables":[{"name":"asm__use_asm","value":"'"$ltm_policy_name"'"},{"name":"monitor__monitor","value":"/Common/https"},{"name":"pool__addr","value":"0.0.0.0"},{"name":"pool__mask","value":"0.0.0.0"},{"name":"pool__persist","value":"/#cookie#"},{"name":"pool__port","value":"'"$vs_http_port"'"},{"name":"pool__port_secure","value":"'"$vs_https_port"'"},{"name":"pool__redirect_to_https","value":"'"$do_redirect"'"},{"name":"pool__redirect_port","value":"'"$vs_http_port"'"},{"name":"pool__redirect_to_port","value":"'"$pool_https_port"'"},{"name":"pool__profiles","value":"'"$l7dos_name $rewrite_profile_name"'"},{"name":"ssl__cert","value":"/Common/wafCert.crt"},{"name":"ssl__key","value":"/Common/wafCert.key"},{"name":"ssl__mode","value":"client_ssl_server_ssl"},{"name":"ssl__server_ssl_profile","value":"/#default#"},{"name":"ssl__use_chain_cert","value":"'"$chain"'"}]}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to deploy encrypted application; exiting with response code '"$response_code"'"
          exit 1
    else
           echo "Deployment of encrypted application succeeded."
     fi
fi

# deploy offloaded application
if [[ $mode == "https-offload" ]]; then           
     response_code=$(curl -sk -u $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'-'"$vs_https_port"'","partition":"Common","deviceGroup":"'"$device_group"'","strictUpdates":"disabled","template":"/Common/f5.http.v1.2.0rc7","trafficGroup":"none","tables":[{"name":"pool__hosts","columnNames":["name"],"rows":[{"row":["'"$deployment"'"]}]},{"name":"pool__members","columnNames":["addr","port","connection_limit"],"rows":[{"row":["'"$pool_member"'","'"$pool_http_port"'","0"]}]},{"name":"server_pools__servers"}],"lists":[{"name":"asm__security_logging","value":["'"$asm_log_name"'","'"$local_asm_log_name"'", "'"$dos_log_name"'"]}],"variables":[{"name":"asm__use_asm","value":"'"$ltm_policy_name"'"},{"name":"monitor__monitor","value":"/Common/http"},{"name":"pool__addr","value":"0.0.0.0"},{"name":"pool__mask","value":"0.0.0.0"},{"name":"pool__persist","value":"/#cookie#"},{"name":"pool__port_secure","value":"'"$vs_https_port"'"},{"name":"pool__redirect_to_https","value":"'"$do_redirect"'"},{"name":"pool__redirect_port","value":"'"$vs_http_port"'"},{"name":"pool__redirect_to_port","value":"'"$pool_https_port"'"},{"name":"pool__profiles","value":"'"$l7dos_name $rewrite_profile_name"'"},{"name":"ssl__cert","value":"/Common/wafCert.crt"},{"name":"ssl__key","value":"/Common/wafCert.key"},{"name":"ssl__mode","value":"client_ssl"},{"name":"ssl__use_chain_cert","value":"'"$chain"'"}]}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to deploy SSL offloaded application; exiting with response code '"$response_code"'"
          exit 1
     else 
           echo "Deployment of offloaded application succeeded."
     fi
fi

echo "Deployment complete."
exit