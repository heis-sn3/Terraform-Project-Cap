output "state_buckets" {
  description = "Map of environment to state bucket name"
  value = {
    for env, bucket in module.state : env => bucket.bucket_id
  }
}
