import json

def lambda_handler(event, context):
    for record in event['Records']:
        print("Stream Record:", json.dumps(record, indent=2))
