# 11-terraform-loops-if

## Loops

### Loops with the [`count` Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)

`count` is Terraform’s oldest 👴, simplest 🍰, and most limited 🤏 iteration construct.

#### Use `count` with a resource

```t
# live/global/iam/main.tf

# Create an IAM user
resource "aws_iam_user" "one_user" {
  name = "neo"
}

# Create 3 IAM users
resource "aws_iam_user" "three_users" {
  count = 3                    # Adding count to a resource turns it into an array of resources.
  name  = "neo.${count.index}" # Use count.index to get the index of each “iteration” in the “loop”
}
```

```shell
$ terraform plan

Terraform will perform the following actions:

  # aws_iam_user.example[0] will be created
  + resource "aws_iam_user" "example" {
      + name          = "neo.0"
      (...)
    }

  # aws_iam_user.example[1] will be created
  + resource "aws_iam_user" "example" {
      + name          = "neo.1"
      (...)
    }

  # aws_iam_user.example[2] will be created
  + resource "aws_iam_user" "example" {
      + name          = "neo.2"
      (...)
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

`neo.0` is not a fascinating name, let's get the names from a list

```t
# live/global/iam/variables.tf
variable "usernames" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}
```

```t
# Create n IAM users from a predefined list
resource "aws_iam_user" "n_users" {
  count = length(var.usernames)      # length(<ARRAY>)
  name  = var.usernames[count.index] # <ARRAY>[<INDEX>]
}
```

After we use `count` on a resource, it's become an array of resources. Instead of read an attribute from that resource with `<PROVIDER>_<TYPE>.<NAME>.<ATTRIBUTE>`, we need to specify which resource we want to access `<PROVIDER>_<TYPE>.<NAME>[INDEX].ATTRIBUTE`.

```t
output "first_arn" {
  description = "The ARN for the first user"
  value       = aws_iam_user.example[0].arn # <PROVIDER>_<TYPE>.<NAME>[INDEX].ATTRIBUTE
}


output "all_arns" {
  description = "The ARNs for all users"
  value       = aws_iam_user.example[*].arn # Use splat expression, “*” to get all the resources
}
```

```shell
$ terraform apply

(...)

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

first_arn = "arn:aws:iam::123456789012:user/neo"
all_arns = [
  "arn:aws:iam::123456789012:user/neo",
  "arn:aws:iam::123456789012:user/trinity",
  "arn:aws:iam::123456789012:user/morpheus",
]
```

#### Use `count` with a module

From Terraform 0.13, the count parameter can also be used on modules

```t
# modules/landing-zone/iam-user
variable "username" {
  description = "The user name to use"
  type        = string
}

resource "aws_iam_user" "example" {
  name = var.username
}

output "user_arn" {
  value       = aws_iam_user.example.arn
  description = "The ARN of the created IAM user"
}
```

```t
# live/global/landing-zone/iam-user
variable "usernames" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["harry", "hermione", "ron"]
}

module "users" {
  source = "../../../modules/landing-zone/iam-user"

  count     = length(var.usernames) # Adding count to a module turns it into an array of modules.
  username = var.usernames[count.index]
}

output "user_arns" {
  value       = module.users[*].user_arn
  description = "The ARNs of the created IAM users"
}
```

#### `count` limitation

1. `count` cannot be used within a resource to loop over inline blocks. e.g.

```t
resource "aws_autoscaling_group" "example" {
  # ...

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}
```

We can't let the module consumers pass a list of tags, then use `count` to loop over the tags list and generate inline `tag` blocks.

2. If we modify the list, `count` will become unpredictable. Because `count` identifies each resource within the array is by its position (index) in that array.

For example, we've already run `terraform apply` with a config of 3 usernames

```
variable "usernames" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["tom", "trinity", "morpheus"]
}
```

If we removed `trinity` from the list, then rerun `terraform apply` again.

```shell
$ terraform plan

(...)

Terraform will perform the following actions:

  # aws_iam_user.example[1] will be updated in-place
  ~ resource "aws_iam_user" "example" {
        id            = "trinity"
      ~ name          = "trinity" -> "morpheus"
    }

  # aws_iam_user.example[2] will be destroyed
  - resource "aws_iam_user" "example" {
      - id            = "morpheus" -> null
      - name          = "morpheus" -> null
    }

