terraform {
  backend "gcs" {
    bucket = "sixtygg-terraform-state"
    prefix = "sixtygg/dev"
  }
}