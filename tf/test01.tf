# Function Secrets Test 1: providing secret in secret_environment_variables block

resource "google_secret_manager_secret" "test_secret_01" {
  secret_id = "test-secret_01"

  replication {
    user_managed {
      replicas {
        location = "us-central1"
      }
      replicas {
        location = "us-east1"
      }
    }
  }
  depends_on = [
    google_project_service.secret_manager
  ]
}

resource "google_secret_manager_secret_version" "test_secret_version_01a" {
  secret      = google_secret_manager_secret.test_secret_01.id
  secret_data = "This is my secret for test 1."


}

# resource "google_secret_manager_secret_version" "test_secret_version_01b" {
#   secret      = google_secret_manager_secret.test_secret_01.id
#   secret_data = "This is another version of my secret for test 1."
# }

resource "google_secret_manager_secret_iam_member" "cloud_function_sa_01" {
  secret_id = google_secret_manager_secret.test_secret_01.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_function_runner.email}"
}

data "archive_file" "cloud_function_1_zip" {
  type        = "zip"
  output_path = "/tmp/cloud_function_1.zip"
  source {
    content  = <<-EOF
    exports.echoSecret = (req, res) => {
    let message = req.query.message || req.body.message || "Secret: "+process.env.MY_SECRET;
    res.status(200).send(message);
    };
    EOF
    filename = "index.js"
  }
}

resource "google_storage_bucket_object" "cloud_function_1_zip" {
  name   = "cloud-function-1.zip"
  bucket = google_storage_bucket.cloud_functions.id
  source = data.archive_file.cloud_function_1_zip.output_path
}



resource "google_cloudfunctions_function" "secrets_test" {
  name                  = "secrets-test-01"
  runtime               = "nodejs14"
  service_account_email = google_service_account.cloud_function_runner.email
  entry_point           = "echoSecret"
  source_archive_bucket = google_storage_bucket.cloud_functions.id
  source_archive_object = google_storage_bucket_object.cloud_function_1_zip.name
  trigger_http          = true
  secret_environment_variables {
    key     = "MY_SECRET"
    secret  = google_secret_manager_secret.test_secret_01.secret_id // description for arg says 'name of secret', terraform keeps this value as "secret_id"
    version = "latest"                                              // This value is not made available by the secret_manager_secret_version resource
  }
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  cloud_function = google_cloudfunctions_function.secrets_test.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}
output "functions_secrets_test_1_URL" {
  value = google_cloudfunctions_function.secrets_test.https_trigger_url
}
