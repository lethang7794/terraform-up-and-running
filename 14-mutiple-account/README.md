# Working with multiple AWS accounts

```t
provider "aws" {
  region = "ap-southeast-1"
  alias  = "parent"
}

provider "aws" {
  region = "ap-southeast-1"
  alias  = "child"

  assume_role {
    role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>"
  }
}

data "aws_caller_identity" "parent" {
  provider = aws.parent
}

data "aws_caller_identity" "child" {
  provider = aws.child
}

output "parent_account_id" {
  value       = data.aws_caller_identity.parent.account_id
  description = "The ID of the parent AWS account"
}

output "child_account_id" {
  value       = data.aws_caller_identity.child.account_id
  description = "The ID of the child AWS account"
}
```

> ⚠️ Cross-account IAM roles are double opt-in
>
> e.g. To allow an IAM role in child account `222222222222` to be assumed from parent account `111111111111`:
>
> - In child account `222222222222` (where the IAM role live), we must config its assume role policy to trust the other account (parent account `111111111111`)
> - In parent account `111111111111` (from which assume the role), we must grant permissions to assume that IAM role.

> ⚠️⚠️⚠️ Use aliases sparingly (again)
>
> Only use alias to create resources in multiple account when you when you intentionally want they to be coupled and deployed together.
