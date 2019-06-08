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
    tmaImage = '972122593702.dkr.ecr.us-east-1.amazonaws.com/tmaengine'   
    
    #### Connect to DynamoDB service
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(tableName)
    
    
    #### Query actvServices Table for deployment values
    data = table.get_item(Key={'appId':appId})
    base_hostPort = int(data['Item']['port']) + 1
    ctr1 = 0
    print (base_hostPort)
    ### Connect to ECS service
    client = boto3.client('ecs')

    ### Create instance task definition
    
    value = []
    value.extend(['['])
    value.extend(['{"hostPort":',str(base_hostPort - 1),',"containerPort":','8113',',"protocol":"','tcp','"},'])
    while (ctr1 < len(subService)):    
        value.extend(['{"hostPort":',str(base_hostPort),',"containerPort":',str(subService[ctr1]['backendPort']),',"protocol":"',subService[ctr1]['protocol'],'"},'])
        base_hostPort += 1
        ctr1 += 1
		
    s = ''
    t = s.join(value)	    
    newt = t[:-1]
    newt = newt + "]"
    import json
    portMapJson = json.loads(newt)

    response = client.register_task_definition(
        containerDefinitions=[
            {
                'name': appId,
                'portMappings': portMapJson,
                'cpu': 128,
                'essential': True,
                'image': tmaImage,
		        'command': [
				    './startup.sh',
                    'https://s3.amazonaws.com/glc-f5tempest-conf-store/' + appId + '.conf'
                ],
                'memory': 128,
            },
        ],
        family=appId,
        taskRoleArn='',
        volumes=[
        ],
    )

    ## create and start service based on previously created task
    response = client.create_service(
        cluster=cluster_Name,
        serviceName=appId,
        taskDefinition=appId,
        role='arn:aws:iam::972122593702:role/glc-autorole',        
        loadBalancers=[
            {
                'loadBalancerName': appId,
                'containerName': appId,
                'containerPort': subService[0]['backendPort']
            }            
        ],
        desiredCount=2,
        placementConstraints=[
            {
                'type': 'distinctInstance'
            },
        ],
    )
    
    return event