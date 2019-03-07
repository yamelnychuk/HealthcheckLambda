import json
import boto3
import decimal
from botocore.vendored import requests
from boto3.dynamodb.conditions import Key, Attr


URL = "http://lambda.orak-test.pp.ua"

def send_email():
    name = 'ymelnyc'
    source = 'ymelnyc@softserveinc.com'
    subject = "Lambda Healthcheck Notification"
    message = "Test server is down during 15 minutes"
    destination = "bkaly@softserveinc.com"
    _message = "Message from: " + name + "\nEmail: " + source + "\nMessage content: " + message

    client = boto3.client('ses')

    client.send_email(
        Destination={
            'ToAddresses': [destination]
            },
        Message={
            'Body': {
                'Text': {
                    'Charset': 'UTF-8',
                    'Data': _message,
                },
            },
            'Subject': {
                'Charset': 'UTF-8',
                'Data': subject,
            },
        },
        Source = source,
    )
    

def healthcheck(event, context):
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('Data')
    r = requests.Response()
    
    try:
        r = requests.get(URL, timeout=5)
        if r.status_code < 400:
            return {
                'statusCode': r.status_code,
                'body': json.dumps(r.text)
            }
        else:
            raise requests.exceptions.ConnectionError
    except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
        failedHealthChecks = table.update_item(
            Key={
                'UID': 1
            },
            UpdateExpression="set CheckFailed = CheckFailed + :val",
            ExpressionAttributeValues={
                ':val': decimal.Decimal(1)
            },
            ReturnValues="UPDATED_NEW"
        )
    
        if failedHealthChecks['Attributes']['CheckFailed'] == 3:
            send_email()
            table.update_item(
                Key={
                    'UID': 1
                },
                UpdateExpression="set CheckFailed = :val",
                ExpressionAttributeValues={
                    ':val': decimal.Decimal(0)
                },
                ReturnValues="UPDATED_NEW"
            )
        
        if(r.status_code == None):
            return {
                'statusCode': r.status_code,
                'body': json.dumps("There is an error")
            }
        else:
            return {
                'statusCode': r.status_code,
                'body': json.dumps(r.text)
            }
    
    