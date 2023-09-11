# 11-terraform-loops-if

## Loops

### Loops with the `count` parameter

`count` is Terraform’s oldest 👴, simplest 🍰, and most limited 🤏 iteration construct.

#### Use `count` with a resource

```t
# live/global/iam/main.tf

# Createa an IAM user
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
$ terrafrom apply

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

- Lose availibility: During the apply, the user can't access AWS.
- Or worse, lose data: If the resource is a database.

To solve these problem, Terrafrom 0.12 introduced `for_each`.

### Loops with the `for_each` expressions

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
  name     = each.value # Use eact.value to access the username
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

If we want to get the same output values as when we use `count`. We need to extract it from the map using `values` function, and a splat expression `*`.

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

#### Using `for_each` witin resources to create multiple inline blocks (or [dynamic Blocks](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks))

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

  dynamic "tag" { # tag is the variable that will store the value of eact "iteration"
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

### Loops with the `for` expressions

We can create use loops to create:

- Multiple copies of resources
- Multiple inline blocks

But can we loop through a set and transform that set (e.g. Make it UPPERCASE)? Like in a GPL

```javascript
let usernames = ["neo", "trinity", "morpheus"];
let usernames_uppercase = usernames.map((u) => u.toUppercase());
// ["NEO", "TRINITY", "MORPHEUS"]
```

Terraform can do this with `for` expression:

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

- Another synxtax `[for <KEY>, <VALUE> in <MAP> : <OUTPUT>]` (Just like Golang).

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

### Loops with the `for` string directive

We can use `for` string directive to

- itereate over a collections
- evalutes a given templace once for each element
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

### Conditionals with the `count` Parameter

#### If-statements with the `count` Parameter

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

Enable auto scaling for `prod` environemnt:

```t
# live/prod/services/webserver-cluster/main.tf
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"
  # ...
  enable_autoscaling   = true
}
```

#### If-else-statements with the `count` Parameter

### Conditionals with `for_each` and `for` Expressions

### Conditionals with the `if` String Directive

## Zero-Downtime Deployment

## Terraform Gotchas

### count and for_each Have Limitations

### Zero-Downtime Deployment Has Limitations

### Valid Plans Can Fail

### Refactoring Can Be Tricky

## Conclusion