Plan: 0 to add, 1 to change, 1 to destroy.
```

Terraform will:

- rename the second user `trinity` to `morpheus`.
- destroy the third user `morpheus`.

That may not what we want.

What's happening?

After the first `terraform apply`, Terraform state is something like this:

```shell
aws_iam_user.example[0]: neo
aws_iam_user.example[1]: trinity
aws_iam_user.example[2]: morpheus
```

After the first `terraform apply`, the state will be:

```shell
aws_iam_user.example[0]: neo
aws_iam_user.example[1]: morpheus
```

This will cause so much problems:

- Lose availability: During the apply, the user can't access AWS.
- Or worse, lose data: If the resource is a database.

To solve these problem, Terrafrom 0.12 introduced `for_each`.

### Loops with the [`for_each` Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)

#### Using `for_each` with resources

```t
# for_each syntax
resource "<PROVIDER>_<TYPE>" "<NAME>" {
  for_each = <COLLECTION>

  [CONFIG ...]
}
```

Within CONFIG, we can use `each.key` and `each.value` to access the current item in `COLLECTION`.

```t
variable "usernames" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

resource "aws_iam_user" "example" {
  # Use for_each to loop over the set of usernames
  for_each = toset(var.usernames) # Use toset to convert the list into a set. ⚠️ When using on a resource, for_each support only sets/maps.
  name     = each.value # Use each.value to access the username
}

output "all_users" {
  value = aws_iam_user.example # After we've used `for_each`on a resource, it becomes a map of resources.
}
```

```shell
$ terraform apply

(...)

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

all_users = {
  "morpheus" = {
    "arn" = "arn:aws:iam::123456789012:user/morpheus"
    "force_destroy" = false
    "id" = "morpheus"
    "name" = "morpheus"
    "path" = "/"
    "tags" = {}
  }
  "neo" = {
    "arn" = "arn:aws:iam::123456789012:user/neo"
    "force_destroy" = false
    "id" = "neo"
    "name" = "neo"
    "path" = "/"
    "tags" = {}
  }
  "trinity" = {
    "arn" = "arn:aws:iam::123456789012:user/trinity"
    "force_destroy" = false
    "id" = "trinity"
    "name" = "trinity"
    "path" = "/"
    "tags" = {}
  }
}
```

After we've used `for_each`on a resource, it becomes a map of resources.

The `aws_iam_user.example` is a map:

- Keys are the key in `for_each` (usernames).
- Values are the outputs for that resource.

> **Note:** The order of the items may be changed. They will be sorted by the keys.

If we want to get the same output values as when we use `count`. We need to extract it from the map using `values` function, and a [`splat expression`](https://developer.hashicorp.com/terraform/language/expressions/splat) `*`.

```t
output "all_arns" {
  value = values(aws_iam_user.example)[*].arn
  # Use values functions to return just the values of the map
  # Use splat expression “*” to get all the resources
}
```

```t
$ terraform apply

(...)

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

all_arns = [
  "arn:aws:iam::123456789012:user/morpheus",
  "arn:aws:iam::123456789012:user/neo",
  "arn:aws:iam::123456789012:user/trinity",
]
```

By having a map of resources, we can safely manipulate (add, remove) the list we pass to the input variable.

Let's remove the `trinity` user.

```shell
$ terraform apply -var 'usernames=["neo", "trinity", "morpheus"]'

Terraform will perform the following actions:

  # aws_iam_user.example["trinity"] will be destroyed
  - resource "aws_iam_user" "example" {
      - arn           = "arn:aws:iam::123456789012:user/trinity" -> null
      - name          = "trinity" -> null
    }

Plan: 0 to add, 0 to change, 1 to destroy.
```

#### Using `for_each` with modules

`for_each` works with modules just as `count`

```t
# live/global/landing-zone/iam-user
variable "usernames" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["harry", "hermione", "ron"]
}

module "users" {
  source = "../../../modules/landing-zone/iam-user"

