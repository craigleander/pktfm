# RDS Deployment Guardrails & Policy Enforcement

This document explains how replica management and organizational policies are enforced in our standardized RDS deployment modules.

## Overview

Our Terraform modules enforce organizational policies through:
1. **Environment-based defaults** - Automatic replica configuration based on environment
2. **Guardrails** - Hard limits preventing policy violations
3. **Security controls** - Mandatory security features that cannot be disabled

---

## Replica Management by Environment

### Default Behavior

| Environment | RDS Replicas | Aurora Readers | Max Allowed |
|-------------|--------------|----------------|-------------|
| **QA**      | 0            | 0              | 0           |
| **Prod**    | 1            | 1              | 5           |

### How It Works

#### RDS Module
**File**: [`modules/rds/main.tf`](modules/rds/main.tf)

```hcl
locals {
  # Default replicas based on environment
  default_replicas = var.environment == "prod" ? 1 : 0
  
  # Use override if provided, otherwise use default
  replicas = coalesce(var.replica_count, local.default_replicas)
  
  # Maximum allowed replicas by environment
  max_replicas = var.environment == "prod" ? 5 : 0
}
```

**Logic**:
- QA environment: 0 replicas by default, max 0 allowed
- Prod environment: 1 replica by default, max 5 allowed
- Optional override via `replica_count` variable (subject to max limits)

#### Aurora Module
**File**: [`modules/rds-aurora/main.tf`](modules/rds-aurora/main.tf)

```hcl
locals {
  # Reader instances based on environment
  reader_count = var.environment == "prod" ? 1 : 0
  
  # Maximum allowed readers by environment
  max_readers = var.environment == "prod" ? 5 : 0
}
```

**Logic**:
- QA environment: 0 reader instances, max 0 allowed
- Prod environment: 1 reader instance, max 5 allowed

---

## Guardrails - Policy Enforcement

Guardrails use Terraform **preconditions** to validate configurations before any resources are created. If a precondition fails, Terraform stops execution immediately.

### RDS Guardrail

**File**: [`modules/rds/main.tf`](modules/rds/main.tf)

```hcl
resource "null_resource" "replica_guardrail" {
  lifecycle {
    precondition {
      condition     = local.replicas <= local.max_replicas
      error_message = "Replica count exceeds org policy"
    }
  }
}
```

**What it does**:
- Validates that requested replica count doesn't exceed maximum
- Runs during `terraform plan` (before any resources are created)
- Blocks deployment if policy is violated

### Aurora Guardrail

**File**: [`modules/rds-aurora/main.tf`](modules/rds-aurora/main.tf)

```hcl
resource "null_resource" "aurora_guardrail" {
  lifecycle {
    precondition {
      condition     = local.reader_count <= local.max_readers
      error_message = "Aurora reader count exceeds org policy"
    }
  }
}
```

**What it does**:
- Validates Aurora reader count against policy limits
- Prevents misconfiguration before deployment
- Provides clear error message when policy is violated

---

## Usage Examples

### ✅ Example 1: QA Environment (Default)

```hcl
module "app_rds" {
  source = "./modules/rds"
  
  name           = "myapp-qa-db"
  environment    = "qa"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  # ... other configs
}
```

**Result**:
- Replicas: `0` (QA default)
- Guardrail check: `0 <= 0` ✅ PASS
- **Deployment succeeds with 0 replicas**

---

### ✅ Example 2: Prod Environment (Default)

```hcl
module "app_rds" {
  source = "./modules/rds"
  
  name           = "myapp-prod-db"
  environment    = "prod"
  engine         = "postgres"
  instance_class = "db.t3.medium"
  # ... other configs
}
```

**Result**:
- Replicas: `1` (Prod default)
- Guardrail check: `1 <= 5` ✅ PASS
- **Deployment succeeds with 1 replica**

---

### ✅ Example 3: Prod with Valid Override

```hcl
module "app_rds" {
  source = "./modules/rds"
  
  name           = "myapp-prod-db"
  environment    = "prod"
  replica_count  = 3  # Override default
  engine         = "postgres"
  instance_class = "db.t3.medium"
  # ... other configs
}
```

