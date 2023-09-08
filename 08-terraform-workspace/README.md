# 08-terraform-workspace

Let's create a S3 bucket

```
provider "aws" {
  region = "ap-southeast-1"
}

resource "random_uuid" "my_uuid" {}

resource "aws_s3_bucket" "main" {
  bucket = "s3-bucket-${random_uuid.my_uuid.result}"
}
```

```shell
terraform apply
```

The state at `terraform.tfstate`

```
{
  "version": 4,
  "terraform_version": "1.5.6",
  "serial": 3,
  "lineage": "716534b1-bada-a6ce-9944-4a050e70ae6a",
  "outputs": {},
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
            "arn": "arn:aws:s3:::s3-bucket-3d01f63a-3922-0509-05bb-fead38d40db1",
            "bucket": "s3-bucket-3d01f63a-3922-0509-05bb-fead38d40db1",
            "bucket_domain_name": "s3-bucket-3d01f63a-3922-0509-05bb-fead38d40db1.s3.amazonaws.com",
            "bucket_prefix": "",
            "bucket_regional_domain_name": "s3-bucket-3d01f63a-3922-0509-05bb-fead38d40db1.s3.ap-southeast-1.amazonaws.com",
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
            "id": "s3-bucket-3d01f63a-3922-0509-05bb-fead38d40db1",
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
          "dependencies": [
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
            "id": "3d01f63a-3922-0509-05bb-fead38d40db1",
            "keepers": null,
            "result": "3d01f63a-3922-0509-05bb-fead38d40db1"
          },
          "sensitive_attributes": []
        }
      ]
    }
  ],
  "check_results": null
}
```

By default, Terraform stores state in the **default** workspace

```shell
terraform workspace list
# * default

terraform workspace show
# default
```

If we're developing with the **trunk based development**, the **default workspace** will correspond with the **main branch**. How do a developer test their Terraform code?

The developer should create a new workspace (like a git branch), which has their own isolated state. Because they don't want to break the running infrastructure everyone is using.

```shell
$ terraform workspace new my-dev-workspace
Created and switched to workspace "my-dev-workspace"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.

$ terraform workspace show
my-dev-workspace

$ terraform workspace list
  default
* my-dev-workspace # The current workspace
```

```shell
$ tree
.
├── main.tf
├── terraform.tfstate
└── terraform.tfstate.d
    └── my-dev-workspace # Terraform create this folder to store state for the new workspace

$ terraform apply
# ...

$ tree
.
├── main.tf
├── terraform.tfstate # State of the default workspace
└── terraform.tfstate.d
    └── my-dev-workspace
        └── terraform.tfstate # State of my-dev-workspace workspace
```


The folder structure is a little different if we use S3

```
➜ aws s3 ls s3://tf-state-07-hello-world-s3-backend --recursive
2023-09-08 15:22:33       4272 env:/my-other-dev-workspace/global/s3/terraform.tfstate
2023-09-07 23:04:59       4269 global/s3/terraform.tfstate
```

```shell
.
├── global
    └── s3
        └── terraform.tfstate # Path of the state is the key in backend config 
├── env:
    └── my-other-dev-workspace # Each workspace is a folder in the env: folder
        └── global
            └── s3
                └── terraform.tfstate
```

The same Terraform configuration, authenticate mechanism are used for all workspaces.

It's very easy to forget which workspace we're using. That could leads to disacter. We might destroy the production environment without knowing it.