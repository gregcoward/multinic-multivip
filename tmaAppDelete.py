from __future__ import print_function

import boto3
import json

print('Loading function')

def lambda_handler(event, context):
    appId = (event['appId'][:30]).replace('-','X')
    tenantId = event['tenantId']
    cluster_Name = 'GLC-tempest-svc-cluster'
    ctr = 0    
    
    # Connect to ECS client
    client = boto3.client('ecs')    

    try:     
        response = client.describe_services(
            cluster=cluster_Name,
            services=[
                appId,
            ]
        )

        # update Service to zero tasks
        response = client.update_service(
            cluster=cluster_Name,
            service=appId,
            desiredCount=0
        )
    
       # Stop running tasks
        response2 = client.list_tasks(
            cluster=cluster_Name,
            serviceName = appId          
        )
 
        while ctr < len(response2['taskArns']):    
            response = client.stop_task(
                cluster=cluster_Name,
                task = response2['taskArns'][ctr]
            )
            ctr += 1
    
        response = client.delete_service(
            cluster=cluster_Name,
            service=appId
        )

        try:
            client = boto3.client('elb')
            response = client.delete_load_balancer(
                LoadBalancerName=appId
            )
        except:
            print ('elb does not exist')
    except:
        print ("service does not exist")


    d = {
        'tenantId': tenantId,
        'appId': event['appId'],
        'status': 'terminated'
        }
    return json.dumps(d)