from __future__ import print_function

import json
import urllib
import boto3

print('Loading message function...')

def send_to_sns(message, context):


    if message['action'] == 'pause':
        status = 'pausing'
    elif message['action'] == 'terminate':
        status = 'terminating'
    else:
        status = 'activating'

    d = {
        'tenantId': message['tenantId'],
        'appId': message['appId'],
        'status': status
        }

# send response back to Portal
    sns = boto3.client('sns')
    sns.publish(
        TopicArn = "arn:aws:sns:us-east-1:972122593702:tma-engine-response",
        Subject = "default",
        Message = json.dumps(d)
    )

    return message
