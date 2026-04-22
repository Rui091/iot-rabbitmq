aws_region  = "us-east-1"
environment = "dev"

# ─── Secrets ───────────────────────────────────────────────────────────────────
# DO NOT put passwords here. Pass them as environment variables:
#
#   export TF_VAR_db_username="admin"
#   export TF_VAR_db_password="<a_secure_password>"
#   export TF_VAR_rabbitmq_username="admin"
#   export TF_VAR_rabbitmq_password="<a_secure_password>"
#
# Then run:
#   terraform plan -out=tfplan -var-file=terraform.tfvars
#   terraform apply tfplan
