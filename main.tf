terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  token = var.github_token
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
}

variable "repo_name" {
  description = "The GitHub repository name"
  type        = string
  default     = "my-repo"
}

variable "github_owner" {
  description = "GitHub organization or user"
  type        = string
  default     = "forcourses"
}

# Create GitHub repository
resource "github_repository" "repo" {
  name        = var.repo_name
  description = "Terraform-managed GitHub repository"
  visibility  = "private"
  has_issues  = true
  has_wiki    = false
  has_projects = false
  auto_init   = true
}

# Create the develop branch
resource "github_branch" "develop" {
  repository = var.repo_name
  branch     = "develop"
}

# Set develop as the default branch
resource "github_branch_default" "default" {
  repository = var.repo_name
  branch     = github_branch.develop.branch
}

# Add softservedata as a collaborator
resource "github_repository_collaborator" "collaborator" {
  repository = var.repo_name
  username   = "softservedata"
  permission = "push"
}

# Protect main branch
resource "github_branch_protection" "main" {
  repository_id                   = github_repository.repo.id
  pattern                         = "main"
  enforce_admins                  = true
  allows_deletions                = false
  require_conversation_resolution = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 1
  }
}

# Protect develop branch
resource "github_branch_protection" "develop" {
  repository_id                   = github_repository.repo.id
  pattern                         = "develop"
  enforce_admins                  = true
  allows_deletions                = false
  require_conversation_resolution = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 2
  }
}

# Assign softservedata as Code Owner for main branch
resource "github_repository_file" "codeowners" {
  repository          = var.repo_name
  file                = ".github/CODEOWNERS"
  content             = "* @softservedata"
  commit_message      = "Add CODEOWNERS file"
  branch              = github_branch.develop.branch
}

# Add Pull Request Template
resource "github_repository_file" "pull_request_template" {
  repository     = var.repo_name
  file          = ".github/pull_request_template.md"
  content       = <<EOT
## Describe your changes
## Issue ticket number and link

### Checklist before requesting a review:
- [ ] I have performed a self-review of my code
- [ ] If it is a core feature, I have added thorough tests
- [ ] Do we need to implement analytics?
- [ ] Will this be part of a product update? If yes, please write one phrase about this update
EOT
  commit_message = "Add pull request template"
  branch         = github_branch.develop.branch
}

# Add Deploy Key
resource "github_repository_deploy_key" "deploy_key" {
  title      = "DEPLOY_KEY"
  repository = var.repo_name
  key        = file("~/.ssh/id_rsa.pub") # Ensure the key exists
  read_only  = false
}

# Discord Webhook for PR Notifications
resource "github_repository_webhook" "discord" {
  repository = var.repo_name
  events     = ["pull_request"]

  configuration {
    url          = "https://discord.com/api/webhooks/YOUR_DISCORD_WEBHOOK"
    content_type = "json"
  }
}

# Store Terraform configuration in GitHub secrets
resource "github_actions_secret" "terraform_config" {
  repository      = var.repo_name
  secret_name     = "TERRAFORM"
  plaintext_value = file("main.tf")
}

# Create GitHub Actions Secret for PAT Token
resource "github_actions_secret" "pat_token" {
  repository      = var.repo_name
  secret_name     = "PAT"
  plaintext_value = var.github_token
}
