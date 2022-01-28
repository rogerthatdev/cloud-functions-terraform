# Resources needed for all tests

resource "google_project_service" "secret_manager" {
  service = "secretmanager.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}

resource "google_service_account" "cloud_function_runner" {
  account_id   = "cloud-function-service"
  display_name = "Testing Cloud Function Secrets integration"
}

resource "google_storage_bucket" "cloud_functions" {
  name                        = "${var.project_id}-cloud-functions"
  location                    = "US"
  uniform_bucket_level_access = true
}







