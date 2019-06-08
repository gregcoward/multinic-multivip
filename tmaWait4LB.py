from __future__ import print_function

import boto3    
import json

print('Loading function')

def lambda_handler(event, context):

    tenantId = event['tenantId']
    appId = (event['appId'][:30]).replace('-','X')
    action = event['action']
    subService = event['subservices']
    cluster_Name = 'GLC-tempest-svc-cluster'
    tableName = "tmaHostPort"	

    elb = boto3.client('elb')
    response = elb.describe_load_balancers(
        LoadBalancerNames=[
            appId,
        ]
    )
    pubId = response['LoadBalancerDescriptions'][0]['DNSName']
    statPort = response['LoadBalancerDescriptions'][0]['ListenerDescriptions'][0]['Listener']['InstancePort']
    
    ctr1 = 0
    ready = 'notready'	
    while ready == 'notready':
        response2 = elb.describe_instance_health(
            LoadBalancerName=appId
        )
        while ctr1 < len(response2['InstanceStates']):
            if response2['InstanceStates'][ctr1]['State'] == 'InService':
                ready = 'ready'
            ctr1 += 1

    lbInstances = []
    lbInstances.extend(['['])    
    ctr2 = 0
    while ctr2 < len(response2['InstanceStates']):
        lbInstances.extend(['"',response2['InstanceStates'][ctr2]['InstanceId'],'",'])
        ctr2 += 1

    s = ''
    t = s.join(lbInstances)	    
    newt = t[:-1]
    newt = newt + "]"
    instIds = json.loads(newt)

    filters = [{
        'Name':'instance-id',
        'Values': instIds
    }]

    instanceIp = []
    ec2client = boto3.client('ec2')
    response3 = ec2client.describe_instances(Filters=filters)
    for reservation in response3["Reservations"]:
        for instance in reservation["Instances"]:
        # This will print will output the value of the Dictionary key 'InstanceId'
            instanceIp.extend([instance["PrivateIpAddress"]])

    d = {
        'tenantId': tenantId,
        'appId': event['appId'],
        'instanceIps': instanceIp,
        'statPort': statPort,
        'publicIP': pubId,
        'status': 'active'
        }
 
    return json.dumps(d)   

