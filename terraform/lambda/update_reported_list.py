import os
from typing import Any, Dict
from http import HTTPStatus

from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.utilities.parser import event_parser, BaseModel
import boto3

class UserInsertionEvent(BaseModel):
    UserAddress: str
    reported_at: str

@event_parser(model=UserInsertionEvent)
def handler(event: UserInsertionEvent, context: LambdaContext) -> Dict[str, Any]:
    s3_client = boto3.client("s3")
    report_file_name = 'report_list.txt'
    bucket_name = os.environ['models_bucket']
    s3_client.download_file(bucket_name, report_file_name, report_file_name)
    # Open in append mode
    with open(report_file_name, 'a') as report_file:
                report_file.write(event.UserAddress + "\t" + event.reported_at + "\n")
    response = s3_client.upload_file(report_file_name, bucket_name, report_file_name)
    return {
        "lambda_request_id": context.aws_request_id,
        "lambda_arn": context.invoked_function_arn,
        "status_code": HTTPStatus.OK.value,
        "event": event.json(),
        "response": response
    }