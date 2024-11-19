import boto3
import botocore
import os
import shutil
import secrets

s3_client = boto3.client('s3')
pipeline = boto3.client('imagebuilder')

def lambda_handler(event, context):
   response = pipeline.start_image_pipeline_execution(
      imagePipelineArn=os.environ['pipeline_arn'],
      clientToken=secrets.token_hex(16)
   )