terraform {
  backend "s3" {
    # The bucket is supplied at init time so it is not hardcoded here:
    #   terraform init -backend-config="bucket=<state bucket>"
    key          = "network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
