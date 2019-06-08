from __future__ import print_function

import json
import urllib
import boto3

print('Loading message function...')


def send_to_sns(message, context):

# send response back to Portal
    sns = boto3.client('sns')
    sns.publish(
        TopicArn = "arn:aws:sns:us-east-1:972122593702:tma-engine-response",
        Subject = "default",
        Message = message
    )

    return ('Sent a message to an Amazon SNS topic: ' + message)
