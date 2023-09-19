# Chap 8. Production-Grade Terraform Code

> **What is production-grade infrastructure?**
>
> The kind of infrastructure we can bet our company on. It won't:
>
> - fall over if traffic goes up
> - lose data if there's an outage
> - allow data to be compromised when hackers try to break in
>   ...
>
> and if it doesn't work, our company might be out of business.

> **How long it takes to build production-grade infrastructure from scratch?**
>
> | Type of infrastructure                      | Example                                             | Time estimate |
> | ------------------------------------------- | --------------------------------------------------- | ------------- |
> | Managed service                             | Amazon RDS                                          | 1–2 weeks     |
> | Self-managed distributed system (stateless) | A cluster of Node.js apps in an ASG                 | 2–4 weeks     |
> | Self-managed distributed system (stateful)  | Elasticsearch cluster                               | 2–4 months    |
> | Entire architecture                         | Apps, data stores, load balancers, monitoring, etc. | 6–36 months   |

## Why It Takes So Long to Build Production-Grade Infrastructure

Time estimates for software projects are notoriously inaccurate. Time estimates for DevOps projects, doubly so.

Infrastructure and DevOps projects, perhaps more than any other type of software, are the ultimate examples of Hofstadter’s Law.

> **[Hofstadter's Law](https://www.wikiwand.com/en/Hofstadter%27s_law)**
>
> It always takes longer than you expect, even when you take into account Hofstadter's Law.

3 reason for this:

- DevOps is still in the Stone Age.

  The terms `Cloud computing`, `Infrastructure as Code`, `DevOps` only appears in mid 2000s.

  Tools like `Docker`, `Terraform`, `Packer`, `Kubernetes` appears in mid 2010s.

  All of these are relative new and changing rapidly.

- DevOps seems to be particularly susceptible to `yak shaving`.

> What is `yak shaving`?
>
> Yak Shaving is the last step of a series of steps that occurs when you find something you need to do.
>
> <img src="https://images.prismic.io/sketchplanations/2a79fca9-374c-464f-a20e-14ae54ee8a7f_SP+726+-+Yak+shaving.png?auto=compress%2Cformat&fit=max&w=750&q=50" width="300">
>
> Try to [Don't shave that yak](https://seths.blog/2005/03/dont_shave_that/)

> **What is _accidental complexity_?**
>
> _Accidental complexity_ relates to problems which engineers create and can fix, imposed by tools and processes you’ve chosen,

> **What is _essential complexity_?**
>
> _Essential complexity_ caused by the problem to be solved, and nothing can remove it

- The essential complexity of DevOps.

  There is a genuinely long checklist of tasks that you must do to prepare infrastructure for production.

  And a vast majority of developers don't know about most items of this checklist. So when they estimate a project, they don't include a lot of critical and time-consuming task.

## The Production-Grade Infrastructure Checklist

| Task                 | Description                                                                                                                               | Example tools                  |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| 🔟 Install           | Install the software **binaries** and all **dependencies**.                                                                               | Bash, Ansible, Docker, Packer  |
| ⚙️ Configure         | Configure the software at **runtime**. Includes port settings, TLS certs, service discovery, leaders, followers, replication, etc.        | Chef, Ansible, Kubernetes      |
| 🖥️ Provision         | Provision the infrastructure. Includes servers, load balancers, network configuration, firewall settings, IAM permissions, etc.           | Terraform, CloudFormation      |
| 🎢 Deploy            | Deploy the service on top of the infrastructure. Roll out updates with no downtime. Includes blue-green, rolling, and canary deployments. | ASG, Kubernetes, ECS           |
| 🫁 High availability | **Withstand outages** of individual processes, servers, services, datacenters, and regions.                                               | Multi-datacenter, multi-region |
| 📈 Scalability       | Scale up and down in **response to load**. Scale horizontally (more servers) and/or vertically (bigger servers).                          | Auto scaling, replication      |
| 💨 Performance       | Optimize CPU, memory, disk, network, and GPU usage. Includes query tuning, benchmarking, load testing, and profiling.                     | Dynatrace, Valgrind, VisualVM  |
| 🌐 Networking        | Configure static and dynamic IPs, ports, service discovery, firewalls, DNS, SSH access, and VPN access.                                   | VPCs, firewalls, Route 53      |
| 🔒 Security          | Encryption in transit (TLS) and on disk, authentication, authorization, secrets management, server hardening.                             | ACM, Let’s Encrypt, KMS, Vault |
| 📊 Metrics           | Availability metrics, business metrics, app metrics, server metrics, events, observability, tracing, and alerting.                        | CloudWatch, Datadog            |
| 📜 Logs              | Rotate logs on disk. Aggregate log data to a central location.                                                                            | Elastic Stack, Sumo Logic      |
| 💾 Data backup       | Make backups of DBs, caches, and other data on a scheduled basis. Replicate to separate region/account.                                   | AWS Backup, RDS snapshots      |
| 💸 Cost optimization | Pick proper Instance types, use spot and reserved Instances, use auto scaling, and clean up unused resources.                             | Auto scaling, Infracost        |
| 📖 Documentation     | Document your code, architecture, and practices. Create playbooks to respond to incidents.                                                | READMEs, wikis, Slack, IaC     |
| 🧪 Tests             | Write automated tests for your infrastructure code. Run tests after every commit and nightly.                                             | Terratest, tflint, OPA, InSpec |

## Production-Grade Infrastructure Modules

### Small Modules

Downside of large modules:

- _Large modules are **slow**_

  Running any command will take a long time.

  No one want to run `terraform plan` if it takes 20 minutes to run!

- _Large modules are **insecure**_

  To change anything, we need permissions to access everything.

  This means that almost every user must be an admin, which goes against the principle of least privilege.

- _Large modules are **risky**_

  A mistake anywhere could break everything.

  e.g. We might be making a minor change to a frontend app in staging, but due to a typo or running the wrong command, we delete the production database.

- _Large modules are **difficult to understand**_

  The more code we have in one place, the more difficult it is for any one person to understand it all. And when we don’t understand the infrastructure we’re dealing with, we end up making costly mistakes.

- _Large modules are **difficult to review**_

  Reviewing a module that consists of several thousand lines of code is nearly impossible.

  If the output of the plan command is several thousand lines, no one will bother to read it.

- _Large modules are **difficult to test**_

  Testing infrastructure code is hard; testing a large amount of infrastructure code is nearly impossible.

In short, we should build our code out of small modules that each do one thing.

In Unix philosophy, it's **write programs that do one thing and do it well**. In Clean Code, it's "The first rule of functions is that they should be small. The second rule of functions is that they should be smaller than that.".

> What is **Unix philosophy**?
>
> Write programs that do one thing and do it well. Write programs to work together.

TODO: Refactor webserver-cluster module in Chapter 5 to 3 reusable modules: ASG, ALB, hello-world-app

### Composable Modules

In Unix philosophy, it's write programs to work together.

One way to do this is through _function composition_, in which you can take the outputs of one function and pass them as the inputs to another.

One of the main ways to make functions composable is to minimize side effects:

- Avoid reading state from the outside world, instead have it passed in via input variables.
- Avoid writing state to the outside world, instead return the result via output variables.

Although we can't avoid side effects when working with infrastructure, we can still follow the same principle in our Terraform code.

> What is _function composition_?
>
> An act or mechanism to combine simple functions to build more complicated ones.

### Testable Modules

> **How to know if our module actually works?**
>
> We need to write some Terraform code to:
>
> - plug in the arguments
> - setup the provider
> - configure the backend
> - ...
>
> A great way to do this is creating an `examples` folder, that show examples of how to use our modules.
>
> These examples is also how we create automated tests for our modules.

> **What is the a typical Terraform module?**
>
> Each Terraform module we have in the `modules` folder should have:
>
> - a corresponding example in `examples` folder.
> - a corresponding test in the `test` folder.

> **What is the folder structure for a typical Terraform modules repo?**
>
> ```shell
> modules
>  └ examples
>    └ alb
>    └ asg-rolling-deploy
>      └ one-instance
>      └ auto-scaling
>      └ with-load-balancer
>      └ custom-tags
>    └ hello-world-app
>  └ modules
>    └ alb
>    └ asg-rolling-deploy
>    └ hello-world-app
>  └ test
>    └ alb
>    └ asg-rolling-deploy
>    └ hello-world-app
> ```

> **What is a great practice to follow when developing a new Terraform module?**
>
> Write the example code first, before we write even a line of module code.
>
> We're free to think through the ideal user experience and come up with a clean API.
>
> This is a form of Test Driven Development (TDD).

#### Self-validating modules

> **What is self-validating modules?**
>
> Modules that can check their own behavior to prevent certain types of bugs.

Terraform has two ways of doing self-validating built in:

- Input Variable Validations
- Preconditions and postconditions

##### [Input Variable Validations](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions#input-variable-validation)

As of Terraform 0.13, we can add `validation` blocks to any input variable to perform checks that go beyond basic type constraints.

For example:

```t
variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Only free tier is allowed: t2.micro | t3.micro."
  }
}
```

The way a `validation` block works is that the condition parameter should evaluate to `true` if the value is valid and `false` otherwise.

Each `variable` block can have multiple `validation` blocks to check multiple conditions.

> ⚠️ The `condition` in a `validation` block:
>
> - can _only_ reference the surrounding variable.
> - only useful for basic input sanitization.
>
> The `condition` block:
>
> - can not checks across multiple variables, e.g. check that exactly one of these two input variables must be set
> - do dynamic check, e.g. check that the AMI requested uses the x86_64 architecture
>
> To do these things, we need to use `precondition` and `postcondition` block.

##### [Preconditions and Postconditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions#preconditions-and-postconditions)

As of Terraform 1.2, you can add precondition and postcondition blocks to resources, data sources, and output variables to perform more dynamic checks.

- The `precondition` blocks: Terraform checks a `precondition` _before_ evaluating the object it is associated with.

  For example, use `precondition` to check that the `instance_type` is eligible for the AWS Free Tier

  ```t
  # Get up-to-date information from AWS:
  data "aws_ec2_instance_type" "instance" {
    instance_type = var.instance_type
  }

  resource "aws_launch_configuration" "example" {
    # ...
    lifecycle {
      # Check that this instance type is eligible for the AWS Free Tier
      precondition {
        condition     = data.aws_ec2_instance_type.instance.free_tier_eligible
        error_message = "${var.instance_type} is not part of the AWS Free Tier!"
      }
    }
  }
  ```

- The `postcondition` blocks: Terraform checks a `postcondition` _after_ evaluating the object it is associated with.

  For example, check that the ASG was deployed across more than one Availability Zone (AZ)

  ```t
  resource "aws_autoscaling_group" "example" {
    # ...
    lifecycle {
      postcondition {
        condition     = length(self.availability_zones) > 1 # Use self expression to to refer to an output ATTRIBUTE of the surrounding resource.
        error_message = "You must use more than one AZ for high availability!"
      }
    }
  }
  ```

> What is Self Expression?
>
> The `self.<ATTRIBUTE>` syntax:
>
> - used in `postcondition`, `connection`, and `provisioner` blocks,
> - to refers to an output `ATTRIBUTE` of the surrounding resource.
>
> It's a workaround to not get a circular dependency error (resources have references to themselves)
>
> e.g.
>
> ```t
>   resource "aws_autoscaling_group" "example" {
>     # ...
>     lifecycle {
>       postcondition {
>         condition     = length(aws_autoscaling_group.example.availability_zones) > 1 # ERROR: circular dependency error (resources have references to themselves)
>       }
>     }
>   }
> ```

##### When to use `Input Variable Validations`, `Preconditions`, and `Postconditions`

- Use `Input Variable Validations` for basic _input sanitization_

  Prevent users from passing invalid variables into your modules.

  - Not as powerful as precondition.
  - Defined with the variable they are validate, leads to more readable, maintainable API.

- Use `Preconditions` for checking basic _assumptions_

  Check assumptions that must be true _before_ any changes have been deployed.

  - Includes check can't be done with `input variable validations`
  - Can also check resources, data sources.

- Use `Postconditions` for enforcing basic _guarantees_

  Check guarantees about how your module behaves after changes have been deployed:

  - Give users of your module confidence:

    - your module will either do what it says when they run apply
    - or exit with an error.

  - Give maintainers a signal of what behaviors this module should have.

- Use **automated testing tools** for enforcing more advanced assumptions and guarantees.

  For more advanced behavior, Terraform HCL is not enough, we should use automated testing tools.

  e.g. To test an internal web server with only Terraform, it will be too tricky.

### Versioned Modules

There are 2 types of versioning for Terraform module:

- Versioning of the module's dependencies.
- Versioning of the module itself.

#### Versioning for module dependencies

Terraform module has 3 types of dependencies:

- Terraform core - the `terraform` binary version
- Providers, e.g. the `aws` version
- Modules: the versions of each reusable module

As a general rule, we'll want to practice versioning pinning with all of our dependencies.

Version upgrades should always be an explicit, deliberate action that is visible in the code we check into version control.

Terraform use a `Version Constraint` for versioning.

> **What is Terraform Version Constraint?**
>
> A string literal contains one or more conditions, which is separated by commas.
>
> e.g. `">= 1.2.0, < 2.0.0"`
>
> Each condition consists of an operator and a version number:
>
> - Version number:
>
>   - A series of number separated by periods, e.g. `0.15.5`, `1.4.7`
>   - An optional suffix to indicate beta release, e.g. `1.5.0-beta1`, `1.5.0-rc1`
>
> - Operator:
>   - `=`: Only allow an exact version number. Cannot be combined with other conditions.
>   - `!=`: Exclude an exact version number.
>   - `>`, `>=`, `<`, `<=`: Comparisons against a specified version.
>   - `~>`: Allows only the _rightmost_ version component to increment.

#### Pinning Terraform core

Use `terraform` block `required_version`

```t
terraform {
  # Require any 1.x version of Terraform
  required_version = ">= 1.0.0, < 2.0.0"
}
```

A production grade Terraform code should use the exact terraform version

```t
terraform {
  # Require Terraform at exactly version 1.2.3
  required_version = "1.2.3"
}
```

> **How to use many `terraform` core version in our computer?**
>
> Use [`tfenv`](https://github.com/tfutils/tfenv) - the Terraform version manager
>
> > ⚠️ TFENV ON APPLE SILICON (M1, M2).
> >
> > As of June 2022, `tfenv` did not install the proper version of Terraform on Apple Silicon, such as Macs running M1 or M2 processors (see this [open issue](https://github.com/tfutils/tfenv/issues/306) for details). The workaround is to set the TFENV_ARCH environment variable to arm64:
> >
> > ```shell
> > $ export TFENV_ARCH=arm64
> > $ tfenv install 1.2.3
> > ```
>
> Alternatives: [`tfswitch`](https://github.com/warrensbox/terraform-switcher)

> **`tfenv` or `tfswitch`?**
>
> With `tfenv`:
>
> - we can pin a specific `terraform` version using a `.terraform-version` file
> - later when we run `terraform`, `tfenv` will use the version defined in that file.

#### Pinning Providers

We can pin provider version using the `terraform`'s `required_providers` block

```t
terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
```

The first time we run `terraform init`, Terraform creates a `.terraform.lock.hcl` file, which records:

- The exact version of each provider you used

- The checksums for each provider

```t
provider "registry.terraform.io/hashicorp/aws" {
  version     = "4.67.0" # We don't need to pin the minor, and patch version.
  constraints = "~> 4.0"
  hashes = [ # Ensure someone can’t swap out provider code with malicious code
    "h1:dCRc4GqsyfqHEMjgtlM1EympBcgTmcTkWaJmtd91+KA=",
    "zh:0843017ecc24385f2b45f2c5fce79dc25b258e50d516877b3affee3bef34f060",
    # ...
    "zh:fac0d2ddeadf9ec53da87922f666e1e73a603a611c57bcbc4b86ac2821619b1d",
  ]
}
```

> LOCK FILES WITH MULTIPLE OPERATING SYSTEMS
>
> By default, Terraform only generates lock file for the current platform/OS we ran `init` on.
>
> If your team works across multiple OSs, you’ll need to run the `terraform providers lock` command to record the checksums for every platform you use
>
> ```shell
> terraform providers lock \
>   -platform=windows_amd64 \ # 64-bit Windows
>   -platform=darwin_amd64 \  # 64-bit macOS
>   -platform=darwin_arm64 \  # 64-bit macOS (ARM)
>   -platform=linux_amd64     # 64-bit Linux
> ```

#### Pinning Modules

Pinning Module Versions by using `source` URLs with the `ref` parameter set to a Git tag.

e.g.

```t
  source = "git@github.com:foo/modules.git//services/hello-world-app?ref=v0.0.5"
```

#### Versioning for module itself

Update the source URL for the module

```t
module "hello_world_app" {
  source = "git@github.com:foo/modules.git//services/hello-world-app?ref=v0.0.5"
}
```

Commit and push it to Git repo for code review.

After the code is reviewed, and merged:

1. Pull the new code and run `terraform init`, `terraform apply` on our local machine.

2. Build a CI pipeline to run these on a CI machine.

Instead of using Git source, we can [publish module](https://developer.hashicorp.com/terraform/registry/modules/publish) to the Terraform Registry

### Beyond Terraform Modules

To build out our entire production-grade infrastructure, we'll need to use other tools, such as `Docker`, `Packer`, `Chef`, `Puppet`... and the duck tape `Bash script`.

Most of these code can reside in the `modules` folder. e.g. `modules/packer`.

However, occasionally, we need to run some none Terraform code directly from the Terraform module. It's can be done with:

- Provisioners
- Provisioners with `null_resource`
- External data source

#### [Provisioners](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax)

> **What is Terraform provisioner?**
>
> Terraform provisioner are used for behaviors that cannot be directly represented in Terraform's declarative model.
>
> With Terraform provisioner, we can
>
> - execute scripts either
>
>   - on the _local machine_, e.g. The one running Terraform
>   - or a _remote machine_, e.g. An EC2 instance
>
> - to do the work of bootstrapping, configuration management, or cleanup.

> **⚠️⚠️⚠️ Provisioners are the Last Resorts**
>
> From v0.15.0, Terraform has remove provisioners for `Chef`, `Puppet`.
>
> For most common situations there are better alternatives.

Let's run a script in our local machine by using [`local-exec` provisioner](https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec):

```t
provider "aws" {
  region = "ap-southeast-1"
}

resource "random_uuid" "my_uuid" {}

resource "aws_s3_bucket" "main" {
  bucket = "s3-bucket-${random_uuid.my_uuid.result}"

  provisioner "local-exec" {
    command = "echo \"Hello, World from $(uname -a)\""
  }
}
```

```shell
$ terraform apply
# ...
Plan: 2 to add, 0 to change, 0 to destroy.
# ...
random_uuid.my_uuid: Creating...
random_uuid.my_uuid: Creation complete after 0s [id=19863098-5762-1676-2a98-fd5330ed8ee4]
aws_s3_bucket.main: Creating...
aws_s3_bucket.main: Provisioning with 'local-exec'...
aws_s3_bucket.main (local-exec): Executing: ["/bin/sh" "-c" "echo \"Hello, World from $(uname -a)\""]
aws_s3_bucket.main (local-exec): Hello, World from Linux LQT-LG-Gram 5.15.90.4-microsoft-standard-WSL2 #1 SMP Tue Jul 18 21:28:32 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
aws_s3_bucket.main: Creation complete after 3s [id=s3-bucket-19863098-5762-1676-2a98-fd5330ed8ee4]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

Now try to run a script on a remote machine by using [`remote-exec` provisioner](https://developer.hashicorp.com/terraform/language/resources/provisioners/remote-exec). It's a lot more complicated.

To execute code on a remote machine, e.g. an EC2 instance, our Terraform client must be able to do the following:

- Communicate over the network with the EC2 instance

  Use a security group.

- Authenticate to the EC2 instance

  The `remote_exec` supports `SSH` and `WinRM` connections.

```t
# Create a security group that allows inbound connections to port 22, the default port for SSH:
resource "aws_security_group" "instance" {
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # To make this example easy to try out, we allow all SSH connections.
    # In real world usage, you should lock this down to solely trusted IPs.
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# To make this example easy to try out, we generate a private key in Terraform.
# In real-world usage, you should manage SSH keys outside of Terraform.
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Update the public key from Terraform state to AWS
resource "aws_key_pair" "generated_key" {
  public_key = tls_private_key.example.public_key_openssh
}

# Get the most recent Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Create an EC2 instance
resource "aws_instance" "example" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]    # Associate that instance with the security group we created earlier
  key_name               = aws_key_pair.generated_key.key_name # Associate that instance with the public key we created earlier

  provisioner "remote-exec" {                           # The remote-exec provisioner block
    inline = ["echo \"Hello, World from $(uname -a)\""] # Instead local-exec's `command` argument, remote-exec use an `inline` argument
  }

  # Configure Terraform to use SSH to connect to this EC2 Instance
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.example.private_key_pem
  }
}
```

```shell
$ terraform apply
data.aws_ami.ubuntu: Reading...
data.aws_ami.ubuntu: Read complete after 1s [id=ami-0da20db83c3a03f26]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the
following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.example will be created
  # aws_key_pair.generated_key will be created
  # aws_security_group.instance will be created
  # tls_private_key.example will be created

Plan: 4 to add, 0 to change, 0 to destroy.
# ...
tls_private_key.example: Creating...
aws_security_group.instance: Creating...
tls_private_key.example: Creation complete after 2s [id=b75de88656203d5c3ab16ea3644cb80a98e8780e]
aws_key_pair.generated_key: Creating...
aws_key_pair.generated_key: Creation complete after 0s [id=terraform-20230918134311913600000002]
aws_security_group.instance: Creation complete after 2s [id=sg-0af3f50b7619e8f9a]
aws_instance.example: Creating...
aws_instance.example: Still creating... [10s elapsed]
aws_instance.example: Still creating... [20s elapsed]
aws_instance.example: Still creating... [30s elapsed]
aws_instance.example: Provisioning with 'remote-exec'...
aws_instance.example (remote-exec): Connecting to remote host via SSH...
aws_instance.example (remote-exec):   Host: 54.169.116.86
aws_instance.example (remote-exec):   User: ubuntu
aws_instance.example (remote-exec):   Password: false
aws_instance.example (remote-exec):   Private key: true
aws_instance.example (remote-exec):   Certificate: false
aws_instance.example (remote-exec):   SSH Agent: false
aws_instance.example (remote-exec):   Checking Host Key: false
aws_instance.example (remote-exec):   Target Platform: unix
# ... retry the SSH connection multiple times
aws_instance.example (remote-exec): Connected!
aws_instance.example (remote-exec): Hello, World from Linux ip-172-31-32-55 5.15.0-1044-aws #49~20.04.1-Ubuntu SMP Mon Aug 21 17:09:32 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
aws_instance.example: Creation complete after 56s [id=i-04c605ffdea68ee68]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

The `remote-exec` provisioner doesn’t know exactly when the EC2 Instance will be booted and ready to accept connections, so it will retry the SSH connection multiple times until it succeeds or hits a timeout (the default timeout is five minutes).

Eventually, the connection succeeds, and we get a “Hello, World” from the server.

> **When does provisioner run?**
>
> By default, when we specify a provisioner, it's a `creation-time provisioner`:
>
> - it runs after `terraform apply`
> - only during the initial creation of the resource. It won't run on any subsequent calls to `terraform apply`.
>
> If we add the `when = destroy` argument to the provisioner. It will be a `destroy-time provisioner`:
>
> - it runs after `terraform destroy`, just before the resource is deleted.
>
> Provisioners also has `on_failure` argument for handling error:
>
> - `continue`: Terraform will ignore the error, and continue with resource creation/destruction.
> - `abort`: Terraform will abort the resource creation/destruction.

> **What is the different between `remote_exec` provisioner and `user_data` script?**
>
> The only advantage of using a `remote_exec` provisioner is it can run scripts of any length (`user_data` script has a limit of 16KB)
>
> `user_data` script has many advantages:
>
> - Don't need to establish a connection to the remote machine.
> - Can be used with ASG, ensuring all servers of that ASG execute the script.
> - The `user_data` script can be seen in the EC2 console. Its execution log is on the EC2 instance itself (typically in `/var/log/cloud-init*.log`).

#### Provisioners with [`null_resource`](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)

Provisioners can only be defined within a resource, but sometimes we want to execute a script without tying it to a specific resource.

Terraform has `null_resource`, which acts like a normal resource, except it doesn't create anything.

```t
resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "echo \"Hello, World from $(uname -a)\""
  }
}
```

`null_resource`'s `trigger` argument allows specifying an arbitrary set of values that, when changed, will cause the resource to be replaced.

```t
resource "null_resource" "example" {
  # Use UUID to force this null_resource to be recreated on every
  # call to 'terraform apply'
  triggers = {
    uuid = uuid()
  }

  provisioner "local-exec" {
    command = "echo \"Hello, World from $(uname -smp)\""
  }
}
```

#### External data source

Sometimes we want to execute a script to fetch data, and make that data available within the Terraform code. We can do this with `external` data source.

> What does `external` data source do?
>
> Allows an **external program** implementing a specific protocol to **act as a data source**, exposing arbitrary data for use elsewhere in the Terraform configuration.

> What is the protocol of `external` data source?
>
> Protocol of `external` data source
>
> - We pass data from Terraform to the external program by using the `query` argument
>
> - The external program reads these arguments as **JSON** from `stdin`
>
> - The external program passes data back to Terraform by writing **JSON** to `stdout`
>
> - The rest of our Terraform code pulls data out of this JSON by using the `result` output attribute of the external data source.

For example:

```t
data "external" "echo" {
  program = ["bash", "-c", "cat /dev/stdin"]

  query = {
    foo = "bar"
  }
}

output "echo" {
  #      `data.external.<NAME>.result`
  value = data.external.echo.result # the JSON returned by the external program
}

output "echo_foo" {
  #      `data.external.<NAME>.result.<PATH>`
  value = data.external.echo.result.foo # navigate within that JSON
}
```

```shell
$ terraform apply

(...)

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

echo = {
  "foo" = "bar"
}
echo_foo = "bar"
```

> `external` data source pros and cons:
>
> Pros: A lovely escape hatch if we need to access data in our Terraform code and there’s no existing data source that knows how to retrieve that data.
>
> Cons: It's make our less portable and more brittle.
>
> - e.g. The `external` data source above relies on Bash, we aren't able to deploy it from a Windows machine.

## Conclusion

The process for creating a production-grade Terraform code:

1. Go through the production-grade infrastructure checklist:

   1. Explicitly identify:

      - the items we will implement
      - the items we will _not_ implement

   2. Use:

      - the results of the checklist
      - the real world time estimate for production-grade infrastructure

      to come up with our time estimate for our boss.

2. Create a `examples` folder

   1. Write the example code first

      Using it to define the best UX and cleanest API for our modules.

   2. Create an example for each important permutation of our module

      Include enough documentation and reasonable defaults to make the example as easy to deploy as possible.

3. Create a `modules` folder

   - Implement the API we came up with a collection of small, reusable, composable modules.

   - Use other tools like Docker, Packer, Bash.

   - Pin the versions of all dependencies: Terraform code, providers, modules.

4. Create a `test` folder

   Write automated tests for each example.
