# Function Secrets Test 2: providing secret in secret_volumes block

resource "google_secret_manager_secret" "test_secret_02" {
  secret_id = "test-secret_02"

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

resource "google_secret_manager_secret_version" "test_secret_version_02a" {
  secret      = google_secret_manager_secret.test_secret_02.id
  secret_data = "This is my secret for test 2."
}


# resource "google_secret_manager_secret_version" "test_secret_version_02b" {
#   secret      = google_secret_manager_secret.test_secret_02.id
#   secret_data = "This is another version of my secret for test 2."
# }


resource "google_secret_manager_secret_iam_member" "cloud_function_sa_02" {
  secret_id = google_secret_manager_secret.test_secret_02.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_function_runner.email}"
}

data "archive_file" "cloud_function_2_zip" {
  type        = "zip"
  output_path = "/tmp/cloud_function_2.zip"
  source {
    content  = <<-EOF
      const fs = require('fs')

      exports.echoSecret = (req, res) => {
        const path = '/etc/secrets/test-secret'
        fs.access(path, fs.F_OK, (err) => {
          if (err) {
            console.error(err)
            res.status(200).send(err)
            return
          }
        fs.readFile(path, 'utf8', function(err,data) {
          res.status(200).send("Secret: "+data)
          return
        });
      })
      };
    EOF
    filename = "index.js"
  }
}


resource "google_cloudfunctions_function" "secrets_test_02" {
  name                  = "secrets-test-02"
  runtime               = "nodejs14"
  service_account_email = google_service_account.cloud_function_runner.email
  entry_point           = "echoSecret"
  source_archive_bucket = google_storage_bucket.cloud_functions.id
  source_archive_object = google_storage_bucket_object.cloud_function_2_zip.name
  trigger_http          = true
# Remove this secret_volumes block on second tf apply
  secret_volumes {
    secret     = google_secret_manager_secret.test_secret_02.secret_id
    mount_path = "/etc/secrets"
    versions { // code suggests this can be left empty, but still required
      version = "latest"
      path    = "/test-secret"
    }
  }
}

resource "google_storage_bucket_object" "cloud_function_2_zip" {
  name   = "cloud-function-2.zip"
  bucket = google_storage_bucket.cloud_functions.id
  source = data.archive_file.cloud_function_2_zip.output_path
}

resource "google_cloudfunctions_function_iam_member" "invoker_02" {
  cloud_function = google_cloudfunctions_function.secrets_test_02.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}
output "functions_secrets_test_2_URL" {
  value = google_cloudfunctions_function.secrets_test_02.https_trigger_url
}
