# Configuration web server

## Terraform Input Variable

### Declaring an Input Variable

```terraform
variable "NAME" { # A variable block
  [CONFIG ...]
}
```

```terraform
variable "image_id" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."
}
```

```terraform
variable "server_port" {
  type= number
  description = "the port the server will use for http requests"
}
```

```terraform
variable "enable_logging" {
  type	= bool
  default = true
}
```

```terraform
variable "availability_zone_names" {
  type    = list(string)
  default = ["us-east-1a", "ap-southeast-1a"]
}
```

```terraform
variable "tags" {
  type = map(string)
  default = {
    Name      = "demo-instance"
    Environment = "dev"
  }
}
```

```terraform
variable "user" {
  type = object({
    name  = string
    email = string
    age   = number
  })

  default = {
    name  = "Sam"
    email = "sam@example.com"
    age   = 30
  }
}
```

```terraform
variable "security_groups" {
  type	= set(string)
  default = ["sg-12345678", "sg-abcdefgh"]
}
```

```terraform
variable "tenant_permissions" {
  description = "A list of permissions for each tenant"
  type = list(tuple([
    string,       # Tenant name
    list(string), # List of allowed actions
  ]))
  default = [
    ["tenant1", ["read", "write"]],
    ["tenant2", ["read"]],
    ["tenant3", []], # No permissions for tenant3
  ]
}
```

### Use Input Variable Values

```terraform
var.<VAR_NAME> # This expression is called a `variable reference`
```

```terraform
resource "aws_instance" "my_instance" {
  instance_type = "t2.micro"
  ami           = var.image_id
}
```

### Validate Input Variable Values

```
variable "image_id" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."

  validation {
    condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
    error_message = "The image_id value must be a valid AMI id, starting with \"ami-\"."
  }
}
```