# A Cluster of web servers

```shell
curl $(terraform output -raw alb_dns_name)
# Hello, World from 18.143.145.196
```