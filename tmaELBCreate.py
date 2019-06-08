from __future__ import print_function

import boto3
import json

print('Loading function')

def lambda_handler(event, context):

    appId = (event['appId'][:30]).replace('-','X')
    tableName = 'tmaHostPort'
    cluster_Name = 'GLC-tempest-svc-cluster'
    subService = event['subservices']
    
    #### Connect to DynamoDB service
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(tableName)
    
    
    #### Query actvServices Table for deployment values
    data = table.get_item(Key={'appId':'currentNum'})
    base_hostPort = int(data['Item']['port'])
    print(base_hostPort)
    sbase_hostPort = str(base_hostPort)
    new_indexPort = len(event['subservices']) + int(data['Item']['port'] + 1)
	
    response = table.update_item(
        Key={
            'appId': 'currentNum'
            },
        UpdateExpression="SET port = :val1",
        ExpressionAttributeValues={
            ':val1': new_indexPort,
            },        
    )
    
    response = table.put_item(
        Item={
            'appId': appId,
            'port' : base_hostPort
            },
        TableName= tableName
    )   
    	
    ### Connect to ELB service
    elb = boto3.client('elb')
    ctr1 = 0
    
    response = elb.create_load_balancer(
        Listeners=[
			{
                'Protocol': 'tcp',
                'LoadBalancerPort': 8113,
                'InstanceProtocol': 'tcp',
                'InstancePort': base_hostPort
			}
		],
        LoadBalancerName= appId,
        Tags=[
            {
                'Key': 'appId',
                'Value': appId
            },
        ],        
        SecurityGroups=[
        ],
        Subnets=[
            'subnet-92776cae', 'subnet-45b74c21', 'subnet-62aed64e', 'subnet-3bf08061','subnet-222d106a','subnet-3c542f30'
        ],
    )

    while (ctr1 < len(subService)):    
        base_hostPort += 1
        response = elb.create_load_balancer_listeners(
            LoadBalancerName = appId,
            Listeners=[
                {
                    'Protocol': subService[ctr1]['protocol'],
                    'LoadBalancerPort': subService[ctr1]['backendPort'],
                    'InstanceProtocol': subService[ctr1]['protocol'],
                    'InstancePort': base_hostPort
                },
            ]
        )
        ctr1 += 1   
    
    if (subService[0]['protocol'].upper() == 'HTTP') or (subService[0]['protocol'].upper() == 'HTTPS'):
        target = subService[0]['protocol'].upper() + ':' + sbase_hostPort + '/'
    else:
        target = subService[0]['protocol'].upper() + ':' + sbase_hostPort
        
    response = elb.configure_health_check(
        HealthCheck={
            'HealthyThreshold': 2,
            'Interval': 15,
            'Target': target,
            'Timeout': 3,
            'UnhealthyThreshold': 2,
        },
        LoadBalancerName = appId,
    )    
    return event   
