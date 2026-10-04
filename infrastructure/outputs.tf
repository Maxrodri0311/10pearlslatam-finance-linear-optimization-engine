# ==============================================================================
# 10Pearls LATAM - Infrastructure Outputs
# Target: AWS Terraform Module | Role: Business Intelligence Engineer
# ==============================================================================

output "telemetry_bronze_bucket_arn" {
  description = "ARN of the primary bronze telemetry raw data lake bucket"
  value       = aws_s3_bucket.telemetry_lake.arn
}

output "telemetry_bronze_bucket_name" {
  description = "Name of the bronze ingestion bucket"
  value       = aws_s3_bucket.telemetry_lake.bucket
}

output "analytics_gold_bucket_arn" {
  description = "ARN of the gold curated data mart bucket"
  value       = aws_s3_bucket.analytics_mart_bucket.arn
}

output "analytics_gold_bucket_name" {
  description = "Name of the gold curated analytics bucket"
  value       = aws_s3_bucket.analytics_mart_bucket.bucket
}

output "glue_catalog_database_name" {
  description = "Name of the Glue Data Catalog database governing data contracts"
  value       = aws_glue_catalog_database.lakehouse_catalog.name
}

output "glue_table_contract_name" {
  description = "Name of the Glue Catalog table contract for telemetry events"
  value       = aws_glue_catalog_table.telemetry_table_contract.name
}

output "execution_role_arn" {
  description = "IAM Role ARN with scoped least-privilege for analytical workloads"
  value       = aws_iam_role.analytics_execution_role.arn
}

output "pg_olap_parameter_group_id" {
  description = "Identifier of the tuned PostgreSQL 16 OLAP parameter group"
  value       = aws_db_parameter_group.pg_olap_tuning.id
}