**Result**:
- Replicas: `3` (override)
- Guardrail check: `3 <= 5` ✅ PASS
- **Deployment succeeds with 3 replicas**

---

### ❌ Example 4: Prod Exceeding Maximum (BLOCKED)

```hcl
module "app_rds" {
  source = "./modules/rds"
  
  name           = "myapp-prod-db"
  environment    = "prod"
  replica_count  = 10  # Exceeds maximum!
  engine         = "postgres"
  instance_class = "db.t3.medium"
  # ... other configs
}
```

**Result**:
```
Error: Resource precondition failed

  on modules/rds/main.tf line 7, in resource "null_resource" "replica_guardrail":
   7: resource "null_resource" "replica_guardrail" {

Replica count exceeds org policy
```

- Replicas: `10` (override)
- Guardrail check: `10 <= 5` ❌ FAIL
- **Deployment blocked - terraform plan fails**

---

### ❌ Example 5: QA Attempting Replicas (BLOCKED)

```hcl
module "app_rds" {
  source = "./modules/rds"
  
  name           = "myapp-qa-db"
  environment    = "qa"
  replica_count  = 2  # Not allowed in QA!
  engine         = "postgres"
  instance_class = "db.t3.micro"
  # ... other configs
}
```

**Result**:
```
Error: Resource precondition failed

  on modules/rds/main.tf line 7, in resource "null_resource" "replica_guardrail":
   7: resource "null_resource" "replica_guardrail" {

Replica count exceeds org policy
```

- Replicas: `2` (override)
- Guardrail check: `2 <= 0` ❌ FAIL
- **Deployment blocked - QA cannot have replicas**

---

## Additional Security Controls

Beyond replica management, the modules enforce mandatory security controls:

### 1. Storage Encryption (Always Enabled)

**RDS**: [`modules/rds/main.tf`](modules/rds/main.tf)
```hcl
storage_encrypted = true
```

**Aurora**: [`modules/rds-aurora/main.tf`](modules/rds-aurora/main.tf)
```hcl
storage_encrypted = true
```

**Policy**: All database storage must be encrypted at rest. Cannot be disabled.

---

### 2. Deletion Protection (Prod Only)

**RDS**: [`modules/rds/main.tf`](modules/rds/main.tf)
```hcl
deletion_protection = var.environment == "prod"
```

**Aurora**: [`modules/rds-aurora/main.tf`](modules/rds-aurora/main.tf)
```hcl
deletion_protection = var.environment == "prod"
```

**Policy**: 
- Prod databases: Deletion protection **enabled** (prevents accidental deletion)
- QA databases: Deletion protection **disabled** (allows easy cleanup)

---

### 3. Performance Insights (Always Enabled)

**RDS**: [`modules/rds/main.tf`](modules/rds/main.tf)
```hcl
performance_insights_enabled          = true
performance_insights_retention_period = 7
```

**Policy**: Performance monitoring enabled with 7-day retention for troubleshooting.

---

### 4. Backup Retention (7 Days)

**RDS**: [`modules/rds/main.tf`](modules/rds/main.tf)
```hcl
backup_retention_period = 7
```

**Aurora**: [`modules/rds-aurora/main.tf`](modules/rds-aurora/main.tf)
```hcl
backup_retention_period = 7
```

**Policy**: All databases maintain 7 days of automated backups.

---

### 5. Enhanced Monitoring (60-second intervals)

**RDS**: [`modules/rds/main.tf`](modules/rds/main.tf)
```hcl
monitoring_interval = 60
```

**Aurora**: [`modules/rds-aurora/main.tf`](modules/rds-aurora/main.tf)
```hcl
monitoring_interval = 60
```

**Policy**: Enhanced monitoring collects metrics every 60 seconds for all databases.

---

### 6. Public Access (Always Disabled)

**RDS**: [`modules/rds/main.tf`](modules/rds/main.tf)
```hcl
publicly_accessible = false
```

