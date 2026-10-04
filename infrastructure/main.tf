# ==============================================================================
# 10Pearls LATAM - Enterprise Lakehouse Infrastructure as Code (IaC)
# Target: AWS Terraform Module | Role: Business Intelligence Engineer
# Paradigm: DeliveryParadigm.MODERN_LAKEHOUSE_CONTRACTS
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      TargetRole  = "Business Intelligence Engineer"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Company     = "10Pearls LATAM"
    }
  }
}

# ------------------------------------------------------------------------------
# 1. Medallion Storage Layer (Bronze / Silver / Gold S3 Architecture)
# ------------------------------------------------------------------------------

# Raw Telemetry Lake (Bronze Tier - Immutable Raw Ingestion)
resource "aws_s3_bucket" "telemetry_lake" {
  bucket        = "${var.project_name}-telemetry-lake-bronze"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "telemetry_versioning" {
  bucket = aws_s3_bucket.telemetry_lake.id
  versioning_configuration {
    status = var.enable_bucket_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "telemetry_crypto" {
  bucket = aws_s3_bucket.telemetry_lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "telemetry_lifecycle" {
  bucket = aws_s3_bucket.telemetry_lake.id

  rule {
    id     = "archive-cold-telemetry"
    status = "Enabled"

    filter {
      prefix = "telemetry/"
    }

    transition {
      days          = var.data_retention_days_bronze
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.data_retention_days_glacier
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "telemetry_block_public" {
  bucket                  = aws_s3_bucket.telemetry_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Curated Analytics Mart Bucket (Gold Tier - Columnar Parquet / Materialized Data Marts)
resource "aws_s3_bucket" "analytics_mart_bucket" {
  bucket        = "${var.project_name}-analytics-gold"
  force_destroy = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gold_crypto" {
  bucket = aws_s3_bucket.analytics_mart_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "gold_block_public" {
  bucket                  = aws_s3_bucket.analytics_mart_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# 2. AWS Glue Catalog (Metadata Governance & Data Contracts)
# ------------------------------------------------------------------------------

resource "aws_glue_catalog_database" "lakehouse_catalog" {
  name        = "tenpearls_lakehouse_catalog_${var.environment}"
  description = "Central metadata catalog governing schema contracts and Parquet partitions for 10Pearls LATAM"
}

resource "aws_glue_catalog_table" "telemetry_table_contract" {
  name          = "telemetry_events"
  database_name = aws_glue_catalog_database.lakehouse_catalog.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"        = "parquet"
    "parquet.compression"   = "SNAPPY"
    "transfers.zero_leaks"  = "enforced"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.telemetry_lake.bucket}/telemetry/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "unit_id"
      type = "string"
    }
    columns {
      name = "domain_cluster"
      type = "string"
    }
    columns {
      name = "primary_metric"
      type = "double"
    }
    columns {
      name = "volume_count"
      type = "bigint"
    }
    columns {
      name = "operating_cost_usd"
      type = "double"
    }
    columns {
      name = "gross_margin_usd"
      type = "double"
    }
    columns {
      name = "allocated_capacity_hours"
      type = "double"
    }
    columns {
      name = "sla_compliance_ratio"
      type = "double"
    }
    columns {
      name = "status_category"
      type = "string"
    }
    columns {
      name = "cost_center"
      type = "string"
    }
    columns {
      name = "is_active"
      type = "boolean"
    }
    columns {
      name = "event_timestamp"
      type = "timestamp"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
}

# ------------------------------------------------------------------------------
# 3. IAM Least-Privilege Execution Boundaries
# ------------------------------------------------------------------------------

resource "aws_iam_role" "analytics_execution_role" {
  name = "${var.project_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "glue.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lakehouse_access_policy" {
  name        = "${var.project_name}-lakehouse-access"
  description = "Scoped read/write permissions for Lakehouse bronze and gold buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3LakehouseObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.telemetry_lake.arn,
          "${aws_s3_bucket.telemetry_lake.arn}/*",
          aws_s3_bucket.analytics_mart_bucket.arn,
          "${aws_s3_bucket.analytics_mart_bucket.arn}/*"
        ]
      },
      {
        Sid    = "GlueMetadataAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:UpdateTable"
        ]
        Resource = [
          aws_glue_catalog_database.lakehouse_catalog.arn,
          aws_glue_catalog_table.telemetry_table_contract.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "analytics_policy_attach" {
  role       = aws_iam_role.analytics_execution_role.name
  policy_arn = aws_iam_policy.lakehouse_access_policy.arn
}

# ------------------------------------------------------------------------------
# 4. PostgreSQL Aurora / RDS Lakehouse Parameter Tuning
# ------------------------------------------------------------------------------

resource "aws_db_parameter_group" "pg_olap_tuning" {
  name   = "${var.project_name}-pg16-olap-params"
  family = "postgres16"

  parameter {
    name  = "work_mem"
    value = "65536" # 64MB for complex in-memory window aggregates
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "524288" # 512MB for high-speed BRIN and B-Tree index builds
  }

  parameter {
    name  = "max_parallel_workers_per_gather"
    value = "4" # Multi-core parallel scan acceleration on partitioned slices
  }

  parameter {
    name  = "effective_cache_size"
    value = "3145728" # 3GB estimated page cache for OS/PostgreSQL buffer pooling
  }

  parameter {
    name  = "random_page_cost"
    value = "1.1" # Tuned for high-IOPS NVMe solid state drives
  }
}