  for_each = toset(var.usernames) # Replace count with for_each, convert the list to a set
  username = each.value           # Just get the item with each.value instead of accessing by index var.usernames[count.index]
}

output "user_arns" {
  description = "The ARNs of the created IAM users"
  value       = values(module.users)[*].user_arn
}
```

```shell
# live/global/landing-zone/iam-user
$ terraform apply

(...)

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

all_arns = [
  "arn:aws:iam::123456789012:user/morpheus",
  "arn:aws:iam::123456789012:user/neo",
  "arn:aws:iam::123456789012:user/trinity",
]
```

#### Using `for_each` within resources to create multiple inline blocks (or [dynamic Blocks](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks))

A `dynamic block` acts much like a `for` expression, but produces nested blocks instead of a complex typed value.

It iterates over a given complex value, and generates a nested block for each element of that complex value.

Let's allow users to add any tags they want.

```t
# modules/services/webserver-cluster/variables.tf
variable "custom_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string) # Use a map because we need both the key and value of item
  default     = {}
}
```

```t
# live/stage/services/webserver-cluster/main.

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  custom_tags = {
    Owner          = "team-foo"
    ManagedBy      = "Terraform"
    TagCreatedWith = "for_each"
  }
}
```

The syntax to of dynamic blocks.

```t
dynamic "<LABEL>" {       # LABEL specifies what kind of nested block to generate.
  for_each = <COLLECTION> # COLLECTION is a list or map to iterate over

  content {     # content block defines the body of each generated block.
    [CONFIG...] # Within CONFIG, the key is access with LABEL.key, the value is access with LABEL.value
  }
}
```

```t
# modules/services/webserver-cluster/main.tf

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  # ...

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" { # tag is the variable that will store the value of each "iteration"
    for_each = var.custom_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
```

```shell
# modules/services/webserver-cluster/
$ terraform plan

