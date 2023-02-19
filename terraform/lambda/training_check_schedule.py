import os
from http import HTTPStatus

import boto3

# Use paginator in case training set size > 1000 (S3 API limit)
def count_updated_dataset_size(s3_client, bucket_name, model_path):
    paginator = s3_client.get_paginator('list_objects_v2')
    training_count = 0
    validation_count = 0
    for result in paginator.paginate(Bucket=bucket_name, Prefix=model_path + '/labels/train/', Delimiter='/'):
        key_count = result.get('KeyCount')
        if key_count is not None:
            training_count += key_count

    for result in paginator.paginate(Bucket=bucket_name, Prefix=model_path + '/labels/valid/', Delimiter='/'):
        key_count = result.get('KeyCount')
        if key_count is not None:
            validation_count += key_count

    return training_count, validation_count

def download_yamls_from_s3(s3_client, models_list, s3_folder, bucket_name):
    for model in models_list:
        if not os.path.exists('/tmp/' + s3_folder + model):
            os.makedirs('/tmp/' + s3_folder + model)
        # Download model data
        s3_client.download_file(bucket_name, s3_folder + model + '/' + model + '.yaml', '/tmp/' + s3_folder + model + '/' + model + '.yaml')

def get_current_dataset_size_yaml(model_name, is_pending=False):
    model_folder_prefix = ''
    if is_pending:
        model_folder_prefix = 'pending_'
    current_training_set_size, current_validation_set_size = 0, 0
    yaml_path = '/tmp/' + model_folder_prefix + 'models/' + model_name + '/' + model_name + '.yaml'
    size_found = 0
    with open(yaml_path, 'r') as yaml_file:
        for line in yaml_file:
            if line.startswith('training_set_size:'):
                current_training_set_size = int(line.replace('training_set_size:', '').strip())
                size_found = size_found + 1
            elif line.startswith('validation_set_size:'):
                current_validation_set_size = int(line.replace('validation_set_size:', '').strip())
                size_found = size_found + 1
            if size_found == 2:
                break
    return current_training_set_size, current_validation_set_size

def get_models_list(s3_client, s3_resource, bucket_name):
    bucket = s3_resource.Bucket(bucket_name)
    result = s3_client.list_objects(Bucket=bucket.name, Prefix='pending_models/', Delimiter='/')
    pending_models_list = []
    models_list = []
    common_prefixes = result.get('CommonPrefixes')
    if common_prefixes:
        pending_models_list = [o.get('Prefix').split('/')[1] for o in common_prefixes]
    result = s3_client.list_objects(Bucket=bucket.name, Prefix='models/', Delimiter='/')
    common_prefixes = result.get('CommonPrefixes')
    if common_prefixes:
        models_list = [o.get('Prefix').split('/')[1] for o in result.get('CommonPrefixes')]
    return pending_models_list, models_list

def get_models_to_train(s3_client, models_list, bucket_name):
    models_to_train = []

    min_new_training_data = int(os.environ['min_new_training_data'])
    min_new_validation_data = int(os.environ['min_new_validation_data'])

    for curr_model in models_list:
        current_training_set_size, current_validation_set_size = get_current_dataset_size_yaml(curr_model, is_pending=False)
        updated_training_set_size, updated_validation_set_size = count_updated_dataset_size(s3_client, bucket_name, 'models/' + curr_model)
        if updated_training_set_size-current_training_set_size >= min_new_training_data and updated_validation_set_size-current_validation_set_size >= min_new_validation_data:
            models_to_train.append(curr_model)
    return models_to_train

def get_pending_models_to_train(s3_client, pending_models_list, bucket_name):
    pending_models_to_train = []

    min_training_data = int(os.environ['min_training_data'])
    min_validation_data = int(os.environ['min_validation_data'])

    for curr_pending_model in pending_models_list:
        training_set_size, validation_set_size = count_updated_dataset_size(s3_client, bucket_name, 'pending_models/' + curr_pending_model)
        if training_set_size >= min_training_data and validation_set_size >= min_validation_data:
            pending_models_to_train.append(curr_pending_model)
    return pending_models_to_train

def write_training_job_to_s3(s3_client, bucket_name, pending_models_to_train, models_to_train):
    pending_models_filename = 'pending_models_job.txt'
    with open('/tmp/' + pending_models_filename, 'w') as pending_models_file:
        for pending_model in pending_models_to_train:
            pending_models_file.write(pending_model + "\n")

    models_filename = 'models_job.txt'
    with open('/tmp/' + models_filename, 'w') as models_file:
        for model in models_to_train:
            models_file.write(model + "\n")
    
    s3_client.upload_file('/tmp/' + pending_models_filename, bucket_name, pending_models_filename)
    s3_client.upload_file('/tmp/' + models_filename, bucket_name, models_filename)

def handler(event, context):
    s3_client = boto3.client("s3")
    s3_resource = boto3.resource("s3")
    bucket_name = os.environ['models_bucket']
    sagemaker_instance_name = os.environ['sagemaker_instance_name']
    print("Starting training check schedule")
    if sagemaker_client.describe_notebook_instance(NotebookInstanceName=sagemaker_instance_name)["NotebookInstanceStatus"] == "InService":
        print("A training job is under way, stopping lambda function")
        
        return {
            "lambda_request_id": context.aws_request_id,
            "lambda_arn": context.invoked_function_arn,
            "status_code": HTTPStatus.OK.value,
            "event": event,
            "response": None
        }

    pending_models_list, models_list = get_models_list(s3_client, s3_resource, bucket_name)
    download_yamls_from_s3(s3_client, pending_models_list, 'pending_models/', bucket_name)
    download_yamls_from_s3(s3_client, models_list, 'models/', bucket_name)
    pending_models_to_train = get_pending_models_to_train(s3_client, pending_models_list, bucket_name)
    models_to_train = get_models_to_train(s3_client, models_list, bucket_name)

    response = None
    # If there is at least a single model to train, start notebook instance
    if pending_models_to_train or models_to_train:
        # Communicate to the SageMaker instance through training job files on S3 (avoid setting up a server or recomputing the models to train)
        write_training_job_to_s3(s3_client, bucket_name, pending_models_to_train, models_to_train)
        sagemaker_client = boto3.client("sagemaker")
        print("Models to train were found. Starting SageMaker notebook instance.")
        response = sagemaker_client.start_notebook_instance(NotebookInstanceName=sagemaker_instance_name)
    else:
        print("No models to train found.")

    return {
        "lambda_request_id": context.aws_request_id,
        "lambda_arn": context.invoked_function_arn,
        "status_code": HTTPStatus.OK.value,
        "event": event,
        "response": response
    }