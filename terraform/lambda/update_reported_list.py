import os
from typing import Any, Dict
from http import HTTPStatus

import boto3

def handler(event, context):
    s3_client = boto3.client("s3")
    report_file_name = 'report_list.txt'
    bucket_name = os.environ['models_bucket']
    s3_client.download_file(bucket_name, report_file_name, '/tmp/' + report_file_name)
    # Open in append mode
    with open('/tmp/' + report_file_name, 'a') as report_file:
                report_file.write(event['UserAddress'] + "\t" + event['reported_at'] + "\n")
    response = s3_client.upload_file('/tmp/' + report_file_name, bucket_name, report_file_name)
    print("User with address " + event['UserAddress'] + " was banned at " + event['reported_at'])
    return {
        "lambda_request_id": context.aws_request_id,
        "lambda_arn": context.invoked_function_arn,
        "status_code": HTTPStatus.OK.value,
        "event": event,
        "response": response
    }