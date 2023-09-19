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

#### Unit Tests in a GPL (Ruby)

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

#### Unit Tests Terraform code

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

```t
# examples/hello-world-app/main.tf
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

> 💡 A convention for external dependencies
>
> Move all of the data sources and resources that represent external dependencies into a separate file named `dependencies.tf`.
>
> 👉 Make it easier for users of our code to know, at a glance, what this code depends on in the outside world.

For each external dependencies, add a new input variable:

```t
# modules/services/hello-world-app/variables.tf
variable "vpc_id" {
  description = "The ID of the VPC to deploy into"
  type        = string
  default     = null # Make this variable and optional variable
}

variable "subnet_ids" {
  description = "The IDs of the subnets to deploy into"
  type        = list(string)
  default     = null
}

variable "mysql_config" {
  description = "The config for the MySQL DB"
  type        = object({ # A nested type with address and port keys, match the output types of `mysql` module
    address = string
    port    = number
  })
  default     = null
}
```

```t
variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the DB's Terraform state"
  type        = string
  default     = null
}

variable "db_remote_state_key" {
  description = "The path in the S3 bucket for the DB's Terraform state"
  type        = string
  default     = null
}
```

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

```t
locals {
  mysql_config = (
    var.mysql_config == null
      ? data.terraform_remote_state.db[0].outputs
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

```t
module "hello_world_app" {
  source = "../../../modules/services/hello-world-app"

  server_text            = "Hello, World"
  environment            = "example"

  # Pass all the outputs from the mysql module straight through!
  mysql_config = module.mysql

  instance_type      = "t2.micro"
  min_size           = 2
  max_size           = 2
  enable_autoscaling = false
  ami                = data.aws_ami.ubuntu.id
}

module "mysql" {
  source = "../../../modules/data-stores/mysql"

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}
```

#### Running tests in parallel

### Integration Tests

### End-to-End Tests

### Other Testing Approaches

## Conclusion
