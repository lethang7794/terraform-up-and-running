# Managing Secrets with Terraform

> What is a **secret**?
>
> > Sensible data (e.g. passwords, keys, tokens, certificates…) that need to be secure.

> What is **secrets management**?
>
> > A practice that allow developers to
> >
> > securely store secret
> >
> > - in a secure environment with strict access controls.

## Secret Management Basics

1. DO NOT STORE SECRETS IN PLAIN TEXT.

   Do not hardcode secret directly in code.

2. DO NOT STORE SECRETS IN PLAIN TEXT IN VERSION CONTROL.
   - _Anyone_ who has access to the VCS has access to that secret.
   - _Every computer_ that has access to the VCS keeps a copy of that secret.
   - _Every piece of software_ all these computer has access to that secret
   - There's no way to _audit or revoke access_ to that secret
3. USE A _SECRET MANAGEMENT TOOL_ TO STORE SECRET

## Secret Management Tools

### The Types of Secrets You Store

There are 3 primary type of secrets:

1. 👕 **Personal secrets**: belong to an individual
   - Username/Password for websites
   - SSH keys
   - Pretty Good Privacy (PGP) keys
1. 👔 **Customer secrets**: belong to our customers
   - Username/Password to log into our product
   - Personal identifiable info (PII) for our customers
   - Personal health information (PHI) for our customers
1. 🛣️ **Infrastructure secrets**: belong to our infrastructure
   - Database passwords
   - API keys
   - TLS certificates

Most secret management tools are designed to store exactly 1 of these types of secrets.

### The Way You Store Secrets

There are 2 common strategies for storing secrets:

1. _File-base secrets store_

   Store secrets in encrypted files, which are typically checked in version control.

> To encrypt these files, we need an encryption key. The key is itself a secret.
>
> ❓ How do we store this encryption key?
>
> - The most common solution is store key in a key management service (KMS) provide by cloud providers (AWS KMS, GPC KMS…).
>
>   We trust the cloud provider to securely store the secret and manage access to it.
>
> - Another option is use PGP keys
>
>   Each developer can have their own PGP key, which consists of a _public key_ and a _private key_.
>
>   The public key is used to encrypt the data. And it can only be decrypt with the private key.
>
>   The private key, are protected by their memorizes 🧠, or in a person secrets manager.

2. _Centralized secret store_

   Web services that encrypt our secrets and store them in a data store (MySQL, DynamoDB…)

   The encryption key is managed by the service themself, or by cloud provider's KMS.

### The Interface You Use to Access Secrets

Most secret management tools can be access via:

1. **CLI**

   All file-based secrets stores work via a CLI.

   Many centralized secrets store also provide a CLI.

2. **API**

   Most centralized secret store expose an API that our applications can consume via network request

   e.g. a REST API that access over HTTP

   - The app can make the API call and retrieve the secret themself
   - or we can write Terraform code that, under the hood call these, retrieve secrets.

3. **UI**

   Some centralized secret store also expose a UI via web, desktop, mobile → More convinient way

### A Comparison of Secret Management Tools

|                              | Types of secrets | Secret storage      | Secret interface |
| ---------------------------- | ---------------- | ------------------- | ---------------- |
| HashiCorp Vault              | Infrastructurea  | Centralized service | UI, API, CLI     |
| AWS Secrets Manager          | Infrastructure   | Centralized service | UI, API, CLI     |
| Google Secrets Manager       | Infrastructure   | Centralized service | UI, API, CLI     |
| Azure Key Vault              | Infrastructure   | Centralized service | UI, API, CLI     |
|                              |                  |                     |                  |
| 1Password                    | Personal         | Centralized service | UI, API, CLI     |
| Keychain (macOS)             | Personal         | Files               | UI, CLI          |
| Credential Manager (Windows) | Personal         | Files               | UI, CLI          |
|                              |                  |                     |                  |
| Active Directory             | Customer         | Centralized service | UI, API, CLI     |
| Auth0                        | Customer         | Centralized service | UI, API, CLI     |
| Okta                         | Customer         | Centralized service | UI, API, CLI     |
| AWS Cognito                  | Customer         | Centralized service | UI, API, CLI     |

## Secret Management Tools with Terraform

### Providers

How do Terraform have access to call APIs from cloud providers?

#### Human users

The most common way is to use environment variables

```shell
$  export AWS_ACCESS_KEY_ID=(YOUR_ACCESS_KEY_ID)
$  export AWS_SECRET_ACCESS_KEY=(YOUR_SECRET_ACCESS_KEY)
```

Using environment variables ensure that creditials are only stored on memory, not in your code.

