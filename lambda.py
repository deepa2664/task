import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])
        file_id = body.get('id')
        content = body.get('content')
        
        try:
            table.put_item(
                Item={
                    'FileID': file_id,
                    'Content': content,
                    'Timestamp': datetime.utcnow().isoformat()
                }
            )
            print(f"Inserted {file_id}")
        except Exception as e:
            print(f"Error inserting {file_id}: {e}")
