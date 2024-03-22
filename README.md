# Project Name
Migration d'une solution Business Intelligence vers le Cloud Azure

## Description

This project aims to migrate a Business Intelligence (BI) solution into the cloud. The BI solution, currently hosted on-premises, will be migrated to a cloud platform to leverage the benefits of scalability, flexibility, and cost-effectiveness offered by cloud computing.

## Table of Contents

- [Project Name](#project-name)
    - [Description](#description)
    - [Table of Contents](#table-of-contents)
    - [Getting Started](#getting-started)
        - [Prerequisites](#prerequisites)
        - [Usage](#usage)
        - [What is the content of the setup.ps1 script ?](#What-is-the-content-of-the-setup.ps1-script-?)  
    - [File Tree](#file-tree)
    - [Technologies Used](#technologies-used)
    - [Contact](#contact)


## Getting Started

These instructions will guide you on how to set up and run the migrated BI solution on the cloud.

### Prerequisites

- Cloud platform account (Azure)
- Azure Subscription: Ensure you have an active Azure subscription.

### Usage
- Firstly open the azure portal https://portal.azure.com/ and log in using your account
- Click on the small terminal icon on the top right corner to open a Powershell

![Alt text](powershell_icon.png) 

- Clone Repository: Clone this repository to your machine
```powershell
git clone https://github.com/amine-krout/procom-buisness-intelligence.git
```
- Run Script: Execute the setup.ps1 script in PowerShell. The script will guide you through the setup process.
```powershell
.\setup.ps1
```
- You can now import the pipeline template (you can check the "Guide de déploiment" file for the rest of the steps) 

### What is the content of the setup.ps1 script ? 
The script is a powershell script that performs the following actions when executed (it uses the powershell template setup.json) :
- Sets up prerequisites such as clearing the console and installing necessary PowerShell modules.
- Handles multiple Azure subscriptions if applicable.
- Prompts the user for a complex password for the SQL Database.
- Registers necessary Azure resource providers.
- Generates a unique random suffix for Azure resources.
- Finds an available region for deployment.
- Tests for subscription Azure SQL capacity constraints.
- Creates a resource group in the selected region.
- Creates a Synapse Analytics workspace within the resource group.
- Creates Azure SQL Server and Serverless SQL Database.
- Uploads CSV files to a specified storage container within the Data Lake Storage Gen2 account. 

## File tree
```arduino
├───data/
│   └───.csv files used during this project
├───setup.json
└───setup.ps1
```

## Technologies Used

- Cloud platform (Azure)
- BI tools (Power BI)
- Database systems (SQL Server)
- ETL tools (Azure Synapse Analytics)

## Contact

For any questions or inquiries, don't hesitate to contact us.