> ⚠️ Most shells will store the command we typed in a history file (.e.g ~/.zsh_history)
>
> To stop the shell from save history for a line, add a leading to the line
>
> ```shell
> pwd # This line will be in the history
>  ls # This line won't be in the history
>
> export AWESOME_VAR_WILL_BE_IN_HISTORY="This line can be access from the shell history"
>  export AWESOME_VAR_WONT_BE_IN_HISTORY="This line can't be access from the shell history"
> ```

> ❓But how we store the credentials (before copy and paste it in the CLI) in a secure way?
>
> We shouldn't store it in a plaintext file. So where? In a personal secret manager, e.g. 1Password, BitWarden.
>
> ---
>
> - Use 1Password
>
>   ```
>   # Login
>   $ eval $(op signin my)
>
>   # Get the fields from password and set it to environement variables
>   $ export AWS_ACCESS_KEY_ID=$(op get item 'aws-dev' --fields 'id')
>   $ export AWS_SECRET_ACCESS_KEY=$(op get item 'aws-dev' --fields 'secret')
>   ```
>
> - Use [`aws-vault`](https://github.com/99designs/aws-vault) > `aws-vault` will store credentials securely in our OS’s native password manager (e.g., Keychain on macOS, Credential Manager on Windows)
>
>   ```shell
>   # Add a profile named dev
>   # aws-vault add <PROFILE_NAME>
>   $ aws-vault add dev
>   Enter Access Key Id: (YOUR_ACCESS_KEY_ID)
>   Enter Secret Key: (YOUR_SECRET_ACCESS_KEY)
>
>   # Use the dev credentials you saved earlier to run terraform apply
>   # aws-vault exec <PROFILE> -- <COMMAND>
>   $ aws-vault exec dev -- terraform apply
>   ```
>
>   > How do aws-vault work?
>   >
>   > - aws-vault uses Amazon's STS service to generate temporary credentials via the GetSessionToken or AssumeRole API calls
>   > - aws-vault then exposes the temporary credentials to the sub-process

#### Machine users

> ❓ How do you get one machine (e.g., our CI server) to authenticate itself to another machine (e.g., AWS API servers) without storing any secrets in plain text?
>
> > The solution depends on the types of machine involes:
>
> - the machine you’re authenticating _from_
> - the machine you’re authenticating _to_

##### CircleCI as a CI server, with stored secrets

- Create a provider user (to used on that CI server)
- Store the credentials in a CircleCI Context.
- Update the `.circleci/config.yml` workflows to use the CircleCI Context we created.

> 👎 Some drawbacks of this approach:
>
> - We have to manually manage credentials.
> - We're using permanent credentials.

##### EC2 Instance running Jenkins as a CI server, with IAM roles

We'll give the EC2 Instance an AWS IAM role (that has enough permissions)

1. Create an **IAM Policy** that allows an EC2 Instance to assume it (`assume role policy`)

   Terraform has `aws_iam_policy_document` data source, that allows us to write **IAM Policy** in HCL (instead of JSON).

   ```t
   data "aws_iam_policy_document" "assume_role_policy" {
     statement {
       effect  = "Allow"
       actions = ["sts:AssumeRole"]
       principals {
          type        = "Service"
          identifiers = ["ec2.amazonaws.com"]
       }
     }
   }
   ```

2. Create an **IAM Role** that has previous `assume role policy` (the policy created in step 1)

   ```t
   resource "aws_iam_role" "instance" {
     name_prefix        = var.name
     assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
   }
   ```

3. Create a **IAM Policy** has permissions the EC2 Instance needs.

   In this case, it's all actions for EC2.

   ```t
   data "aws_iam_policy_document" "ec2_admin_permissions" {
   statement {
     effect    = "Allow"
     actions   = ["ec2:*"]
     resources = ["*"]
   }
   }
   ```

4. Attach permissions (IAM Policy in step 3) to the role (`aws_iam_role` in step 2)

   ```t
   resource "aws_iam_role_policy" "example" {
     role   = aws_iam_role.instance.id
     policy = data.aws_iam_policy_document.ec2_admin_permissions.json
   }
   ```

5. Allow our EC2 instance to automatically assume that role

   1. Crete an `iam_instance_profile`

      ```t
      resource "aws_iam_instance_profile" "instance" {
        role = aws_iam_role.instance.name
      }
      ```

   2. Tell EC2 instance to use that `iam_instance_profile`

      ```t
      resource "aws_instance" "example" {
        ami           = "ami-0fb653ca2d3203ac1"
        instance_type = "t2.micro"

        # Attach the instance profile
        iam_instance_profile = aws_iam_instance_profile.instance.name
      }
      ```

> ℹ️ How do the EC2 instance has the credential for the role?
>
> AWS runs an _instance metadata endpoint_ on every EC2 Instance at http://169.254.169.254.
>
> - This endpoint can only be reached by the processes running on the instance itself.
> - If the instance has an IAM role attached (via an instance profile), that metadata will include AWS credentials that can be used to authenticate to AWS and assume that IAM role.
>
> Tools that use AWS SDK (e.g. Terraform) use that _instance metadata endpoint_ to get the credentials automatically.

> 👍 Using IAM Roles for authenticate has many benefits:
>
> - We don't need to manually manage credentials.
> - The credentials are temporary, and rotated automatically.

##### GitHub Actions as a CI server, with OIDC

In the past, GitHub Actions required us to copy/paste credentials just like CircleCI.

From 2021, Github Actions offer a better alternative: Open ID Connect (OIDC). By using OIDC, our Github Actions can authenticate to cloud providers (AWS, GCP, Azure) automatically.

Let's do it

1. Create an IAM OIDC identity provider that trusts GitHub

   ```t
   # Create an IAM OIDC identity provider that trusts GitHub
   resource "aws_iam_openid_connect_provider" "github_actions" {
     url             = "https://token.actions.githubusercontent.com"
     client_id_list  = ["sts.amazonaws.com"]
     thumbprint_list = [
       data.tls_certificate.github.certificates[0].sha1_fingerprint
     ]
   }

   # Fetch GitHub's OIDC thumbprint
   data "tls_certificate" "github" {
     url = "https://token.actions.githubusercontent.com"
   }
   ```

2. Create an an IAM role with EC2 admin permissions attached, except the assume role policy will look different

   ```t
   # this policy allows the IAM OIDC identity provider to assume the IAM role via federated authentication
   data "aws_iam_policy_document" "assume_role_policy" {
     statement {
       actions = ["sts:AssumeRoleWithWebIdentity"]
       effect  = "Allow"

       principals {
         identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
         type        = "Federated"
       }

       condition {
         test     = "StringEquals"
         variable = "token.actions.githubusercontent.com:sub"
         # The repos and branches defined in var.allowed_repos_branches
         # will be able to assume this IAM role
         values = [
           for a in var.allowed_repos_branches :
           "repo:${a["org"]}/${a["repo"]}:ref:refs/heads/${a["branch"]}"
         ]
       }
     }
   }

   # Example:
   # allowed_repos_branches = [
   #   {
   #     org    = "brikis98"
   #     repo   = "terraform-up-and-running-code"
   #     branch = "main"
   #   }
   # ]
   variable "allowed_repos_branches" {
     description = "GitHub repos/branches allowed to assume the IAM role."
     type = list(object({
       org    = string
       repo   = string
       branch = string
     }))
   }
   ```

3. Set up Github Action to authenticate with AWS through OIDC

   ```yaml
   # .github/workflows/terraform.yml
   name: Terraform Apply

   # Only run this workflow on commits to the main branch
   on:
     push:
       branches:
         - "main"

   permissions:
     id-token: write

   jobs:
     TerraformApply:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v2

         # Authenticate to AWS using OIDC
         - uses: aws-actions/configure-aws-credentials@v1
           with:
             # Specify the IAM role to assume here
             role-to-assume: arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ROLE_ID>
             aws-region: <AWS_REGION>

         # Run Terraform using HashiCorp's setup-terraform Action
         - uses: hashicorp/setup-terraform@v1
           with:
             terraform_version: 1.1.0
             terraform_wrapper: false
           run: |
             terraform init
             terraform apply -auto-approve
   ```

### Resources and Data Sources

```t
resource "aws_db_instance" "example" {
  username = "admin"    # 🛑 DO NOT DO THIS!!!
  password = "password" # 🛑 DO NOT DO THIS!!!
}
```

#### Environment variables

Use Terraform native support for reading environment variables.

```t
variable "db_username" {
  description = "The username for the database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "example" {
  # Pass the secrets to the resource
  username = var.db_username
  password = var.db_password
}
```

```shell
$  export TF_VAR_db_username=(DB_USERNAME) # Don't forget leading space
$  export TF_VAR_db_password=(DB_PASSWORD) # Don't forget leading space
```

> 👎 **Drawbacks**
>
> - Not anything is defined in Terraform
>
>   e.g. More fiction to run our Terraform code. 🦥
>
> - Standardizing ~~secret management practices~~ is harder.
>
>   e.g. Someone may still store passwords in plaintext. 😭
>
> - Secrets are not ~~versioned, packaged, tested~~ with our code.
>
>   e.g. It's easy to add secret in 1 environment, and FORGET in another environment. 🐒

#### Encrypted files

Let's do it with AWS KMS.

- Create a KMS _Customer Managed Key_ (an encrypted key that AWS manages for us)

  To keep this example simple, we'll create a `key_policy` that give the **current user** _admin permissions over the CMK_

  ```
  provider "aws" {
    region = "ap-southeast-1"
  }

  # Fetch current user's information
  data "aws_caller_identity" "self" {}

  # Create a key IAM policy that gives the current user admin permissions over the CMK
  data "aws_iam_policy_document" "cmk_admin_policy" {
    statement {
      effect    = "Allow"
      resources = ["*"]
      actions   = ["kms:*"]
      principals {
        type        = "AWS"
        identifiers = [data.aws_caller_identity.self.arn]
      }
    }
  }

  # Create the CMK
  resource "aws_kms_key" "cmk" {
    policy = data.aws_iam_policy_document.cmk_admin_policy.json
  }

  # Create a human-friendly alias for our CMK
  resource "aws_kms_alias" "cmk" {
    name          = "alias/kms-cmk-example"
    target_key_id = aws_kms_key.cmk.id
  }
  ```

- Using the CMK to encrypt

  - Our data

    ```yaml
    #
    # db-creds.yml
    username: admin
    password: secret-password
    ```

  - A script to encrypt data and save to a file

    ```bash
    CMK_ID="$1"
    AWS_REGION="$2"
    INPUT_FILE="$3"
    OUTPUT_FILE="$4"

    echo "Encrypting contents of $INPUT_FILE using CMK $CMK_ID..."
    ciphertext=$(aws kms encrypt \
      --key-id "$CMK_ID" \
      --region "$AWS_REGION" \
      --plaintext "fileb://$INPUT_FILE" \
      --output text \
      --query CiphertextBlob)

    echo "Writing result to $OUTPUT_FILE..."
    echo "$ciphertext" > "$OUTPUT_FILE"

    echo "Done!"
    ```

  - Use the script to encrypt our data

    ```shell
    $ ./encrypt.sh \
         alias/kms-cmk-example \
         ap-southeast-1 \
         db-creds.yml \
         db-creds.yml.encrypted
    ```

- Using the CMK to decrypt data (and use it in our Terraform code)

```t
# Read the encrypted file
# Decrypted the contents
data "aws_kms_secrets" "creds" {
  secret {
    name    = "db"
    payload = file("${path.module}/db-creds.yml.encrypted")
  }
}

# Pull out the decrypted secrets
# Parse the YAML
# Store the results in local variable `db_creds`
locals {
  db_creds = yamldecode(data.aws_kms_secrets.creds.plaintext["db"])
}

# Pass the secrets to the resource
resource "aws_db_instance" "example" {
  username = local.db_creds.username
  password = local.db_creds.password
}
```

> 👎 Drawbacks:
>
> - Storing secrets is harder.
> - Integrated tests is harder.
> - The ability to audit who accessed is minimal.

#### Secret stores

e.g. AWS Secrets Manager, Google Secret Manager, Azure Key Vault, Hashicorp Vault.

Let's try AWS Secrets Manager.

- To store a new secret, we'll use the AWS Web Console.
  The secrets will be store in JSON format.

- To read a secret in Terraform code use `aws_secretsmanager_secret_version` data source, and `jsondecode` function

```t
data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "db-creds" # It's the secret name in Web Console
}

locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

# Pass the secrets to the resource
resource "aws_db_instance" "example" {
  username = local.db_creds.username
  password = local.db_creds.password
}
```

> 👎 Drawbacks:
>
> - Secrets are not versioned, packaged, tested with our code
> - Secret stores cost money

### State Files and Plan Files

#### State Files

**Any secrets** we pass into our Terraform resources and data sources will _end up in **plain text** in our Terraform state file_.

This has been an [open issue](https://github.com/hashicorp/terraform/issues/516) since 2014, with no clear plans for a first class solution.

For now, we must do the following:

- Store Terraform state in a remote backend that supports encryption (in transit and at rest).
  e.g. S3, GCS. Azure Blob Storage

- Strictly control who can access our Terraform backend
  Only some trusted devs should have access to S3 bucket that store Terraform state.

#### Plan Files

The `plan` command can store its output in a file

```shell
$ terraform plan -out=example.plan
```

Later, we can run `apply` command on this saved plan file to ensure that Terraform applies _exactly_ the changes we saw originally

```shell
$ terraform apply example.plan
```

It's the same problem with state files. 😑

## Conclusion

Do _NOT_ store secrets in plaintext. 🔐

To pass secrets to providers:

- for **human users**:
  - personal secret managers
  - Set environemnt variables
- for **machine users**"
  - Use stored credentials
  - IAM roles
  - OIDC

To pass secrets to resources:

- Environment variables
- Encrypted files
- Centralized secret stores.

No mater how we pass secrets, Terraform will store those secrets in plaintext in state files and plan files.
