# GitHub Actions Runner Setup on Azure VMSS (OIDC Authentication)

This repository demonstrates the process of setting up and removing self-hosted GitHub Actions runners on Azure Virtual Machine Scale Sets (VMSS) using OIDC authentication.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation Process](#installation-process)
- [Removal Process](#removal-process)
- [Security Features](#security-features)
- [Resource Components](#resource-components)
- [Usage](#usage)
- [Key Components](#key-components)
- [Limitations and Considerations](#limitations-and-considerations)

## Overview

This POC showcases how to:
- Set up self-hosted GitHub Actions runners on Azure VMSS
- Implement secure authentication using OIDC
- Automatically scale runners based on demand
- Safely manage runner registration and deregistration

## Architecture

The solution consists of the following components:
- Azure Virtual Machine Scale Set (VMSS)
- Azure Key Vault for secure secret storage
- Managed Identity for OIDC authentication
- GitHub Actions runner installation scripts
- Runner cleanup and uninstallation scripts

## Prerequisites

- Azure subscription
- GitHub repository with admin access
- Azure CLI installed
- GitHub Personal Access Token (PAT) 

## Installation Process

### 1. Environment Setup
- Creates the runner root directory (`/opt/actions-runner`)
- Sets up logging to `/var/log/github-runner-install.log`
- Configures necessary permissions

### 2. Dependency Installation
Installs required packages:
- `curl` for downloading files
- `tar` for archive extraction
- `git` for repository access
- `jq` for JSON processing

### 3. Runner Download
- Downloads the GitHub Actions runner package (version 2.326.0)
- Extracts the package to the runner directory

### 4. OIDC Authentication Setup
- Retrieves the Azure Managed Identity Client ID from Instance Metadata Service (IMDS)
- Obtains an OIDC token for GitHub authentication using the managed identity

### 5. Runner Registration
- Gets a Personal Access Token (PAT) from Azure Key Vault
- Uses the PAT to obtain a temporary registration token from GitHub
- Configures the runner in unattended mode with:
  - Repository URL (https://github.com/Yogesh3052/azure-oidc-vmss-runners-poc)
  - Registration token

### 6. Service Installation
- Installs the runner as a systemd service
- Starts the service

## Removal Process

### 1. Service Cleanup
- Stops the runner service
- Uninstalls the systemd service

### 2. GitHub Deregistration
- Retrieves the PAT from Azure Key Vault
- Identifies the runner by hostname in GitHub's runner list
- Removes the runner from GitHub's registry

### 3. File Cleanup
- Deletes all runner files from `/opt/actions-runner`

## Security Features

- OIDC authentication for enhanced security
- Secure secret management using Azure Key Vault
- Managed Identity for Azure resource access
- Automatic cleanup of deregistered runners

## Resource Components

The POC includes:
- Network Interface configuration
- Managed Identity setup
- Key Vault integration
- VMSS configuration
- Load Balancer setup

## Usage

1. Configure Azure resources:
   - Set up VMSS
   - Configure Managed Identity
   - Create Key Vault and store GitHub PAT

2. Update configuration:
   - Modify repository details in scripts
   - Adjust VMSS settings as needed

3. Deploy and test:
   - Deploy VMSS instances
   - Verify runner registration
   - Test GitHub Actions workflows

## Limitations and Considerations

- Currently configured for a specific repository
- Requires manual PAT rotation
- Scale set limitations apply as per Azure quotas

## Key Components

### Authentication Flow
- Azure Managed Identity provides OIDC tokens
- Key Vault stores and provides the GitHub PAT securely
- IMDS (Instance Metadata Service) provides identity information

### Security Features
- Uses Azure Managed Identity instead of storing credentials
- Temporary registration tokens minimize exposure
- Root directory has strict permissions

### Logging
- Detailed logs at `/var/log/github-runner-install.log` (installation)
- Detailed logs at `/var/log/github-runner-uninstall.log` (removal)

### Error Handling
- Script fails fast with `set -e`
- Comprehensive error checking for each step
- Graceful handling of missing components during removal

## Contributing

Feel free to submit issues and enhancement requests!
