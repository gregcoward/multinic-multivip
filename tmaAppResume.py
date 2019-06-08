from __future__ import print_function

import boto3
import json

print('Loading function')

def lambda_handler(event, context):

    appId = (event['appId'][:30]).replace('-','X')
    tenantId = event['tenantId']
    cluster_Name = 'GLC-tempest-svc-cluster'
    
    client = boto3.client('elb')    
    response = client.attach_load_balancer_to_subnets(
        LoadBalancerName=appId,
        Subnets=[
            'subnet-92776cae', 'subnet-45b74c21', 'subnet-62aed64e', 'subnet-3bf08061','subnet-3c542f30'
        ],
    )

    d = {
        'tenantId': tenantId,
        'appId': event['appId'],
        'status': 'active'
        }
    return json.dumps(d)        