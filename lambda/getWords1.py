import json
import urllib3
import boto3
from uuid import uuid4


endPoint = 'https://' + events['headers']['Host'] + '/' + events['requestContext']['stage'] + events['path']
client = boto3.client('apigatewaymanagementapi', endpoint_url=endPoint)
dynamodb = boto3.resource("dynamodb")

def lambda_handler(event, context):
    
    print(event)
    
    connectionId = event["requestContext"]["connectionId"]
    
    table = dynamodb.Table("TestCollection")
    singleItem = table.scan(Limit=1, ExclusiveStartKey={'word': str(uuid4())})
    
    if singleItem['Items']:
        response = client.post_to_connection(ConnectionId=connectionId, Data=json.dumps(singleItem))
    else:
        response = client.post_to_connection(ConnectionId=connectionId, Data=json.dumps("Didn't find an item. Please try again."))
    
    #print(singleItem)
    
    return { "statusCode": 200 }
    #return None
