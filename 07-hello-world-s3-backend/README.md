# 07-hello-world-s3-backend

A Terraform configuration uses the remote backend (S3), which consists of a bucket with random name

```terraform
terraform {
  backend "s3" {
    bucket = "tf-state-07-hello-world-s3-backend"
    key    = "global/s3/terraform.tfstate"
    region = "ap-southeast-1"

    dynamodb_table = "tf-state-07-hello-world-s3-backend"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "random_uuid" "my_uuid" {}

resource "aws_s3_bucket" "main" {
  bucket = "s3-bucket-${random_uuid.my_uuid.result}"
}
```

Let's check the state

```json
{
  "version": 4,
  "terraform_version": "1.5.6",
  "serial": 1,
  "lineage": "b9474ad4-97d6-8fa1-c18b-b51321ca8105",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "aws_s3_bucket",
      "name": "terraform_state",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "acceleration_status": "",
            "acl": null,
            "arn": "arn:aws:s3:::s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "bucket": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "bucket_domain_name": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44.s3.amazonaws.com",
            "bucket_prefix": "",
            "bucket_regional_domain_name": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44.s3.ap-southeast-1.amazonaws.com",
            "cors_rule": [],
            "force_destroy": false,
            "grant": [
              {
                "id": "33c05eaa9c1c48633d94df2e894c86d5e41521ad15a10f7ecea445386947f2e2",
                "permissions": ["FULL_CONTROL"],
                "type": "CanonicalUser",
                "uri": ""
              }
            ],
            "hosted_zone_id": "Z3O0J2DXBE1FTB",
            "id": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "lifecycle_rule": [],
            "logging": [],
            "object_lock_configuration": [],
            "object_lock_enabled": false,
            "policy": "",
            "region": "ap-southeast-1",
            "replication_configuration": [],
            "request_payer": "BucketOwner",
            "server_side_encryption_configuration": [
              {
                "rule": [
                  {
                    "apply_server_side_encryption_by_default": [
                      {
                        "kms_master_key_id": "",
                        "sse_algorithm": "AES256"
                      }
                    ],
                    "bucket_key_enabled": false
                  }
                ]
              }
            ],
            "tags": null,
            "tags_all": {},
            "timeouts": null,
            "versioning": [
              {
                "enabled": false,
                "mfa_delete": false
              }
            ],
            "website": [],
            "website_domain": null,
            "website_endpoint": null
          },
          "sensitive_attributes": [],
          "private": "eyJlMmJmYjczMC1lY2FhLTExZTYtOGY4OC0zNDM2M2JjN2M0YzAiOnsiY3JlYXRlIjoxMjAwMDAwMDAwMDAwLCJkZWxldGUiOjM2MDAwMDAwMDAwMDAsInJlYWQiOjEyMDAwMDAwMDAwMDAsInVwZGF0ZSI6MTIwMDAwMDAwMDAwMH19",
          "dependencies": ["random_uuid.my_uuid"]
        }
      ]
    },
    {
      "mode": "managed",
      "type": "random_uuid",
      "name": "my_uuid",
      "provider": "provider[\"registry.terraform.io/hashicorp/random\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "id": "0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "keepers": null,
            "result": "0476833b-4608-b28a-6fcf-4432eb3a9e44"
          },
          "sensitive_attributes": []
        }
      ]
    }
  ],
  "check_results": null
}
```

Let's make some changes:
- Turn on the versioning
- At an output of the bucket name

```terraform

```

```json
{
  "version": 4,
  "terraform_version": "1.5.6",
  "serial": 4,
  "lineage": "b9474ad4-97d6-8fa1-c18b-b51321ca8105",
  "outputs": {
    "s3_bucket_name": {
      "value": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
      "type": "string"
    }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "aws_s3_bucket",
      "name": "main",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "acceleration_status": "",
            "acl": null,
            "arn": "arn:aws:s3:::s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "bucket": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "bucket_domain_name": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44.s3.amazonaws.com",
            "bucket_prefix": "",
            "bucket_regional_domain_name": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44.s3.ap-southeast-1.amazonaws.com",
            "cors_rule": [],
            "force_destroy": false,
            "grant": [
              {
                "id": "33c05eaa9c1c48633d94df2e894c86d5e41521ad15a10f7ecea445386947f2e2",
                "permissions": [
                  "FULL_CONTROL"
                ],
                "type": "CanonicalUser",
                "uri": ""
              }
            ],
            "hosted_zone_id": "Z3O0J2DXBE1FTB",
            "id": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "lifecycle_rule": [],
            "logging": [],
            "object_lock_configuration": [],
            "object_lock_enabled": false,
            "policy": "",
            "region": "ap-southeast-1",
            "replication_configuration": [],
            "request_payer": "BucketOwner",
            "server_side_encryption_configuration": [
              {
                "rule": [
                  {
                    "apply_server_side_encryption_by_default": [
                      {
                        "kms_master_key_id": "",
                        "sse_algorithm": "AES256"
                      }
                    ],
                    "bucket_key_enabled": false
                  }
                ]
              }
            ],
            "tags": {},
            "tags_all": {},
            "timeouts": null,
            "versioning": [
              {
                "enabled": true,
                "mfa_delete": false
              }
            ],
            "website": [],
            "website_domain": null,
            "website_endpoint": null
          },
          "sensitive_attributes": [],
          "private": "eyJlMmJmYjczMC1lY2FhLTExZTYtOGY4OC0zNDM2M2JjN2M0YzAiOnsiY3JlYXRlIjoxMjAwMDAwMDAwMDAwLCJkZWxldGUiOjM2MDAwMDAwMDAwMDAsInJlYWQiOjEyMDAwMDAwMDAwMDAsInVwZGF0ZSI6MTIwMDAwMDAwMDAwMH19",
          "dependencies": [
            "random_uuid.my_uuid"
          ]
        }
      ]
    },
    {
      "mode": "managed",
      "type": "aws_s3_bucket_versioning",
      "name": "main",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "bucket": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "expected_bucket_owner": "",
            "id": "s3-bucket-0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "mfa": null,
            "versioning_configuration": [
              {
                "mfa_delete": "",
                "status": "Enabled"
              }
            ]
          },
          "sensitive_attributes": [],
          "private": "bnVsbA==",
          "dependencies": [
            "aws_s3_bucket.main",
            "random_uuid.my_uuid"
          ]
        }
      ]
    },
    {
      "mode": "managed",
      "type": "random_uuid",
      "name": "my_uuid",
      "provider": "provider[\"registry.terraform.io/hashicorp/random\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "id": "0476833b-4608-b28a-6fcf-4432eb3a9e44",
            "keepers": null,
            "result": "0476833b-4608-b28a-6fcf-4432eb3a9e44"
          },
          "sensitive_attributes": []
        }
      ]
    }
  ],
  "check_results": null
}
```