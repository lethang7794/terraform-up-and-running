# How To Test Terraform Code

> **What is the goal testing?**
>
> Give us _confidence_ to make changes.
>
> ⚠️ No form of testing can guarantee that your code is ~~free of bugs~~, so it’s more of a game of probability.

## Manual Tests

> How to manually test a web server?
>
> 1. Start the web server locally, or using a deployed environment.

> 2. Manually test the behavior with web browser or `curl`
>
>    ```shell
>    curl localhost:8000
>    ```

### Manual Testing Basics

> **What is the equivalent of manual testing with Terraform code?**
>
> When testing Terraform code (or any IaC), we can't use localhost.
>
> The only practical way to do manual testing with Terraform is:
>
> - To deploy a real environment (e.g. deploy to AWS)
>
> - In other words, we need to run `terraform apply` then `terraform destroy` on our local machine.
>
> That's why we need an easy-to-deploy `examples` folder for each module.

> **ℹ️ Key testing takeaway #1** 🌐
>
> When testing Terraform code (or any IaC), we can't use localhost.

For example, we have a `alb` module:

```t
# modules/networking/alb/main.tf
resource "aws_lb" "example" {
  name               = var.alb_name
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb" {
  name = var.alb_name
}
```

To test this `alb` module,

- We create an example:

  ```t
  # examples/alb/main.tf

  provider "aws" {
    region = "ap-southeast-1"
  }

  module "alb" {
    source = "../../modules/networking/alb"

    alb_name   = "terraform-up-and-running"
    subnet_ids = data.aws_subnets.default.ids
  }
  ```

- We deploy this example

  ```shell
  $ terraform apply

  (...)

  Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

  Outputs:

  alb_dns_name = "hello-world-stage-477699288.us-east-2.elb.amazonaws.com"
  ```

- We validates that the infrastructure is working

  ```shell
  # For this example we'll use curl
  $ curl \
    -s \
    -o /dev/null \
    -w "%{http_code}" \
    hello-world-stage-477699288.us-east-2.elb.amazonaws.com

  404
  ```

> **Validating infrastructure**
>
> Each infrastructure needs to use a corresponding tool to validate that it's working.
>
> For example:
>
> - For a load balancer that responds to HTTP requests, we'll use `curl` or a browser.
> - For a MySQL database, we'll use a MySQL client.
> - For a VPN server, we'll use VPN client.
> - If the server doesn't listen for requests at all, we'll SSH to the server, and execute from command locally.

> What is `sandbox environment`?
>
> The environment in which developers can bring up and tear down any infrastructure we want without worrying about affect others.
>
> The gold standard is each developer get their own completely isolated `sandbox environment`.

### Cleaning Up After Tests

If we're not careful, we can end up with infrastructure running all over the place, costing we a lot of money. 💸

> **ℹ️ Key testing takeaway #2 🧹**
>
> Regularly clean up your sandbox environments.

At a minimum, create a culture in which developers clean up whatever they deployed when they're done testing by running `terraform destroy`.

