# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse_name": "",
# META       "default_lakehouse_workspace_id": ""
# META     }
# META   }
# META }

# MARKDOWN ********************

# # Re-usable functions for Azure Active Directory

# CELL ********************

%run /common/keyvault-functions {"kvLinkedService": "keyvault01"}

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# PARAMETERS CELL ********************

tenandIdSecret = "<Azure Key Vault Secret for TenantID>"
servicePrincipalIdSecret = "<Azure Key Vault Secret for Service Principal ID>"
servicePrincipalSecret = "<Azure Key Vault Secret for Service Principal secret>"
authUrl = "https://login.windows.net"
resourceUrl = "https://database.windows.net/"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import adal



# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# # getBearerToken()

# CELL ********************

def getBearerToken():
    ############################################################################
    # getBearerToken
    # Returns a bearer token for a service principal AAD authentication
    #
    # Parameters:
    #       None
    #
    # Returns:
    #     Bearer Token  
    ############################################################################

    tenantId = getSecret(tenandIdSecret)
    servicePrincipalId = getSecret(servicePrincipalIdSecret)
    secret = getSecret(servicePrincipalSecret)

    assert tenantId is not None, "tenantId not specified"
    assert servicePrincipalId is not None, "servicePrincipalId not specified"
    assert secret is not None, "secret not specified"
    assert authUrl is not None, "authUrl not specified"
    assert resourceUrl is not None, "resourceUrl not specified"

    authority = authUrl + "/" + tenantId
    try:
        context = adal.AuthenticationContext(authority)
        token = context.acquire_token_with_client_credentials(resourceUrl, servicePrincipalId, secret)
        accessToken = token["accessToken"]
    except Exception as e:
        print("getBearerToken failed with exception:")
        raise e
    return accessToken

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
