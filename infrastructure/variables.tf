# ==============================================================================
# 10Pearls LATAM - Enterprise Lakehouse Infrastructure Variables
# Target: AWS Terraform Module | Role: Business Intelligence Engineer
# ==============================================================================

variable "aws_region" {
  description = "AWS deployment region for Lakehouse infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Operational environment tier (production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Canonical project identifier for resource tagging and IAM boundaries"
  type        = string
  default     = "10pearlslatam-finance-linear-optimization-engine"
}

variable "data_retention_days_bronze" {
  description = "Retention period before transitioning bronze raw telemetry to cold archive"
  type        = number
  default     = 90
}

variable "data_retention_days_glacier" {
  description = "Retention period before transitioning cold telemetry to Glacier Deep Archive"
  type        = number
  default     = 365
}

variable "enable_bucket_versioning" {
  description = "Enforces object versioning on data lake buckets for immutable audit compliance"
  type        = bool
  default     = true
}

variable "rds_allocated_storage_gb" {
  description = "Allocated NVMe storage in GB for PostgreSQL Aurora / RDS analytical cluster"
  type        = number
  default     = 100
}

variable "rds_max_allocated_storage_gb" {
  description = "Storage autoscaling threshold for PostgreSQL analytical lakehouse"
  type        = number
  default     = 1000
}

variable "rds_instance_class" {
  description = "Compute instance tier for PostgreSQL analytical workloads"
  type        = string
  default     = "db.r6g.xlarge"
}

variable "cost_centers" {
  description = "List of operational LATAM cost centers governed by the optimization engine"
  type        = list(string)
  default     = ["LATAM-BOG", "LATAM-BA", "LATAM-CDMX", "LATAM-SP", "US-EAST"]
}