We might run a cron job to automatically cleanup unused or old resources, such as [`cloud-nuke`](https://github.com/gruntwork-io/cloud-nuke), [`aws-nuke`](https://github.com/rebuy-de/aws-nuke).

For example:

```shell
$ cloud-nuke aws --older-than 48h
```

## Automated Tests

> **What are 3 types of automated tests?**
>
> - **Unit tests**: verify the functionality of a single, small unit of code.
> - **Integration tests**: verify that multiple units work together correctly.
> - **End-to-end tests**: running your entire architecture — for example, your apps, your data stores, your load balancers — and validating that your system works as a whole.

> **What are unit tests?**
>
> **Unit tests**: verify the functionality of a single, small unit of code.
>
> A unit is typically a single function or class.
>
> Usually, any external dependencies — for example, databases, web services, even the filesystem — are replaced with _test doubles_ or _mocks_:
>
> - to finely control the behavior of these dependencies
> - to test that our code handles a variety of scenarios.

> **What are integration tests?**
>
> **Integration tests**: verify that multiple units work together correctly.
>
> An integration test validates that several functions or classes work together correctly.
>
> Integration tests typically use a mix of real dependencies and mocks.
>
> For example, if we're testing the part of our application that communicates with the database:
>
> - We'll test it with a real database
> - And mock other dependencies, such as app's authentication.

> **What are end-to-end tests?**
>
> **End-to-end tests**: running your entire architecture — for example, your apps, your data stores, your load balancers — and validating that your system works as a whole.
>
> Usually, end-to-end tests are done from the end-user's perspective, such as using Selenium to automate interact with our product via a web browser.
>
> End-to-end tests typically use real system everywhere, without mocks, in an architecture that mirrors production.

> **What is the purpose of unit tests?**
>
> Have tests that run _quickly_ so that you can
>
> - get _fast feedback_ on your changes
> - validate a variety of different permutations
>
> to build up confidence that the _basic building blocks_ of your code (the individual units) work as expected.

> **What is the purpose of integration tests?**
>
> Ensure the basic building blocks fit together correctly.

> **What is the purpose of end-to-end tests?**
>
> Validate that your code behaves as expected in conditions similar to production.

### Unit Tests

#### Unit Tests with Ruby

For example, we have a Ruby web server code:

```ruby
class WebServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    case request.path
    when "/"
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = 'Hello, World'
    when "/api"
      response.status = 201
      response['Content-Type'] = 'application/json'
      response.body = '{"foo":"bar"}'
    else
      response.status = 404
      response['Content-Type'] = 'text/plain'
      response.body = 'Not Found'
    end
  end
end
```

Writing a unit test that calls the do_GET method directly is tricky, as you’d have to:

- either instantiate real `WebServer`, `request`, and `response` objects
- or create test doubles of them

both of which require a fair bit of work

> 💡 When you find it difficult to write unit tests, that’s often a code smell and indicates that the code needs to be refactored

Let's refactor this code and extract the "handlers" into a `Handler` class:

```ruby
class Handlers
  def handle(path)
    case path
    when "/"
      [200, 'text/plain', 'Hello, World']
    when "/api"
      [201, 'application/json', '{"foo":"bar"}']
    else
      [404, 'text/plain', 'Not Found']
    end
  end
end
```

This `Handlers` class:

- **Simple values as inputs**:

  - The Handlers class does not depend on HTTPServer, HTTPRequest, or HTTPResponse
  - Instead, all of its inputs are simple values, such as the path of the URL, which is a string.

- **Simple values as output**:

  - Instead of setting values on a mutable HTTPResponse object (a side effect)
  - The methods in the Handlers class return the HTTP response as a simple value (an array that contains the HTTP status code, content type, and body).

> 💡 Code that takes in simple values as inputs and returns simple values as outputs is typically easier to understand, update, and test.

Let's update the `WebServer` to use the new `Handler` class:

```ruby
class WebServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    handlers = Handlers.new
    status_code, content_type, body = handlers.handle(request.path)

    response.status = status_code
    response['Content-Type'] = content_type
    response.body = body
  end
end
```

Now let's write 3 unit tests that check each endpoints in the `Handler` class:

```ruby
class TestWebServer < Test::Unit::TestCase
  def initialize(test_method_name)
    super(test_method_name)
    @handlers = Handlers.new
  end

  def test_unit_hello
    status_code, content_type, body = @handlers.handle("/")
    assert_equal(200, status_code)
    assert_equal('text/plain', content_type)
    assert_equal('Hello, World', body)
  end

  def test_unit_api
    status_code, content_type, body = @handlers.handle("/api")
    assert_equal(201, status_code)
    assert_equal('application/json', content_type)
    assert_equal('{"foo":"bar"}', body)
  end

  def test_unit_404
    status_code, content_type, body = @handlers.handle("/invalid-path")
    assert_equal(404, status_code)
    assert_equal('text/plain', content_type)
    assert_equal('Not Found', body)
  end
end
```

Finally, run our unit tests:

```shell
$ ruby web-server-test.rb
Loaded suite web-server-test
Finished in 0.000572 seconds.
-------------------------------------------
3 tests, 9 assertions, 0 failures, 0 errors
100% passed
-------------------------------------------
```

#### Unit Tests with Terraform

> **What a _“unit”_ is in the Terraform world?**
>
> The closest equivalent to a single function or class in Terraform is a **single reusable module**,
> such as the `alb` module we created in Chapter 8.

> **Can we refactoring Terraform code to write a unit test?**
>
> There is no practical way to reduce the number of external dependencies to zero, and even if we could, we'd effectively be left with no code to test.

> **ℹ️ Key testing takeaway #3 💩**
>
> We cannot do pure unit testing for Terraform code.

> **What kind of _unit test_ we can do in Terraform code?**
>
> We can write _unit test_ that deploy real infrastructure into a real environment (e.g. into AWS account).
>
> In other words, an _unit test_ in Terraform is an _integration test_ for a single _reusable module_.

> **How to write unit test in Terraform code?**
>
> 1. Create a small, standalone module.
> 2. Create an easy-to-deploy example for that module.
> 3. Run `terraform apply` to deploy the example into a real environment.
> 4. Validate that what you just deployed works as expected.
>
>    This step is specific to the type of infrastructure you’re testing.
>
>    e.g. For an ALB, you’d validate it by sending an HTTP request and checking that you receive back the expected response.
>
> 5. Run `terraform destroy` at the end of the test to clean up.
>
> 👉 In other words, you do exactly the same steps as you would when doing manual testing, but you capture those steps as code.

We'll use [`Terratest`](https://terratest.gruntwork.io/) to write automated tests for Terraform code.

```go
// 19-terratest/test/alb_example_test.go
package test

import (
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestAlbExample(t *testing.T) {
	opts := &terraform.Options{
		// You should update this relative path to point at your alb
		// example directory!
		TerraformDir: "../examples/alb",
	}

	// Clean up everything at the end of the test
	defer terraform.Destroy(t, opts)

	// Deploy the example
	terraform.InitAndApply(t, opts) // Run terraform init and terraform apply

	// Get the URL of the ALB
	albDnsName := terraform.OutputRequired(t, opts, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	// Test that the ALB's default action is working and returns a 404
	var (
		expectedStatus     = 404
		expectedBody       = "404: page not found"
		maxRetries         = 10
		timeBetweenRetries = 10 * time.Second
	)

	http_helper.HttpGetWithRetry(
		t,
		url,
		nil,
		expectedStatus,
		expectedBody,
		maxRetries,
		timeBetweenRetries,
	)
}
```

Run the test

```shell
$ go test -v -timeout 30m # Increase the timeout of go test from 10m to 30m
$  go test -v -timeout 30m
=== RUN   TestAlbExample
TestAlbExample 2023-09-19T16:38:22+07:00 logger.go:66: Running command terraform with args [init -upgrade=false]
# ...
TestAlbExample 2023-09-19T16:38:25+07:00 logger.go:66: Running command terraform with args [apply -input=false -auto-approve -lock=false]
# ...
TestAlbExample 2023-09-19T16:40:48+07:00 logger.go:66: Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
# ...
TestAlbExample 2023-09-19T16:40:48+07:00 logger.go:66: Running command terraform with args [output -no-color -json alb_dns_name]
# ...
TestAlbExample 2023-09-19T16:40:49+07:00 http_helper.go:32: Making an HTTP GET call to URL http://terraform-up-and-running-1450049100.ap-southeast-1.elb.amazonaws.com
# ...
TestAlbExample 2023-09-19T16:41:10+07:00 logger.go:66: Running command terraform with args [destroy -auto-approve -input=false -lock=false]
# ...
TestAlbExample 2023-09-19T16:41:40+07:00 logger.go:66: Destroy complete! Resources: 3 destroyed.
# ...
--- PASS: TestAlbExample (197.97s)
PASS
ok      example.com/my-terra-test       197.982s
```

> **⚠️ By default, Go imposes a timeout of 10 minutes for tests**
>
> After that Go forcibly kills the test run:
>
> - causing the test to fail.
> - preventing `terratest` cleanup code (i.e. run `terraform destroy`) from running.
>
> 👉 It's safer to set an extra-long timeout for our Terraform test.

> **Is the test too long for a feedback loop?**
>
> The test took nearly 200 seconds to run, but
>
> - this is about as fast of a feedback loop as we can get with IaC in AWS. 🐌
> - it gives us confidence that our code works as expected. 💪

#### Dependency injection

##### Dependency injection for GPL (Ruby)

For example, a more complicated code:

- A `WebServer` class

  ```ruby
  class WebServer < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      handlers = Handlers.new
      status_code, content_type, body = handlers.handle(request.path)

      response.status = status_code
      response['Content-Type'] = content_type
      response.body = body
    end
  end
  ```

- A `Handlers` class

  ```ruby
  class Handlers
    def handle(path)
      case path
      when "/"
        [200, 'text/plain', 'Hello, World']
      when "/api"
        [201, 'application/json', '{"foo":"bar"}']

      # New endpoint that calls a web service
      when "/web-service"
        uri = URI("http://www.example.org")
        response = Net::HTTP.get_response(uri)
        [response.code.to_i, response['Content-Type'], response.body]

      else
        [404, 'text/plain', 'Not Found']
      end
    end
  end
  ```

The `Handlers` class shouldn’t need to deal with all of the details of how to call a web service.

- Instead, we can extract that logic into a separate `WebService` class:

  ```ruby
  class WebService
    def initialize(url)
      @uri = URI(url)
    end

    def proxy
      response = Net::HTTP.get_response(@uri)
      [response.code.to_i, response['Content-Type'], response.body]
    end
  end
  ```

- Then refactor the `Handlers` class and `WebService` class:

  ```ruby
  class Handlers
    def initialize(web_service)
      @web_service = web_service
    end

    def handle(path)
      case path
      when "/"
        [200, 'text/plain', 'Hello, World']
      when "/api"
        [201, 'application/json', '{"foo":"bar"}']

      # New endpoint that calls a web service
      when "/web-service"
        @web_service.proxy

      else
        [404, 'text/plain', 'Not Found']
      end
    end
  end
  ```

  ```ruby
  class WebServer < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(request, response)
      web_service = WebService.new("http://www.example.org")
      handlers = Handlers.new(web_service)

      status_code, content_type, body = handlers.handle(request.path)

      response.status = status_code
      response['Content-Type'] = content_type
      response.body = body
    end
  end
  ```

And in our unit test:

- Create a mock version of `WebService` class, that allows us to specify a mock response to return:

  ```ruby
  class MockWebService
    def initialize(response)
      @response = response
    end

    def proxy
      @response
    end
  end
  ```

- Create an instance of this `MockWebService` class and inject it into the `Handlers` class:

  ```ruby
  class TestWebServer < Test::Unit::TestCase
    def initialize(test_method_name)
      super(test_method_name)
      @handlers = Handlers.new
    end

    def test_unit_hello
      status_code, content_type, body = @handlers.handle("/")
      assert_equal(200, status_code)
      assert_equal('text/plain', content_type)
      assert_equal('Hello, World', body)
    end

    # ...

    def test_unit_web_service
      expected_status = 200
      expected_content_type = 'text/html'
      expected_body = 'mock example.org'
      mock_response = [expected_status, expected_content_type, expected_body]

      mock_web_service = MockWebService.new(mock_response)
      handlers = Handlers.new(mock_web_service)

      status_code, content_type, body = handlers.handle("/web-service")
      assert_equal(expected_status, status_code)
      assert_equal(expected_content_type, content_type)
      assert_equal(expected_body, body)
    end
  end
  ```

> **What is the downside of writing test for code that hardcodes an external dependency?**
>
> - If that dependency:
>   - has an outage, our tests will fail.
>   - changed its behavior, we will need to update our tests.
>   - were slow, our test would be slow.
> - If we want to test various corner cases based on how that dependency behaves, we have no way to do it.

> **Which type of automated tests should work with real dependencies?**
>
> Working with real dependencies makes sense for integration tests and end-to-end tests.
>
> But for unit tests, we should minimize external dependencies as much as possible.

> **What is _dependency injection_?**
>
> The strategy to
>
> - pass in (`inject`) external dependencies from outside of our code.
> - rather than hardcoding them within our code.

> **Why using dependency injection?**
>
> Using dependency injection to minimize external dependencies allows you to write fast, reliable tests and check all the various corner cases.

##### Dependency Injection for Terraform code

For example,

- Our Terraform code before writing unit test:

  ```t
  # examples/hello-world-app/standalone/main.tf
  provider "aws" {
    region = "ap-southeast-1"
  }

  module "hello_world_app" {
    source = "../../../modules/services/hello-world-app"

    server_text = "Hello, World"
    environment = "example"

    db_remote_state_bucket = "(YOUR_BUCKET_NAME)"         # An external dependency
    db_remote_state_key    = "examples/terraform.tfstate" # An external dependency

    instance_type      = "t2.micro"
    min_size           = 2
    max_size           = 2
    enable_autoscaling = false
    ami                = data.aws_ami.ubuntu.id
  }

  data "aws_ami" "ubuntu" {
    most_recent = true
    owners      = ["099720109477"] # Canonical

    filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
  }
  ```

> 💡 A convention for external dependencies
>
> Move all of the data sources and resources that represent external dependencies into a separate file named `dependencies.tf`.
>
> 👉 Make it easier for users of our code to know, at a glance, what this code depends on in the outside world.

- Extract external dependencies to another files:

  ```t
  # modules/services/hello-world-app/dependencies.tf
  data "terraform_remote_state" "db" {
    backend = "s3"

    config = {
      bucket = var.db_remote_state_bucket
      key    = var.db_remote_state_key
      region = "ap-southeast-1"
    }
  }

  data "aws_vpc" "default" {
    default = true
  }

  data "aws_subnets" "default" {
    filter {
      name   = "vpc-id"
      values = [data.aws_vpc.default.id]
    }
  }
  ```

- For each external dependencies, add a new input variable:

  ```t
  # modules/services/hello-world-app/variables.tf
  variable "vpc_id" {
    description = "The ID of the VPC to deploy into"
    type        = string
    default     = null # Make this variable an optional variable
  }

  variable "subnet_ids" {
    description = "The IDs of the subnets to deploy into"
    type        = list(string)
    default     = null # optional variable
  }

  variable "mysql_config" {
    description = "The config for the MySQL DB"
    type        = object({ # A nested type with address and port keys, match the output types of `mysql` module
      address = string
      port    = number
    })
    default     = null # optional variable
  }
  ```

> 📝 NOTE:
>
> - The shape of `mysql_config` match the output types of the `mysql` module:
>
>   ```t
>   # modules/services/hello-world-app/variables.tf
>   variable "db_remote_state_bucket" {
>     description = "The name of the S3 bucket for the DB's Terraform state"
>     type        = string
>     default     = null # Should now be optional
>   }
>
>   variable "db_remote_state_key" {
>     description = "The path in the S3 bucket for the DB's Terraform state"
>     type        = string
>     default     = null # Should now be optional
>   }
>   ```
>
> - Later we can pass the outputs from the mysql module straight through
>
>   ```t
>   module "hello_world_app" {
>     source = "../../../modules/services/hello-world-app"
>
>     server_text            = "Hello, World"
>     environment            = "example"
>
>     # Pass all the outputs from the mysql module straight through!
>     mysql_config = module.mysql
>
>     instance_type      = "t2.micro"
>     min_size           = 2
>     max_size           = 2
>     enable_autoscaling = false
>     ami                = data.aws_ami.ubuntu.id
>   }
>   ```

- Use the `count` parameter to optionally create the three data sources

  ```t
  # modules/services/hello-world-app/dependencies.tf
  data "terraform_remote_state" "db" {
    count = var.mysql_config == null ? 1 : 0

    backend = "s3"

    config = {
      bucket = var.db_remote_state_bucket
      key    = var.db_remote_state_key
      region = "us-east-2"
    }
  }

  data "aws_vpc" "default" {
    count   = var.vpc_id == null ? 1 : 0
    default = true
  }

  data "aws_subnets" "default" {
    count = var.subnet_ids == null ? 1 : 0
    filter {
      name   = "vpc-id"
      values = [data.aws_vpc.default.id]
    }
  }
  ```

- Update references to these data sources to conditionally use: either the input variable or the data source

  - Use local values to capture these values conditionally:

    ```t
    locals {
      mysql_config = (
        var.mysql_config == null
          ? data.terraform_remote_state.db[0].outputs # Because the data sources use the count parameters, they are now arrays.
          : var.mysql_config
      )

      vpc_id = (
        var.vpc_id == null
          ? data.aws_vpc.default[0].id
          : var.vpc_id
      )

      subnet_ids = (
        var.subnet_ids == null
          ? data.aws_subnets.default[0].ids
          : var.subnet_ids
      )
    }
    ```

  - Replace all the references to the data sources to these local values

    ```t
    # modules/services/hello-world-app/dependencies.tf
    data "aws_subnets" "default" {
      filter {
        values = [local.vpc_id]
      }
    }
    ```

    ```t
    # modules/services/hello-world-app/main.tf
    module "alb" {
      # ...
      subnet_ids = local.subnet_ids
    }

    module "asg" {
      # ...
      user_data = templatefile("${path.module}/user-data.sh", {
        # ...
        db_address  = local.mysql_config.address
        db_port     = local.mysql_config.port
      })
      # ....
      subnet_ids        = local.subnet_ids
    }

    resource "aws_lb_target_group" "asg" {
      # ...
      vpc_id   = local.vpc_id
    }
    ```

- Now we can inject `vpc_id`, `subnet_ids`, and/or `mysql_config` into `hello-world-module`, or omit all of these parameters.

- Let's update the `hello-world-app` example to inject only `mysql_config`:

  ```t
  # examples/hello-world-app/standalone/variables.tf
  variable "mysql_config" {
    description = "The config for the MySQL DB"

    type = object({
      address = string
      port    = number
    })

    default = {
      address = "mock-mysql-address"
      port    = 12345
    }
  }
  ```

  ```t
  # examples/hello-world-app/standalone/main.tf
  module "hello_world_app" {
    # ...
    mysql_config = var.mysql_config
  }
  ```

- Finally, we can write a unit test for `hello-world-app` example:

```go
func TestHelloWorldAppExample(t *testing.T) {
	opts := &terraform.Options{
		// You should update this relative path to point at your
		// hello-world-app example directory!
		TerraformDir: "../examples/hello-world-app/standalone",

    Vars: map[string]interface{}{
			"mysql_config": map[string]interface{}{
				"address": "mock-value-for-test",
				"port":    3306,
			},
		},
	}

	// Clean up everything at the end of the test
	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	albDnsName := terraform.OutputRequired(t, opts, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	maxRetries := 10
	timeBetweenRetries := 10 * time.Second

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		maxRetries,
		timeBetweenRetries,
		func(status int, body string) bool {
			return status == 200 &&
				strings.Contains(body, "Hello, World")
		},
	)
}
```

#### Running tests in parallel

> **How to run test in parallel with `terratest`?**
>
> Add `t.Parallel()` to the top of each test.
>
> ```go
> func TestHelloWorldAppExample(t *testing.T) {
> 	t.Parallel()
>   // ...
> }
> ```
>
> ```go
> func TestAlbExample(t *testing.T) {
> 	t.Parallel()
>   // ...
> }
> ```

> **What happen if we run tests in parallel but the resources have the same name?**
>
> The tests will fail.

> **ℹ️ Key testing takeaway #4** 🌌
>
> We must namespace all of our resources.

- Add namespace (a random ID) for `alb` module

  - Make the name of the ALB configurable

    ```t
    # examples/alb/variables.tf
    variable "alb_name" {
      description = "The name of the ALB and all its resources"
      type        = string
      default     = "terraform-up-and-running"
    }
    ```

  - Pass this value through to the example for `alb` module

    ```t
    # examples/alb/main.tf
    module "alb" {
      alb_name   = var.alb_name
    }
    ```

  - In our test, use a unique value for this variable:

    ```go
    // test/alb_example_test.go
    func TestAlbExample(t *testing.T) {
      opts := &terraform.Options{
        Vars: map[string]interface{}{
          "alb_name": fmt.Sprintf("test-%s", random.UniqueId()),
        },
      }
    }
    ```

- Add namespace (it's environment) for `hello-world-app` example

  - Add input variable

    ```t
    # examples/hello-world-app/variables.tf
    variable "environment" {
      description = "The name of the environment we're deploying to"
      type        = string
      default     = "example"
    }
    ```

  - Pass that variable through to the `hello-world-app` module's `environment` argument:

    ```t
    # examples/hello-world-app/main.tf
    module "hello_world_app" {
      source = "../../../modules/services/hello-world-app"
      # ...
      environment = var.environment
    }
    ```

  - In our test, set environment to a value that includes random.UniqueId():

    ```go
    // test/hello_world_app_example_test.go
    func TestHelloWorldAppExample(t *testing.T) {
      opts := &terraform.Options{
        Vars: map[string]interface{}{
          "environment": fmt.Sprintf("test-%s", random.UniqueId()),
        },
      }
      // (...)
    }
    ```

> **How many tests are run in parallel?**
>
> By default, the number of tests Go will run in parallel is equal to how many CPUs we have on our computer (`GOMAXPROCS`).
>
> We can override this setting by:
>
> - setting the `GOMAXPROCS` environment variable.
> - passing the `-parallel` argument to the `go test` command.

> **How to run multiple tests in parallel against the same Terraform folder?**
>
> e.g. Run several tests to provider different input values.
>
> The easiest solution is to have each test copy that folder to a temporary folder, and run Terraform in that temporary folder to avoid conflicts.
>
> `terratest` has `test_structure.CopyTerraformFolderToTemp` method for this purpose.

### Integration Tests

#### Integration Tests with Ruby

- To run an integration test for a Ruby web server, we need to do the following:

  1. Run the web server on localhost so that it listens on a port.
  2. Send HTTP requests to the web server.
  3. Validate you get back the responses you expect.

- Let's implement these steps:

  ```ruby
  # web-server-test.rb
  class TestWebServer < Test::Unit::TestCase
    def test_integration_hello
      do_integration_test('/', lambda { |response|
        assert_equal(200, response.code.to_i)
        assert_equal('text/plain', response['Content-Type'])
        assert_equal('Hello, World', response.body)
      })

    def do_integration_test(path, check_response)
      port = 8000
      server = WEBrick::HTTPServer.new :Port => port
      server.mount '/', WebServer

      begin
        #1 Start the web server in a separate thread so it doesn't block the test
        thread = Thread.new do
          server.start
        end

        #2 Make an HTTP request to the web server at the specified path
        uri = URI("http://localhost:#{port}#{path}")
        response = Net::HTTP.get_response(uri)

        #3 Use the specified check_response lambda to validate the response
        check_response.call(response)

      ensure
        # Shut the server and thread down at the end of the test
        server.shutdown
        thread.join
      end
    end
  end
  ```

- Run the test

  ```ruby
  $ ruby web-server-test.rb

  (...)

  Finished in 0.221561 seconds.
  --------------------------------------------
  8 tests, 24 assertions, 0 failures, 0 errors
  100% passed
  --------------------------------------------
  ```

> **What is the different between a unit test and an integration test in Terraform?**
>
> A “unit” in Terraform is a single module
>
> An integration test validates how several units work together, it would need to deploy several modules and see that they work correctly.

#### Integration Tests with Terraform

- Expose the database name:

  ```t
  # live/stage/data-stores/mysql/variables.tf
  variable "db_name" {
    description = "The name to use for the database"
    type        = string
    default     = "example_database_stage"
  }
  ```

- Pass that value through to `mysql` module:

  ```t
  # live/stage/data-stores/mysql/main.tf
  module "mysql" {
    source = "../../../../modules/data-stores/mysql"
    # ...
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
  }
  ```

- Create the skeleton of the integration test:

```go
// test/hello_world_integration_test.go
const (
	  = "../live/stage/data-stores/mysql"
	appDirStage = "../live/stage/services/hello-world-app"
)

func TestHelloWorldAppStage(t *testing.T) {
	t.Parallel()

	// Deploy the MySQL DB
	dbOpts := createDbOpts(t, )
	defer terraform.Destroy(t, dbOpts)
	terraform.InitAndApply(t, dbOpts)

	// Deploy the hello-world-app
	helloOpts := createHelloOpts(dbOpts, appDirStage)
	defer terraform.Destroy(t, helloOpts)
	terraform.InitAndApply(t, helloOpts)

	// Validate the hello-world-app works
	validateHelloApp(t, helloOpts)
}


func createDbOpts(t *testing.T, terraformDir string) *terraform.Options {
	uniqueId := random.UniqueId()

	return &terraform.Options{
		TerraformDir: terraformDir,

		Vars: map[string]interface{}{
			"db_name":     fmt.Sprintf("test%s", uniqueId),
			"db_username": "admin",
			"db_password": "password",
		},
	}
}
```

- Extract the backend config to use partial configuration

  ```t
  # live/stage/data-stores/mysql/backend.hcl
  bucket         = "terraform-up-and-running-state"
  key            = "stage/data-stores/mysql/terraform.tfstate"
  region         = "us-east-2"
  dynamodb_table = "terraform-up-and-running-locks"
  encrypt        = true
  ```

  ```t
  # live/stage/data-stores/mysql/main.tf
  terraform {
    backend "s3" {
      # This backend configuration is filled in automatically at test time by Terratest. If you wish to run this example
      # manually, uncomment and fill in the config below.

      # bucket         = "<YOUR S3 BUCKET>"
      # key            = "<SOME PATH>/terraform.tfstate"
      # region         = "us-east-2"
      # dynamodb_table = "<YOUR DYNAMODB TABLE>"
      # encrypt        = true
    }
  }
  ```

- Tell Terratest to pass in test-time-friendly values using the `BackendConfig` parameter of `terraform.Options`:

  ```go
  // test/hello_world_integration_test.go
  func createDbOpts(t *testing.T, terraformDir string) *terraform.Options {
    // ...
    bucketForTesting := "YOUR_S3_BUCKET_FOR_TESTING"
    bucketRegionForTesting := "YOUR_S3_BUCKET_REGION_FOR_TESTING"
    dbStateKey := fmt.Sprintf("%s/%s/terraform.tfstate", t.Name(), uniqueId)

    return &terraform.Options{
      // ...
      BackendConfig: map[string]interface{}{
        "bucket":  bucketForTesting,
        "region":  bucketRegionForTesting,
        "key":     dbStateKey,
        "encrypt": true,
      },
    }
  }
  ```

- Updates to the `hello-world-app` module in the staging environment to expose variables for `db_remote_state_bucket`, `db_remote_state_key`, and `environment`:

  ```t
  # live/stage/services/hello-world-app/variables.tf
  variable "db_remote_state_bucket" {
    description = "The name of the S3 bucket for the database's remote state"
    type        = string
  }

  variable "db_remote_state_key" {
    description = "The path for the database's remote state in S3"
    type        = string
  }

  variable "environment" {
    description = "The name of the environment we're deploying to"
    type        = string
    default     = "stage"
  }
  ```

- Pass those values through to the `hello-world-app` module:

  ```t
  # live/stage/services/hello-world-app/main.tf
  module "hello_world_app" {
    # ...
    environment            = var.environment
    db_remote_state_bucket = var.db_remote_state_bucket
    db_remote_state_key    = var.db_remote_state_key
    # ...
  ```

  > 💡 When you’re deploying the `mysql` module to the real staging environment, we tell Terraform to use the backend configuration in `backend.hcl` via the `-backend-config` argument:
  >
  > ```shell
  > $ terraform init -backend-config=backend.hcl
  > ```

- Implement our test `createHelloOpts`:

  ```go
  func createHelloOpts(
    dbOpts *terraform.Options,
    terraformDir string) *terraform.Options {

    return &terraform.Options{
      TerraformDir: terraformDir,

      Vars: map[string]interface{}{
        "db_remote_state_bucket": dbOpts.BackendConfig["bucket"],
        "db_remote_state_key":    dbOpts.BackendConfig["key"],
        "environment":            dbOpts.Vars["db_name"],
      },
    }
  }
  ```

- Implement the `validateHelloApp` method:

  ```go
  func validateHelloApp(t *testing.T, helloOpts *terraform.Options) {
    albDnsName := terraform.OutputRequired(t, helloOpts, "alb_dns_name")
    url := fmt.Sprintf("http://%s", albDnsName)

    maxRetries := 10
    timeBetweenRetries := 10 * time.Second

    http_helper.HttpGetWithRetryWithCustomValidation(
      t,
      url,
      nil,
      maxRetries,
      timeBetweenRetries,
      func(status int, body string) bool { // Check that the HTTP response contains the string “Hello, World,”
        return status == 200 &&
          strings.Contains(body, "Hello, World")
      },
    )
  }
  ```

- Finally, run the test:

```shell
$ go test -v -timeout 30m -run "TestHelloWorldAppStage"
```

#### Test Stages

Current stages of our test:

1. Run `terraform apply` on the `mysql` module.
2. Run `terraform apply` on the `hello-world-app` module.
3. Run validations to make sure everything is working.
4. Run `terraform destroy` on the `hello-world-app` module.
5. Run `terraform destroy` on the `mysql` module.

When we run these tests in a CI environment, we’ll want to run all of the stages, from start to finish.

However, if we’re running these tests in our local dev environment while iteratively making changes to the code, running all of these stages is unnecessary.

Ideally, the workflow would look more like this:

1. Run `terraform apply` on the `mysql` module.
2. Run `terraform apply` on the `hello-world-app` module.
3. Now, you start doing iterative development:

   3.1. Make a change to the `hello-world-app` module.

   3.2. Rerun terraform apply on the `hello-world-app` module to deploy your updates.

   3.3. Run validations to make sure everything is working.

   3.4. If everything works, move on to the next step. If not, go back to step 3.1.

4. Run `terraform destroy` on the `hello-world-app` module.
5. Run `terraform destroy` on the `mysql` module.

Having the ability to quickly do that inner loop in step 3 is the key to fast, iterative development with Terraform.

To support this, we need to break our test code into stages, in which we can choose the stages to execute and those that you can skip. Terratest supports this natively with the `test_structure` package.

- First, break the test into stages and wrap each stage with `test_structure.RunTestStage`:

  ```go
  // test/hello_world_integration_test.go
  func TestHelloWorldAppStageWithStages(t *testing.T) {
    t.Parallel()

    // Deploy the MySQL DB
    defer test_structure.RunTestStage(t, "teardown_db", func() { teardownDb(t, ) })
    test_structure.RunTestStage(t, "deploy_db", func() { deployDb(t, ) })

    // Deploy the hello-world-app
    defer test_structure.RunTestStage(t, "teardown_app", func() { teardownApp(t, appDirStage) })
    test_structure.RunTestStage(t, "deploy_app", func() { deployApp(t, , appDirStage) })

    // Validate the hello-world-app works
    test_structure.RunTestStage(t, "validate_app", func() { validateApp(t, appDirStage) })
  }
  ```

- Next, implement test for each stage:

  - Deploy database and save terraform stage to disk:

    ```go
    func deployDb(t *testing.T, dbDir string) {
      dbOpts := createDbOpts(t, dbDir)

      // Save data to disk so that other test stages executed at a later time can read the data back in
      test_structure.SaveTerraformOptions(t, dbDir, dbOpts)

      terraform.InitAndApply(t, dbOpts)
    }
    ```

  - Load Terraform stage from disk and tear down the database:

    ```go
    func teardownDb(t *testing.T, dbDir string) {
      dbOpts := test_structure.LoadTerraformOptions(t, dbDir) // load the dbOpts data from disk that was earlier saved by the deployDb function
      defer terraform.Destroy(t, dbOpts)
    }
    ```

  - Deploy app and save terraform stage to disk:

    ```go
    func deployApp(t *testing.T, dbDir string, helloAppDir string) {
      dbOpts := test_structure.LoadTerraformOptions(t, dbDir)
      helloOpts := createHelloOpts(dbOpts, helloAppDir)

      // Save data to disk so that other test stages executed at a later
      // time can read the data back in
      test_structure.SaveTerraformOptions(t, helloAppDir, helloOpts)

      terraform.InitAndApply(t, helloOpts)
    }
    ```

  - Load terraform stage from disk and teardown app:

    ```go
    func teardownApp(t *testing.T, helloAppDir string) {
      helloOpts := test_structure.LoadTerraformOptions(t, helloAppDir)
      defer terraform.Destroy(t, helloOpts)
    }
    ```

  - Validate the app:

    ```go
    func validateApp(t *testing.T, helloAppDir string) {
      helloOpts := test_structure.LoadTerraformOptions(t, helloAppDir)
      validateHelloApp(t, helloOpts)
    }
    ```

- Now we can instruct Terratest to skip any test stage called `foo` by setting the environment variable `SKIP_foo=tru`:

  - Skip `teardown_db` and `teardown_app`:

    ```shell
    $ SKIP_teardown_db=true \
      SKIP_teardown_app=true \
      go test -timeout 30m -run 'TestHelloWorldAppStageWithStages'
    ```

  - Start iterating on the `hello-world-app` module:

    - Make some change to `hello-world-app` module.

    - Deploy only the app

      ```shell
      $ SKIP_teardown_db=true \
        SKIP_teardown_app=true \
        SKIP_deploy_db=true \
        go test -timeout 30m -run 'TestHelloWorldAppStageWithStages'
      ```

    - Repeat

  - Once everything is working, run the teardown:

    ```shell
    $ SKIP_deploy_db=true \
      SKIP_deploy_app=true \
      SKIP_validate_app=true \
      go test -timeout 30m -run 'TestHelloWorldAppStageWithStages'
    ```

> **Why saves terraform state to disk when break a test into stages?**
>
> So we can run each test stage as part of a different test run — and therefore, as part of a different process.

> **What is the benefit of breaking a Terraform test into stages?**
>
> It won’t make any difference in how long tests take in our CI environment, but the impact on the development environment is huge.
>
> It lets us get rapid feedback from your automated tests.
>
> 👉 Dramatically increasing the speed and quality of iterative development.

#### Test Retires

The infrastructure world is a messy place. We should expect intermittent failures in our tests and handle them correctly.

`Terratest` supports retries with `terraform.Options`'s arguments:

- `MaxRetries`
- `TimeBetweenRetries`
- `RetryableTerraformErrors`

For example:

```go
func createHelloOpts(dbOpts *terraform.Options, terraformDir string) *terraform.Options {
	// ...
	return &terraform.Options{
		// ...
		MaxRetries:         3,               // Retry up to 3 times,
		TimeBetweenRetries: 5 * time.Second, // with 5 seconds between retries,
		RetryableTerraformErrors: map[string]string{ // on known errors
			"RequestError: send request failed": "Throttling issue?",
		},
	}
}
```

### End-to-End Tests

For a web server, an `end-to-end test` might consists of:

- deploying the web server and any data store it depends on,
- testing it from a web browser using a tool such as Selenium.

For Terraform, an `end-to-end test` will look similar:

- deploy everything into an environment that mimics production,
- test it from the end-user's perspective.

> **What is `test pyramid`?**
>
> ![Test Pyramid](https://learning.oreilly.com/api/v2/epubs/urn:orm:book:9781098116736/files/assets/tur3_0901.png)

> **What is the idea of `test pyramid`?**
>
> The idea of `test pyramid` is that we should typically be aiming for:
>
> - a large number of unit tests (the bottom of the pyramid),
> - a smaller number of integration tests (the middle of the pyramid),
> - and an even smaller number of end-to-end tests (the top of the pyramid)

> **ℹ️ Key testing takeaway #5** 🤏
>
> Smaller modules are easier and faster to test.

> **Can we run tests that deploy a complicated architecture from scratch for production?**
>
> No. It's:
>
> - Too slow
>
>   It can take several hours. The feedback loop is too slow.
>
> - Too fragile.
>
>   The infrastructure world is messy.
>
> For example:
>
> Suppose a single resource has one-in-a-thousand (0.1%) chance of failing due to an intermittent error.
>
> That means the probability that a test that deploys a single resource runs without any intermittent errors is 99.9%.
>
> - If the tests has \_\_10 resources, the odds of success are **99**% (0.999^10).
> - If the tests has \_\_50 resources, the odds of success are **95**%.
> - If the tests has \_100 resources, the odds of success are **90**%.
> - If the tests has \_200 resources, the odds of success are **82**%.
> - If the tests has \_500 resources, the odds of success are **61**%.
> - If the tests has \_700 resources, the odds of success are **49**%.
> - If the tests has 1000 resources, the odds of success are **37**%.

> **How to run end-to-end for a complicated infrastructure?**
>
> In practice, very few companies with a complicated infrastructure run end-to-end tests that deploy everything from scratch.
>
> The common strategy is:
>
> 1.  (One time) Deploy a persistent, production-like environment called `test` and let it running.
>
> 2.  Every time someone make a change to the infrastructure code, the end-to-end test:
>
>     1. Apply the infrastructure change to the `test` environment
>
>        > ⚠️ We're applying only incremental changes, not teardown the whole environment and bring it up from scratch.
>
>     2. Runs validations against the test environment to make sure everything is working.
>
>        e.g. Use Selenium to test our code from end-user's perspective.
>
> > 💡 This style of end-to-end testing offers a huge advantage:
> >
> > We can test:
> >
> > - not only that our _infrastructure_ works correctly
> > - but also that the _deployment process_ for that infrastructure works correctly, too.

### Other Testing Approaches

There are three other types of automated tests we can use:

- Static analysis: Parse the code and analyze it without actually executing it in any way.
- Plan testing: Run `terraform plan` and to analyze the plan output.
- "Server testing": Testing that your servers (including virtual servers) have been properly configured.

#### Static analysis

`Static analysis` is the most basic way to test your Terraform code

A comparison of popular `static analysis` tools for Terraform (February 2022):

|                   | `terraform validate`       | `tfsec`                                         | `tflint`                   | `Terrascan`                               |
| ----------------- | -------------------------- | ----------------------------------------------- | -------------------------- | ----------------------------------------- |
| Brief description | Built-in Terraform command | Spot potential security issues                  | Pluggable Terraform linter | Detect compliance and security violations |
| License           | (same as Terraform)        | MIT                                             | MPL 2.0                    | Apache 2.0                                |
| Backing company   | (same as Terraform)        | Aqua Security                                   | (none)                     | Accurics                                  |
| Stars             | (same as Terraform)        | 3,874                                           | 2,853                      | 2,768                                     |
| Contributors      | (same as Terraform)        | 96                                              | 77                         | 63                                        |
| First release     | (same as Terraform)        | 2019                                            | 2016                       | 2017                                      |
| Latest release    | (same as Terraform)        | v1.1.2                                          | v0.34.1                    | v1.13.0                                   |
| Built-in checks   | Syntax checks only         | AWS, Azure, GCP, Kubernetes, DigitalOcean, etc. | AWS, Azure, and GCP        | AWS, Azure, GCP, Kubernetes, etc.         |
| Custom checks     | Not supported              | Defined in YAML or JSON                         | Defined in a Go plugin     | Defined in Rego                           |

> **What is the pros and cons of Terraform **static analysis**?**
>
> 👍 Pros:
>
> - Fast.
> - Easy to use.
> - Stable (no flaky tests).
> - No need to authenticate with providers.
> - No need to deploy/undeploy real resouces.
>
> 👎 Cons:
>
> - Very limited in the type of errors they can catch.
> - These tests aren’t checking functionality, so it’s possible for all the checks to pass and the infrastructure still doesn’t work!

#### Plan testing

`Plan testing` is running `terraform plan` and analyze the plan output.

`Plan testing` is more than static analysis, but it’s less than a unit or integration test

A comparison of popular `plan testing` tools for Terraform (February 2022):

|                   | Terratest                  | Open Policy Agent (OPA)       | HashiCorp Sentinel                               | Checkov                           | terraform-compliance             |
| ----------------- | -------------------------- | ----------------------------- | ------------------------------------------------ | --------------------------------- | -------------------------------- |
| Brief description | Go library for IaC testing | General-purpose policy engine | Policy-as-code for HashiCorp enterprise products | Policy-as-code for everyone       | BDD test framework for Terraform |
| License           | Apache 2.0                 | Apache 2.0                    | Commercial / proprietary license                 | Apache 2.0                        | MIT                              |
| Backing company   | Gruntwork                  | Styra                         | HashiCorp                                        | Bridgecrew                        | (none)                           |
| Stars             | 5,888                      | 6,207                         | (not open source)                                | 3,758                             | 1,104                            |
| Contributors      | 157                        | 237                           | (not open source)                                | 199                               | 36                               |
| First release     | 2016                       | 2016                          | 2017                                             | 2019                              | 2018                             |
| Latest release    | v0.40.0                    | v0.37.1                       | v0.18.5                                          | 2.0.810                           | 1.3.31                           |
| Built-in checks   | None                       | None                          | None                                             | AWS, Azure, GCP, Kubernetes, etc. | None                             |
| Custom checks     | Defined in Go              | Defined in Rego               | Defined in Sentinel                              | Defined in Python or YAML         | Defined in BDD                   |

For example:

- A plan testing with `terratest`:

  ```go
  func TestAlbExamplePlan(t *testing.T) {
    t.Parallel()

    albName := fmt.Sprintf("test-%s", random.UniqueId())

    opts := &terraform.Options{
      // point at your alb example directory!
      TerraformDir: "../examples/alb",
      Vars: map[string]interface{}{
        "alb_name": albName,
      },
    }

    planString := terraform.InitAndPlan(t, opts)

    // An example of how to check the plan output's add/change/destroy counts
    resourceCounts := terraform.GetResourceCount(t, planString)
    require.Equal(t, 5, resourceCounts.Add)
    require.Equal(t, 0, resourceCounts.Change)
    require.Equal(t, 0, resourceCounts.Destroy)

    // parse the plan output into a struct
    planStruct :=
      terraform.InitAndPlanAndShowWithStructNoLogTempPlanFile(t, opts)

    alb, exists :=
      planStruct.ResourcePlannedValuesMap["module.alb.aws_lb.example"]
    require.True(t, exists, "aws_lb resource must exist")

    name, exists := alb.AttributeValues["name"]
    require.True(t, exists, "missing name parameter")
    require.Equal(t, albName, name)
  }
  ```

  Terratest’s approach to plan testing is:

  - Flexible.

    We can write arbitrary Go code to check whatever you want

  - Hard to get started.

Some teams prefer a more declarative language for defining their policies as code. In the last few years, [Open Policy Agent (OPA)](https://github.com/open-policy-agent/opa) has become a popular policy-as-code tool, as it allows your to capture you company’s policies as code in a declarative language called Rego.

> **What is pros and cons of plan testing?**
>
> 👍 Pros of plan testing tools
>
> - Fast — not quite as fast as pure static analysis but much faster than unit or integration tests.
> - Easy to use — not quite as easy as pure static analysis but much easier than unit or integration tests.
> - Stable (few flaky tests) — not quite as stable as pure static analysis but much more stable than unit or integration tests.
> - You don’t have to deploy/undeploy real resources.
>
> 👎 Cons of plan testing tools
>
> - Limited in the types of errors they can catch. They can catch more than pure static analysis but nowhere near as many errors as unit and integration testing.
> - You have to authenticate to a real provider (e.g., to a real AWS account). This is required for plan to work.
> - These tests aren’t checking functionality, so it’s possible for all the checks to pass and the infrastructure still doesn’t work!

#### Server testing

"Server testing" tests that your servers (including virtual servers) have been properly configured.

They are originally built to be used with configuration management tools, such as Chef and Puppet, which were entirely focused on launching servers.

However, as Terraform has grown in popularity, it’s now very common to use it to launch servers, and these tools can be helpful for validating that the servers you launched are working.

A comparison of popular server testing tools (February 2022)

|                   | InSpec                         | Serverspec                   | Goss                                     |
| ----------------- | ------------------------------ | ---------------------------- | ---------------------------------------- |
| Brief description | Auditing and testing framework | RSpec tests for your servers | Quick and easy server testing/validation |
| License           | Apache 2.0                     | MIT                          | Apache 2.0                               |
| Backing company   | Chef                           | (none)                       | (none)                                   |
| Stars             | 2,472                          | 2,426                        | 4,607                                    |
| Contributors      | 279                            | 128                          | 89                                       |
| First release     | 2016                           | 2013                         | 2015                                     |
| Latest release    | v4.52.9                        | v2.42.0                      | v0.3.16                                  |
| Built-in checks   | None                           | None                         | None                                     |
| Custom checks     | Defined in a Ruby-based DSL    | Defined in a Ruby-based DSL  | Defined in YAML                          |

Most of these tools provide a simple domain-specific language (DSL) for checking that the servers you’ve deployed conform to some sort of specification.

For example:

- Testing a Terraform module that deployed an EC2 Instance

  ```t
  # Validate that the Instance has proper permissions on specific files
  describe file('/etc/myapp.conf') do
    it { should exist }
    its('mode') { should cmp 0644 }
  end

  # has certain dependencies installed
  describe apache_conf do
    its('Listen') { should cmp 8080 }
  end

  # is listening on a specific port
  describe port(8080) do
    it { should be_listening }
  end
  ```

> **What are the pros and cons of server testing?**
>
> 👍 Pros:
>
> - Easy to validate specific properties of server useing DSLs than doing it from scratch.
> - Can build up a library of policy checks.
> - Catch many types of errors.
>
> 👎 Cons:
>
> - Not as fast.
>
>   Only works on the deployed server <- Run full `apply`, `destroy` cycle.
>
> - Not as stable.
> - Have to authenticate to provider.
> - Have to deploy/undeploy.
> - Can only check the servers, not other types of infrastructure.
> - These tests aren’t checking functionality, so it’s possible for all the checks to pass and the infrastructure still doesn’t work!

## Conclusion

_Infrastructure code without automated tests is broken_

Writing automated tests as shown in this chapter is not easy:

- it takes considerable effort to write these tests,
- it takes even more effort to maintain them and add enough retry logic to make them reliable,
- and it takes still more effort to keep your test environment clean to keep costs in check.

But it’s all worth it.

Key takeaways of testing Terraform code:

1. _When testing Terraform code, you can’t use ~~localhost~~_

   Therefore, you need to do all of your manual testing by deploying real resources into one or more isolated sandbox environments.

2. _You cannot do ~~pure unit testing~~ for Terraform code_

   Therefore, you have to do all of your automated testing by writing code that deploys real resources into one or more isolated sandbox environments.

3. _Regularly **clean up** your sandbox environments_

   Otherwise, the environments will become unmanageable, and costs will spiral out of control.

4. _You must **namespace** all of your resources_

   This ensures that multiple tests running in parallel do not conflict with one another.

5. **_Smaller modules are easier and faster to test_**

   This was one of the key takeaways in Chapter 8, and it’s worth repeating in this chapter, too: smaller modules are easier to create, maintain, use, and test.

A comparison of testing approaches (more black squares is better):

|                                             | Static analysis | Plan testing | Server testing | Unit tests | Integration tests | End-to-end tests |
| ------------------------------------------- | --------------- | ------------ | -------------- | ---------- | ----------------- | ---------------- |
| Fast to run                                 | ■■■■■           | ■■■■□        | ■■■□□          | ■■□□□      | ■□□□□             | □□□□□            |
| Cheap to run                                | ■■■■■           | ■■■■□        | ■■■□□          | ■■□□□      | ■□□□□             | □□□□□            |
| Stable and reliable                         | ■■■■■           | ■■■■□        | ■■■□□          | ■■□□□      | ■□□□□             | □□□□□            |
| Easy to use                                 | ■■■■■           | ■■■■□        | ■■■□□          | ■■□□□      | ■□□□□             | □□□□□            |
| Check syntax                                | ■■■■■           | ■■■■■        | ■■■■■          | ■■■■■      | ■■■■■             | ■■■■■            |
| Check policies                              | ■■□□□           | ■■■■□        | ■■■■□          | ■■■■■      | ■■■■■             | ■■■■■            |
| Check servers work                          | □□□□□           | □□□□□        | ■■■■■          | ■■■■■      | ■■■■■             | ■■■■■            |
| Check other infrastructure works            | □□□□□           | □□□□□        | ■■□□□          | ■■■■□      | ■■■■■             | ■■■■■            |
| Check all the infrastructure works together | □□□□□           | □□□□□        | □□□□□          | ■□□□□      | ■■■□□             | ■■■■■            |

> **Which testing approach should we use?**
>
> The answer is: a mix of all of them.
>
> Each type of test has strengths and weaknesses, combine multiple types of tests to be confident your code works as expected.

> **What is the proportion of tests we should use?**
>
> The testing pyramid:
>
> - lots of _unit tests_,
> - fewer _integration tests_
> - and only a small number of high-value _end-to-end tests_

> **Do we have to write all types of tests at once?**
>
> No. Pick the ones that give you the best bang for your buck and add those first.
>
> Almost any testing is better than none, so if all you can add for now is static analysis, then use that as a starting point, and build on top of it incrementally.