**Policy**: Databases are never publicly accessible - must be accessed through VPC.

---

## Environment Validation

The `environment` variable is validated to ensure only approved values:

**File**: [`modules/rds/variables.tf`](modules/rds/variables.tf)

```hcl
variable "environment" {
  validation {
    condition     = contains(["qa", "prod"], var.environment)
    error_message = "Environment must be qa or prod"
  }
}
```

**Allowed values**: `qa`, `prod`

**Invalid example**:
```hcl
environment = "dev"  # ❌ Will fail validation
```

**Error**:
```
Error: Invalid value for variable

Environment must be qa or prod
```

---

## Policy Summary

| Policy | QA | Prod | Enforcement |
|--------|----|----|-------------|
| **Default Replicas** | 0 | 1 | Automatic |
| **Max Replicas** | 0 | 5 | Precondition guardrail |
| **Storage Encryption** | ✅ Required | ✅ Required | Hardcoded |
| **Deletion Protection** | ❌ Disabled | ✅ Enabled | Environment-based |
| **Performance Insights** | ✅ Enabled | ✅ Enabled | Hardcoded |
| **Backup Retention** | 7 days | 7 days | Hardcoded |
| **Enhanced Monitoring** | 60s | 60s | Hardcoded |
| **Public Access** | ❌ Blocked | ❌ Blocked | Hardcoded |

---

## Testing Guardrails

To test that guardrails are working:

### Test 1: Validate QA Cannot Have Replicas
```bash
# Create test configuration
cat > test-qa-replicas.tf <<EOF
module "test_rds" {
  source         = "./modules/rds"
  name           = "test-qa"
  environment    = "qa"
  replica_count  = 1  # Should fail
  # ... other required vars
}
EOF

# Run plan - should fail
terraform plan
```

**Expected**: Error message "Replica count exceeds org policy"

### Test 2: Validate Prod Max Limit
```bash
# Create test configuration
cat > test-prod-max.tf <<EOF
module "test_rds" {
  source         = "./modules/rds"
  name           = "test-prod"
  environment    = "prod"
  replica_count  = 6  # Exceeds max of 5
  # ... other required vars
}
EOF

# Run plan - should fail
terraform plan
```

**Expected**: Error message "Replica count exceeds org policy"

### Test 3: Validate Prod Default
```bash
# Create test configuration
cat > test-prod-default.tf <<EOF
module "test_rds" {
  source      = "./modules/rds"
  name        = "test-prod"
  environment = "prod"
  # No replica_count specified - should use default of 1
  # ... other required vars
}
EOF

# Run plan - should succeed with 1 replica
terraform plan
```

**Expected**: Plan succeeds, shows 1 replica will be created

---

## Modifying Policies

To change organizational policies, update the following files:

### Change Default Replica Counts
Edit [`modules/rds/main.tf`](modules/rds/main.tf) and [`modules/rds-aurora/main.tf`](modules/rds-aurora/main.tf):

```hcl
locals {
  # Change these values
  default_replicas = var.environment == "prod" ? 2 : 0  # Changed from 1 to 2
  max_replicas     = var.environment == "prod" ? 10 : 0  # Changed from 5 to 10
}
```

### Add New Environment
Edit [`modules/rds/variables.tf`](modules/rds/variables.tf):

```hcl
variable "environment" {
  validation {
    condition     = contains(["qa", "staging", "prod"], var.environment)  # Added "staging"
    error_message = "Environment must be qa, staging, or prod"
  }
}
```

Then update logic in `main.tf` to handle the new environment.

---

## Conclusion

This guardrail system ensures:
- ✅ **Compliance** - All deployments follow organizational policies
- ✅ **Safety** - Prevents misconfiguration before deployment
- ✅ **Consistency** - Same rules apply across all teams
- ✅ **Flexibility** - Allows overrides within policy limits
- ✅ **Transparency** - Clear error messages when policies are violated

The combination of environment-based defaults and precondition guardrails provides a robust framework for managing RDS deployments at scale.