Terraform will perform the following actions:

  # aws_autoscaling_group.example will be updated in-place
  ~ resource "aws_autoscaling_group" "example" {
        (...)

        tag {
            key                 = "Name"
            propagate_at_launch = true
            value               = "webservers-prod"
        }
      + tag {
          + key                 = "Owner"
          + propagate_at_launch = true
          + value               = "team-foo"
        }
      + tag {
          + key                 = "ManagedBy"
          + propagate_at_launch = true
          + value               = "terraform"
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

> 💡: We can apply tags to all AWS resources using `default_tags` block in `aws` provider
>
> ```tf
> provider "aws" {
>   region = "ap-southeast-1"
>
>   # Tags to apply to all AWS resources by default
>   default_tags {
>     tags = {
>       Owner          = "team-foo"
>       ManagedBy      = "Terraform"
>       TagCreatedWith = "default_tags"
>     }
>   }
> }
> ```

### Loops with the [`for` Expressions](https://developer.hashicorp.com/terraform/language/expressions/for)

We can create use loops to create:

- Multiple copies of resources
- Multiple inline blocks

But can we loop through a set and transform that set (e.g. Make it UPPERCASE)? Like in a GPL

```javascript
let usernames = ["neo", "trinity", "morpheus"];
let usernames_uppercase = usernames.map((u) => u.toUppercase());
// ["NEO", "TRINITY", "MORPHEUS"]
```

Terraform can do this with `for` Expression:

```t
[for <ITEM> in <LIST> : <OUTPUT>]
```

```t
# Example
variable "names" {
  description = "A list of names"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

output "upper_names" {
  value = [for name in var.names : upper(name)] # [for <ITEM> in <LIST> : <OUTPUT>]
}
```

```shell
$ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

upper_names = [
  "NEO",
  "TRINITY",
  "MORPHEUS",
]
```

`for` expression also supports:

- Filter the resulting list.

  ```t
  output "short_upper_names" {
    value = [for name in var.names : upper(name) if length(name) < 5]
  }
  ```

  ```shell
  $ terraform apply
  ...
  short_upper_names = [
    "NEO",
  ]
  ```

- Another syntax `[for <KEY>, <VALUE> in <MAP> : <OUTPUT>]` (Just like Golang).

  ```t
  variable "character_roles" {
    description = "map"
    type        = map(string)
    default     = {
      neo      = "hero"
      trinity  = "love interest"
      morpheus = "mentor"
    }
  }

  output "roles" {
    value = [for name, role in var.character_roles : "${name} is the ${role}"]
  }
  ```

  ```
  $ terrafrom apply
  roles = [
    "morpheus is the mentor",
    "neo is the hero",
    "trinity is the love interest",
  ]
  ```

- Loop over a list and output a map

  ```t
  {for <ITEM> in <LIST> : <OUTPUT_KEY> => <OUTPUT_VALUE>}
  ```

- Loop over a map and output a map

  ```t
  {for <KEY>, <VALUE> in <MAP> : <OUTPUT_KEY> => <OUTPUT_VALUE>}
  ```

  For example

  ```t
  output "upper_roles" {
    value = {for name, role in var.character_roles : upper(name) => upper(role)}
  }
  ```

  > ⚠️ Don't forget the curly brackets {}

### Loops with the `for` [String Directive](https://developer.hashicorp.com/terraform/language/expressions/strings#string-templates)

We can use `for` string directive to

- iterate over a collections
- evaluate a given template once for each element
- concatenate the results together.

It's call `string directive`:

```t
# Access the item
%{ for <ITEM> in <COLLECTION> }<BODY>%{ endfor }

# Access both the index and item
%{ for <INDEX>, <ITEM> in <COLLECTION> }<BODY>%{ endfor }
```

e.g.

```t
variable "names" {
  description = "Names to render"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

output "awesome_string" {
  value = "%{ for name in var.names }${name}, %{ endfor }"
}
```

```shell
$ terraform apply

(...)

Outputs:

awesome_string = "neo, trinity, morpheus, "
```

We can also get the index of the items (Just like Golang again).

```t
# Access both the index and item
%{ for <INDEX>, <ITEM> in <COLLECTION> }<BODY>%{ endfor }
```

```t
variable "names" {
  description = "Names to render"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

output "awesome_string_with_index" {
  value = "%{ for i, name in var.names }(${i}) ${name}, %{ endfor }"
}
```

```shell
$ terraform apply

(...)

Outputs:

awesome_string_with_index = "(0) neo, (1) trinity, (2) morpheus, "
```

> ℹ️ For now, in both outputs there is an extra trailing comma and space. We will fix it with conditionals - the `if` string directive.

## Conditionals

Each of the ways to do loops needs a different way to do conditionals. 🥲

### Conditionals with the `count` Meta-Argument

#### If-statements with the `count` Meta-Argument

Back to the Auto Scaling Group example, we want to scale the cluster out only in production.

Currently, we define the `aws_autoscaling_schedule` directly in the `root module` of `prod` environment .

What if we want consistency and define it inside the module? If some one need it, they can just turn it on without worry about the resource config.

We can do it by:

- Toggle count between `1` and `0`.
  - If count is `1`, we get one copy of that resource.
  - If count is `0`, that resource is not created at all.
- Use the `conditional expression` - `ternary syntax` to conditional get the count value
  ```t
  <CONDITION> ? <TRUE_VAL> : <FALSE_VAL>
  ```

```t
# modules/services/webserver-cluster/main.tf
variable "enable_autoscaling" {
  description = "If set to true, enable auto scaling"
  type        = bool
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0 # A fake if with count and ternary

  # ...
  recurrence             = "0 9 * * *"
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = var.enable_autoscaling ? 1 : 0 # Another fake if with count and ternary

  # ...
  recurrence             = "0 17 * * *"
}
```

Disable auto scaling for `stage` environment:

```t
# live/stage/services/webserver-cluster/main.tf
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"
  # ...
  enable_autoscaling   = false
}
```

Enable auto scaling for `prod` environment:

```t
# live/prod/services/webserver-cluster/main.tf
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"
  # ...
  enable_autoscaling   = true
}
```

#### If-else-statements with the `count` Parameter

Example: We have 2 `aws_iam_policy` needs to be conditional applied to an `aws_iam_user`

```t
# A IAM policy with CloudWatch read only permissions
resource "aws_iam_policy" "cloudwatch_read_only" {
  name   = "cloudwatch-read-only"
  policy = data.aws_iam_policy_document.cloudwatch_read_only.json
}

data "aws_iam_policy_document" "cloudwatch_read_only" {
  statement {
    effect    = "Allow"
    actions   = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*"
    ]
    resources = ["*"]
  }
}
```

```t
# A IAM policy with CloudWatch full permissions
resource "aws_iam_policy" "cloudwatch_full_access" {
  name   = "cloudwatch-full-access"
  policy = data.aws_iam_policy_document.cloudwatch_full_access.json
}

data "aws_iam_policy_document" "cloudwatch_full_access" {
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:*"]
    resources = ["*"]
  }
}
```

Which use will have full access?

```t
variable "give_neo_cloudwatch_full_access" {
  description = "If true, neo gets full access to CloudWatch"
  type        = bool
}
```

Let's simulate if-else-statements with `count` and `ternary`:

```t
resource "aws_iam_user_policy_attachment" "neo_cloudwatch_full_access" {
  count = var.give_neo_cloudwatch_full_access ? 1 : 0

  user       = aws_iam_user.example[0].name
  policy_arn = aws_iam_policy.cloudwatch_full_access.arn
}

resource "aws_iam_user_policy_attachment" "neo_cloudwatch_read_only" {
  count = var.give_neo_cloudwatch_full_access ? 0 : 1

  user       = aws_iam_user.example[0].name
  policy_arn = aws_iam_policy.cloudwatch_read_only.arn
}

# A not so robust output
output "neo_cloudwatch_policy_arn_BAD" {
  value = (
    var.give_neo_cloudwatch_full_access
    ? aws_iam_user_policy_attachment.neo_cloudwatch_full_access[0].policy_arn
    : aws_iam_user_policy_attachment.neo_cloudwatch_read_only[0].policy_arn
  )
}

# A better output
output "neo_cloudwatch_policy_arn_GOOD" {
  # one function takes a list as input
  # - if the list has 0 elements, it returns null;
  # - if the list has 1 element, it returns that element;
  # - if the list has more than 1 element, it shows an error.

  # concat function takes two or more lists as inputs and combines them into a single list.
  value = one(concat(
    aws_iam_user_policy_attachment.neo_cloudwatch_full_access[*].policy_arn,
    aws_iam_user_policy_attachment.neo_cloudwatch_read_only[*].policy_arn
  ))
}
```

### Conditionals with `for_each` Meta-Argument and `for` Expressions

Recall previous `for_each` example, there is already a little conditional here.

```t
# modules/services/webserver-cluster/main.tf

resource "aws_autoscaling_group" "example" {
  # ...
  dynamic "tag" {
    for_each = var.custom_tags  If var.custom_tags is empty, no tag will be set.

    content {
      key                 = tag.key
      value               = tag.value
    }
  }
}
```

We can go even further by combining adding a `for` expression:

```t
resource "aws_autoscaling_group" "example" {
  dynamic "tag" {
    for_each = {
      for key, value in var.custom_tags: key => upper(value) # A normal for expression
      if key != "Name"                                       # Conditional with if clause (or filter elements)
    }

    content {
      # ...
    }
  }
}
```

### Conditionals with the `if` String Directive

```t
%{ if <CONDITION> }<TRUEVAL>%{ endif }
```

e.g.

```t
variable "names" {
  description = "Names to render"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

output "awesome_string_without_if" {
  # This will have an extra comma and space `, `
  value = "%{ for name in var.names }${name}, %{ endfor }"

  # Use HEREDOC to make it more readable
  value = <<EOF
"%{ for i, name in var.names }
  ${name},
%{ endfor }"
EOF
}

output "awesome_string_with_if" {
  value = <<EOF
%{ for i, name in var.names }
  ${name}%{ if i < length(var.names) - 1 }, %{ endif } # Skip the separator for the last item
%{ endfor }
EOF
}
```

```shell
$ terraform apply

(...)

Outputs:

for_directive_index_if = <<EOT

  neo,

  trinity,

  morpheus


EOT
```

> HEREDOC: Allow define multiline strings
>
> 👉 The code can be split to several lines so it is more readable.

The extra comma and extra space are removed. But we have some other whitespace (spaces and new lines)

We can fix this by adding `strip markers` (`~`) to our string directive.

```t
output "for_directive_index_if_strip" {
  value = <<EOF
%{~ for i, name in var.names ~}
${name}%{ if i < length(var.names) - 1 }, %{ endif }
%{~ endfor ~}
EOF
}
```

```shell
$ terraform apply
(...)
Outputs:
for_directive_index_if_strip = "neo, trinity, morpheus"
```

We can even make a the output a little more fancy by adding an `else` statement:

```t
# if-else string directive syntax
%{ if <CONDITION> }<TRUEVAL>%{ else }<FALSEVAL>%{ endif }
```

```t
output "for_directive_index_if_else_strip" {
  value = <<EOF
%{~ for i, name in var.names ~}
${name}%{ if i < length(var.names) - 1 }, %{ else }.%{ endif } # Add a period at the end
%{~ endfor ~}
EOF
}
```

```shell
$ terraform apply
(...)
Outputs:
for_directive_index_if_else_strip = "neo, trinity, morpheus."
```

## Zero-Downtime Deployment

### Simulating a new deployment

Our module is now clean and simple for deploying a web server cluster.

The next question is how do we update that cluster?

- When we make changes to our code, how do we deploy the new AMI across the cluster?
- How to do that without causing downtime?

In a real world scenario, the first step is expose the AMI as an input variable

```t
# modules/services/webserver-cluster/variables.tf
variable "ami" {
  description = "The AMI to run in the cluster"
  type        = string
  default     = "ami-0fb653ca2d3203ac1"
}
```

But for now, we will simulate the new code (and the new AMI) with a change in `User Data` script by exposing a `server_text` input variable:

```t
variable "server_text" {
  description = "The text the web server should return"
  type        = string
  default     = "Hello, World"
}
```

Pass the `server_text` value to the template:

```t
# modules/services/webserver-cluster/main.tf
resource "aws_launch_configuration" "example" {
  # ...
  user_data = templatefile("${path.module}/user-data.sh", {
    # ...
    server_text = var.server_text
  })
  # ...
}
```

Use the `server_text` value in user data script:

```bash
# modules/services/webserver-cluster/user-data.sh
# ...
<h1>${server_text}</h1>
# ...
```

###

The final step is set the `ami` and `server_text` to a new value in `root module`:

```t
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"
  ami         = "ami-0fb653ca2d3203ac1"
  server_text = "New server text"
  # ...
}
```

```shell
$ terraform plan

Terraform will perform the following actions:

  # module.webserver_cluster.aws_autoscaling_group.ex will be updated in-place
  ~ resource "aws_autoscaling_group" "example" {
        id                        = "webservers-stage-terraform-20190516"
      ~ launch_configuration      = "terraform-20190516" -> (known after apply)
        (...)
    }

  # module.webserver_cluster.aws_launch_configuration.ex must be replaced
+/- resource "aws_launch_configuration" "example" {
      ~ id                          = "terraform-20190516" -> (known after apply)
        (...)
      ~ user_data                   = "bd7c0a6" -> "4919a13" # forces replacement
        (...)
    }

Plan: 1 to add, 1 to change, 1 to destroy.
```

Terraform plan to do 2 things:

- Replace the `aws_launch_configuration` with a new that has updated `user_data`.
- Update in-place `aws_autoscaling_group` to reference to the new `aws_launch_configuration`.

### Implement zero-downtime deployment with Terraform

Currently, the `aws_autoscaling_group` only applies the new AMI image for new EC2 instances.

> **❓ How do we instruct the ASG to deploy new instances (with the new AMI)?**
>
> 1. Destroy the ASG, then re-create it.
>
>    There will be downtime 🚧, which is not what we want.
>
> 2. Create a ASG first, then destroy the old one.
>
>    This can be easily done with Terraform [`lifecycle`](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle) - `create_before_destroy`

> 🛠️ Implement zero-downtime deployment with `lifecycle` `create_before_destroy`
>
> 1. Force Terraform to replace the ASG when the launch config changed
>
>    Add a `name` parameter of ASG which reference the launch config name.
>
> 2. Tell Terraform to create a new ASG before destroy the old one
>
>    Set `create_before_destroy` parameter of ASG to `true`.
>
> 3. Make sure the new ASG working as expected before destroy the old one
>
>    Set `min_elb_capacity` of ASG to its `min_size`.

```t
# modules/services/webserver-cluster/main.tf
resource "aws_autoscaling_group" "example" {
  name = "${var.cluster_name}-${aws_launch_configuration.example.name}" # Explicitly depend on the launch configuration's name so each time it's replaced, this ASG is also replaced
  # ...
  min_elb_capacity = var.min_size # Wait for at least this many instances to pass health checks before considering the ASG deployment complete

  lifecycle {
    create_before_destroy = true # When replacing this ASG, create the replacement first, and only delete the original after
  }
}

resource "aws_autoscaling_group" "example" {
  # ...
}
```

### Make a zero-downtime

```shell
$ terraform apply

Terraform will perform the following actions:

  # module.webserver_cluster.aws_autoscaling_group.example must be replaced
+/- resource "aws_autoscaling_group" "example" {
      ~ id     = "example-2019" -> (known after apply)
      ~ name   = "example-2019" -> (known after apply) # forces replacement
        (...)
    }

  # module.webserver_cluster.aws_launch_configuration.example must be replaced
+/- resource "aws_launch_configuration" "example" {
      ~ id              = "terraform-2019" -> (known after apply)
        image_id        = "ami-0fb653ca2d3203ac1"
        instance_type   = "t2.micro"
      ~ name            = "terraform-2019" -> (known after apply)
      ~ user_data       = "bd7c0a" -> "4919a" # forces replacement
        (...)
    }

    (...)

Plan: 2 to add, 2 to change, 2 to destroy.
```

```shell
$ while true; do curl http://<load_balancer_url>; sleep 1; done
# 1. Only the old code are running
# 2. Both old code and new code run at the same time. This will happen still the new ASG has registered enough instance to load balancer
# 3. Only the new code are running
```

If something went wrong, Terrafrom will:

- wait up to `wait_for_capacity_timeout` (default is 10 minutes) for the `min_elb_capacity` servers of the ASG v2 to register with the LB.
- after that the deployment is considered failed
- then Terraform destroys the ASG v2, and exits with an error. Meanwhile ASG v1 is still up and running.

## Terraform Gotchas

### count and for_each Have Limitations

`count` and `for_each` can reference:

- hardcoded values

  e.g `count = 3`

- variables

  e.g. `count = var.num_of_servers`

- data sources

  e.g. `count = length(data.aws_availability_zones.all.names)`

- and even lists of resources (so long as the length of the list can be determined during plan)

But NOT another resource outputs.

e.g. `count = random_integer.num_instances.result # This does NOT work`

Terraform requires that it can compute `count` and `for_each` during the plan phase, before any resources are created or modified.

### Zero-Downtime Deployment Has Limitations

Using `create_before_destroy` for zero-downtime deployment has drawback:

- It doesn't work with auto scaling policies (the ASG size is reset back to its `min_size`)

  There is some workaround for this

  - Use the `autoscaling_schedule`'s `recurrence` parameter

  - Get the _current capacity_ through a script (that called AWS API), and set the `desired_capacity` to that value.

> 💡 AWS now offers a native solution for zero-downtime deployment for ASG. It's `instance_refresh`.
>
> The zero-downtime deployment is now a fully managed process by AWS.
>
> The only drawback is it's too slow. 🐌

```t
resource "aws_autoscaling_group" "example" {
  name = var.cluster_name
  # ...
  instance_refresh { # AWS native solution
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}
```

Nowadays, many resources support native deployment options:

- [AWS ECS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)

  ```t
  resources "aws_ecs_service" "example" {
    # deployment_maximum_percent
    # deployment​_minimum_healthy_percent
  }
  ```

- [Kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment)

  ```t
  resource "kubernetes_deployment" "example" {
    strategy = "RollingUpdate"
    rolling_update {
      # max_surge
      # max_unavailable
    }
  }
  ```

Make use of native functionality when we can!

### Valid Plans Can Fail

Sometimes,

- we run the `terraform plan` and it shows we a perfectly valid-looking plan ✅,
- but when we run `terraform apply`, it shows an error ❌.

This happens because Terraform looks only at resources in its Terraform state.

If some resources are _out-of-band_:

- Someone manually clicking around the AWS console, or use AWS CLI to update that resources
  👉 `terraform apply` will fail.

This is a tricky problem.

For now we only need to remember:

- After a resource is created with Terraform, only use Terraform to managed it.
- If someone modify a resource created with Terraform, check this talk: [Terraform Config Drift: How to Handle Out-of-Band Infrastructure Changes](https://www.hashicorp.com/resources/terraform-config-drift-how-to-handle-out-of-band-infrastructure-changes)
- If we have existing infrastructure:
  - Manually use [`terraform import`](https://developer.hashicorp.com/terraform/cli/commands/import) for each resources.
  - Or use a tool ([`terraformer`](https://github.com/GoogleCloudPlatform/terraformer), [`terracognita`](https://github.com/cycloidio/terracognita)) to automatically import.

### Refactoring Can Be Tricky

> Refactoring: Restructure the internal details of an existing piece of code without changing its external behavior.
>
> The goal is to improve the readability, maintainability, and general hygiene of the code.
>
> e.g. Rename a variable, function. This can be done easily without thinking twice if the IDE supports it.

With Terraform, refactor can be tricky.

#### Rename a input variable

For example:

```t
variable "cluster_name" {
  type = string
}

resource "aws_lb" "example" {
  name = var.cluster_name
}
```

If we rename the input variable from `cluster_name` to `name`, the `aws_lb` `name` parameter will be changed too.

When we run `terraform apply`, Terraform will delete the old `aws_lb` and create a new `aws_lb` resource. It's downtime 🚧.

> **⚠️ Warning**
>
> If we change the `name` parameter of certain resources, Terraform will delete the old version of resource, and create a new version to replace it.
>
> While the resources is re-created, the might be side-effect that we don't want:
>
> - If it's a ALB, no traffic is routed to the web servers.
> - If it'a security group, the server will reject all network traffic.

#### Rename a resource identifier

For example:

```t
resource "aws_security_group" "instance" {
  # (...)
}
```

If we change `instance` to `ec2_instance`, and apply it. It's downtime.

As far as Terraform knows, we deleted the old resource and have added a completely new one.

> ℹ️ INFO
>
> Terraform associates each _resource identifier_ with an _identifier_ from the cloud provider.
>
> e.g.
>
> - an `iam_user` resource is associated with an AWS _IAM User ID_
> - an `aws_instance` resource with an AWS _EC2 Instance ID_

#### Refactoring lessons

1. Always use `terraform plan`.

   Carefully scan the output and check if Terraform is deleting some resources that we don't want to delete.

2. If a resource need to be replaced, create before destroy

   - Use the `lifecycle` `create_before_destroy`
   - Or do it manually:
     - Add the _new_ resource to Terraform config then apply.
     - Remove the _old_ resource from Terraform config.

3. Refactoring may require changing state

   But don't modify Terraform state files by hand.

   - Do it manually with `terraform state mv`.

     ```shell
     terraform state mv <ORIGINAL_REFERENCE> <NEW_REFERENCE>

     # e.g.
     terraform state mv \
       aws_security_group.instance \
       aws_security_group.cluster_instance
     ```

   - or do it automatically by adding a `moved` block to code.
     ```t
     moved {
       from = aws_security_group.instance
       to   = aws_security_group.cluster_instance
     }
     ```

4. Some parameters are _immutable_

   If we change these _immutable_ parameters, Terraform will delete the old resource and create a new one.

## Conclusion

Although Terraform is a **declarative** language, it includes a large number of tools:

- variables and modules
- loops: count, for_each, for
- if-statement tricks
- lifecycle (create_before_destroy), and built-in functions

that give the language a surprising amount of flexibility and expressive power.
