# proj_10pearls_latam_business_intelligence_engineer_bridge_pr - Infrastructure Outputs

output "telemetry_bucket_arn" {
  description = "ARN of the primary telemetry data lake bucket"
  value       = aws_s3_bucket.telemetry_lake.arn
}

output "execution_role_arn" {
  description = "IAM Role ARN for analytical workloads"
  value       = aws_iam_role.analytics_execution_role.arn
}