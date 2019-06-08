from __future__ import print_function

import boto3

print('Loading function')


def lambda_handler(event, context):
    
    appId = (event['appId'][:30]).replace('-','X')
    action = event['action']
    subService = event['subservices']
    workloads = event['workloads']

 
    #### Create customized Nginx conf based on event input and upload to S3 bucket

    confLoc = '/tmp/' + appId + '.conf'
    confName = appId + '.conf'
    f = open(confLoc, 'w')
    
    ctr1 = 0
    ctr2 = 0
    value = []
    s = ''
    while (ctr1 < len(subService)):
        appName = 'app' + str(subService[ctr1]['backendPort'])
        
        if subService[ctr1]['method'] == 'Round Robin':
            value.extend(['upstream ',appName,' {'])		
        elif subService[ctr1]['method'] == 'hash':
            value.extend(['upstream ',appName,' {',subService[ctr1]['method'],' ',appId,' consistent;'])
        else:
            value.extend(['upstream ',appName,' {',subService[ctr1]['method'],';'])
        
        while (ctr2 < len(workloads)):
            value.extend(['server ',str(workloads[ctr2]['ipAddress']),':',str(subService[ctr1]['backendPort']),' weight=1;'])
            ctr2 += 1
        value.extend(['check interval=5000 rise=1 fall=3 timeout=4000;}server {listen ',str(subService[ctr1]['backendPort']),' default_server;'])
		
        if str(subService[ctr1]['compress']) == 'True':
            value.extend(['gzip on;gzip_types   text/plain text/html application/xml;gzip_min_length 1000;'])			    
		
        value.extend(['location / {proxy_pass http://',appName,';}}'])
        ctr1 += 1
        ctr2 = 0
    t = s.join(value)		
    f.write(t)
    f.close()
    
    s3 = boto3.resource('s3')
    s3.meta.client.upload_file(confLoc, 'glc-f5tempest-conf-store', confName)
    
    return event